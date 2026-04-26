package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"
)

const (
	SERVER_NAME    = "LmaoboxContext"
	SERVER_VERSION = "1.0.6"
)

type BundleRequest struct {
	ProjectDir      string `json:"projectDir"`
	EntryFile       string `json:"entryFile,omitempty"`
	BundleOutputDir string `json:"bundleOutputDir,omitempty"`
	DeployDir       string `json:"deployDir,omitempty"`
}

type LuaModule struct {
	FilePath string
	Content  string
	Requires []string
}

type BundleContext struct {
	ProjectDir  string
	SearchPaths []string
	Modules     map[string]*LuaModule
	Visited     map[string]bool
	Stack       map[string]bool
}

// LineMapEntry maps a contiguous range of lines in the bundled file back to
// a single source file starting at SourceStart (always 1).
type LineMapEntry struct {
	BundledStart int    `json:"bundledStart"` // first bundled line (1-based, inclusive)
	BundledEnd   int    `json:"bundledEnd"`   // last bundled line (1-based, inclusive)
	SourceFile   string `json:"sourceFile"`   // absolute path to source file
	SourceStart  int    `json:"sourceStart"`  // source line that BundledStart maps to (always 1)
}

// BundleLineMap is written as JSON next to the bundle file (<bundle>.map).
type BundleLineMap struct {
	BundleFile string         `json:"bundleFile"` // basename of the bundle
	ProjectDir string         `json:"projectDir"` // absolute project directory
	Entries    []LineMapEntry `json:"entries"`
}

type luacheckState struct {
	mu         sync.RWMutex
	ready      bool
	installing bool
	status     string
	lastError  string
}

var globalLuacheckState = &luacheckState{}
var preferLuaLanguageServer bool

func main() {
	preferLuaLanguageServer = hasArg("--prefer-lua-ls") || strings.EqualFold(strings.TrimSpace(os.Getenv("LMAOBOX_LINT_PROVIDER")), "lua-ls")

	// Ensure dependencies are installed before starting server
	if err := ensureDependencies(); err != nil {
		log.Fatalf("Failed to initialize dependencies: %v", err)
	}

	// Create MCP server
	s := server.NewMCPServer(
		SERVER_NAME,
		SERVER_VERSION,
	)

	// Add bundle tool
	bundleTool := mcp.NewTool(
		"bundle",
		mcp.WithDescription("Bundle and deploy Lua to %LOCALAPPDATA%/lua. Provide path to folder containing Main.lua or main.lua (case insensitive). That folder IS the bundle root - all require() calls resolve from there."),
		mcp.WithString("projectDir",
			mcp.Required(),
			mcp.Description("Path to folder containing Main.lua or main.lua. ABSOLUTE paths recommended. This folder becomes the bundle root. MUST contain Main.lua/main.lua unless entryFile is specified."),
		),
		mcp.WithString("entryFile",
			mcp.Description("Entry file name only (not path). Defaults to Main.lua (case-insensitive). If not Main.lua, only that file deploys (no bundling)."),
		),
		mcp.WithString("bundleOutputDir",
			mcp.Description("Override for build output. Can be absolute or relative to projectDir. Defaults to projectDir/build."),
		),
		mcp.WithString("deployDir",
			mcp.Description("Override deployment target. Can be absolute or relative to projectDir. Defaults to %LOCALAPPDATA%/lua."),
		),
	)

	s.AddTool(bundleTool, handleBundle)

	// Add luacheck tool
	luacheckTool := mcp.NewTool(
		"luacheck",
		mcp.WithDescription("Validate Lua file syntax and optionally test bundling. Fast syntax check using Lua 5.4+ compiler (supports modern syntax like & operator) OR test if file bundles correctly without deploying."),
		mcp.WithString("filePath",
			mcp.Required(),
			mcp.Description("Absolute path to .lua file to check. Can be a single file or Main.lua for bundle validation."),
		),
		mcp.WithBoolean("checkBundle",
			mcp.Description("If true, test if file/project bundles correctly (dry-run without deploy). If false (default), only run syntax check with luac."),
		),
	)

	s.AddTool(luacheckTool, handleLuacheck)

	// Add get_types tool
	getTypesTool := mcp.NewTool(
		"get_types",
		mcp.WithDescription("Look up Lmaobox Lua API function signature, parameters, return types and required constants for an exact symbol name. Use this when you already know the symbol (e.g. 'engine.TraceLine', 'draw.Color'). If not found, returns did_you_mean suggestions. For unknown symbols use smart_search first."),
		mcp.WithString("symbol",
			mcp.Required(),
			mcp.Description("Exact Lmaobox API symbol name. Use dot notation for namespaced symbols: 'engine.TraceLine', 'draw.Color', 'Entity.GetHealth', 'E_TFCond'. Case-sensitive for best results."),
		),
	)

	s.AddTool(getTypesTool, handleGetTypes)

	// Add get_smart_context tool
	getSmartContextTool := mcp.NewTool(
		"get_smart_context",
		mcp.WithDescription("Get full usage documentation for a Lmaobox Lua API symbol: signature, description, parameters, return values, code examples and usage patterns. Always call this BEFORE writing any API call to understand correct usage, parameter types and gotchas. Returns richer info than get_types. If symbol is unknown, use smart_search first, then call this with the exact match."),
		mcp.WithString("symbol",
			mcp.Required(),
			mcp.Description("Exact Lmaobox API symbol name. Use dot notation: 'engine.TraceLine', 'draw.Color', 'callbacks.CreateMove'. get_smart_context will also try fuzzy fallbacks."),
		),
	)

	s.AddTool(getSmartContextTool, handleGetSmartContext)

	// Add smart_search tool
	smartSearchTool := mcp.NewTool(
		"smart_search",
		mcp.WithDescription("Fuzzy-search the Lmaobox Lua API when you don't know the exact symbol name. Returns ranked symbols with kind (function/constant/class), section (library/class/constants), description and signature. Use this to: (1) discover API when unsure of name, (2) recover from misspellings, (3) explore what's available for a topic. After finding matches, use get_smart_context with the exact symbol for full docs."),
		mcp.WithString("query",
			mcp.Required(),
			mcp.Description("Natural language or partial name search. Examples: 'player health', 'trace line', 'draw text', 'get velocity', 'local player', 'shoot'. Fuzzy matching handles typos."),
		),
		mcp.WithNumber("limit",
			mcp.Description("Max results to return (1-50). Default 15."),
		),
	)

	s.AddTool(smartSearchTool, handleSmartSearch)

	// Add traceback tool
	tracebackTool := mcp.NewTool(
		"traceback",
		mcp.WithDescription("Map a line number in a bundled Lua file back to its original source file and line. Use this when Lmaobox reports an error with a bundled-file line number to instantly find the original source location without manually scanning the merged file."),
		mcp.WithString("bundleFile",
			mcp.Required(),
			mcp.Description("Absolute path to the bundled .lua file (e.g. /path/to/project/build/Main.lua) OR absolute path to the project directory (will look for build/Main.lua). A .map file must exist next to the bundle (created automatically by the bundle tool)."),
		),
		mcp.WithNumber("line",
			mcp.Required(),
			mcp.Description("Line number in the bundled file to resolve (1-based)."),
		),
	)

	s.AddTool(tracebackTool, handleTraceback)

	// Start server
	if err := server.ServeStdio(s); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}

func handleBundle(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
	// Parse arguments from request
	projectDir, ok := req.Params.Arguments["projectDir"].(string)
	if !ok || projectDir == "" {
		return mcp.NewToolResultError("projectDir is required"), nil
	}

	entryFile, _ := req.Params.Arguments["entryFile"].(string)
	bundleOutputDir, _ := req.Params.Arguments["bundleOutputDir"].(string)
	deployDir, _ := req.Params.Arguments["deployDir"].(string)

	// Create timeout context (30 seconds)
	bundleCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()

	// Find entry file if not specified
	if entryFile == "" {
		var err error
		entryFile, err = findEntryFile(projectDir)
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Failed to find entry file: %v", err)), nil
		}
	}

	// Use native Go bundling instead of Node.js
	bundleResult, err := bundleLuaProject(bundleCtx, projectDir, entryFile, bundleOutputDir, deployDir)
	if err != nil {
		if bundleCtx.Err() == context.DeadlineExceeded {
			return mcp.NewToolResultError("Bundle operation timed out after 30 seconds. This usually indicates:\n1. Circular dependency loop\n2. Very large project (try splitting into smaller modules)\n3. Invalid require() paths causing infinite resolution\nCheck your dependencies for cycles and fix require() paths."), nil
		}
		return mcp.NewToolResultError(fmt.Sprintf("Bundle failed: %v", err)), nil
	}

	return mcp.NewToolResultText(fmt.Sprintf("Bundle successful:\n%s", bundleResult)), nil
}

func handleLuacheck(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
	// Parse arguments from request
	filePath, ok := req.Params.Arguments["filePath"].(string)
	if !ok || filePath == "" {
		return mcp.NewToolResultError("filePath is required"), nil
	}

	checkBundle, _ := req.Params.Arguments["checkBundle"].(bool)

	// Create timeout context (10 seconds for syntax check, 30 for bundle check)
	timeout := 10 * time.Second
	if checkBundle {
		timeout = 30 * time.Second
	}

	checkCtx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()

	if checkBundle {
		// Test bundle (dry run) using native Go implementation
		projectDir := filepath.Dir(filePath)
		entryFile := filepath.Base(filePath)

		// Perform dry-run bundle check
		err := validateBundleStructure(checkCtx, projectDir, entryFile)
		if err != nil {
			if checkCtx.Err() == context.DeadlineExceeded {
				return mcp.NewToolResultError("Bundle check timed out after 30 seconds"), nil
			}
			return mcp.NewToolResultError(fmt.Sprintf("Bundle check failed: %v", err)), nil
		}

		return mcp.NewToolResultText("✓ Bundle structure is valid and can be bundled successfully"), nil
	} else {
		if err := validateLuaSyntax(checkCtx, filePath); err != nil {
			if checkCtx.Err() == context.DeadlineExceeded {
				return mcp.NewToolResultError("Syntax check timed out after 10 seconds"), nil
			}
			return mcp.NewToolResultError(err.Error()), nil
		}

		advisories, err := collectLuaAdvisoryWarnings(filePath)
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("warning scan failed: %v", err)), nil
		}
		if len(advisories) > 0 {
			result := formatLuaValidationSuccessWithWarnings(advisories)
			if statusText := luacheckNotReadyStatusText(); statusText != "" {
				result = result + "\n\n" + statusText
			}
			return mcp.NewToolResultText(result), nil
		}

		result := "✓ Lua syntax is valid and passed Zero-Mutation callback policy"
		if statusText := luacheckNotReadyStatusText(); statusText != "" {
			result = result + "\n\n" + statusText
		}

		return mcp.NewToolResultText(result), nil
	}
}

