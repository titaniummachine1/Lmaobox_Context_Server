local MenuLib = require("Menu")

-- Check the menu version to prevent errors due to changes in the library
assert(MenuLib.Version >= 1.44,
"MenuLib version is too old, please update to 1.44 or newer! Current version: " .. MenuLib.Version)

-- Create a menu
local menu = MenuLib.Create("loader", MenuFlags.AutoSize)
-- Add the textbox and search button
local textBox = menu:AddComponent(MenuLib.Textbox("name...", text))
-- Add an event listener to the textbox to update the search query whenever its value changes
textBox.OnValueChanged = function()
    local lua_name = textBox:GetValue()
    Load()
    print("Loaded ", textbox1)
end

function Load()
    LoadScript(textbox)
    print("Loaded ", textbox1)
end

--[[ Remove the menu when unloaded ]]
--
local function OnUnload()                                -- Called when the script is unloaded
    MenuLib.RemoveMenu(menu)                             -- Remove the menu
    client.Command('play "ui/buttonclickrelease"', true) -- Play the "buttonclickrelease" sound
end

--[[ Unregister previous callbacks ]]--
callbacks.Unregister("Unload", "MCT_Unload")                    -- Unregister the "Unload" callback
--[[ Register callbacks ]]--
callbacks.Register("Unload", "MCT_Unload", OnUnload)                         -- Register the "Unload" callback
--[[ Play sound when loaded ]]
--
client.Command('play "ui/buttonclick"', true) -- Play the "buttonclick" sound when the script is loaded
