## Lmaobox VS Code Snippet Catalog

This catalog mirrors the first-party snippets shipped with the VS Code
extension. It exists so MCP smart-context search can surface snippet matches
when the user asks for examples, templates, boilerplate, or callback skeletons.

### Callback Snippets

- `lm.createMove`: CreateMove callback with `callbacks.Unregister` and `cmd`
- `lm.draw`: Draw callback skeleton
- `lm.fireGameEvent`: FireGameEvent callback skeleton
- `lm.dispatchUserMessage`: DispatchUserMessage callback skeleton
- `lm.unregister`: callback unregister helper

### Entity And Guard Snippets

- `lm.localPlayer`: get local player and early return if nil
- `lm.aliveLocalPlayer`: local player + alive check

### Utility Snippets

- `lm.chatPrintf`: print a chat line
- `lm.command`: run a client command
- `lm.worldToScreen`: convert a world position with nil guard
- `lm.traceLine`: trace line boilerplate
- `lm.drawText`: draw colored text

### Example Templates

#### CreateMove
```lua
callbacks.Unregister("CreateMove", "unique_id")
callbacks.Register("CreateMove", "unique_id", function(cmd)
    local localPlayer = entities.GetLocalPlayer()
    if localPlayer == nil or not localPlayer:IsAlive() then
        return
    end
end)
```

#### Draw
```lua
callbacks.Unregister("Draw", "unique_id")
callbacks.Register("Draw", "unique_id", function()
    draw.Color(255, 255, 255, 255)
    draw.Text(10, 10, "Hello")
end)
```

#### WorldToScreen Guard
```lua
local screenX, screenY = client.WorldToScreen(position)
if screenX == nil or screenY == nil then
    return
end
```

### Notes

- Snippets accelerate writing code but do not replace type definitions.
- For type shapes, hover, and completion details, use `types/`.
- For symbol-specific MCP guidance, prefer the matching markdown page under
  `data/smart_context/lmaobox_lua_api/`.