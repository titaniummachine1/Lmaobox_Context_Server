package main

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// Test Summary:
// These tests verify the Zero-Mutation Lbox policy is:
// 1. STRICT ENOUGH for AI to reliably follow without loopholes
// 2. NOT OVERLY RIGID for human developers
//
// Acceptable patterns:
// - State control (local flags) in Unload callback
// - If/for/while/repeat blocks at depth 0 (they don't isolate)
// - Multiple separate callback pairs
// - Unregister without ID
//
// Forbidden patterns:
// - Unregister inside any function (including Unload, nested fns)
// - Register inside any function
// - Register without prior unregister at depth 0 (kill-switch)

func writeTempLua(t *testing.T, name, content string) string {
	t.Helper()
	path := filepath.Join(os.TempDir(), "policy_test_"+name+".lua")
	if err := os.WriteFile(path, []byte(content), 0644); err != nil {
		t.Fatalf("failed to write temp lua file: %v", err)
	}
	return path
}

func TestUnregisterInsideFunction(t *testing.T) {
	src := `
local function stop()
    callbacks.unregister("Draw", "MyLoop")
end

callbacks.register("MyLoop", "MyLoop", function() end)
`
	path := writeTempLua(t, "unregister_in_fn", src)
	violations, err := checkLuaCallbackMutationPolicy(path, defaultLboxMutationPolicy)
	if err != nil {
		t.Fatalf("policy check error: %v", err)
	}
	if len(violations) == 0 {
		t.Fatalf("expected violations for unregister inside function, got none")
	}
	found := false
	for _, v := range violations {
		if strings.Contains(v.Message, "Illegal Unregister") || strings.Contains(v.Message, "callbacks.Unregister must be declared at depth 0") {
			found = true
			break
		}
	}
	if !found {
		t.Fatalf("expected Illegal Unregister violation, got: %+v", violations)
	}
}

func TestKillSwitchViolation(t *testing.T) {
	src := `
callbacks.register("Draw", "MyLoop", function() end)
`
	path := writeTempLua(t, "kill_switch_violation", src)
	violations, err := checkLuaCallbackMutationPolicy(path, defaultLboxMutationPolicy)
	if err != nil {
		t.Fatalf("policy check error: %v", err)
	}
	if len(violations) == 0 {
		t.Fatalf("expected kill-switch violation for register without prior unregister, got none")
	}
	found := false
	for _, v := range violations {
		if strings.Contains(v.Message, "Kill-Switch violation") {
			found = true
			break
		}
	}
	if !found {
		t.Fatalf("expected Kill-Switch violation, got: %+v", violations)
	}
}

func TestValidUnregisterThenRegister(t *testing.T) {
	src := `
callbacks.unregister("Draw", "MyLoop")
callbacks.register("Draw", "MyLoop", function() end)
`
	path := writeTempLua(t, "valid_kill_switch", src)
	violations, err := checkLuaCallbackMutationPolicy(path, defaultLboxMutationPolicy)
	if err != nil {
		t.Fatalf("policy check error: %v", err)
	}
	if len(violations) != 0 {
		t.Fatalf("expected no violations for valid unregister->register, got: %+v", violations)
	}
}

func TestUnregisterInOnUnload(t *testing.T) {
	src := `
callbacks.register("Unload", function()
	callbacks.unregister("Draw", "MyLoop")
end)
`
	path := writeTempLua(t, "unload_unreg", src)
	violations, err := checkLuaCallbackMutationPolicy(path, defaultLboxMutationPolicy)
	if err != nil {
		t.Fatalf("policy check error: %v", err)
	}
	if len(violations) == 0 {
		t.Fatalf("expected violations for unregister inside OnUnload, got none")
	}
	found := false
	for _, v := range violations {
		if strings.Contains(v.Message, "Illegal Unregister") {
			found = true
			break
		}
	}
	if !found {
		t.Fatalf("expected Illegal Unregister violation, got: %+v", violations)
	}
}

func TestRunLuacheckIntegration(t *testing.T) {
	src := `
local unused = 123
`
	path := writeTempLua(t, "luacheck_test", src)

	issues, err := runLuacheck(context.Background(), path)
	if err != nil {
		if errors.Is(err, errLuacheckNotFound) {
			t.Skip("luacheck not installed; skipping integration test")
		}
		t.Fatalf("luacheck execution error: %v", err)
	}

	if len(issues) == 0 {
		t.Fatalf("expected luacheck to report issues for unused variable, got none")
	}
}

// ── Tests for Balanced Rigidity ──────────────────────────────────────────────

func TestGhostPatternApproved(t *testing.T) {
	// "Ghost Pattern" from user: State control (running flag) inside Unload is OK.
	// This should NOT trigger any violations.
	src := `
local running = true

callbacks.register("Unload", function()
    running = false -- Safe: Just changing a variable
end)

callbacks.register("MyMainLoop", function()
    if not running then return end
    -- ... core logic ...
end)
`
	path := writeTempLua(t, "ghost_pattern_approved", src)
	violations, err := checkLuaCallbackMutationPolicy(path, defaultLboxMutationPolicy)
	if err != nil {
		t.Fatalf("policy check error: %v", err)
	}
	if len(violations) != 0 {
		t.Fatalf("expected no violations for Ghost Pattern (state control), got: %+v", violations)
	}
}

