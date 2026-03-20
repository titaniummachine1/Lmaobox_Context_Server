package main

import (
	"context"
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

func main() {
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
		// Syntax check with luac
		luacPath := findLuac()
		if luacPath == "" {
			return mcp.NewToolResultError("Lua compiler not found. Install Lua 5.4+ from https://luabinaries.sourceforge.net/"), nil
		}

		cmd := exec.CommandContext(checkCtx, luacPath, "-p", filePath)
		output, err := cmd.CombinedOutput()

		if checkCtx.Err() == context.DeadlineExceeded {
			return mcp.NewToolResultError("Syntax check timed out after 10 seconds"), nil
		}

		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Lua syntax error:\n%s", string(output))), nil
		}

		return mcp.NewToolResultText("✓ Lua syntax is valid"), nil
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

	// Add bundle header
	builder.WriteString("-- Bundled Lua generated by Lmaobox Context Server\n")
	builder.WriteString("-- Entry point: " + filepath.Base(entryFile) + "\n\n")

	// Add all modules except entry file
	for filePath, module := range bundleCtx.Modules {
		if filePath != entryFile {
			moduleName := getModuleName(filePath, bundleCtx.ProjectDir)
			builder.WriteString(fmt.Sprintf("-- Module: %s\n", moduleName))
			builder.WriteString("local " + strings.ReplaceAll(moduleName, ".", "_") + " = (function()\n")
			builder.WriteString(module.Content)
			builder.WriteString("\nend)()\n\n")
		}
	}

	// Add entry file content
	if entryModule, exists := bundleCtx.Modules[entryFile]; exists {
		builder.WriteString("-- Entry point\n")
		builder.WriteString(entryModule.Content)
	}

	return builder.String(), nil
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

	return nil
}

func findTypeDefinition(symbol string) (string, error) {
	typesDir := filepath.Join(filepath.Dir(os.Args[0]), "types", "lmaobox_lua_api")

	// Search in .d.lua files
	typeFiles := []string{
		"Lua_Globals.d.lua",
		"Lua_Constants.d.lua",
		"Lua_Callbacks.d.lua",
	}

	for _, file := range typeFiles {
		filePath := filepath.Join(typesDir, file)
		content, err := os.ReadFile(filePath)
		if err != nil {
			continue
		}

		// Search for symbol in file content
		lines := strings.Split(string(content), "\n")
		for i, line := range lines {
			if strings.Contains(line, symbol) {
				// Extract context around the symbol
				start := max(0, i-2)
				end := min(len(lines), i+5)
				context := strings.Join(lines[start:end], "\n")
				return fmt.Sprintf("Found in %s:\n\n%s", file, context), nil
			}
		}
	}

	// Also check docs-index.json for API structure
	docsPath := filepath.Join(filepath.Dir(os.Args[0]), "types", "docs-index.json")
	if docsContent, err := os.ReadFile(docsPath); err == nil {
		if strings.Contains(string(docsContent), symbol) {
			return fmt.Sprintf("API reference found for '%s' - check types/docs-index.json for detailed structure", symbol), nil
		}
	}

	return "", nil
}

func findSmartContext(symbol string) (string, error) {
	smartContextDir := filepath.Join(filepath.Dir(os.Args[0]), "data", "smart_context")

	// Try different search strategies
	strategies := []string{
		symbol + ".md",                  // direct match like "Color.md"
		strings.ToLower(symbol) + ".md", // lowercase version
		strings.Title(symbol) + ".md",   // title case
	}

	// Also try to find by path (e.g., "draw.Color" -> "draw/Color.md")
	if strings.Contains(symbol, ".") {
		parts := strings.Split(symbol, ".")
		if len(parts) == 2 {
			strategies = append(strategies, filepath.Join(parts[0], parts[1]+".md"))
		}
	}

	for _, strategy := range strategies {
		filePath := filepath.Join(smartContextDir, strategy)
		if content, err := os.ReadFile(filePath); err == nil {
			return string(content), nil
		}
	}

	// Search recursively in subdirectories
	var foundContent string
	err := filepath.WalkDir(smartContextDir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return nil // Continue on errors
		}
		if d.IsDir() || !strings.HasSuffix(path, ".md") {
			return nil
		}

		fileName := filepath.Base(path)
		if strings.Contains(strings.ToLower(fileName), strings.ToLower(symbol)) {
			if content, readErr := os.ReadFile(path); readErr == nil {
				foundContent = string(content)
				return filepath.SkipAll // Stop walking
			}
		}
		return nil
	})

	if err == filepath.SkipAll {
		return foundContent, nil
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
