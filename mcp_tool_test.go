package main

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// ── MCP Tool Tests ──────────────────────────────────────────────────────────
//
// These tests verify that the core validation functions work correctly,
// which are used by the MCP tools (luacheck, bundle, etc).

func createTempLuaFile(t *testing.T, name, content string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), name+".lua")
	if err := os.WriteFile(path, []byte(content), 0644); err != nil {
		t.Fatalf("failed to create temp file: %v", err)
	}
	return path
}

// ── Tests for Validation Functions (Used by MCP Tools) ──────────────────────

// TestValidateLuaSyntaxValid tests that valid Lua syntax passes
func TestValidateLuaSyntaxValid(t *testing.T) {
	if findLuac() == "" {
		t.Skip("Lua compiler not installed; skipping syntax validation test")
	}

	src := `
local x = 10
local function add(a, b)
    return a + b
end
print(add(5, 3))
`
	path := createTempLuaFile(t, "valid_syntax", src)

	ctx := context.Background()
	err := validateLuaSyntax(ctx, path)
	if err != nil {
		t.Fatalf("expected valid syntax, got error: %v", err)
	}
}

// TestValidateLuaSyntaxInvalid tests that invalid Lua syntax fails
func TestValidateLuaSyntaxInvalid(t *testing.T) {
	if findLuac() == "" {
		t.Skip("Lua compiler not installed; skipping syntax validation test")
	}

	src := `local x = `
	path := createTempLuaFile(t, "invalid_syntax", src)

	ctx := context.Background()
	err := validateLuaSyntax(ctx, path)
	if err == nil {
		t.Fatalf("expected syntax error, got success")
	}

	if !strings.Contains(err.Error(), "syntax") && !strings.Contains(err.Error(), "error") {
		t.Fatalf("expected syntax error message, got: %v", err)
	}
}

// TestZeroMutationUnregisterInFunction tests Zero-Mutation rule violation
func TestZeroMutationUnregisterInFunction(t *testing.T) {
	src := `
local function cleanup()
    callbacks.unregister("Draw", "MyLoop")
end

callbacks.register("Draw", "MyLoop", function() end)
`
	path := createTempLuaFile(t, "zero_mut_unreg_fn", src)

	violations, err := checkLuaCallbackMutationPolicy(path, defaultLboxMutationPolicy)
	if err != nil {
		t.Fatalf("policy check error: %v", err)
	}

	if len(violations) == 0 {
		t.Fatalf("expected policy violation for unregister in function")
	}

	if !strings.Contains(violations[0].Message, "Illegal Unregister") {
		t.Fatalf("expected Illegal Unregister violation, got: %s", violations[0].Message)
	}
}

// TestZeroMutationUnregisterInOnUnload tests unregister in OnUnload is banned
func TestZeroMutationUnregisterInOnUnload(t *testing.T) {
	src := `
callbacks.register("Unload", function()
    callbacks.unregister("Draw", "MyLoop")
end)

callbacks.register("Draw", "MyLoop", function() end)
`
	path := createTempLuaFile(t, "zero_mut_unload", src)

	violations, err := checkLuaCallbackMutationPolicy(path, defaultLboxMutationPolicy)
	if err != nil {
		t.Fatalf("policy check error: %v", err)
	}

	if len(violations) == 0 {
		t.Fatalf("expected violation in OnUnload")
	}

	if !strings.Contains(violations[0].Message, "Illegal Unregister") {
		t.Fatalf("expected Illegal Unregister violation, got: %s", violations[0].Message)
	}
}

// TestZeroMutationKillSwitchViolation tests kill-switch requirement
func TestZeroMutationKillSwitchViolation(t *testing.T) {
	src := `
callbacks.register("Draw", "MyLoop", function()
    print("Running")
end)
`
	path := createTempLuaFile(t, "zero_mut_kill_switch", src)

	violations, err := checkLuaCallbackMutationPolicy(path, defaultLboxMutationPolicy)
	if err != nil {
		t.Fatalf("policy check error: %v", err)
	}

	if len(violations) == 0 {
		t.Fatalf("expected kill-switch violation")
	}

	if !strings.Contains(violations[0].Message, "Kill-Switch") {
		t.Fatalf("expected Kill-Switch violation, got: %s", violations[0].Message)
	}
}

