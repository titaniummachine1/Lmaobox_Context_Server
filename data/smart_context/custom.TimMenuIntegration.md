## Pattern: TimMenu Custom GUI

> Use TimMenu library for custom in-game menus

### Required Context

- Library: https://github.com/titaniummachine1/TimMenu
- Functions: TimMenu.Begin, TimMenu.Checkbox, TimMenu.Slider, TimMenu.Button
- Pattern: Only draw menu when gui.IsMenuOpen()

### Curated Usage Examples

#### Basic menu structure

```lua
local TimMenu = require("TimMenu")

local settings = {
    aimbot = true,
    fov = 360,
    smoothing = 0.2,
}

local function DrawMenu()
    if not gui.IsMenuOpen() then return end

    if TimMenu.Begin("My Script Settings") then
        settings.aimbot = TimMenu.Checkbox("Enable Aimbot", settings.aimbot)
        settings.fov = TimMenu.Slider("FOV", settings.fov, 0, 360, 1)
        settings.smoothing = TimMenu.Slider("Smoothing", settings.smoothing, 0, 1, 0.01)

        TimMenu.Separator()

        if TimMenu.Button("Reset") then
            settings.aimbot = true
            settings.fov = 360
            settings.smoothing = 0.2
        end
        TimMenu.Tooltip("Reset all settings to default")
    end
end

callbacks.Register("Draw", "menu_draw", DrawMenu)
```

#### Multi-tab menu

```lua
local currentTab = 1
local tabs = {"Aimbot", "Visuals", "Misc"}

local function DrawMenu()
    if not gui.IsMenuOpen() then return end

    if TimMenu.Begin("Advanced Script") then
        -- Tab buttons
        for i, tabName in ipairs(tabs) do
            if TimMenu.Button(tabName) then
                currentTab = i
            end
            if i < #tabs then TimMenu.SameLine() end
        end

        TimMenu.Separator()

        -- Tab content
        if currentTab == 1 then
            settings.aimbot = TimMenu.Checkbox("Enable", settings.aimbot)
            settings.fov = TimMenu.Slider("FOV", settings.fov, 0, 360, 1)
        elseif currentTab == 2 then
            settings.esp = TimMenu.Checkbox("ESP", settings.esp)
            settings.chams = TimMenu.Checkbox("Chams", settings.chams)
        end
    end
end
```

#### Integration with config system

```lua
-- Load config at startup
local cfg = LoadCFG(settings, "Lua MyScript")
if cfg then settings = cfg end

-- Save on button
if TimMenu.Button("Save Config") then
    SaveCFG(settings, "Lua MyScript")
end

-- Save on unload
callbacks.Register("Unload", "save", function()
    SaveCFG(settings, "Lua MyScript")
end)
```

### TimMenu API Reference

- `TimMenu.Begin(title)` - Start window
- `TimMenu.Checkbox(label, value)` - Returns new bool value
- `TimMenu.Slider(label, value, min, max, step)` - Returns new number
- `TimMenu.Button(label)` - Returns true if clicked
- `TimMenu.Text(text)` - Display text
- `TimMenu.Separator()` - Horizontal line
- `TimMenu.Tooltip(text)` - Show tooltip on hover
- `TimMenu.SameLine()` - Next item on same line
- `TimMenu.NextLine()` - Force new line
- `TimMenu.Spacing(pixels)` - Add vertical space

### Notes

- Only render when `gui.IsMenuOpen()` to avoid conflicts
- Save settings to config on unload
- Use tabs for complex menus (aimbot/ESP/misc)
- Tooltips add clarity without clutter