func handleGetTypes(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
	symbol, ok := req.Params.Arguments["symbol"].(string)
	if !ok || symbol == "" {
		return mcp.NewToolResultError("symbol is required"), nil
	}

	// Search for type information
	typeInfo, err := findTypeDefinition(symbol)
	if err != nil {
		return mcp.NewToolResultError(fmt.Sprintf("Failed to find types: %v", err)), nil
	}

	if typeInfo == "" {
		return mcp.NewToolResultText(fmt.Sprintf(
			"## get_types: No definition found for `%s`\n\n"+
				"**Suggestions:**\n"+
				"- Check spelling/capitalization (`engine.TraceLine` not `Engine.Traceline`)\n"+
				"- Try the parent namespace (e.g. `draw` instead of `draw.Color`)\n"+
				"- Use `smart_search` with a keyword to find the correct name\n"+
				"- Use `get_smart_context` if you want examples and usage patterns",
			symbol)), nil
	}

	return mcp.NewToolResultText(fmt.Sprintf("## get_types: `%s`\n\n%s", symbol, typeInfo)), nil
}

func handleGetSmartContext(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
	symbol, ok := req.Params.Arguments["symbol"].(string)
	if !ok || symbol == "" {
		return mcp.NewToolResultError("symbol is required"), nil
	}

	// Search for smart context
	contextInfo, err := findSmartContext(symbol)
	if err != nil {
		return mcp.NewToolResultError(fmt.Sprintf("Failed to find smart context: %v", err)), nil
	}

	if contextInfo == "" {
		// Try to fall back to type definition
		typeInfo, _ := findTypeDefinition(symbol)
		if typeInfo != "" {
			return mcp.NewToolResultText(fmt.Sprintf(
				"## get_smart_context: `%s` (types fallback)\n\nNo curated context file found, but type definition is available:\n\n%s\n\n"+
					"---\n**Tip:** Use `smart_search` with keywords to find the exact symbol name.",
				symbol, typeInfo)), nil
		}
		return mcp.NewToolResultText(fmt.Sprintf(
			"## get_smart_context: Not found for `%s`\n\n"+
				"**Try:**\n"+
				"- Variations: `draw.Color`, `Color`, `draw`\n"+
				"- `smart_search` with a keyword to discover the correct name\n"+
				"- `get_types` for raw type signatures",
			symbol)), nil
	}

	return mcp.NewToolResultText(fmt.Sprintf("## get_smart_context: `%s`\n\n%s", symbol, contextInfo)), nil
}

// Native Go bundling functions

func bundleLuaProject(ctx context.Context, projectDir, entryFile, bundleOutputDir, deployDir string) (string, error) {
	// Resolve paths
	projectDirAbs, err := filepath.Abs(projectDir)
	if err != nil {
		return "", fmt.Errorf("invalid project directory: %v", err)
	}

	entryFilePath := filepath.Join(projectDirAbs, entryFile)
	if _, err := os.Stat(entryFilePath); err != nil {
		return "", fmt.Errorf("entry file not found: %s", entryFilePath)
	}

	// Check if this is just a single file deployment (non-Main.lua)
	if !strings.EqualFold(entryFile, "main.lua") {
		return deploySingleFile(ctx, entryFilePath, deployDir)
	}

	// Perform bundling for Main.lua
	bundleCtx := &BundleContext{
		ProjectDir:  projectDirAbs,
		SearchPaths: []string{projectDirAbs},
		Modules:     make(map[string]*LuaModule),
		Visited:     make(map[string]bool),
		Stack:       make(map[string]bool),
	}

	// Validate all Lua files first
	if err := validateAllLuaFiles(ctx, projectDirAbs); err != nil {
		return "", fmt.Errorf("syntax validation failed: %v", err)
	}

	// Build dependency tree
	if err := buildDependencyTree(ctx, bundleCtx, entryFilePath); err != nil {
		return "", fmt.Errorf("dependency analysis failed: %v", err)
	}

	// Generate bundled output
	bundledContent, mapEntries, err := generateBundledLua(bundleCtx, entryFilePath)
	if err != nil {
		return "", fmt.Errorf("bundle generation failed: %v", err)
	}

	// Write bundle to output directory
	buildDir := bundleOutputDir
	if buildDir == "" {
		buildDir = filepath.Join(projectDirAbs, "build")
	}
	bundlePath := filepath.Join(buildDir, "Main.lua")

	if err := os.MkdirAll(filepath.Dir(bundlePath), 0755); err != nil {
		return "", fmt.Errorf("failed to create build directory: %v", err)
	}

	if err := os.WriteFile(bundlePath, []byte(bundledContent), 0644); err != nil {
		return "", fmt.Errorf("failed to write bundle: %v", err)
	}

	// Final validation: run luac on the bundled output to catch any merge-time
	// syntax issues. Policy checks and luacheck already ran on each source file.
	if luacErr := runLuacOnly(ctx, bundlePath); luacErr != nil {
		return "", fmt.Errorf("bundled file failed final syntax check: %v", luacErr)
	}

	// Write line-map alongside the bundle for traceback lookups
	lineMap := BundleLineMap{
		BundleFile: filepath.Base(bundlePath),
		ProjectDir: projectDirAbs,
		Entries:    mapEntries,
	}
	if mapData, merr := json.Marshal(lineMap); merr == nil {
		if werr := os.WriteFile(bundlePath+".map", mapData, 0644); werr != nil {
			log.Printf("warning: failed to write bundle map file %s.map: %v (traceback tool will not work for this bundle)", bundlePath, werr)
		}
	} else {
		log.Printf("warning: failed to serialize bundle map: %v (traceback tool will not work for this bundle)", merr)
	}

	// Deploy bundle
	deployPath, err := deployBundle(ctx, bundlePath, deployDir)
	if err != nil {
		return "", fmt.Errorf("deployment failed: %v", err)
	}

	return fmt.Sprintf("Bundle created: %s\nDeployed to: %s\nModules bundled: %d", bundlePath, deployPath, len(bundleCtx.Modules)), nil
}

func deploySingleFile(ctx context.Context, filePath, deployDir string) (string, error) {
	// Validate syntax first
	if err := validateLuaSyntax(ctx, filePath); err != nil {
		return "", fmt.Errorf("syntax error: %v", err)
	}

	// Deploy single file
	deployPath, err := deployBundle(ctx, filePath, deployDir)
	if err != nil {
		return "", fmt.Errorf("deployment failed: %v", err)
	}

	return fmt.Sprintf("Single file deployed to: %s", deployPath), nil
}

func validateAllLuaFiles(ctx context.Context, projectDir string) error {
	var files []string
	err := filepath.WalkDir(projectDir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return nil // Skip inaccessible files
		}
		if d.IsDir() {
			// Skip build and hidden directories
			base := filepath.Base(path)
			if base == "build" || base == "node_modules" || strings.HasPrefix(base, ".") {
				return filepath.SkipDir
			}
			return nil
		}
		if strings.HasSuffix(path, ".lua") {
			files = append(files, path)
		}
		return nil
	})
	if err != nil {
		return err
	}

	for _, file := range files {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
		}
		if err := validateLuaSyntax(ctx, file); err != nil {
			relPath, _ := filepath.Rel(projectDir, file)
			return fmt.Errorf("syntax error in %s: %v", relPath, err)
		}
	}

	return nil
}

func buildDependencyTree(ctx context.Context, bundleCtx *BundleContext, entryFile string) error {
	return resolveDependencies(ctx, bundleCtx, entryFile)
}

func resolveDependencies(ctx context.Context, bundleCtx *BundleContext, filePath string) error {
	absPath, err := filepath.Abs(filePath)
	if err != nil {
		return err
	}

	// Check for circular dependencies
	if bundleCtx.Stack[absPath] {
		return fmt.Errorf("circular dependency detected involving: %s", absPath)
	}

	// Skip if already processed
	if bundleCtx.Visited[absPath] {
		return nil
	}

	bundleCtx.Stack[absPath] = true
	defer func() {
		delete(bundleCtx.Stack, absPath)
		bundleCtx.Visited[absPath] = true
	}()

	// Read and parse file
	content, err := os.ReadFile(absPath)
	if err != nil {
		return fmt.Errorf("failed to read %s: %v", absPath, err)
	}

	requires := extractRequires(string(content))
	module := &LuaModule{
		FilePath: absPath,
		Content:  string(content),
		Requires: requires,
	}
	bundleCtx.Modules[absPath] = module

	// Resolve all dependencies
	for _, req := range requires {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
		}

		depPath, err := resolveModulePath(req, bundleCtx.SearchPaths)
		if err != nil {
			// Check if it's a global module (skip if exists in deploy dir)
			if isGlobalModule(req, bundleCtx.ProjectDir) {
				continue
			}
			return fmt.Errorf("cannot resolve require('%s') from %s: %v", req, absPath, err)
		}

		if err := resolveDependencies(ctx, bundleCtx, depPath); err != nil {
			return err
		}
	}

	return nil
}

func extractRequires(content string) []string {
	re := regexp.MustCompile(`require\s*\(\s*["']([^"']+)["']\s*\)`)
	matches := re.FindAllStringSubmatch(content, -1)
	var requires []string
	for _, match := range matches {
		if len(match) > 1 {
			requires = append(requires, match[1])
		}
	}
	return requires
}

func resolveModulePath(moduleName string, searchPaths []string) (string, error) {
	// Convert dot notation to path separators
	modulePath := strings.ReplaceAll(moduleName, ".", string(filepath.Separator))

	for _, searchPath := range searchPaths {
		candidates := []string{
			filepath.Join(searchPath, modulePath+".lua"),
			filepath.Join(searchPath, modulePath, "init.lua"),
		}

		for _, candidate := range candidates {
			if _, err := os.Stat(candidate); err == nil {
				return candidate, nil
			}
		}
	}

	return "", fmt.Errorf("module not found: %s", moduleName)
}

func isGlobalModule(moduleName, projectDir string) bool {
	deployDir := resolveDeployDir()
	modulePath := strings.ReplaceAll(moduleName, ".", string(filepath.Separator))

	candidates := []string{
		filepath.Join(deployDir, modulePath+".lua"),
		filepath.Join(deployDir, modulePath, "init.lua"),
	}

	for _, candidate := range candidates {
		if _, err := os.Stat(candidate); err == nil {
			return true
		}
	}
	return false
}

// countLuaLines returns the number of logical lines in content.
// Files that end with "\n" have one line per "\n"; files without a trailing
// newline have one additional line for the last unterminated chunk.
func countLuaLines(content string) int {
	n := strings.Count(content, "\n")
	if len(content) > 0 && !strings.HasSuffix(content, "\n") {
		n++
	}
	return n
}

