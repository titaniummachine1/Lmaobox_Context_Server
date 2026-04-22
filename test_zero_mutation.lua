-- Test file: Should FAIL Zero-Mutation policy check
-- This violates the rule: "NO unregister inside any function block"

local function OnUnload()
    -- VIOLATION: unregister inside function scope (including Unload)
    callbacks.Unregister("CreateMove", "MyScript")
end

callbacks.Register("Unload", "cleanup", OnUnload)