// TestZeroMutationGhostPatternApproved tests Ghost Pattern is allowed
func TestZeroMutationGhostPatternApproved(t *testing.T) {
	src := `
local running = true

callbacks.unregister("Draw", "MyLoop")
callbacks.register("Draw", "MyLoop", function()
    if not running then return end
    print("Running")
end)

callbacks.register("Unload", function()
    running = false
end)
`
	path := createTempLuaFile(t, "ghost_pattern", src)

	violations, err := checkLuaCallbackMutationPolicy(path, defaultLboxMutationPolicy)
	if err != nil {
		t.Fatalf("policy check error: %v", err)
	}

	if len(violations) > 0 {
		t.Fatalf("expected Ghost Pattern to pass, got violations: %v", violations)
	}
}

// TestZeroMutationRegisterInNestedFunction tests register in nested function is banned
func TestZeroMutationRegisterInNestedFunction(t *testing.T) {
	src := `
local function setup()
    local function inner()
        callbacks.register("Draw", "MyLoop", function() end)
    end
    inner()
end
setup()
`
	path := createTempLuaFile(t, "register_nested_fn", src)

	violations, err := checkLuaCallbackMutationPolicy(path, defaultLboxMutationPolicy)
	if err != nil {
		t.Fatalf("policy check error: %v", err)
	}

	if len(violations) == 0 {
		t.Fatalf("expected error for register in nested function")
	}

	if !strings.Contains(violations[0].Message, "depth 0") {
		t.Fatalf("expected depth violation message, got: %s", violations[0].Message)
	}
}

// TestZeroMutationIfBlockNoDepthIsolation tests if blocks don't isolate
func TestZeroMutationIfBlockNoDepthIsolation(t *testing.T) {
	// If block at depth 0 should fail kill-switch, not depth check
	src := `
if true then
    callbacks.register("Draw", "MyLoop", function() end)
end
`
	path := createTempLuaFile(t, "if_block", src)

	violations, err := checkLuaCallbackMutationPolicy(path, defaultLboxMutationPolicy)
	if err != nil {
		t.Fatalf("policy check error: %v", err)
	}

	if len(violations) == 0 {
		t.Fatalf("expected kill-switch violation")
	}

	if !strings.Contains(violations[0].Message, "Kill-Switch") {
		t.Fatalf("expected Kill-Switch violation (not depth), got: %s", violations[0].Message)
	}
}

// TestZeroMutationMultipleViolations tests that multiple violations are reported
func TestZeroMutationMultipleViolations(t *testing.T) {
	src := `
local function bad1()
    callbacks.unregister("Draw", "Loop1")
end

local function bad2()
    callbacks.unregister("Tick", "Loop2")
end

callbacks.register("Draw", "Loop1", function() end)
`
	path := createTempLuaFile(t, "multiple_violations", src)

	violations, err := checkLuaCallbackMutationPolicy(path, defaultLboxMutationPolicy)
	if err != nil {
		t.Fatalf("policy check error: %v", err)
	}

	if len(violations) < 2 {
		t.Fatalf("expected at least 2 violations, got: %d", len(violations))
	}
}

// TestZeroMutationMissingFile tests error handling for missing file
func TestZeroMutationMissingFile(t *testing.T) {
	violations, err := checkLuaCallbackMutationPolicy("/nonexistent/path/file.lua", defaultLboxMutationPolicy)
	if err == nil {
		t.Fatalf("expected error for missing file, got success")
	}

	if len(violations) > 0 {
		t.Fatalf("expected empty violations on error, got: %v", violations)
	}
}