func generateBundledLua(bundleCtx *BundleContext, entryFile string) (string, []LineMapEntry, error) {
	var builder strings.Builder
	var mapEntries []LineMapEntry
	currentLine := 1 // next output line to be written (1-based)

	writeln := func(s string) {
		builder.WriteString(s)
		currentLine += strings.Count(s, "\n")
	}

	bundledModuleNames := make(map[string]bool)
	modulePaths := sortedModulePaths(bundleCtx.Modules)

	// Add bundle header (infrastructure – not mapped to any source file)
	writeln("-- Bundled Lua generated by Lmaobox Context Server\n")
	writeln("-- Entry point: " + filepath.Base(entryFile) + "\n\n")
	writeln("local __bundle_modules = {}\n")
	writeln("local __bundle_loaded = {}\n\n")
	writeln("local function __bundle_require(name)\n")
	writeln("    local loader = __bundle_modules[name]\n")
	writeln("    if loader == nil then\n")
	writeln("        return require(name)\n")
	writeln("    end\n\n")
	writeln("    local cached = __bundle_loaded[name]\n")
	writeln("    if cached ~= nil then\n")
	writeln("        return cached\n")
	writeln("    end\n\n")
	writeln("    local loaded = loader()\n")
	writeln("    if loaded == nil then\n")
	writeln("        loaded = true\n")
	writeln("    end\n\n")
	writeln("    __bundle_loaded[name] = loaded\n")
	writeln("    return loaded\n")
	writeln("end\n\n")

	for _, filePath := range modulePaths {
		if filePath == entryFile {
			continue
		}
		moduleName := getModuleName(filePath, bundleCtx.ProjectDir)
		bundledModuleNames[moduleName] = true
	}

	// Add all modules except entry file
	for _, filePath := range modulePaths {
		module := bundleCtx.Modules[filePath]
		if filePath != entryFile {
			moduleName := getModuleName(filePath, bundleCtx.ProjectDir)
			writeln(fmt.Sprintf("-- Module: %s\n", moduleName))
			writeln(fmt.Sprintf("__bundle_modules[%q] = function()\n", moduleName))

			transformed := transformBundledRequires(module.Content, bundledModuleNames)
			lineCount := countLuaLines(transformed)
			mapEntries = append(mapEntries, LineMapEntry{
				BundledStart: currentLine,
				BundledEnd:   currentLine + lineCount - 1,
				SourceFile:   filePath,
				SourceStart:  1,
			})
			writeln(transformed)
			writeln("\nend\n\n")
		}
	}

	// Add entry file content
	if entryModule, exists := bundleCtx.Modules[entryFile]; exists {
		writeln("-- Entry point\n")

		transformed := transformBundledRequires(entryModule.Content, bundledModuleNames)
		lineCount := countLuaLines(transformed)
		mapEntries = append(mapEntries, LineMapEntry{
			BundledStart: currentLine,
			BundledEnd:   currentLine + lineCount - 1,
			SourceFile:   entryFile,
			SourceStart:  1,
		})
		writeln(transformed)
	}

	return builder.String(), mapEntries, nil
}

func sortedModulePaths(modules map[string]*LuaModule) []string {
	paths := make([]string, 0, len(modules))
	for filePath := range modules {
		paths = append(paths, filePath)
	}
	sort.Strings(paths)
	return paths
}

func transformBundledRequires(content string, bundledModuleNames map[string]bool) string {
	re := regexp.MustCompile(`require\s*\(\s*["']([^"']+)["']\s*\)`)

	return re.ReplaceAllStringFunc(content, func(match string) string {
		submatches := re.FindStringSubmatch(match)
		if len(submatches) < 2 {
			return match
		}

		moduleName := submatches[1]
		if !bundledModuleNames[moduleName] {
			return match
		}

		return fmt.Sprintf("__bundle_require(%q)", moduleName)
	})
}

func getModuleName(filePath, projectDir string) string {
	relPath, _ := filepath.Rel(projectDir, filePath)
	relPath = strings.TrimSuffix(relPath, ".lua")
	if strings.HasSuffix(relPath, "init") {
		relPath = filepath.Dir(relPath)
	}
	return strings.ReplaceAll(relPath, string(filepath.Separator), ".")
}

func deployBundle(ctx context.Context, sourcePath, deployDir string) (string, error) {
	targetDir := deployDir
	if targetDir == "" {
		targetDir = resolveDeployDir()
	}

	if err := os.MkdirAll(targetDir, 0755); err != nil {
		return "", fmt.Errorf("failed to create deploy directory: %v", err)
	}

	fileName := filepath.Base(sourcePath)
	deployPath := filepath.Join(targetDir, fileName)

	sourceData, err := os.ReadFile(sourcePath)
	if err != nil {
		return "", fmt.Errorf("failed to read source: %v", err)
	}

	if err := os.WriteFile(deployPath, sourceData, 0644); err != nil {
		return "", fmt.Errorf("failed to write to deploy path: %v", err)
	}

	return deployPath, nil
}

func resolveDeployDir() string {
	localAppData := os.Getenv("LOCALAPPDATA")
	if localAppData != "" {
		return filepath.Join(localAppData, "lua")
	}
	// Fallback for non-Windows systems
	homeDir, _ := os.UserHomeDir()
	return filepath.Join(homeDir, ".local", "share", "lua")
}

// Helper functions

func findEntryFile(projectDir string) (string, error) {
	candidates := []string{"Main.lua", "main.lua", "MAIN.LUA"}

	for _, candidate := range candidates {
		fullPath := filepath.Join(projectDir, candidate)
		if _, err := os.Stat(fullPath); err == nil {
			return candidate, nil
		}
	}

	return "", fmt.Errorf("no Main.lua found in project directory")
}

func validateBundleStructure(ctx context.Context, projectDir, entryFile string) error {
	// Resolve paths
	projectDirAbs, err := filepath.Abs(projectDir)
	if err != nil {
		return fmt.Errorf("invalid project directory: %v", err)
	}

	entryFilePath := filepath.Join(projectDirAbs, entryFile)
	if _, err := os.Stat(entryFilePath); err != nil {
		return fmt.Errorf("entry file not found: %s", entryFilePath)
	}

	// For non-Main.lua files, just validate syntax
	if !strings.EqualFold(entryFile, "main.lua") {
		return validateLuaSyntax(ctx, entryFilePath)
	}

	// Create bundle context for dependency validation
	bundleCtx := &BundleContext{
		ProjectDir:  projectDirAbs,
		SearchPaths: []string{projectDirAbs},
		Modules:     make(map[string]*LuaModule),
		Visited:     make(map[string]bool),
		Stack:       make(map[string]bool),
	}

	// Validate all Lua files
	if err := validateAllLuaFiles(ctx, projectDirAbs); err != nil {
		return fmt.Errorf("syntax validation failed: %v", err)
	}

	// Test dependency resolution without writing files
	if err := buildDependencyTree(ctx, bundleCtx, entryFilePath); err != nil {
		return fmt.Errorf("dependency analysis failed: %v", err)
	}

	return nil
}

func validateLuaSyntax(ctx context.Context, filePath string) error {
	luacPath := findLuac()
	if luacPath == "" {
		return fmt.Errorf("Lua compiler not found. Install Lua 5.4+ from https://luabinaries.sourceforge.net/")
	}

	cmd := exec.CommandContext(ctx, luacPath, "-p", filePath)
	output, err := cmd.CombinedOutput()

	if err != nil {
		return fmt.Errorf("syntax error: %s", string(output))
	}

	violations, err := checkLuaCallbackMutationPolicy(filePath, defaultLboxMutationPolicy)
	if err != nil {
		return fmt.Errorf("policy check failed: %v", err)
	}
	if len(violations) > 0 {
		return fmt.Errorf(formatLuaPolicyViolations(filePath, violations))
	}

	// Additional lint pass: run luacheck. Since we ensure luacheck is installed
	// at startup, this should never fail with "not found". If it does, it's a
	// runtime error that should be reported.
	luacheckIssues, lerr := runLuacheck(ctx, filePath)
	if lerr != nil {
		if errors.Is(lerr, errLuacheckNotFound) {
			// luacheck not installed — policy check already passed, so succeed gracefully
			return nil
		}
		return fmt.Errorf("luacheck failed: %v", lerr)
	}
	if len(luacheckIssues) > 0 {
		return fmt.Errorf(formatLuacheckIssues(filePath, luacheckIssues))
	}

	return nil
}

func formatLuacheckIssues(filePath string, issues []string) string {
	var builder strings.Builder
	builder.WriteString("Luacheck reported issue(s):\n")
	builder.WriteString(fmt.Sprintf("file: %s\n", filePath))

	for _, issue := range issues {
		builder.WriteString(fmt.Sprintf("- %s\n", issue))
	}

	return builder.String()
}

func formatLuaValidationSuccessWithWarnings(warnings []string) string {
	var builder strings.Builder
	builder.WriteString("✓ Lua syntax is valid and passed Zero-Mutation callback policy\n")
	builder.WriteString("\nStyle warning(s):\n")
	for _, warning := range warnings {
		builder.WriteString(fmt.Sprintf("- %s\n", warning))
	}
	return builder.String()
}

var errLuacheckNotFound = errors.New("luacheck not found")

// runLuacheck executes luacheck on a single file and returns any reported lines
// as a slice of strings. If luacheck is not installed this returns
// errLuacheckNotFound.
func runLuacheck(ctx context.Context, filePath string) ([]string, error) {
	luacheckPath := findLuacheck()
	if luacheckPath == "" {
		return nil, errLuacheckNotFound
	}

	// Use --no-color to keep output parseable. Luacheck exits non-zero when
	// issues are present; still capture stdout/stderr and parse any output.
	cmd := exec.CommandContext(ctx, luacheckPath, "--no-color", "--codes", filePath)
	output, err := cmd.CombinedOutput()
	if len(output) == 0 && err != nil {
		return nil, fmt.Errorf("luacheck execution failed: %v", err)
	}

	raw := strings.TrimSpace(string(output))
	if raw == "" {
		return nil, nil
	}

	lines := strings.Split(raw, "\n")
	issues := make([]string, 0, len(lines))
	for _, l := range lines {
		l = strings.TrimSpace(l)
		if l == "" {
			continue
		}
		issues = append(issues, l)
	}

	return issues, nil
}

func searchRoots() []string {
	seen := make(map[string]bool)
	roots := make([]string, 0, 3)

	addRoot := func(root string) {
		if root == "" {
			return
		}
		absRoot, err := filepath.Abs(root)
		if err != nil {
			absRoot = root
		}
		if seen[absRoot] {
			return
		}
		seen[absRoot] = true
		roots = append(roots, absRoot)
	}

	if exePath, err := os.Executable(); err == nil {
		addRoot(filepath.Dir(exePath))
	}
	addRoot(filepath.Dir(os.Args[0]))
	if cwd, err := os.Getwd(); err == nil {
		addRoot(cwd)
	}

	return roots
}

