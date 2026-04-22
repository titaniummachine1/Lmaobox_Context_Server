package main

import (
	"context"
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
	"time"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"
)

const (
	SERVER_NAME    = "LmaoboxContext"
	SERVER_VERSION = "1.0.0"
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

type LboxMutationPolicy struct {
	RequireDepthZeroRegister   bool
	RequireDepthZeroUnregister bool
	RequireKillSwitchOrder     bool
	ForbidRuntimeUnregister    bool
}

type luaPolicyViolation struct {
	Line    int
	Message string
}

type luaToken struct {
	Kind string
	Text string
	Line int
}

type luaPolicyBlockKind int

const (
	luaBlockGeneric luaPolicyBlockKind = iota
	luaBlockFunction
	luaBlockRepeat
)

var defaultLboxMutationPolicy = LboxMutationPolicy{
	RequireDepthZeroRegister:   true,
	RequireDepthZeroUnregister: true,
	RequireKillSwitchOrder:     true,
	ForbidRuntimeUnregister:    true,
}

func main() {
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

		return mcp.NewToolResultText("✓ Lua syntax is valid and passed Zero-Mutation callback policy"), nil
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
	bundledContent, err := generateBundledLua(bundleCtx, entryFilePath)
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

func generateBundledLua(bundleCtx *BundleContext, entryFile string) (string, error) {
	var builder strings.Builder
	bundledModuleNames := make(map[string]bool)
	modulePaths := sortedModulePaths(bundleCtx.Modules)

	// Add bundle header
	builder.WriteString("-- Bundled Lua generated by Lmaobox Context Server\n")
	builder.WriteString("-- Entry point: " + filepath.Base(entryFile) + "\n\n")
	builder.WriteString("local __bundle_modules = {}\n")
	builder.WriteString("local __bundle_loaded = {}\n\n")
	builder.WriteString("local function __bundle_require(name)\n")
	builder.WriteString("    local loader = __bundle_modules[name]\n")
	builder.WriteString("    if loader == nil then\n")
	builder.WriteString("        return require(name)\n")
	builder.WriteString("    end\n\n")
	builder.WriteString("    local cached = __bundle_loaded[name]\n")
	builder.WriteString("    if cached ~= nil then\n")
	builder.WriteString("        return cached\n")
	builder.WriteString("    end\n\n")
	builder.WriteString("    local loaded = loader()\n")
	builder.WriteString("    if loaded == nil then\n")
	builder.WriteString("        loaded = true\n")
	builder.WriteString("    end\n\n")
	builder.WriteString("    __bundle_loaded[name] = loaded\n")
	builder.WriteString("    return loaded\n")
	builder.WriteString("end\n\n")

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
			builder.WriteString(fmt.Sprintf("-- Module: %s\n", moduleName))
			builder.WriteString(fmt.Sprintf("__bundle_modules[%q] = function()\n", moduleName))
			builder.WriteString(transformBundledRequires(module.Content, bundledModuleNames))
			builder.WriteString("\nend\n\n")
		}
	}

	// Add entry file content
	if entryModule, exists := bundleCtx.Modules[entryFile]; exists {
		builder.WriteString("-- Entry point\n")
		builder.WriteString(transformBundledRequires(entryModule.Content, bundledModuleNames))
	}

	return builder.String(), nil
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

func checkLuaCallbackMutationPolicy(filePath string, policy LboxMutationPolicy) ([]luaPolicyViolation, error) {
	contentBytes, err := os.ReadFile(filePath)
	if err != nil {
		return nil, fmt.Errorf("failed to read file for policy scan: %v", err)
	}

	tokens, err := tokenizeLua(string(contentBytes))
	if err != nil {
		return nil, err
	}

	violations := make([]luaPolicyViolation, 0)
	blockStack := make([]luaPolicyBlockKind, 0)
	functionDepth := 0
	unregisteredAtDepthZero := make(map[string]bool)

	for i := 0; i < len(tokens); i++ {
		tok := tokens[i]

		if method, args, endIndex, ok := extractCallbacksCall(tokens, i); ok {
			line := tok.Line
			eventName := stringArgValue(args, 0)
			uniqueID := stringArgValue(args, 1)

			if strings.EqualFold(method, "register") {
				if policy.RequireDepthZeroRegister && functionDepth > 0 {
					violations = append(violations, luaPolicyViolation{
						Line:    line,
						Message: "CRITICAL: callbacks.Register must be declared at depth 0 (global scope only)",
					})
				}

				if policy.RequireKillSwitchOrder && functionDepth == 0 && eventName != "" {
					// Check kill-switch: either exact ID match or event-only unregister
					killSwitchKeyExact := strings.ToLower(eventName + "|" + uniqueID)
					killSwitchKeyEvent := strings.ToLower(eventName + "|")
					hasExactMatch := unregisteredAtDepthZero[killSwitchKeyExact]
					hasEventMatch := unregisteredAtDepthZero[killSwitchKeyEvent]

					if uniqueID != "" && !hasExactMatch && !hasEventMatch {
						violations = append(violations, luaPolicyViolation{
							Line:    line,
							Message: fmt.Sprintf("CRITICAL: Kill-Switch violation for id '%s' on event '%s': callbacks.Unregister must appear before callbacks.Register at depth 0", uniqueID, eventName),
						})
					}
				}
			}

			if strings.EqualFold(method, "unregister") {
				reportedRuntimeUnregister := false
				if policy.ForbidRuntimeUnregister && functionDepth > 0 {
					violations = append(violations, luaPolicyViolation{
						Line:    line,
						Message: "CRITICAL: Illegal Unregister inside function scope (including Unload). Runtime callback table mutation is forbidden",
					})
					reportedRuntimeUnregister = true
				}

				if policy.RequireDepthZeroUnregister && functionDepth > 0 && !reportedRuntimeUnregister {
					violations = append(violations, luaPolicyViolation{
						Line:    line,
						Message: "CRITICAL: callbacks.Unregister must be declared at depth 0 (global scope only)",
					})
				}

				if functionDepth == 0 && eventName != "" {
					// Track unregister at depth 0. If no ID, mark as event-only unregister
					if uniqueID != "" {
						killSwitchKey := strings.ToLower(eventName + "|" + uniqueID)
						unregisteredAtDepthZero[killSwitchKey] = true
					} else {
						// Unregister without ID satisfies kill-switch for this event
						killSwitchKey := strings.ToLower(eventName + "|")
						unregisteredAtDepthZero[killSwitchKey] = true
					}
				}
			}

			// Process the tokens between i and endIndex to track function depth changes
			// AND check for nested callbacks calls inside function arguments.
			for j := i; j < endIndex; j++ {
				t := tokens[j]

				// Update depth BEFORE checking for nested callbacks calls
				if t.Kind == "keyword" {
					switch t.Text {
					case "function":
						blockStack = append(blockStack, luaBlockFunction)
						functionDepth++
					case "end":
						if len(blockStack) > 0 {
							for k := len(blockStack) - 1; k >= 0; k-- {
								if blockStack[k] == luaBlockRepeat {
									continue
								}
								if blockStack[k] == luaBlockFunction && functionDepth > 0 {
									functionDepth--
								}
								blockStack = append(blockStack[:k], blockStack[k+1:]...)
								break
							}
						}
					}
				}

				// Check for nested callbacks calls inside this range using CURRENT depth
				if t.Kind == "ident" && strings.EqualFold(t.Text, "callbacks") {
					if nestedMethod, _, _, nestedOk := extractCallbacksCall(tokens, j); nestedOk {
						nestedLine := t.Line

						// Check nested call violations at CURRENT functionDepth
						if strings.EqualFold(nestedMethod, "unregister") {
							if policy.ForbidRuntimeUnregister && functionDepth > 0 {
								violations = append(violations, luaPolicyViolation{
									Line:    nestedLine,
									Message: "CRITICAL: Illegal Unregister inside function scope (including Unload). Runtime callback table mutation is forbidden",
								})
							}
						}
						if strings.EqualFold(nestedMethod, "register") {
							if policy.RequireDepthZeroRegister && functionDepth > 0 {
								violations = append(violations, luaPolicyViolation{
									Line:    nestedLine,
									Message: "CRITICAL: callbacks.Register must be declared at depth 0 (global scope only)",
								})
							}
						}
					}
				}
			}

			i = endIndex
			continue
		}

		if tok.Kind == "keyword" {
			switch tok.Text {
			case "function":
				blockStack = append(blockStack, luaBlockFunction)
				functionDepth++
			case "if", "for", "while", "do":
				blockStack = append(blockStack, luaBlockGeneric)
			case "repeat":
				blockStack = append(blockStack, luaBlockRepeat)
			case "end":
				if len(blockStack) > 0 {
					for j := len(blockStack) - 1; j >= 0; j-- {
						if blockStack[j] == luaBlockRepeat {
							continue
						}
						if blockStack[j] == luaBlockFunction && functionDepth > 0 {
							functionDepth--
						}
						blockStack = append(blockStack[:j], blockStack[j+1:]...)
						break
					}
				}
			case "until":
				if len(blockStack) > 0 {
					for j := len(blockStack) - 1; j >= 0; j-- {
						if blockStack[j] == luaBlockRepeat {
							blockStack = append(blockStack[:j], blockStack[j+1:]...)
							break
						}
					}
				}
			}
		}
	}

	return violations, nil
}

func formatLuaPolicyViolations(filePath string, violations []luaPolicyViolation) string {
	var builder strings.Builder
	builder.WriteString("Zero-Mutation Lbox policy violation(s) detected:\n")
	builder.WriteString(fmt.Sprintf("file: %s\n", filePath))

	for _, violation := range violations {
		builder.WriteString(fmt.Sprintf("- line %d: %s\n", violation.Line, violation.Message))
	}

	return builder.String()
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

func extractCallbacksCall(tokens []luaToken, start int) (string, [][]luaToken, int, bool) {
	if start+3 >= len(tokens) {
		return "", nil, start, false
	}

	if !(tokens[start].Kind == "ident" && strings.EqualFold(tokens[start].Text, "callbacks")) {
		return "", nil, start, false
	}

	if tokens[start+1].Kind != "symbol" || tokens[start+1].Text != "." {
		return "", nil, start, false
	}

	if tokens[start+2].Kind != "ident" {
		return "", nil, start, false
	}

	method := strings.ToLower(tokens[start+2].Text)
	if method != "register" && method != "unregister" {
		return "", nil, start, false
	}

	if tokens[start+3].Kind != "symbol" || tokens[start+3].Text != "(" {
		return "", nil, start, false
	}

	args, endIndex := collectLuaCallArgs(tokens, start+3)
	if endIndex <= start+3 {
		return "", nil, start, false
	}

	return method, args, endIndex, true
}

func collectLuaCallArgs(tokens []luaToken, openParenIndex int) ([][]luaToken, int) {
	args := make([][]luaToken, 0)
	currentArg := make([]luaToken, 0)
	parenDepth := 0
	braceDepth := 0
	bracketDepth := 0

	for i := openParenIndex; i < len(tokens); i++ {
		tok := tokens[i]
		if tok.Kind == "symbol" {
			switch tok.Text {
			case "(":
				parenDepth++
				if parenDepth > 1 {
					currentArg = append(currentArg, tok)
				}
				continue
			case ")":
				if parenDepth == 1 {
					if len(currentArg) > 0 {
						args = append(args, trimLuaArgTokens(currentArg))
					}
					return args, i
				}
				if parenDepth > 1 {
					currentArg = append(currentArg, tok)
				}
				parenDepth--
				continue
			case "{":
				braceDepth++
			case "}":
				if braceDepth > 0 {
					braceDepth--
				}
			case "[":
				bracketDepth++
			case "]":
				if bracketDepth > 0 {
					bracketDepth--
				}
			case ",":
				if parenDepth == 1 && braceDepth == 0 && bracketDepth == 0 {
					args = append(args, trimLuaArgTokens(currentArg))
					currentArg = make([]luaToken, 0)
					continue
				}
			}
		}

		if parenDepth >= 1 {
			currentArg = append(currentArg, tok)
		}
	}

	return args, openParenIndex
}

func trimLuaArgTokens(arg []luaToken) []luaToken {
	if len(arg) == 0 {
		return arg
	}

	start := 0
	end := len(arg)
	for start < end && arg[start].Kind == "whitespace" {
		start++
	}
	for end > start && arg[end-1].Kind == "whitespace" {
		end--
	}

	if start >= end {
		return []luaToken{}
	}

	return arg[start:end]
}

func stringArgValue(args [][]luaToken, index int) string {
	if index < 0 || index >= len(args) {
		return ""
	}

	arg := args[index]
	if len(arg) != 1 {
		return ""
	}
	if arg[0].Kind != "string" {
		return ""
	}

	return arg[0].Text
}

func tokenizeLua(content string) ([]luaToken, error) {
	tokens := make([]luaToken, 0, len(content)/3)

	runes := []rune(content)
	line := 1

	for i := 0; i < len(runes); {
		ch := runes[i]

		if ch == '\n' {
			line++
			i++
			continue
		}

		if ch == ' ' || ch == '\t' || ch == '\r' {
			i++
			continue
		}

		if ch == '-' && i+1 < len(runes) && runes[i+1] == '-' {
			i += 2
			if openLen, ok := detectLuaLongBracketOpen(runes, i); ok {
				i += openLen
				for i < len(runes) {
					if runes[i] == '\n' {
						line++
					}
					if closeLen, closed := detectLuaLongBracketClose(runes, i, openLen); closed {
						i += closeLen
						break
					}
					i++
				}
				continue
			}

			for i < len(runes) && runes[i] != '\n' {
				i++
			}
			continue
		}

		if ch == '\'' || ch == '"' {
			quote := ch
			startLine := line
			i++
			var builder strings.Builder
			for i < len(runes) {
				if runes[i] == '\n' {
					line++
				}
				if runes[i] == '\\' && i+1 < len(runes) {
					builder.WriteRune(runes[i])
					builder.WriteRune(runes[i+1])
					i += 2
					continue
				}
				if runes[i] == quote {
					i++
					break
				}
				builder.WriteRune(runes[i])
				i++
			}
			tokens = append(tokens, luaToken{Kind: "string", Text: builder.String(), Line: startLine})
			continue
		}

		if openLen, ok := detectLuaLongBracketOpen(runes, i); ok {
			startLine := line
			i += openLen
			var builder strings.Builder
			for i < len(runes) {
				if runes[i] == '\n' {
					line++
				}
				if closeLen, closed := detectLuaLongBracketClose(runes, i, openLen); closed {
					i += closeLen
					break
				}
				builder.WriteRune(runes[i])
				i++
			}
			tokens = append(tokens, luaToken{Kind: "string", Text: builder.String(), Line: startLine})
			continue
		}

		if isLuaIdentifierStart(ch) {
			start := i
			startLine := line
			i++
			for i < len(runes) && isLuaIdentifierPart(runes[i]) {
				i++
			}
			text := string(runes[start:i])
			kind := "ident"
			if isLuaKeyword(text) {
				kind = "keyword"
			}
			tokens = append(tokens, luaToken{Kind: kind, Text: text, Line: startLine})
			continue
		}

		if ch == '.' || ch == '(' || ch == ')' || ch == ',' || ch == '{' || ch == '}' || ch == '[' || ch == ']' {
			tokens = append(tokens, luaToken{Kind: "symbol", Text: string(ch), Line: line})
			i++
			continue
		}

		i++
	}

	return tokens, nil
}

func detectLuaLongBracketOpen(runes []rune, index int) (int, bool) {
	if index >= len(runes) || runes[index] != '[' {
		return 0, false
	}

	i := index + 1
	for i < len(runes) && runes[i] == '=' {
		i++
	}

	if i < len(runes) && runes[i] == '[' {
		return i - index + 1, true
	}

	return 0, false
}

func detectLuaLongBracketClose(runes []rune, index, openLen int) (int, bool) {
	if index >= len(runes) || runes[index] != ']' {
		return 0, false
	}

	eqCount := openLen - 2
	if eqCount < 0 {
		eqCount = 0
	}

	i := index + 1
	for j := 0; j < eqCount; j++ {
		if i >= len(runes) || runes[i] != '=' {
			return 0, false
		}
		i++
	}

	if i < len(runes) && runes[i] == ']' {
		return i - index + 1, true
	}

	return 0, false
}

func isLuaIdentifierStart(ch rune) bool {
	return (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ch == '_'
}

func isLuaIdentifierPart(ch rune) bool {
	return isLuaIdentifierStart(ch) || (ch >= '0' && ch <= '9')
}

func isLuaKeyword(text string) bool {
	switch text {
	case "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "goto", "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while":
		return true
	default:
		return false
	}
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
	if foundContent != "" {
		return combineTypeAndSmartContext(typeInfo, foundContent), nil
	}

	return "", nil
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

	results, err := smartSearch(query, limit)
	if err != nil {
		return mcp.NewToolResultError(fmt.Sprintf("Search failed: %v", err)), nil
	}

	output := formatSearchResultsMarkdown(query, results, limit)
	return mcp.NewToolResultText(output), nil
}

func formatSearchResultsMarkdown(query string, results []SmartSearchResult, limit int) string {
	var sb strings.Builder

	sb.WriteString(fmt.Sprintf("## smart_search: `%s`\n", query))
	sb.WriteString(fmt.Sprintf("_Returned %d of up to %d results_\n\n", len(results), limit))

	if len(results) == 0 {
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

	// Suggest next steps based on top result
	if len(results) > 0 {
		top := results[0]
		sb.WriteString("---\n")
		sb.WriteString("**Next steps:**\n")
		sb.WriteString(fmt.Sprintf("- Full docs & examples: `get_smart_context(\"%s\")` \n", top.Symbol))
		sb.WriteString(fmt.Sprintf("- Type signature only: `get_types(\"%s\")` \n", top.Symbol))
		if len(results) > 1 {
			sb.WriteString(fmt.Sprintf("- More results: re-run `smart_search` with `limit` > %d\n", limit))
		}
	}

	return sb.String()
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
	case "symbol":
		return "Other Symbols"
	default:
		return strings.Title(section)
	}
}

func smartSearch(query string, limit int) ([]SmartSearchResult, error) {
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

	tokens := strings.Fields(queryLower)
	var scored []smartCandidate
	for _, c := range candidates {
		c.Score = scoreSmartCandidate(queryLower, tokens, c.combinedLower, strings.ToLower(c.Symbol))
		if c.Score > 0 {
			scored = append(scored, c)
		}
	}

	sort.Slice(scored, func(i, j int) bool {
		return scored[i].Score > scored[j].Score
	})

	if len(scored) > limit {
		scored = scored[:limit]
	}

	out := make([]SmartSearchResult, len(scored))
	for i, c := range scored {
		out[i] = c.SmartSearchResult
	}
	return out, nil
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

// ── end smart_search ─────────────────────────────────────────────────────────

func ensureDependencies() error {
	luacPath := findLuac()
	luacheckPath := findLuacheck()

	// If both are available, we're good
	if luacPath != "" && luacheckPath != "" {
		log.Printf("✓ Dependencies satisfied: Lua compiler found at %s, luacheck found at %s", luacPath, luacheckPath)
		return nil
	}

	// Need to auto-install. Try running setup scripts.
	scriptDir := filepath.Join(filepath.Dir(os.Args[0]), "automations")

	if luacPath == "" {
		log.Printf("Lua compiler not found, attempting auto-install...")
		if err := runSetupScript(scriptDir, "install_lua.py"); err != nil {
			return fmt.Errorf("Lua 5.4+ installation failed: %w\n"+
				"Please install manually from: https://luabinaries.sourceforge.net/\n"+
				"Or use: choco install lua (if you have Chocolatey)", err)
		}
		log.Printf("✓ Lua compiler installed successfully")
	}

	if luacheckPath == "" {
		log.Printf("luacheck not found, attempting auto-install...")
		if err := installLuacheck(scriptDir); err != nil {
			log.Printf("⚠ luacheck auto-install failed (non-critical): %v", err)
			// Don't fail here - luacheck is optional for MCP functionality
		} else {
			log.Printf("✓ luacheck installed successfully")
		}
	}

	return nil
}

func installLuacheck(scriptDir string) error {
	// Strategy 1: Python setup script
	pythonBin := findPython()
	if _, err := exec.LookPath(pythonBin); err == nil {
		scriptPath := filepath.Join(scriptDir, "install_luacheck.py")
		if _, serr := os.Stat(scriptPath); serr == nil {
			cmd := exec.Command(pythonBin, scriptPath)
			if out, err := cmd.CombinedOutput(); err == nil {
				log.Printf("luacheck install (python script) output:\n%s", string(out))
				return nil
			}
			log.Printf("Python install script failed, trying next method...")
		}
	}

	// Strategy 2: npm install -g luacheck
	if _, err := exec.LookPath("npm"); err == nil {
		log.Printf("Trying: npm install -g luacheck")
		cmd := exec.Command("npm", "install", "-g", "luacheck")
		out, err := cmd.CombinedOutput()
		log.Printf("npm output:\n%s", string(out))
		if err == nil {
			return nil
		}
		log.Printf("npm install failed: %v, trying next method...", err)
	}

	// Strategy 3: pip install luacheck
	for _, pip := range []string{"pip3", "pip"} {
		if _, err := exec.LookPath(pip); err == nil {
			log.Printf("Trying: %s install luacheck", pip)
			cmd := exec.Command(pip, "install", "luacheck")
			out, err := cmd.CombinedOutput()
			log.Printf("%s output:\n%s", pip, string(out))
			if err == nil {
				return nil
			}
			log.Printf("%s install failed: %v", pip, err)
		}
	}

	return fmt.Errorf("all install methods failed. Install manually: npm install -g luacheck  OR  pip install luacheck")
}

func runSetupScript(scriptDir, scriptName string) error {
	scriptPath := filepath.Join(scriptDir, scriptName)

	// Check if script exists
	if _, err := os.Stat(scriptPath); err != nil {
		return fmt.Errorf("setup script not found at %s", scriptPath)
	}

	// Run the Python script
	cmd := exec.Command(findPython(), scriptPath)
	output, err := cmd.CombinedOutput()

	if err != nil {
		return fmt.Errorf("setup script %s failed: %s\n%s", scriptName, err, string(output))
	}

	log.Printf("Setup script output:\n%s", string(output))
	return nil
}

func findPython() string {
	candidates := []string{"python3", "python", "python.exe"}
	for _, cmd := range candidates {
		if _, err := exec.LookPath(cmd); err == nil {
			return cmd
		}
	}
	return "python"
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
	candidates := []string{
		filepath.Join(filepath.Dir(os.Args[0]), "automations", "bin", "luacheck", "luacheck.exe"),
		filepath.Join(filepath.Dir(os.Args[0]), "automations", "bin", "luacheck", "luacheck"),
		"luacheck",
		"luacheck.exe",
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
