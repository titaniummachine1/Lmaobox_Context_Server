## Function/Symbol: engine.GetServerIP / GetGameDir / SendKeyValues

> Server/game environment query functions

### Signatures

```lua
engine.GetServerIP()              → string   -- current server IP address
engine.GetGameDir()               → string   -- game directory path
engine.SendKeyValues(keyvalue: string) → boolean -- send a KeyValues string to the server
```

### Curated Usage Examples

```lua
-- Check if on a local/listen server
local ip = engine.GetServerIP()
local isLocal = ip == "loopback"

-- Get game directory for file path construction
local gameDir = engine.GetGameDir()
-- Returns something like: "C:/Program Files/Steam/steamapps/common/Team Fortress 2/tf"

-- Send a keyvalues string to the server (exploit use-case)
local sent = engine.SendKeyValues([[
    gameui_activate
    {
    }
]])
```

### Notes

- `GetServerIP()` returns `"loopback"` when running a local game (offline/LAN)
- `GetGameDir()` returns the full TF directory path; useful for file I/O with custom assets
- `SendKeyValues()` returns false if the connection isn't active or the send fails