func findExistingRepoPath(parts ...string) string {
	roots := searchRoots()
	for _, root := range roots {
		candidate := filepath.Join(append([]string{root}, parts...)...)
		if _, err := os.Stat(candidate); err == nil {
			return candidate
		}
	}

	if len(roots) > 0 {
		return filepath.Join(append([]string{roots[0]}, parts...)...)
	}

	return filepath.Join(parts...)
}

func resolveSmartContextRoot() string {
	preferred := findExistingRepoPath("smart_context")
	preferredAPI := filepath.Join(preferred, "lmaobox_lua_api")
	if info, err := os.Stat(preferredAPI); err == nil && info.IsDir() {
		return preferred
	}

	legacy := findExistingRepoPath("data", "smart_context")
	return legacy
}

func extractTypeSignature(lines []string, symbol string) (string, int) {
	shortSymbol := symbol
	if dot := strings.LastIndex(symbol, "."); dot >= 0 {
		shortSymbol = symbol[dot+1:]
	}

	hasNamespace := strings.Contains(symbol, ".")
	patternFull := regexp.MustCompile(`\b` + regexp.QuoteMeta(symbol) + `\b`)
	patternShort := regexp.MustCompile(`\b` + regexp.QuoteMeta(shortSymbol) + `\b`)

	for index, raw := range lines {
		trimmed := strings.TrimSpace(raw)
		if strings.HasPrefix(trimmed, "---") || strings.HasPrefix(trimmed, "--") {
			continue
		}
		if strings.Contains(trimmed, "function") {
			matchesSymbol := hasNamespace && patternFull.MatchString(trimmed)
			matchesShort := !hasNamespace && patternShort.MatchString(trimmed)
			if matchesSymbol || matchesShort {
				return strings.TrimSuffix(trimmed, " end"), index
			}
		}
	}

	if !hasNamespace {
		for index, raw := range lines {
			trimmed := strings.TrimSpace(raw)
			if strings.HasPrefix(trimmed, "---") || strings.HasPrefix(trimmed, "--") {
				continue
			}
			if patternShort.MatchString(trimmed) {
				return strings.TrimSuffix(trimmed, " end"), index
			}
		}
	}

	return "", -1
}

func extractTypeDocblock(lines []string, signatureIndex int) string {
	if signatureIndex < 0 {
		return ""
	}

	docLines := make([]string, 0)
	for index := signatureIndex - 1; index >= 0; index-- {
		trimmed := strings.TrimSpace(lines[index])
		if strings.HasPrefix(trimmed, "---") || strings.HasPrefix(trimmed, "--") {
			cleaned := strings.TrimSpace(strings.TrimLeft(trimmed, "-"))
			docLines = append(docLines, cleaned)
			continue
		}
		if trimmed == "" {
			docLines = append(docLines, "")
			continue
		}
		break
	}

	if len(docLines) == 0 {
		return ""
	}

	for left, right := 0, len(docLines)-1; left < right; left, right = left+1, right-1 {
		docLines[left], docLines[right] = docLines[right], docLines[left]
	}

	for len(docLines) > 0 && docLines[0] == "" {
		docLines = docLines[1:]
	}
	for len(docLines) > 0 && docLines[len(docLines)-1] == "" {
		docLines = docLines[:len(docLines)-1]
	}

	return strings.Join(docLines, "\n")
}

func parseTypeDocblock(doc string) (string, []string, []string) {
	if doc == "" {
		return "", nil, nil
	}

	lines := strings.Split(doc, "\n")
	summary := make([]string, 0)
	params := make([]string, 0)
	returns := make([]string, 0)

	for _, raw := range lines {
		line := strings.TrimSpace(raw)
		if strings.HasPrefix(line, "@param") {
			parts := strings.Fields(line)
			if len(parts) >= 2 {
				name := parts[1]
				optional := strings.HasSuffix(name, "?")
				name = strings.TrimSuffix(name, "?")
				detail := ""
				if len(parts) > 2 {
					detail = strings.Join(parts[2:], " ")
				}
				if detail != "" {
					if optional {
						params = append(params, fmt.Sprintf("%s (optional): %s", name, detail))
					} else {
						params = append(params, fmt.Sprintf("%s (required): %s", name, detail))
					}
				} else if optional {
					params = append(params, fmt.Sprintf("%s (optional)", name))
				} else {
					params = append(params, fmt.Sprintf("%s (required)", name))
				}
			}
			continue
		}
		if strings.HasPrefix(line, "@return") {
			parts := strings.Fields(line)
			if len(parts) > 1 {
				returns = append(returns, strings.Join(parts[1:], " "))
			} else {
				returns = append(returns, "")
			}
			continue
		}
		if strings.HasPrefix(line, "@") {
			continue
		}
		summary = append(summary, line)
	}

	for len(summary) > 0 && summary[0] == "" {
		summary = summary[1:]
	}
	for len(summary) > 0 && summary[len(summary)-1] == "" {
		summary = summary[:len(summary)-1]
	}

	return strings.Join(summary, "\n"), params, returns
}

func fuzzyConstantGroups(symbol string) []string {
	name := strings.ToLower(symbol)
	groups := make([]string, 0, 1)
	if strings.Contains(name, "trace") || strings.Contains(name, "mask") {
		groups = append(groups, "E_TraceLine")
	}
	return groups
}

func formatMarkdownSection(title string, items []string) string {
	if len(items) == 0 {
		return ""
	}
	var builder strings.Builder
	builder.WriteString("### ")
	builder.WriteString(title)
	builder.WriteString("\n")
	for _, item := range items {
		builder.WriteString("- ")
		builder.WriteString(item)
		builder.WriteString("\n")
	}
	return strings.TrimRight(builder.String(), "\n")
}

func formatTypeInfo(signature string, description string, params []string, returns []string, requiredConstants []string, constants []string) string {
	sections := make([]string, 0, 6)
	if signature != "" {
		sections = append(sections, "### Signature\n"+signature)
	}
	if description != "" {
		sections = append(sections, "### Description\n"+description)
	}
	if section := formatMarkdownSection("Parameters", params); section != "" {
		sections = append(sections, section)
	}
	if section := formatMarkdownSection("Returns", returns); section != "" {
		sections = append(sections, section)
	}
	if section := formatMarkdownSection("Required Constants", requiredConstants); section != "" {
		sections = append(sections, section)
	}
	if section := formatMarkdownSection("Constants", constants); section != "" {
		sections = append(sections, section)
	}
	return strings.Join(sections, "\n\n")
}

func loadConstantsGroup(symbol string) (string, error) {
	path := findExistingRepoPath("types", "lmaobox_lua_api", "constants", symbol+".d.lua")
	content, err := os.ReadFile(path)
	if err != nil {
		return "", nil
	}

	lines := strings.Split(string(content), "\n")
	descriptionLines := make([]string, 0)
	constants := make([]string, 0)
	constantPattern := regexp.MustCompile(`^([A-Z0-9_]+)\s*=`)

	for _, raw := range lines {
		trimmed := strings.TrimSpace(raw)
		if strings.HasPrefix(trimmed, "--") {
			cleaned := strings.TrimSpace(strings.TrimLeft(trimmed, "-"))
			if cleaned != "" &&
				!strings.HasPrefix(cleaned, "Constants:") &&
				!strings.HasPrefix(cleaned, "Auto-generated") &&
				!strings.HasPrefix(cleaned, "Last updated") {
				descriptionLines = append(descriptionLines, cleaned)
			}
			continue
		}
		if matches := constantPattern.FindStringSubmatch(trimmed); len(matches) > 1 {
			constants = append(constants, matches[1])
		}
	}

	description := strings.TrimSpace(strings.Join(descriptionLines, "\n"))
	if description == "" {
		description = fmt.Sprintf("Constants group %s", symbol)
	}

	return formatTypeInfo("", description, nil, nil, nil, constants), nil
}

func prioritizedTypeFiles(symbol string, typesDir string) []string {
	paths := make([]string, 0)
	seen := make(map[string]bool)
	addPath := func(path string) {
		if path == "" || seen[path] {
			return
		}
		seen[path] = true
		paths = append(paths, path)
	}

	parts := strings.Split(symbol, ".")
	if len(parts) > 1 {
		namespace := parts[0]
		addPath(filepath.Join(typesDir, "Lua_Libraries", namespace+".d.lua"))
		addPath(filepath.Join(typesDir, "Lua_Classes", namespace+".d.lua"))
		addPath(filepath.Join(typesDir, "entity_props", namespace+".d.lua"))
	}

	_ = filepath.WalkDir(typesDir, func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return nil
		}
		if strings.HasSuffix(d.Name(), ".d.lua") {
			addPath(path)
		}
		return nil
	})

	return paths
}

func findTypeDefinition(symbol string) (string, error) {
	if symbol == "" {
		return "", nil
	}

	if strings.HasPrefix(symbol, "E_") {
		constantsGroup, err := loadConstantsGroup(symbol)
		if err != nil {
			return "", err
		}
		if constantsGroup != "" {
			return constantsGroup, nil
		}
	}

	typesDir := findExistingRepoPath("types", "lmaobox_lua_api")
	for _, filePath := range prioritizedTypeFiles(symbol, typesDir) {
		content, err := os.ReadFile(filePath)
		if err != nil {
			continue
		}

		lines := strings.Split(string(content), "\n")
		signature, signatureIndex := extractTypeSignature(lines, symbol)
		if signature == "" {
			continue
		}

		description, params, returns := parseTypeDocblock(extractTypeDocblock(lines, signatureIndex))
		requiredConstants := fuzzyConstantGroups(symbol)
		return formatTypeInfo(signature, description, params, returns, requiredConstants, nil), nil
	}

	return "", nil
}