func TestFormatSearchResultsMarkdownIncludesSnippetSection(t *testing.T) {
	results := []SmartSearchResult{{
		Symbol:      "draw.Color",
		Kind:        "function",
		Section:     "library",
		Description: "Sets the current draw color",
		Signature:   "draw.Color(r, g, b, a)",
	}}
	snippetResults := []SmartSearchResult{{
		Symbol:      "lm.draw",
		Kind:        "snippet",
		Section:     "snippet",
		Description: "Draw callback scaffold",
		Signature:   "callbacks.Register('Draw', 'Example', function()",
	}}

	output := formatSearchResultsMarkdown("draw", results, snippetResults, 10)

	if !strings.Contains(output, "### Snippets (secondary matches)") {
		t.Fatalf("expected snippet section in output, got: %s", output)
	}

	if !strings.Contains(output, "`lm.draw`") {
		t.Fatalf("expected snippet prefix in output, got: %s", output)
	}

	if !strings.Contains(output, "get_smart_context(\"draw.Color\")") {
		t.Fatalf("expected primary-result next steps in output, got: %s", output)
	}
}

func TestFormatSearchResultsMarkdownSnippetOnlyNextSteps(t *testing.T) {
	snippetResults := []SmartSearchResult{{
		Symbol:      "lm.createMove",
		Kind:        "snippet",
		Section:     "snippet",
		Description: "CreateMove callback scaffold",
		Signature:   "callbacks.Register('CreateMove', 'Example', function(cmd)",
	}}

	output := formatSearchResultsMarkdown("create move", nil, snippetResults, 10)

	if !strings.Contains(output, "Try snippet prefix `lm.createMove` in a Lua file") {
		t.Fatalf("expected snippet-only next step, got: %s", output)
	}

	if strings.Contains(output, "get_smart_context") {
		t.Fatalf("did not expect API next steps when only snippets matched, got: %s", output)
	}
}

func TestFormatSearchResultsMarkdownUsesDisplayedPrimaryForNextSteps(t *testing.T) {
	results := []SmartSearchResult{
		{
			Symbol:      "E_TraceLine",
			Kind:        "function",
			Section:     "symbol",
			Description: "Legacy constant helper",
			Signature:   "function E_TraceLine()",
		},
		{
			Symbol:      "engine.TraceLine",
			Kind:        "function",
			Section:     "library",
			Description: "Primary trace API",
			Signature:   "function engine.TraceLine(src, dst, mask, shouldHitEntity)",
		},
	}

	output := formatSearchResultsMarkdown("trace line", results, nil, 8)

	if !strings.Contains(output, "get_smart_context(\"engine.TraceLine\")") {
		t.Fatalf("expected next steps to use first displayed primary result, got: %s", output)
	}

	if strings.Contains(output, "get_smart_context(\"E_TraceLine\")") {
		t.Fatalf("did not expect next steps to use hidden top-scoring symbol, got: %s", output)
	}
}

func TestBuildLuacheckCandidatesIncludesGlobalWindowsPaths(t *testing.T) {
	candidates := buildLuacheckCandidates(
		`C:\repo`,
		`C:\Users\Tester\AppData\Roaming\npm`,
		`C:\Users\Tester\AppData\Roaming`,
		`C:\Users\Tester`,
	)

	joined := strings.Join(candidates, "\n")

	checks := []string{
		`C:\repo\automations\bin\luacheck\luacheck.exe`,
		`C:\Users\Tester\AppData\Roaming\npm\luacheck.cmd`,
		`C:\Users\Tester\AppData\Roaming\npm\luacheck`,
		`luacheck.cmd`,
	}

	for _, check := range checks {
		if !strings.Contains(joined, check) {
			t.Fatalf("expected candidate list to include %q, got: %s", check, joined)
		}
	}
}

// TestZeroMutationUnregisterWithoutID tests ID-less unregister satisfies kill-switch
func TestZeroMutationUnregisterWithoutID(t *testing.T) {
	src := `
callbacks.unregister("Draw")
callbacks.register("Draw", "MyLoop", function()
    print("Running")
end)
`
	path := createTempLuaFile(t, "unreg_without_id", src)

	violations, err := checkLuaCallbackMutationPolicy(path, defaultLboxMutationPolicy)
	if err != nil {
		t.Fatalf("policy check error: %v", err)
	}

	if len(violations) > 0 {
		t.Fatalf("expected ID-less unregister to satisfy kill-switch, got violations: %v", violations)
	}
}

