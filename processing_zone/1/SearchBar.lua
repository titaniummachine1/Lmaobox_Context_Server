local MenuLib = require("Menu")

-- Check the menu version to prevent errors due to changes in the library
assert(MenuLib.Version >= 1.44,
"MenuLib version is too old, please update to 1.44 or newer! Current version: " .. MenuLib.Version)

-- Create a menu
local menu = MenuLib.Create("Search Bar", MenuFlags.AutoSize)
-- Add the textbox and search button
local textBox = MenuLib.Textbox("Search...")
-- Add an event listener to the textbox to update the search query whenever its value changes
textBox.OnValueChanged = function()
    searchQuery = textBox:GetValue()
    SearchFeatures()
end
menu:AddComponent(textBox)
menu:AddComponent(MenuLib.Seperator())

-- Add a button to initialize the search
local searchButton = MenuLib.Button("Search", SearchFeatures)
menu:AddComponent(searchButton)

-- Create a table to store all features and their respective sections
local mainTable = {
    Aimbot = { "Nospread", "Silent Aim", "Auto Wall", "Triggerbot" },
    Triggerbot = { "Always On", "On Key", "Burst", "Delay" },
    ESP = { "Box", "Name", "Health", "Weapon" },
    Visuals = { "Chams", "Glow", "FOV", "Crosshair" },
    Misc = { "Bunnyhop", "Auto Strafe", "Rank Revealer", "Radar" },
}

-- Create a table to store matching features and their respective sections
local results = {}

-- Store the search query in a global variable
local searchQuery = ""

-- Search for features matching the query
function SearchFeatures()
    results = {} -- Clear the results table

    -- Search for features matching the query
    for section, features in pairs(mainTable) do
        for i, feature in ipairs(features) do
            if string.match(feature:lower(), searchQuery:lower()) then
                table.insert(results, { feature, section })
            end
        end
    end

    UpdateMenu()
end

-- Update the menu to show the matching features
function UpdateMenu()
    -- Create a menu
    local newMenu = MenuLib.Create("Search Bar", MenuFlags.AutoSize)
    -- Add the textbox and search button, and set the text to the stored query
    local newTextBox = MenuLib.Textbox("Search...", searchQuery)
    newMenu:AddComponent(newTextBox)
    newMenu:AddComponent(MenuLib.Seperator())
    -- Add matching features as checkboxes to the menu
    if #results > 0 then
        for i = 1, math.min(#results, 10) do
            local feature = results[i]
            local checkbox = MenuLib.Checkbox(feature[1] .. " (" .. feature[2] .. ")", false)
            -- set the feature to true or false based on checkbox state
            newMenu:AddComponent(checkbox)
        end
    else
        newMenu:AddComponent(MenuLib.Label("No matching features."))
    end
    MenuLib.RemoveMenu(menu)
    menu = newMenu
end

-- Call SearchFeatures function once to show all features initially
SearchFeatures()

-- Code needed to run 66 times a second
local iterationCount = 0
local function doDraw()
    iterationCount = iterationCount + 1
    if iterationCount % 100 == 0 then
        SearchFeatures()
    end
end










--[[ Remove the menu when unloaded ]]
--
local function OnUnload()                                -- Called when the script is unloaded
    MenuLib.RemoveMenu(menu)                             -- Remove the menu
    client.Command('play "ui/buttonclickrelease"', true) -- Play the "buttonclickrelease" sound
end

--[[ Unregister previous callbacks ]]--
callbacks.Unregister("Unload", "MCT_Unload")                    -- Unregister the "Unload" callback
callbacks.Unregister("Draw", "MCT_Draw")                        -- Unregister the "Draw" callback
--[[ Register callbacks ]]--
callbacks.Register("Unload", "MCT_Unload", OnUnload)                         -- Register the "Unload" callback
callbacks.Register("Draw", "MCT_Draw", doDraw)                               -- Register the "Draw" callback
--[[ Play sound when loaded ]]
--
client.Command('play "ui/buttonclick"', true) -- Play the "buttonclick" sound when the script is loaded