func smartContextCandidatePaths(symbol string) []string {
	normalized := strings.ReplaceAll(strings.ReplaceAll(strings.TrimSpace(symbol), "::", "."), "/", ".")
	if normalized == "" {
		return nil
	}

	smartRoot := resolveSmartContextRoot()
	mirrorRoot := filepath.Join(smartRoot, "lmaobox_lua_api")
	parts := strings.Split(normalized, ".")
	paths := make([]string, 0)
	seen := make(map[string]bool)
	appendPath := func(path string) {
		if seen[path] {
			return
		}
		seen[path] = true
		paths = append(paths, path)
	}

	if len(parts) > 1 {
		namespace := parts[0]
		namespaceLower := strings.ToLower(namespace)
		nested := parts[1 : len(parts)-1]
		leaf := parts[len(parts)-1] + ".md"

		appendPath(filepath.Join(append(append([]string{mirrorRoot, "Lua_Libraries", namespace}, nested...), leaf)...))
		appendPath(filepath.Join(append(append([]string{mirrorRoot, "Lua_Classes", namespace}, nested...), leaf)...))
		appendPath(filepath.Join(append(append([]string{mirrorRoot, "entity_props", namespace}, nested...), leaf)...))
		if namespaceLower == "callbacks" {
			appendPath(filepath.Join(mirrorRoot, "Lua_Callbacks", leaf))
		}
		if namespaceLower == "constants" {
			appendPath(filepath.Join(mirrorRoot, "constants", leaf))
		}
	} else {
		leaf := parts[0] + ".md"
		if strings.HasPrefix(parts[0], "E_") {
			appendPath(filepath.Join(mirrorRoot, "constants", leaf))
		}
		appendPath(filepath.Join(mirrorRoot, "Lua_Globals", leaf))
		appendPath(filepath.Join(mirrorRoot, "Lua_Callbacks", leaf))
		appendPath(filepath.Join(mirrorRoot, "Lua_Classes", leaf))
		appendPath(filepath.Join(mirrorRoot, "Lua_Libraries", leaf))
		appendPath(filepath.Join(mirrorRoot, "constants", leaf))
		appendPath(filepath.Join(mirrorRoot, "entity_props", leaf))
		// Also try directory/index.md (e.g. Lua_Classes/UserCmd/index.md)
		appendPath(filepath.Join(mirrorRoot, "Lua_Globals", parts[0], "index.md"))
		appendPath(filepath.Join(mirrorRoot, "Lua_Callbacks", parts[0], "index.md"))
		appendPath(filepath.Join(mirrorRoot, "Lua_Classes", parts[0], "index.md"))
		appendPath(filepath.Join(mirrorRoot, "Lua_Libraries", parts[0], "index.md"))
		appendPath(filepath.Join(mirrorRoot, "constants", parts[0], "index.md"))
		appendPath(filepath.Join(mirrorRoot, "entity_props", parts[0], "index.md"))
	}

	appendPath(filepath.Join(smartRoot, normalized+".md"))
	segments := strings.Split(normalized, ".")
	for len(segments) > 0 {
		if len(segments) == 1 {
			appendPath(filepath.Join(smartRoot, segments[0]+".md"))
		} else {
			appendPath(filepath.Join(filepath.Join(append([]string{smartRoot}, segments[:len(segments)-1]...)...), segments[len(segments)-1]+".md"))
		}
		segments = segments[:len(segments)-1]
	}

	return paths
}

func combineTypeAndSmartContext(typeInfo string, additional string) string {
	trimmedAdditional := strings.TrimSpace(additional)
	if typeInfo != "" && trimmedAdditional != "" {
		return strings.Join([]string{typeInfo, "---", "## Additional Smart Context", trimmedAdditional}, "\n\n")
	}
	if trimmedAdditional != "" {
		return trimmedAdditional
	}
	return typeInfo
}

func findBestSmartContextMatch(root string, symbol string) (string, error) {
	normalized := strings.ToLower(strings.ReplaceAll(strings.ReplaceAll(strings.TrimSpace(symbol), "::", "."), "/", "."))
	if normalized == "" {
		return "", nil
	}

	parts := strings.Split(normalized, ".")
	leaf := parts[len(parts)-1]
	joined := strings.Join(parts, "/")

	bestScore := -1
	bestPath := ""

	err := filepath.WalkDir(root, func(path string, d fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return nil
		}
		if d.IsDir() || !strings.HasSuffix(strings.ToLower(path), ".md") {
			return nil
		}

		relPath, relErr := filepath.Rel(root, path)
		if relErr != nil {
			return nil
		}
		rel := strings.ToLower(filepath.ToSlash(relPath))
		base := strings.ToLower(strings.TrimSuffix(filepath.Base(path), ".md"))
		parent := strings.ToLower(filepath.Base(filepath.Dir(path)))

		score := 0

		// Highest confidence: index.md directly in a symbol directory.
		if base == "index" && parent == leaf {
			score += 120
		}

		// Direct leaf filename match (e.g. GetRoundState.md).
		if base == leaf {
			score += 100
		}

		// Full symbol path structure match (e.g. engine/TraceLine.md or UserCmd/index.md).
		if rel == joined+".md" || strings.HasSuffix(rel, "/"+joined+".md") {
			score += 90
		}
		if strings.HasSuffix(rel, "/"+joined+"/index.md") {
			score += 90
		}

		// Generic containment fallback for flexible discovery.
		if strings.Contains(rel, leaf) {
			score += 15
		}

		if score > bestScore {
			bestScore = score
			bestPath = path
		}
		return nil
	})
	if err != nil {
		return "", err
	}

	if bestScore <= 0 || bestPath == "" {
		return "", nil
	}

	content, readErr := os.ReadFile(bestPath)
	if readErr != nil {
		return "", readErr
	}

	return string(content), nil
}

func findSmartContext(symbol string) (string, error) {
	typeInfo, typeErr := findTypeDefinition(symbol)
	if typeErr != nil {
		return "", typeErr
	}

	apiRoot := filepath.Join(resolveSmartContextRoot(), "lmaobox_lua_api")
	foundContent, err := findBestSmartContextMatch(apiRoot, symbol)
	if err != nil {
		return "", err
	}

	snippetAppendix, snippetErr := buildSnippetAppendix(symbol)
	if snippetErr != nil {
		return "", snippetErr
	}
	if foundContent != "" {
		combined := combineTypeAndSmartContext(typeInfo, foundContent)
		if snippetAppendix != "" {
			combined = strings.Join([]string{combined, "---", snippetAppendix}, "\n\n")
		}
		return combined, nil
	}

	if typeInfo != "" && snippetAppendix != "" {
		return strings.Join([]string{typeInfo, "---", snippetAppendix}, "\n\n"), nil
	}
	if snippetAppendix != "" {
		return snippetAppendix, nil
	}

	return "", nil
}