func TestIfBlockDoesNotIncrementDepth(t *testing.T) {
	// If/for/while blocks should NOT increment functionDepth.
	// Register inside if block at depth 0 should violate kill-switch, not register depth.
	src := `
if condition then
    callbacks.register("Draw", "MyLoop", function() end)
end
`
	path := writeTempLua(t, "if_block_depth", src)
	violations, err := checkLuaCallbackMutationPolicy(path, defaultLboxMutationPolicy)
	if err != nil {
		t.Fatalf("policy check error: %v", err)
	}
	// Should report kill-switch violation, not "register at depth 0" violation
	found := false
	for _, v := range violations {
		if strings.Contains(v.Message, "Kill-Switch violation") {
			found = true
			break
		}
	}
	if !found {
		t.Fatalf("expected Kill-Switch violation (if blocks don't increment depth), got: %+v", violations)
	}
}

func TestRepeatUntilBlockAllowed(t *testing.T) {
	// Repeat/until is a loop, but should not prevent register/unregister at depth 0.
	// However, if unregister is INSIDE repeat, it should fail.
	src := `
repeat
    callbacks.register("Draw", "MyLoop", function() end)
until false
`
	path := writeTempLua(t, "repeat_block", src)
	violations, err := checkLuaCallbackMutationPolicy(path, defaultLboxMutationPolicy)
	if err != nil {
		t.Fatalf("policy check error: %v", err)
	}
	// Register inside repeat block = depth 0 semantically (not in a function),
	// so it should only report kill-switch, not "register at depth 0".
	for _, v := range violations {
		if strings.Contains(v.Message, "callbacks.Register must be declared at depth 0") {
			t.Fatalf("repeat block incorrectly incremented function depth")
		}
	}
}

func TestMultipleSeparateCallbacks(t *testing.T) {
	// Different event/ID combos can be registered independently.
	// Each should have its own kill-switch check.
	src := `
callbacks.unregister("Draw", "Loop1")
callbacks.register("Draw", "Loop1", function() end)

callbacks.unregister("Tick", "Loop2")
callbacks.register("Tick", "Loop2", function() end)
`
	path := writeTempLua(t, "multi_callbacks", src)
	violations, err := checkLuaCallbackMutationPolicy(path, defaultLboxMutationPolicy)
	if err != nil {
		t.Fatalf("policy check error: %v", err)
	}
	if len(violations) != 0 {
		t.Fatalf("expected no violations for separate callback pairs, got: %+v", violations)
	}
}

func TestUnregisterWithoutIDAllowed(t *testing.T) {
	// Some engines allow callbacks.unregister("EventName") without ID.
	// This is at depth 0 so should pass kill-switch check (no ID to check).
	src := `
callbacks.unregister("Draw")
callbacks.register("Draw", "MyLoop", function() end)
`
	path := writeTempLua(t, "unregister_no_id", src)
	violations, err := checkLuaCallbackMutationPolicy(path, defaultLboxMutationPolicy)
	if err != nil {
		t.Fatalf("policy check error: %v", err)
	}
	if len(violations) != 0 {
		t.Fatalf("expected no violations for unregister without ID, got: %+v", violations)
	}
}

func TestNestedFunctionCallbacks(t *testing.T) {
	// Nested function (function inside function) should increment depth.
	src := `
local function setup()
    local function innerRegister()
        callbacks.register("Draw", "MyLoop", function() end)
    end
    innerRegister()
end
setup()
`
	path := writeTempLua(t, "nested_function", src)
	violations, err := checkLuaCallbackMutationPolicy(path, defaultLboxMutationPolicy)
	if err != nil {
		t.Fatalf("policy check error: %v", err)
	}
	// Nested function => depth > 0 => register should fail
	found := false
	for _, v := range violations {
		if strings.Contains(v.Message, "callbacks.Register must be declared at depth 0") {
			found = true
			break
		}
	}
	if !found {
		t.Fatalf("expected depth violation for nested function register, got: %+v", violations)
	}
}

func TestCommentedOutUnregister(t *testing.T) {
	// Comments should be stripped; this code has unregister commented out.
	// The register should fail kill-switch because unregister is not "real".
	src := `
-- callbacks.unregister("Draw", "MyLoop")
callbacks.register("Draw", "MyLoop", function() end)
`
	path := writeTempLua(t, "commented_unregister", src)
	violations, err := checkLuaCallbackMutationPolicy(path, defaultLboxMutationPolicy)
	if err != nil {
		t.Fatalf("policy check error: %v", err)
	}
	// Should report kill-switch violation
	found := false
	for _, v := range violations {
		if strings.Contains(v.Message, "Kill-Switch violation") {
			found = true
			break
		}
	}
	if !found {
		t.Fatalf("expected Kill-Switch violation (comment was stripped), got: %+v", violations)
	}
}