// TestForbidCollectGarbage verifies collectgarbage() is flagged
func TestForbidCollectGarbage(t *testing.T) {
	src := `
local function cleanup()
    collectgarbage("collect")
end
`
	path := createTempLuaFile(t, "collectgarbage", src)

	violations, err := checkLuaCallbackMutationPolicy(path, defaultLboxMutationPolicy)
	if err != nil {
		t.Fatalf("policy check error: %v", err)
	}

	if len(violations) == 0 {
		t.Fatalf("expected collectgarbage violation")
	}

	if !strings.Contains(violations[0].Message, "collectgarbage") {
		t.Fatalf("expected collectgarbage message, got: %s", violations[0].Message)
	}
}

// TestCollectGarbageAllowed verifies collectgarbage as a variable name is not flagged
func TestCollectGarbageNotACall(t *testing.T) {
	src := `
local collectgarbage = nil
print(collectgarbage)
`
	path := createTempLuaFile(t, "collectgarbage_var", src)

	violations, err := checkLuaCallbackMutationPolicy(path, defaultLboxMutationPolicy)
	if err != nil {
		t.Fatalf("policy check error: %v", err)
	}

	for _, v := range violations {
		if strings.Contains(v.Message, "collectgarbage") {
			t.Fatalf("should not flag collectgarbage variable, got: %s", v.Message)
		}
	}
}

// TestForbidRequireInFunction verifies require() inside a function is flagged
func TestForbidRequireInFunction(t *testing.T) {
	src := `
local function setup()
    local lib = require("SomeLib")
    lib.init()
end
`
	path := createTempLuaFile(t, "require_in_func", src)

	violations, err := checkLuaCallbackMutationPolicy(path, defaultLboxMutationPolicy)
	if err != nil {
		t.Fatalf("policy check error: %v", err)
	}

	if len(violations) == 0 {
		t.Fatalf("expected require-in-function violation")
	}

	if !strings.Contains(violations[0].Message, "require()") {
		t.Fatalf("expected require() message, got: %s", violations[0].Message)
	}
}

// TestRequireAtTopLevelAllowed verifies top-level require() is fine
func TestRequireAtTopLevelAllowed(t *testing.T) {
	src := `
local lnxLib = require("lnxLib")
local TimMenu = require("TimMenu")
`
	path := createTempLuaFile(t, "require_top", src)

	violations, err := checkLuaCallbackMutationPolicy(path, defaultLboxMutationPolicy)
	if err != nil {
		t.Fatalf("policy check error: %v", err)
	}

	for _, v := range violations {
		if strings.Contains(v.Message, "require()") {
			t.Fatalf("top-level require should be allowed, got: %s", v.Message)
		}
	}
}

// TestForbidGlobalTable verifies _G access is flagged
func TestForbidGlobalTable(t *testing.T) {
	src := `
_G["myVar"] = 42
`
	path := createTempLuaFile(t, "global_table", src)

	violations, err := checkLuaCallbackMutationPolicy(path, defaultLboxMutationPolicy)
	if err != nil {
		t.Fatalf("policy check error: %v", err)
	}

	if len(violations) == 0 {
		t.Fatalf("expected _G violation")
	}

	if !strings.Contains(violations[0].Message, "_G") {
		t.Fatalf("expected _G message, got: %s", violations[0].Message)
	}
}

// TestForbidGlobalTableDotAccess verifies _G.foo access is flagged
func TestForbidGlobalTableDotAccess(t *testing.T) {
	src := `
local x = _G.someGlobal
`
	path := createTempLuaFile(t, "global_table_dot", src)

	violations, err := checkLuaCallbackMutationPolicy(path, defaultLboxMutationPolicy)
	if err != nil {
		t.Fatalf("policy check error: %v", err)
	}

	if len(violations) == 0 {
		t.Fatalf("expected _G dot-access violation")
	}
}