func buildSnippetAppendix(symbol string) (string, error) {
	candidates, err := loadSnippetCandidates()
	if err != nil {
		return "", err
	}
	if len(candidates) == 0 {
		return "", nil
	}

	queryLower := strings.ToLower(strings.TrimSpace(symbol))
	tokens := strings.Fields(strings.ReplaceAll(strings.ReplaceAll(queryLower, ".", " "), "_", " "))
	if len(tokens) == 0 {
		tokens = strings.Fields(queryLower)
	}

	matched := make([]smartCandidate, 0)
	for _, c := range candidates {
		c.Score = scoreSnippetCandidate(queryLower, tokens, c.combinedLower, strings.ToLower(c.Symbol))
		if c.Score > 20 {
			matched = append(matched, c)
		}
	}

	if len(matched) == 0 {
		return "", nil
	}

	sort.Slice(matched, func(i, j int) bool {
		return matched[i].Score > matched[j].Score
	})
	if len(matched) > 3 {
		matched = matched[:3]
	}

	var sb strings.Builder
	sb.WriteString("## Related Snippets\n\n")
	for _, match := range matched {
		sb.WriteString(fmt.Sprintf("- Prefix `%s`: %s\n", match.Symbol, match.Description))
		if match.Signature != "" {
			sb.WriteString(fmt.Sprintf("  - Preview: `%s`\n", match.Signature))
		}
	}

	return strings.TrimSpace(sb.String()), nil
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

// ── smart_search ────────────────────────────────────────────────────────────

type SmartSearchResult struct {
	Symbol      string  `json:"symbol"`
	Kind        string  `json:"kind"`
	Section     string  `json:"section"`
	Score       float64 `json:"score"`
	Description string  `json:"description,omitempty"`
	Signature   string  `json:"signature,omitempty"`
}

type snippetFileEntry struct {
	Prefix      interface{} `json:"prefix"`
	Body        interface{} `json:"body"`
	Description string      `json:"description"`
}

type smartCandidate struct {
	SmartSearchResult
	combinedLower string
}

func handleSmartSearch(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
	query, ok := req.Params.Arguments["query"].(string)
	if !ok || strings.TrimSpace(query) == "" {
		return mcp.NewToolResultError("query is required"), nil
	}

	limit := 15
	if rawLimit, ok := req.Params.Arguments["limit"].(float64); ok {
		limit = int(rawLimit)
		if limit < 1 {
			limit = 1
		}
		if limit > 50 {
			limit = 50
		}
	}

	results, snippetResults, err := smartSearch(query, limit)
	if err != nil {
		return mcp.NewToolResultError(fmt.Sprintf("Search failed: %v", err)), nil
	}

	output := formatSearchResultsMarkdown(query, results, snippetResults, limit)
	return mcp.NewToolResultText(output), nil
}

func formatSearchResultsMarkdown(query string, results []SmartSearchResult, snippetResults []SmartSearchResult, limit int) string {
	var sb strings.Builder

	sb.WriteString(fmt.Sprintf("## smart_search: `%s`\n", query))
	sb.WriteString(fmt.Sprintf("_Returned %d primary results of up to %d_\n\n", len(results), limit))

	if len(results) == 0 && len(snippetResults) == 0 {
		sb.WriteString("No matches found. Try broader terms or check spelling.\n")
		sb.WriteString("\n**Tip:** Use `smart_search` with simpler keywords, e.g. `health`, `trace`, `draw`")
		return sb.String()
	}

	// Group by section for hierarchy clarity
	sectionOrder := []string{"library", "class", "entity_props", "constants", "symbol"}
	bySection := make(map[string][]SmartSearchResult)
	for _, r := range results {
		sec := r.Section
		if sec == "" {
			sec = "symbol"
		}
		bySection[sec] = append(bySection[sec], r)
	}

	// Add any sections not in the fixed order
	known := make(map[string]bool)
	for _, s := range sectionOrder {
		known[s] = true
	}
	for sec := range bySection {
		if !known[sec] {
			sectionOrder = append(sectionOrder, sec)
		}
	}

	primarySuggestion, hasPrimarySuggestion := firstDisplayedPrimaryResult(results, sectionOrder)

	for _, sec := range sectionOrder {
		rows, ok := bySection[sec]
		if !ok || len(rows) == 0 {
			continue
		}

		sectionLabel := sectionDisplayName(sec)
		sb.WriteString(fmt.Sprintf("### %s\n", sectionLabel))
		sb.WriteString("| Symbol | Kind | Description | Signature |\n")
		sb.WriteString("|---|---|---|---|\n")

		for _, r := range rows {
			desc := r.Description
			if len(desc) > 80 {
				desc = desc[:77] + "..."
			}
			sig := r.Signature
			if len(sig) > 60 {
				sig = sig[:57] + "..."
			}
			// Escape pipe chars in cells
			desc = strings.ReplaceAll(desc, "|", `\|`)
			sig = strings.ReplaceAll(sig, "|", `\|`)
			sb.WriteString(fmt.Sprintf("| `%s` | %s | %s | %s |\n",
				r.Symbol, r.Kind, desc, sig))
		}
		sb.WriteString("\n")
	}

	if len(snippetResults) > 0 {
		sb.WriteString("### Snippets (secondary matches)\n")
		sb.WriteString("| Prefix | Description | Template Preview |\n")
		sb.WriteString("|---|---|---|\n")

		for _, r := range snippetResults {
			desc := r.Description
			if len(desc) > 90 {
				desc = desc[:87] + "..."
			}
			sig := r.Signature
			if len(sig) > 70 {
				sig = sig[:67] + "..."
			}
			desc = strings.ReplaceAll(desc, "|", `\|`)
			sig = strings.ReplaceAll(sig, "|", `\|`)
			sb.WriteString(fmt.Sprintf("| `%s` | %s | %s |\n", r.Symbol, desc, sig))
		}

		sb.WriteString("\n")
		sb.WriteString("_Snippet matches are a secondary pass after formal type/API matches._\n\n")
	}

	// Suggest next steps based on top result
	if hasPrimarySuggestion {
		top := primarySuggestion
		sb.WriteString("---\n")
		sb.WriteString("**Next steps:**\n")
		sb.WriteString(fmt.Sprintf("- Full docs & examples: `get_smart_context(\"%s\")` \n", top.Symbol))
		sb.WriteString(fmt.Sprintf("- Type signature only: `get_types(\"%s\")` \n", top.Symbol))
		if len(results) > 1 {
			sb.WriteString(fmt.Sprintf("- More results: re-run `smart_search` with `limit` > %d\n", limit))
		}
	} else if len(snippetResults) > 0 {
		top := snippetResults[0]
		sb.WriteString("---\n")
		sb.WriteString("**Next steps:**\n")
		sb.WriteString(fmt.Sprintf("- Try snippet prefix `%s` in a Lua file\n", top.Symbol))
		sb.WriteString("- Re-run `smart_search` with the related API symbol or library for formal docs\n")
	}

	return sb.String()
}

func firstDisplayedPrimaryResult(results []SmartSearchResult, sectionOrder []string) (SmartSearchResult, bool) {
	if len(results) == 0 {
		return SmartSearchResult{}, false
	}

	for _, sec := range sectionOrder {
		for _, result := range results {
			resultSection := result.Section
			if resultSection == "" {
				resultSection = "symbol"
			}

			if resultSection == sec {
				return result, true
			}
		}
	}

	return results[0], true
}

func sectionDisplayName(section string) string {
	switch section {
	case "library":
		return "Library Functions (e.g. engine.*, draw.*, entities.*)"
	case "class":
		return "Class Methods (e.g. Entity.*, Trace.*)"
	case "entity_props":
		return "Entity Properties"
	case "constants":
		return "Constants / Enums"
	case "snippet":
		return "Snippets"
	case "symbol":
		return "Other Symbols"
	default:
		return strings.Title(section)
	}
}

func smartSearch(query string, limit int) ([]SmartSearchResult, []SmartSearchResult, error) {
	queryLower := strings.ToLower(strings.TrimSpace(query))

	execDir := filepath.Dir(os.Args[0])
	typesDir := filepath.Join(execDir, "types", "lmaobox_lua_api")

	var candidates []smartCandidate

	_ = filepath.WalkDir(typesDir, func(path string, d fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return nil
		}
		if d.IsDir() {
			return nil
		}
		if !strings.HasSuffix(d.Name(), ".d.lua") {
			return nil
		}
		content, readErr := os.ReadFile(path)
		if readErr != nil {
			return nil
		}
		entries := parseDLuaEntries(path, string(content))
		candidates = append(candidates, entries...)
		return nil
	})

	snippetCandidates, err := loadSnippetCandidates()
	if err != nil {
		return nil, nil, err
	}

	tokens := strings.Fields(queryLower)
	var scored []smartCandidate
	for _, c := range candidates {
		c.Score = scoreSmartCandidate(queryLower, tokens, c.combinedLower, strings.ToLower(c.Symbol))
		if c.Score > 0 {
			scored = append(scored, c)
		}
	}

	var snippetScored []smartCandidate
	for _, c := range snippetCandidates {
		c.Score = scoreSnippetCandidate(queryLower, tokens, c.combinedLower, strings.ToLower(c.Symbol))
		if c.Score > 0 {
			snippetScored = append(snippetScored, c)
		}
	}

	sort.Slice(scored, func(i, j int) bool {
		return scored[i].Score > scored[j].Score
	})
	sort.Slice(snippetScored, func(i, j int) bool {
		return snippetScored[i].Score > snippetScored[j].Score
	})

	if len(scored) > limit {
		scored = scored[:limit]
	}

	snippetLimit := min(5, max(1, limit/3))
	if len(snippetScored) > snippetLimit {
		snippetScored = snippetScored[:snippetLimit]
	}

	out := make([]SmartSearchResult, len(scored))
	for i, c := range scored {
		out[i] = c.SmartSearchResult
	}

	snippetOut := make([]SmartSearchResult, len(snippetScored))
	for i, c := range snippetScored {
		snippetOut[i] = c.SmartSearchResult
	}

	return out, snippetOut, nil
}

func loadSnippetCandidates() ([]smartCandidate, error) {
	paths := resolveSnippetSearchFiles()
	if len(paths) == 0 {
		return nil, nil
	}

	seen := make(map[string]bool)
	results := make([]smartCandidate, 0)
	for _, path := range paths {
		if seen[path] {
			continue
		}
		seen[path] = true

		content, err := os.ReadFile(path)
		if err != nil {
			continue
		}
		results = append(results, parseSnippetEntries(string(content))...)
	}

	return results, nil
}

func resolveSnippetSearchFiles() []string {
	roots := searchRoots()
	paths := make([]string, 0)
	seen := make(map[string]bool)
	patterns := []string{
		filepath.Join("snippets", "*.code-snippets"),
		filepath.Join("vscode-extension", "snippets", "*.code-snippets"),
	}

	for _, root := range roots {
		for _, pattern := range patterns {
			matches, err := filepath.Glob(filepath.Join(root, pattern))
			if err != nil {
				continue
			}
			for _, match := range matches {
				if !seen[match] {
					seen[match] = true
					paths = append(paths, match)
				}
			}
		}
	}

	return paths
}

func parseSnippetEntries(content string) []smartCandidate {
	cleaned := stripJSONComments(content)
	entries := make(map[string]snippetFileEntry)
	if err := json.Unmarshal([]byte(cleaned), &entries); err != nil {
		return nil
	}

	results := make([]smartCandidate, 0, len(entries))
	for title, entry := range entries {
		prefixes := toStringSlice(entry.Prefix)
		bodyLines := toStringSlice(entry.Body)

		prefix := title
		if len(prefixes) > 0 && strings.TrimSpace(prefixes[0]) != "" {
			prefix = strings.TrimSpace(prefixes[0])
		}

		description := strings.TrimSpace(entry.Description)
		if description == "" {
			description = title
		}

		signature := ""
		if len(bodyLines) > 0 {
			signature = strings.TrimSpace(bodyLines[0])
		}

		combinedParts := []string{title, strings.Join(prefixes, " "), description, strings.Join(bodyLines, " ")}
		combined := strings.ToLower(strings.Join(combinedParts, " "))

		results = append(results, smartCandidate{
			SmartSearchResult: SmartSearchResult{
				Symbol:      prefix,
				Kind:        "snippet",
				Section:     "snippet",
				Description: fmt.Sprintf("%s (%s)", description, title),
				Signature:   signature,
			},
			combinedLower: combined,
		})
	}

	return results
}

func stripJSONComments(content string) string {
	var sb strings.Builder
	inString := false
	escaped := false
	inLineComment := false
	inBlockComment := false

	for i := 0; i < len(content); i++ {
		ch := content[i]
		next := byte(0)
		if i+1 < len(content) {
			next = content[i+1]
		}

		if inLineComment {
			if ch == '\n' {
				inLineComment = false
				sb.WriteByte(ch)
			}
			continue
		}
		if inBlockComment {
			if ch == '*' && next == '/' {
				inBlockComment = false
				i++
			}
			continue
		}

		if inString {
			sb.WriteByte(ch)
			if escaped {
				escaped = false
				continue
			}
			if ch == '\\' {
				escaped = true
				continue
			}
			if ch == '"' {
				inString = false
			}
			continue
		}

		if ch == '/' && next == '/' {
			inLineComment = true
			i++
			continue
		}
		if ch == '/' && next == '*' {
			inBlockComment = true
			i++
			continue
		}
		if ch == '"' {
			inString = true
		}

		sb.WriteByte(ch)
	}

	return sb.String()
}

func toStringSlice(raw interface{}) []string {
	switch typed := raw.(type) {
	case string:
		return []string{typed}
	case []interface{}:
		out := make([]string, 0, len(typed))
		for _, value := range typed {
			if str, ok := value.(string); ok {
				out = append(out, str)
			}
		}
		return out
	default:
		return nil
	}
}

func parseDLuaEntries(filePath, content string) []smartCandidate {
	var results []smartCandidate

	section := "symbol"
	switch {
	case strings.Contains(filePath, "Lua_Libraries"):
		section = "library"
	case strings.Contains(filePath, "Lua_Classes"):
		section = "class"
	case strings.Contains(filePath, "constants"):
		section = "constants"
	case strings.Contains(filePath, "entity_props"):
		section = "entity_props"
	}

	funcRe := regexp.MustCompile(`^function\s+([\w.]+)\s*\(`)
	constRe := regexp.MustCompile(`^([A-Z_][A-Z0-9_]{2,})\s*=`)

	lines := strings.Split(content, "\n")
	var commentBlock []string

	for _, line := range lines {
		trimmed := strings.TrimSpace(line)

		if strings.HasPrefix(trimmed, "---") {
			cleaned := strings.TrimLeft(trimmed, "-")
			cleaned = strings.TrimSpace(cleaned)
			commentBlock = append(commentBlock, cleaned)
			continue
		}

		if strings.HasPrefix(trimmed, "function ") {
			sig := strings.TrimSuffix(trimmed, " end")

			var symbolName string
			if m := funcRe.FindStringSubmatch(trimmed); len(m) > 1 {
				symbolName = m[1]
			}

			desc := buildDesc(commentBlock)

			if symbolName != "" {
				combined := strings.ToLower(symbolName + " " + desc + " " + sig)
				results = append(results, smartCandidate{
					SmartSearchResult: SmartSearchResult{
						Symbol:      symbolName,
						Kind:        "function",
						Section:     section,
						Description: desc,
						Signature:   sig,
					},
					combinedLower: combined,
				})
			}
			commentBlock = commentBlock[:0]
			continue
		}

		if m := constRe.FindStringSubmatch(trimmed); len(m) > 1 {
			name := m[1]
			desc := buildDesc(commentBlock)
			combined := strings.ToLower(name + " " + desc)
			results = append(results, smartCandidate{
				SmartSearchResult: SmartSearchResult{
					Symbol:      name,
					Kind:        "constant",
					Section:     section,
					Description: desc,
				},
				combinedLower: combined,
			})
			commentBlock = commentBlock[:0]
			continue
		}

		if trimmed != "" && !strings.HasPrefix(trimmed, "--") {
			commentBlock = commentBlock[:0]
		}
	}

	return results
}

func buildDesc(commentBlock []string) string {
	var parts []string
	for _, c := range commentBlock {
		if !strings.HasPrefix(c, "@") && c != "" {
			parts = append(parts, c)
		}
	}
	return strings.TrimSpace(strings.Join(parts, " "))
}

func scoreSmartCandidate(queryLower string, tokens []string, combinedLower, symbolLower string) float64 {
	score := 0.0

	if symbolLower == queryLower {
		score += 120
	}
	if queryLower != "" && strings.HasPrefix(symbolLower, queryLower) {
		score += 80
	}
	if queryLower != "" && strings.Contains(symbolLower, queryLower) {
		score += 60
	}

	for _, token := range tokens {
		if strings.Contains(symbolLower, token) {
			score += 30
		} else if strings.Contains(combinedLower, token) {
			score += 15
		}
	}

	if len(tokens) > 0 {
		hits := 0
		for _, t := range tokens {
			if strings.Contains(combinedLower, t) {
				hits++
			}
		}
		coverage := float64(hits) / float64(len(tokens))
		score += 20 * coverage
	}

	return score
}

func scoreSnippetCandidate(queryLower string, tokens []string, combinedLower, symbolLower string) float64 {
	base := scoreSmartCandidate(queryLower, tokens, combinedLower, symbolLower)
	if base <= 0 {
		return 0
	}

	return base * 0.55
}

// ── end smart_search ─────────────────────────────────────────────────────────

// runLuacOnly runs the Lua compiler syntax check (-p) on the given file without
// executing the Zero-Mutation policy or luacheck passes.  This is used for the
// final bundle validation where per-file checks have already been done.
func runLuacOnly(ctx context.Context, filePath string) error {
	luacPath := findLuac()
	if luacPath == "" {
		return nil // no compiler available -- skip silently like validateLuaSyntax does
	}
	cmd := exec.CommandContext(ctx, luacPath, "-p", filePath)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("syntax error: %s", strings.TrimSpace(string(output)))
	}
	return nil
}

// resolveBundleMapPath resolves the .map file path from either a bundle .lua
// file path or a project directory (looks for build/Main.lua.map).
func resolveBundleMapPath(bundleFileArg string) (string, error) {
	info, err := os.Stat(bundleFileArg)
	if err != nil {
		return "", fmt.Errorf("path not found: %s", bundleFileArg)
	}
	if info.IsDir() {
		candidate := filepath.Join(bundleFileArg, "build", "Main.lua.map")
		if _, serr := os.Stat(candidate); serr == nil {
			return candidate, nil
		}
		return "", fmt.Errorf("no build/Main.lua.map found in directory %s – run the bundle tool first", bundleFileArg)
	}
	// bundleFileArg is a file – strip .map extension if already provided
	mapPath := bundleFileArg
	if !strings.HasSuffix(mapPath, ".map") {
		mapPath = mapPath + ".map"
	}
	if _, serr := os.Stat(mapPath); serr != nil {
		return "", fmt.Errorf("map file not found at %s – run the bundle tool first to generate it", mapPath)
	}
	return mapPath, nil
}

// lookupBundleLine finds which source file and line a bundled line number
// corresponds to.  Returns found=false when the line is in bundle
// infrastructure (header / module wrapper boilerplate).
func lookupBundleLine(entries []LineMapEntry, bundledLine int) (entry LineMapEntry, sourceLine int, found bool) {
	for _, e := range entries {
		if bundledLine >= e.BundledStart && bundledLine <= e.BundledEnd {
			return e, e.SourceStart + (bundledLine - e.BundledStart), true
		}
	}
	return LineMapEntry{}, 0, false
}

func handleTraceback(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
	bundleFileArg, ok := req.Params.Arguments["bundleFile"].(string)
	if !ok || strings.TrimSpace(bundleFileArg) == "" {
		return mcp.NewToolResultError("bundleFile is required"), nil
	}
	rawLine, ok := req.Params.Arguments["line"].(float64)
	if !ok {
		return mcp.NewToolResultError("line is required and must be a number"), nil
	}
	bundledLine := int(rawLine)
	if bundledLine < 1 {
		return mcp.NewToolResultError("line must be >= 1"), nil
	}

	mapPath, err := resolveBundleMapPath(bundleFileArg)
	if err != nil {
		return mcp.NewToolResultError(err.Error()), nil
	}

	mapData, err := os.ReadFile(mapPath)
	if err != nil {
		return mcp.NewToolResultError(fmt.Sprintf("failed to read map file: %v", err)), nil
	}

	var lineMap BundleLineMap
	if err := json.Unmarshal(mapData, &lineMap); err != nil {
		return mcp.NewToolResultError(fmt.Sprintf("map file is corrupt: %v", err)), nil
	}

	entry, sourceLine, found := lookupBundleLine(lineMap.Entries, bundledLine)
	if !found {
		return mcp.NewToolResultText(fmt.Sprintf(
			"## traceback: line %d\n\nLine %d is in the bundle infrastructure (header / module wrapper boilerplate) and does not correspond to any source file.",
			bundledLine, bundledLine,
		)), nil
	}

	// Make the source file path relative to the project dir for readability
	relPath := entry.SourceFile
	if lineMap.ProjectDir != "" {
		if rel, rerr := filepath.Rel(lineMap.ProjectDir, entry.SourceFile); rerr == nil {
			relPath = rel
		}
	}

	var sb strings.Builder
	sb.WriteString(fmt.Sprintf("## traceback: bundled line %d\n\n", bundledLine))
	sb.WriteString(fmt.Sprintf("**Source file:** `%s`\n", relPath))
	sb.WriteString(fmt.Sprintf("**Source line:** %d\n", sourceLine))
	sb.WriteString(fmt.Sprintf("**Bundle range:** lines %d-%d map to `%s`\n", entry.BundledStart, entry.BundledEnd, relPath))

	// Optionally show the source line content
	if srcBytes, rerr := os.ReadFile(entry.SourceFile); rerr == nil {
		srcLines := strings.Split(string(srcBytes), "\n")
		if sourceLine >= 1 && sourceLine <= len(srcLines) {
			lineContent := srcLines[sourceLine-1]
			sb.WriteString(fmt.Sprintf("\n**Line content:**\n```lua\n%s\n```\n", lineContent))

			// Show a few lines of context (±3)
			contextStart := sourceLine - 3
			if contextStart < 1 {
				contextStart = 1
			}
			contextEnd := sourceLine + 3
			if contextEnd > len(srcLines) {
				contextEnd = len(srcLines)
			}
			if contextEnd > contextStart {
				sb.WriteString("\n**Context:**\n```lua\n")
				for i := contextStart; i <= contextEnd; i++ {
					marker := "  "
					if i == sourceLine {
						marker = ">>"
					}
					sb.WriteString(fmt.Sprintf("%s %4d | %s\n", marker, i, srcLines[i-1]))
				}
				sb.WriteString("```\n")
			}
		}
	}

	return mcp.NewToolResultText(sb.String()), nil
}

func ensureDependencies() error {
	luacPath := findLuac()
	luacheckPath := findLuacheck()

	if luacPath == "" {
		log.Printf("Lua compiler not found, attempting auto-install via choco...")
		if err := installLuac(); err != nil {
			return fmt.Errorf("Lua 5.4+ installation failed: %w\n"+
				"Please install manually from: https://luabinaries.sourceforge.net/\n"+
				"Or use: choco install lua (if you have Chocolatey)", err)
		}
		luacPath = findLuac()
		if luacPath == "" {
			return fmt.Errorf("Lua compiler install completed but luac is still not discoverable")
		}
		log.Printf("✓ Lua compiler installed successfully")
	}

	if luacheckPath != "" {
		updateLuacheckState(true, false, "ready", "")
		log.Printf("✓ Dependencies satisfied: Lua compiler found at %s, luacheck found at %s", luacPath, luacheckPath)
		return nil
	}

	if preferLuaLanguageServer {
		log.Printf("luacheck bootstrap disabled: prefer Lua language server diagnostics (--prefer-lua-ls)")
		updateLuacheckState(false, false, "disabled-lua-ls", "")
		return nil
	}

	log.Printf("luacheck not found at startup. Continuing without lint until bootstrap finishes.")
	updateLuacheckState(false, false, "queued", "")
	requestLuacheckBootstrap()

	return nil
}

func requestLuacheckBootstrap() {
	globalLuacheckState.mu.Lock()
	if globalLuacheckState.installing || globalLuacheckState.ready {
		globalLuacheckState.mu.Unlock()
		return
	}
	globalLuacheckState.installing = true
	globalLuacheckState.status = "starting install"
	globalLuacheckState.lastError = ""
	globalLuacheckState.mu.Unlock()

	go runLuacheckBootstrap()
}

func runLuacheckBootstrap() {
	log.Printf("luacheck bootstrap started in background")

	updateLuacheckState(false, true, "installing", "")
	if err := installLuacheck(""); err != nil {
		updateLuacheckState(false, false, "failed", err.Error())
		log.Printf("⚠ luacheck bootstrap failed: %v", err)
		return
	}

	luacheckPath := findLuacheck()
	if luacheckPath == "" {
		errText := "install finished but executable is still not discoverable"
		updateLuacheckState(false, false, "failed", errText)
		log.Printf("⚠ luacheck bootstrap failed: %s", errText)
		return
	}

	updateLuacheckState(true, false, "ready", "")
	log.Printf("✓ luacheck bootstrap complete: %s", luacheckPath)
}

func updateLuacheckState(ready bool, installing bool, status string, lastError string) {
	globalLuacheckState.mu.Lock()
	globalLuacheckState.ready = ready
	globalLuacheckState.installing = installing
	globalLuacheckState.status = status
	globalLuacheckState.lastError = lastError
	globalLuacheckState.mu.Unlock()
}

func luacheckNotReadyStatusText() string {
	globalLuacheckState.mu.RLock()
	ready := globalLuacheckState.ready
	installing := globalLuacheckState.installing
	status := globalLuacheckState.status
	lastError := globalLuacheckState.lastError
	globalLuacheckState.mu.RUnlock()

	if ready || findLuacheck() != "" {
		if !ready {
			updateLuacheckState(true, false, "ready", "")
		}
		return ""
	}

	if status == "disabled-lua-ls" {
		return "ℹ luacheck bootstrap is disabled in prefer-Lua-LS mode. Use the VS Code Lua extension diagnostics for lint warnings; MCP syntax and policy checks remain active."
	}

	if !installing {
		requestLuacheckBootstrap()
	}

	if lastError != "" {
		return fmt.Sprintf("⚠ luacheck is not ready yet (status: %s). Last bootstrap error: %s", status, lastError)
	}

	if status == "" {
		status = "installing"
	}

	return fmt.Sprintf("⚠ luacheck is not ready yet (status: %s). Syntax and policy checks are available; lint checks will activate once bootstrap finishes.", status)
}

func hasArg(target string) bool {
	for _, arg := range os.Args[1:] {
		if arg == target {
			return true
		}
	}
	return false
}

func installLuac() error {
	for _, choco := range []string{"choco", "choco.exe"} {
		if _, err := exec.LookPath(choco); err == nil {
			log.Printf("Trying: %s install lua", choco)
			cmd := exec.Command(choco, "install", "lua", "-y")
			out, err := cmd.CombinedOutput()
			log.Printf("choco output:\n%s", string(out))
			if err == nil {
				return nil
			}
		}
	}
	return fmt.Errorf("choco not available. Install Lua 5.4+ manually from: https://luabinaries.sourceforge.net/")
}

func installLuacheck(_ string) error {
	if path := findLuacheck(); path != "" {
		log.Printf("luacheck already available at %s", path)
		return nil
	}

	// Strategy 1: use luarocks directly when available
	if err := installLuacheckViaLuaRocks(); err == nil {
		return nil
	}

	// Strategy 2: install Lua (includes luarocks) via winget, then retry luarocks
	if _, err := exec.LookPath("winget"); err == nil {
		log.Printf("Trying: winget install DEVCOM.Lua")
		cmd := exec.Command("winget", "install", "--id", "DEVCOM.Lua", "--exact", "--silent", "--accept-package-agreements", "--accept-source-agreements")
		out, installErr := cmd.CombinedOutput()
		log.Printf("winget output:\n%s", string(out))
		if installErr == nil {
			if err := installLuacheckViaLuaRocks(); err == nil {
				return nil
			}
		}
	}

	// Strategy 3: pip install luacheck
	for _, pip := range []string{"pip3", "pip"} {
		if _, err := exec.LookPath(pip); err == nil {
			log.Printf("Trying: %s install luacheck", pip)
			cmd := exec.Command(pip, "install", "luacheck")
			out, err := cmd.CombinedOutput()
			log.Printf("%s output:\n%s", pip, string(out))
			if err == nil && findLuacheck() != "" {
				return nil
			}
			log.Printf("%s install failed: %v", pip, err)
		}
	}

	return fmt.Errorf("all install methods failed. Install manually with LuaRocks: luarocks install luacheck")
}

func installLuacheckViaLuaRocks() error {
	compilerPath := findGCCCompiler()
	if compilerPath == "" {
		if err := installCompilerToolchain(); err == nil {
			compilerPath = findGCCCompiler()
		}
	}

	luarocksCandidates := []string{"luarocks", "luarocks.exe", "luarocks.bat"}
	if localAppData := os.Getenv("LOCALAPPDATA"); localAppData != "" {
		luarocksCandidates = append(luarocksCandidates,
			filepath.Join(localAppData, "Programs", "Lua", "bin", "luarocks.exe"),
			filepath.Join(localAppData, "Programs", "Lua", "bin", "luarocks.bat"),
		)
	}

	for _, luarocks := range uniqueStrings(luarocksCandidates) {
		if _, err := exec.LookPath(luarocks); err != nil {
			if filepath.IsAbs(luarocks) {
				if _, statErr := os.Stat(luarocks); statErr == nil {
					// absolute path exists, continue to execution
				} else {
					continue
				}
			} else {
				continue
			}
		}

		log.Printf("Trying: %s install luacheck", luarocks)
		cmd := exec.Command(luarocks, "install", "luacheck")
		if compilerPath != "" {
			cmd.Env = append(os.Environ(), "CC="+compilerPath)
		}
		out, err := cmd.CombinedOutput()
		log.Printf("%s output:\n%s", luarocks, string(out))
		if err == nil && findLuacheck() != "" {
			return nil
		}
	}

	return fmt.Errorf("luarocks not available or luacheck install failed")
}

func installCompilerToolchain() error {
	if _, err := exec.LookPath("winget"); err != nil {
		return fmt.Errorf("winget unavailable")
	}

	log.Printf("Trying: winget install BrechtSanders.WinLibs.POSIX.UCRT")
	cmd := exec.Command("winget", "install", "--id", "BrechtSanders.WinLibs.POSIX.UCRT", "--exact", "--silent", "--accept-package-agreements", "--accept-source-agreements")
	out, err := cmd.CombinedOutput()
	log.Printf("winget compiler output:\n%s", string(out))
	if err != nil {
		return err
	}

	return nil
}

func findGCCCompiler() string {
	for _, candidate := range []string{"x86_64-w64-mingw32-gcc", "x86_64-w64-mingw32-gcc.exe", "gcc", "gcc.exe"} {
		if path, err := exec.LookPath(candidate); err == nil {
			return path
		}
	}

	localAppData := os.Getenv("LOCALAPPDATA")
	if localAppData == "" {
		return ""
	}

	roots := []string{
		filepath.Join(localAppData, "Microsoft", "WinGet", "Packages"),
		filepath.Join(localAppData, "Programs"),
	}

	targets := map[string]bool{
		"x86_64-w64-mingw32-gcc.exe": true,
		"gcc.exe":                    true,
	}

	for _, root := range roots {
		path := findFirstFileByName(root, targets)
		if path != "" {
			return path
		}
	}

	return ""
}

func findFirstFileByName(root string, fileNames map[string]bool) string {
	if root == "" {
		return ""
	}
	if _, err := os.Stat(root); err != nil {
		return ""
	}

	found := ""
	_ = filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		if d.IsDir() {
			return nil
		}
		if fileNames[strings.ToLower(d.Name())] {
			found = path
			return fs.SkipAll
		}
		return nil
	})

	return found
}

func findLuac() string {
	candidates := []string{
		filepath.Join(filepath.Dir(os.Args[0]), "automations", "bin", "lua", "luac54.exe"),
		filepath.Join(filepath.Dir(os.Args[0]), "automations", "bin", "lua", "luac5.4.exe"),
		filepath.Join(filepath.Dir(os.Args[0]), "automations", "bin", "lua", "luac.exe"),
		"luac5.4",
		"luac54",
		"luac5.5",
		"luac55",
		"luac",
	}

	for _, candidate := range candidates {
		if filepath.IsAbs(candidate) {
			if _, err := os.Stat(candidate); err == nil {
				return candidate
			}
		} else {
			if _, err := exec.LookPath(candidate); err == nil {
				return candidate
			}
		}
	}

	return ""
}

func findLuacheck() string {
	candidates := buildLuacheckCandidates(filepath.Dir(os.Args[0]), getNpmGlobalPrefix(), os.Getenv("APPDATA"), os.Getenv("USERPROFILE"))

	for _, candidate := range candidates {
		if filepath.IsAbs(candidate) {
			if _, err := os.Stat(candidate); err == nil {
				return candidate
			}
		} else {
			if _, err := exec.LookPath(candidate); err == nil {
				return candidate
			}
		}
	}

	return ""
}

func buildLuacheckCandidates(execDir, npmPrefix, appData, userProfile string) []string {
	candidates := []string{
		filepath.Join(execDir, "automations", "bin", "luacheck", "luacheck.exe"),
		filepath.Join(execDir, "automations", "bin", "luacheck", "luacheck"),
		filepath.Join(execDir, "automations", "bin", "luacheck", "luacheck.bat"),
	}

	if localAppData := os.Getenv("LOCALAPPDATA"); localAppData != "" {
		candidates = append(candidates,
			filepath.Join(localAppData, "Programs", "Lua", "bin", "luacheck.bat"),
			filepath.Join(localAppData, "Programs", "Lua", "bin", "luacheck.exe"),
		)
	}

	if npmPrefix != "" {
		candidates = append(candidates,
			filepath.Join(npmPrefix, "luacheck.cmd"),
			filepath.Join(npmPrefix, "luacheck.exe"),
			filepath.Join(npmPrefix, "luacheck"),
			filepath.Join(npmPrefix, "bin", "luacheck"),
			filepath.Join(npmPrefix, "bin", "luacheck.cmd"),
		)
	}

	if appData != "" {
		candidates = append(candidates,
			filepath.Join(appData, "npm", "luacheck.cmd"),
			filepath.Join(appData, "npm", "luacheck"),
			filepath.Join(appData, "luarocks", "bin", "luacheck.bat"),
			filepath.Join(appData, "luarocks", "bin", "luacheck.exe"),
		)
	}

	if userProfile != "" {
		candidates = append(candidates,
			filepath.Join(userProfile, "AppData", "Roaming", "npm", "luacheck.cmd"),
			filepath.Join(userProfile, "AppData", "Roaming", "npm", "luacheck"),
			filepath.Join(userProfile, "scoop", "apps", "luarocks", "current", "luarocks.exe"),
			filepath.Join(userProfile, "scoop", "apps", "luarocks", "current", "luarocks.bat"),
			filepath.Join(userProfile, "scoop", "apps", "luarocks", "current", "luacheck.bat"),
			filepath.Join(userProfile, "AppData", "Roaming", "luarocks", "bin", "luacheck.bat"),
			filepath.Join(userProfile, "AppData", "Roaming", "luarocks", "bin", "luacheck.exe"),
		)
	}

	for _, pf := range []string{os.Getenv("ProgramFiles"), os.Getenv("ProgramFiles(x86)")} {
		if pf == "" {
			continue
		}
		candidates = append(candidates,
			filepath.Join(pf, "Lua", "bin", "luacheck.bat"),
			filepath.Join(pf, "Lua", "bin", "luacheck.exe"),
		)
	}

	candidates = append(candidates,
		"luacheck",
		"luacheck.exe",
		"luacheck.cmd",
		"luacheck.bat",
	)

	return uniqueStrings(candidates)
}

func getNpmGlobalPrefix() string {
	for _, npm := range []string{"npm.cmd", "npm"} {
		if _, err := exec.LookPath(npm); err != nil {
			continue
		}

		out, err := exec.Command(npm, "prefix", "-g").Output()
		if err != nil {
			continue
		}

		prefix := strings.TrimSpace(string(out))
		if prefix != "" {
			return prefix
		}
	}

	return ""
}

func uniqueStrings(values []string) []string {
	seen := make(map[string]bool, len(values))
	unique := make([]string, 0, len(values))
	for _, value := range values {
		if value == "" || seen[value] {
			continue
		}
		seen[value] = true
		unique = append(unique, value)
	}
	return unique
}
