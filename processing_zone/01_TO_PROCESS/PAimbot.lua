local __bundle_require, __bundle_loaded, __bundle_register, __bundle_modules = (function(superRequire)
	local loadingPlaceholder = {[{}] = true}

	local register
	local modules = {}

	local require
	local loaded = {}

	register = function(name, body)
		if not modules[name] then
			modules[name] = body
		end
	end

	require = function(name)
		local loadedModule = loaded[name]

		if loadedModule then
			if loadedModule == loadingPlaceholder then
				return nil
			end
		else
			if not modules[name] then
				if not superRequire then
					local identifier = type(name) == 'string' and '\"' .. name .. '\"' or tostring(name)
					error('Tried to require ' .. identifier .. ', but no such module has been registered')
				else
					return superRequire(name)
				end
			end

			loaded[name] = loadingPlaceholder
			loadedModule = modules[name](require, loaded, register, modules)
			loaded[name] = loadedModule
		end

		return loadedModule
	end

	return require, loaded, register, modules
end)(require)
__bundle_register("__root", function(require, _LOADED, __bundle_register, __bundle_modules)
---@diagnostic disable: unused-function
---@diagnostic disable: undefined-global
---@class engine

--[[
    PAimbot lua
    Autor: Titaniummachine1
    Github: https://github.com/Titaniummachine1

    pasted stuff from GoodEveningFellOff - (https://github.com/GoodEveningFellOff/lmaobox-visualize-arc-trajectories)
]]

--[[ Activate the script Modules ]]
local G = require("PAimbot.Globals")
local Common = require("PAimbot.Common")
local Config = require("PAimbot.Config")

--[[Classes]] --
local FastPlayers = require("PAimbot.Modules.Helpers.FastPlayers")
local BestTarget = require("PAimbot.Modules.Helpers.BestTarget")
local Prediction = require("PAimbot.Modules.Prediction.Prediction")

require("PAimbot.Modules.Helpers.VariableUpdater")
require("PAimbot.Visuals")
require("PAimbot.Menu")

-- Load configuration
Config:Load()
-- Main function - just find target and predict
local function Main()
    -- Clear visualization stack at start of each tick
    Prediction.ClearVisualizationStack()

    local pLocal = FastPlayers.GetLocal()
    if not pLocal or not pLocal:IsAlive() or pLocal:InCond(7) then return end
    -- Only run if aimbot is enabled
    if not Config.main.enable then
        return
    end

    -- Always update history for best targets (pass lnxLib wrapper)
    BestTarget.UpdateHistory(pLocal)

    -- Find best target
    --local currentTarget = BestTarget.Get()
    --G.Target = currentTarget -- Store for visuals

    -- Update prediction for visuals if we have a target
    --if currentTarget then
    -- Update prediction system with the target
    Prediction:update(pLocal)
    Prediction:predict(66)
    --end
end

-- Save config on unload
local function OnUnload()
    Config:Save()
    Common.Log:Info("PAimbot unloaded and config saved")
end

-- Register callbacks
callbacks.Unregister("CreateMove", "PAimbot_ProjectileAimbot")
callbacks.Unregister("CreateMove", "PAimbot_OnCreateMove")
callbacks.Unregister("Unload", "PAimbot_OnUnload")

callbacks.Register("CreateMove", "PAimbot_Main", Main)
callbacks.Register("Unload", "PAimbot_OnUnload", OnUnload)

-- Log successful load
Common.Log:Info("PAimbot loaded successfully!")

end)
__bundle_register("PAimbot.Menu", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[require modules]] --
local G = require("PAimbot.Globals")
local Common = require("PAimbot.Common")
local Config = require("PAimbot.Config")

local Menu = {}

local Lib = Common.Lib
local Fonts = Lib.UI.Fonts

---@type boolean, TimMenu
local menuLoaded, TimMenu = pcall(require, "TimMenu")
assert(menuLoaded, "TimMenu not found, please install it!")

Menu.lastToggleTime = 0
Menu.toggleCooldown = 0.1

-- Key binding helper
local bindTimer = 0
local bindDelay = 0.15

local function handleKeybind(noKeyText, keybind, keybindName)
    if keybindName ~= "Press The Key" and TimMenu.Button(keybindName or noKeyText) then
        bindTimer = os.clock() + bindDelay
        keybindName = "Press The Key"
    elseif keybindName == "Press The Key" then
        TimMenu.Text("Press the key")
    end

    if keybindName == "Press The Key" then
        if os.clock() >= bindTimer then
            local pressedKey = Common.GetPressedKey()
            if pressedKey then
                if pressedKey == KEY_ESCAPE then
                    keybind = 0
                    keybindName = "Always On"
                else
                    keybind = pressedKey
                    keybindName = Common.GetKeyName(pressedKey)
                    Common.Notify.Simple("Keybind Success", "Bound Key: " .. keybindName, 2)
                end
            end
        end
    end
    return keybind, keybindName
end



local function DrawMenu()
    -- Only show menu when GUI is visible and menu is open
    if not (gui.GetValue("Clean Screenshots") and engine.IsTakingScreenshot()) and gui.IsMenuOpen() and TimMenu.Begin("PAimbot - Projectile Aimbot", true) then
        draw.SetFont(Fonts.Verdana)
        draw.Color(255, 255, 255, 255)

        -- Tab system
        local tabNames = { "Main", "Advanced", "Visuals" }
        local currentTab = 1
        if Config.menu.tabs.main then
            currentTab = 1
        elseif Config.menu.tabs.advanced then
            currentTab = 2
        elseif Config.menu.tabs.visuals then
            currentTab = 3
        end

        local selectedTab = TimMenu.TabControl("main_tabs", tabNames, currentTab)

        -- Update tab states
        Config.menu.tabs.main = (selectedTab == 1)
        Config.menu.tabs.advanced = (selectedTab == 2)
        Config.menu.tabs.visuals = (selectedTab == 3)

        TimMenu.NextLine()

        -- Main Tab
        if Config.menu.tabs.main then
            -- Core Settings Section
            TimMenu.BeginSector("Core Settings")
            Config.main.enable = TimMenu.Checkbox("Enable Aimbot", Config.main.enable)
            TimMenu.NextLine()

            if Config.main.enable then
                Config.main.silent = TimMenu.Checkbox("Silent Aim", Config.main.silent)
                TimMenu.NextLine()

                Config.main.autoShoot = TimMenu.Checkbox("Auto Shoot", Config.main.autoShoot)
                TimMenu.NextLine()
            end
            TimMenu.EndSector()

            if Config.main.enable then
                TimMenu.NextLine()

                -- Targeting Settings Section
                TimMenu.BeginSector("Targeting Settings")
                Config.main.aimfov = TimMenu.Slider("Aim FOV", Config.main.aimfov, 0.1, 360, 0.1)
                TimMenu.NextLine()

                Config.main.minHitchance = TimMenu.Slider("Min Hit Chance", Config.main.minHitchance, 1, 100, 1)
                TimMenu.NextLine()

                Config.main.minDistance = TimMenu.Slider("Min Distance", Config.main.minDistance, 50, 500, 10)
                TimMenu.NextLine()

                Config.main.maxDistance = TimMenu.Slider("Max Distance", Config.main.maxDistance, 500, 3000, 50)
                TimMenu.NextLine()

                Config.main.aimKey.key = TimMenu.Keybind("Aim Key", Config.main.aimKey.key)
                TimMenu.NextLine()
                TimMenu.EndSector()

                TimMenu.NextLine()

                -- Status Information Section
                TimMenu.BeginSector("Status Information")
                -- Display detailed motion analysis and predictability
                if G.Aimbot and G.Aimbot.MotionAnalysis then
                    local motion = G.Aimbot.MotionAnalysis
                    local predictabilityHitchance = G.Aimbot.PredictabilityHitchance or 0
                    local actualHitchance = G.Aimbot.HitChance or 0

                    TimMenu.Text(string.format("Predictability HC: %.1f%% | Actual HC: %.1f%%",
                        predictabilityHitchance, actualHitchance))
                    TimMenu.NextLine()

                    TimMenu.Text("Motion Analysis (current target):")
                    TimMenu.NextLine()

                    TimMenu.Text(string.format("Acceleration: %.1f | Jerk: %.1f",
                        motion.acceleration, motion.jerk))
                    TimMenu.NextLine()

                    TimMenu.Text(string.format("Snap: %.1f | Pop: %.1f | Strafe: %.1f",
                        motion.snap, motion.pop, motion.strafe))
                    TimMenu.NextLine()
                else
                    TimMenu.Text("No target selected")
                    TimMenu.NextLine()
                end
                TimMenu.EndSector()
            end
        end

        -- Advanced Tab with better organization
        if Config.menu.tabs.advanced then
            -- Targeting Mode Section
            TimMenu.BeginSector("Targeting Mode")
            TimMenu.Text("Select targeting behavior:")
            local targetingModes = { "Legit", "Blatant" }
            local currentMode = Config.advanced.targetingMode.legit and 1 or 2
            local selectedMode = TimMenu.TabControl("targeting_modes", targetingModes, currentMode)

            -- Update targeting mode based on selection
            Config.advanced.targetingMode.legit = (selectedMode == 1)
            Config.advanced.targetingMode.blatant = (selectedMode == 2)

            TimMenu.NextLine()
            if Config.advanced.targetingMode.legit then
                TimMenu.Text("Legit: Only targets visible enemies")
            else
                TimMenu.Text("Blatant: Can target enemies behind walls")
            end
            TimMenu.NextLine()
            TimMenu.EndSector()

            TimMenu.NextLine()

            -- Prediction Settings Section
            TimMenu.BeginSector("Prediction Settings")
            TimMenu.Text("Prediction: 33 ticks (fixed for optimal performance)")
            TimMenu.NextLine()

            Config.advanced.maxPredictionHistory = TimMenu.Slider("Max Prediction History",
                Config.advanced.maxPredictionHistory or 66, 7, 198, 1)
            TimMenu.NextLine()
            TimMenu.EndSector()

            TimMenu.NextLine()

            -- Performance Settings Section
            TimMenu.BeginSector("Performance Settings")
            Config.advanced.projectileSegments = TimMenu.Slider("Projectile Segments", Config.advanced
                .projectileSegments, 3, 50, 1)
            TimMenu.NextLine()

            Config.advanced.maxTargetsToPredict = TimMenu.Slider("Max Targets to Predict",
                Config.advanced.maxTargetsToPredict or 4, 1, 8, 1)
            TimMenu.NextLine()

            Config.advanced.maxTrackedTargets = TimMenu.Slider("Max Tracked Targets",
                Config.advanced.maxTrackedTargets or 8, 4, 8, 1)
            TimMenu.NextLine()
            TimMenu.EndSector()

            TimMenu.NextLine()

            -- Splash Prediction Section
            TimMenu.BeginSector("Splash Prediction")
            Config.advanced.splashPrediction = TimMenu.Checkbox("Enable Splash Prediction",
                Config.advanced.splashPrediction)
            TimMenu.NextLine()

            if Config.advanced.splashPrediction then
                Config.advanced.splashAccuracy = TimMenu.Slider("Splash Accuracy", Config.advanced.splashAccuracy, 2, 20,
                    1)
                TimMenu.NextLine()
            end
            TimMenu.EndSector()

            TimMenu.NextLine()
        end

        -- Visuals Tab
        if Config.menu.tabs.visuals then
            -- Main Visual Settings
            TimMenu.BeginSector("Visual Settings")
            Config.visuals.active = TimMenu.Checkbox("Enable Visuals", Config.visuals.active)

            if Config.visuals.active then
                TimMenu.NextLine()
                Config.visuals.visualizePath = TimMenu.Checkbox("Player Path", Config.visuals.visualizePath)
                Config.visuals.visualizeProjectile = TimMenu.Checkbox("Projectile Path",
                    Config.visuals.visualizeProjectile)
                TimMenu.NextLine()
                Config.visuals.visualizeHitPos = TimMenu.Checkbox("Hit Position", Config.visuals.visualizeHitPos)
                Config.visuals.crosshair = TimMenu.Checkbox("Crosshair", Config.visuals.crosshair)
                TimMenu.NextLine()
                Config.visuals.visualizeHitchance = TimMenu.Checkbox("Hit Chance", Config.visuals.visualizeHitchance)
                Config.visuals.nccPred = TimMenu.Checkbox("NCC Style", Config.visuals.nccPred)

                if Config.visuals.visualizePath then
                    TimMenu.NextLine()
                    Config.visuals.path_styles_selected = TimMenu.Selector("Path Style",
                        Config.visuals.path_styles_selected, Config.visuals.path_styles)
                end
            end
            TimMenu.EndSector()

            if Config.visuals.active then
                TimMenu.NextLine()

                -- Path Line Settings
                TimMenu.BeginSector("Path Lines")
                Config.visuals.line.enabled = TimMenu.Checkbox("Enable Lines", Config.visuals.line.enabled)
                if Config.visuals.line.enabled then
                    TimMenu.NextLine()
                    Config.visuals.line.r = TimMenu.Slider("Red", Config.visuals.line.r, 0, 255, 1)
                    Config.visuals.line.g = TimMenu.Slider("Green", Config.visuals.line.g, 0, 255, 1)
                    TimMenu.NextLine()
                    Config.visuals.line.b = TimMenu.Slider("Blue", Config.visuals.line.b, 0, 255, 1)
                    Config.visuals.line.a = TimMenu.Slider("Alpha", Config.visuals.line.a, 0, 255, 1)
                end
                TimMenu.EndSector()

                TimMenu.NextLine()

                -- Impact Polygon Settings
                TimMenu.BeginSector("Impact Polygon")
                Config.visuals.polygon.enabled = TimMenu.Checkbox("Enable Polygon", Config.visuals.polygon.enabled)
                if Config.visuals.polygon.enabled then
                    TimMenu.NextLine()
                    Config.visuals.polygon.size = TimMenu.Slider("Size", Config.visuals.polygon.size, 5, 50, 1)
                    Config.visuals.polygon.segments = TimMenu.Slider("Segments", Config.visuals.polygon.segments, 8, 32,
                        1)
                    TimMenu.NextLine()
                    Config.visuals.polygon.r = TimMenu.Slider("Red", Config.visuals.polygon.r, 0, 255, 1)
                    Config.visuals.polygon.g = TimMenu.Slider("Green", Config.visuals.polygon.g, 0, 255, 1)
                    TimMenu.NextLine()
                    Config.visuals.polygon.b = TimMenu.Slider("Blue", Config.visuals.polygon.b, 0, 255, 1)
                    Config.visuals.polygon.a = TimMenu.Slider("Alpha", Config.visuals.polygon.a, 0, 255, 1)
                end
                TimMenu.EndSector()

                TimMenu.NextLine()

                -- Outline Settings
                TimMenu.BeginSector("Outlines")
                Config.visuals.outline.line_and_flags = TimMenu.Checkbox("Line Outline",
                    Config.visuals.outline.line_and_flags)
                Config.visuals.outline.polygon = TimMenu.Checkbox("Polygon Outline", Config.visuals.outline.polygon)

                if Config.visuals.outline.line_and_flags or Config.visuals.outline.polygon then
                    TimMenu.NextLine()
                    Config.visuals.outline.r = TimMenu.Slider("Red", Config.visuals.outline.r, 0, 255, 1)
                    Config.visuals.outline.g = TimMenu.Slider("Green", Config.visuals.outline.g, 0, 255, 1)
                    TimMenu.NextLine()
                    Config.visuals.outline.b = TimMenu.Slider("Blue", Config.visuals.outline.b, 0, 255, 1)
                    Config.visuals.outline.a = TimMenu.Slider("Alpha", Config.visuals.outline.a, 0, 255, 1)
                end
                TimMenu.EndSector()
            end
        end



        TimMenu.End()
    end
end

--[[ Callbacks ]]
callbacks.Unregister("Draw", G.scriptName .. "_Menu")
callbacks.Register("Draw", G.scriptName .. "_Menu", DrawMenu)

return Menu

end)
__bundle_register("PAimbot.Config", function(require, _LOADED, __bundle_register, __bundle_modules)
-- Config.lua

-- Require the JSON library from the modules folder.
local json = require("PAimbot.Modules.Json")
local G = require("PAimbot.Globals")

local Hitbox = {
    Head = 1,
    Body = 5,
    Feet = 11,
}

-- Default configuration table.
-- (Keys are in lower-case for easier access, e.g. Config.main.enable)
local defaultConfig = {
    currentTab = 1,    -- Top-level tab, if needed
    main = {
        enable = true, -- Enable flag for the main module
        aimKey = {
            key = KEY_LSHIFT,
            aimKeyName = "LSHIFT",
        },
        aimfov = 60,
        minHitchance = 40,
        autoShoot = true,
        silent = true,
        minDistance = 100,
        maxDistance = 1500,
        aimPos = {
            currentAimPos = Hitbox.Feet,
            hitscan = Hitbox.Head,
            projectile = Hitbox.Feet,
        },
    },
    advanced = {
        splashPrediction = true,
        splashAccuracy = 4,
        -- 0.5 to 8, determines the size of the segments traced; lower values = worse performance (default 2.5)
        projectileSegments = 10,
        maxTargetsToPredict = 4,
        maxTrackedTargets = 8,     -- Number of targets to track for history/entropy (4-8)
        maxPredictionHistory = 66, -- History length for motion analysis (7-198, default 66)
        targetingMode = {
            legit = true,          -- Only shoot at visible targets (legit mode)
            blatant = false,       -- Allow shooting at hidden targets (blatant mode)
        },
    },
    visuals = {
        active = true,
        visualizePath = true,
        path_styles = { "Line", "Alt Line", "Dashed" },
        path_styles_selected = 1,
        visualizeHitchance = false,
        visualizeProjectile = false,
        visualizeHitPos = false,
        crosshair = false,
        nccPred = false,
        polygon = {
            enabled = true,
            r = 255,
            g = 200,
            b = 155,
            a = 50,
            size = 10,
            segments = 20,
        },
        line = {
            enabled = true,
            r = 255,
            g = 255,
            b = 255,
            a = 255,
        },
        flags = {
            enabled = true,
            r = 255,
            g = 0,
            b = 0,
            a = 255,
            size = 5,
        },
        outline = {
            line_and_flags = true,
            polygon = true,
            r = 0,
            g = 0,
            b = 0,
            a = 155,
        },
    },
    menu = {
        isOpen = true,
        toggleKey = KEY_INSERT,
        lastToggleTime = 0,
        tabs = {
            main = true,
            advanced = false,
            visuals = false,
        },
    },
}

-- Create our singleton Config table.
local Config = {}
Config.__index = Config

-- Merge default configuration values into our Config table.
for key, value in pairs(defaultConfig) do
    Config[key] = value
end

-- Private variables for file handling.
local scriptName = G.scriptName or "DefaultScript"
local folderName = string.format("Lua %s", scriptName)
filesystem.CreateDirectory(folderName)
local filePath = folderName .. "/" .. scriptName .. "_config.json"

--------------------------------------------------------------------------------
-- Helper function: copyMatchingKeys
-- Creates a deep copy of the source table using only the keys defined in 'filter'.
-- This avoids copying extra keys that may introduce cycles.
--------------------------------------------------------------------------------
local function copyMatchingKeys(src, filter, copies)
    copies = copies or {}
    if type(src) ~= "table" then
        return src
    end
    if copies[src] then
        return copies[src]
    end
    local result = {}
    copies[src] = result
    for key, fval in pairs(filter) do
        local sval = src[key]
        if type(fval) == "table" then
            if type(sval) == "table" then
                result[key] = copyMatchingKeys(sval, fval, copies)
            else
                result[key] = sval
            end
        else
            if type(sval) ~= "function" then
                result[key] = sval
            end
        end
    end
    return result
end

--------------------------------------------------------------------------------
-- Utility: recursively check that every key in 'expected' exists in 'loaded'.
--------------------------------------------------------------------------------
local function deepCheck(expected, loaded)
    for key, value in pairs(expected) do
        if loaded[key] == nil then
            return false
        end
        if type(value) == "table" then
            if type(loaded[key]) ~= "table" then
                return false
            end
            if not deepCheck(value, loaded[key]) then
                return false
            end
        end
    end
    return true
end

--------------------------------------------------------------------------------
-- Save the current configuration to file (in JSON format)
-- Only the data is saved (functions are excluded) using a filtered deep copy.
--------------------------------------------------------------------------------
function Config:Save()
    local file = io.open(filePath, "w")
    if file then
        -- Create a deep copy of the configuration data using defaultConfig as a filter.
        local dataToSave = copyMatchingKeys(self, defaultConfig)
        local content = json.encode(dataToSave)
        file:write(content)
        file:close()
        printc(100, 183, 0, 255, "Success Saving Config: " .. filePath)
    else
        printc(255, 0, 0, 255, "Failed to open file for writing: " .. filePath)
    end
end

--------------------------------------------------------------------------------
-- Load configuration from file.
-- If the file does not exist or if the structure is outdated, the default config is saved.
--------------------------------------------------------------------------------
function Config:Load()
    local file = io.open(filePath, "r")
    if file then
        local content = file:read("*a")
        file:close()
        local loadedConfig, decodeErr = json.decode(content)
        if loadedConfig and deepCheck(defaultConfig, loadedConfig) and not input.IsButtonDown(KEY_LSHIFT) then
            -- Overwrite our configuration values with those from the file.
            for key, value in pairs(loadedConfig) do
                self[key] = value
            end
            printc(100, 183, 0, 255, "Success Loading Config: " .. filePath)
        else
            local warnMsg = decodeErr or "Config is outdated or invalid. Creating a new config."
            printc(255, 0, 0, 255, warnMsg)
            self:Save()
        end
    else
        printc(255, 215, 0, 255, "Config file not found. Creating default config: " .. filePath)
        self:Save()
    end
end

return Config

end)
__bundle_register("PAimbot.Globals", function(require, _LOADED, __bundle_register, __bundle_modules)
local G = {}

G.scriptName = GetScriptName():match("([^/\\]+)%.lua$")

G.Hitbox = { Min = Vector3(-24, -24, 0), Max = Vector3(24, 24, 82) }
G.TickInterval = globals.TickInterval()
G.TickCount = globals.TickCount()

G.history = {}
G.predictionDelta = {}

G.PredictionData = {
    PredPath = {},
}

-- Aimbot specific data
G.Aimbot = {
    Target = nil,
    CurrentAngles = nil,
    HitChance = 0,
    PredictabilityHitchance = 0, -- Hitchance based on motion predictability
    CanEngage = false,           -- Whether aimbot can engage based on predictability
    ReadyToShoot = false,        -- Whether we're ready to shoot (aim key + predictable target)
    MotionAnalysis = {           -- Detailed motion analysis for current target
        acceleration = 0,
        jerk = 0,
        snap = 0,
        pop = 0,
        strafe = 0,
        hitchance = 0
    },
    ProjectilePath = {},
    TargetPredictionPath = {},
    LatencyData = {
        latency = 0,
        lerp = 0,
    },
    TargetData = {},
}

-- Projectile simulation data
G.ProjectileSimulation = {
    TrajectoryPath = {},
    SplashPosition = nil,
    ImpactPosition = nil,
    TimeToTarget = 0,
}

-- Hit chance tracking
G.HitChanceData = {
    lastPositions = {},
    priorPredictions = {},
    hitChanceRecords = {},
}

local Hitbox = {
    Head = 1,
    Body = 5,
    Feet = 11,
}

-- Contains pairs of keys and their names
---@type table<integer, string>
G.KeyNames = {
    [KEY_SEMICOLON] = "SEMICOLON",
    [KEY_APOSTROPHE] = "APOSTROPHE",
    [KEY_BACKQUOTE] = "BACKQUOTE",
    [KEY_COMMA] = "COMMA",
    [KEY_PERIOD] = "PERIOD",
    [KEY_SLASH] = "SLASH",
    [KEY_BACKSLASH] = "BACKSLASH",
    [KEY_MINUS] = "MINUS",
    [KEY_EQUAL] = "EQUAL",
    [KEY_ENTER] = "ENTER",
    [KEY_SPACE] = "SPACE",
    [KEY_BACKSPACE] = "BACKSPACE",
    [KEY_TAB] = "TAB",
    [KEY_CAPSLOCK] = "CAPSLOCK",
    [KEY_NUMLOCK] = "NUMLOCK",
    [KEY_ESCAPE] = "ESCAPE",
    [KEY_SCROLLLOCK] = "SCROLLLOCK",
    [KEY_INSERT] = "INSERT",
    [KEY_DELETE] = "DELETE",
    [KEY_HOME] = "HOME",
    [KEY_END] = "END",
    [KEY_PAGEUP] = "PAGEUP",
    [KEY_PAGEDOWN] = "PAGEDOWN",
    [KEY_BREAK] = "BREAK",
    [KEY_LSHIFT] = "LSHIFT",
    [KEY_RSHIFT] = "RSHIFT",
    [KEY_LALT] = "LALT",
    [KEY_RALT] = "RALT",
    [KEY_LCONTROL] = "LCONTROL",
    [KEY_RCONTROL] = "RCONTROL",
    [KEY_UP] = "UP",
    [KEY_LEFT] = "LEFT",
    [KEY_DOWN] = "DOWN",
    [KEY_RIGHT] = "RIGHT",
}

-- Contains pairs of keys and their values
---@type table<integer, string>
G.KeyValues = {
    [KEY_LBRACKET] = "[",
    [KEY_RBRACKET] = "]",
    [KEY_SEMICOLON] = ";",
    [KEY_APOSTROPHE] = "'",
    [KEY_BACKQUOTE] = "`",
    [KEY_COMMA] = ",",
    [KEY_PERIOD] = ".",
    [KEY_SLASH] = "/",
    [KEY_BACKSLASH] = "\\",
    [KEY_MINUS] = "-",
    [KEY_EQUAL] = "=",
    [KEY_SPACE] = " ",
}

-- Constants for projectile simulation
G.Constants = {
    MASK_PLAYERSOLID = 100679691,
    FULL_HIT_FRACTION = 1.0,
    DRAG_COEFFICIENT = 0.029374,
    M_RADPI = 180 / math.pi,
    EMPTY_VECTOR = Vector3(0, 0, 0),
}

G.Menu = G.Default_Menu

return G

end)
__bundle_register("PAimbot.Modules.Json", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[
David Kolf's JSON module for Lua 5.1 - 5.4

Version 2.6


For the documentation see the corresponding readme.txt or visit
<http://dkolf.de/src/dkjson-lua.fsl/>.

You can contact the author by sending an e-mail to 'david' at the
domain 'dkolf.de'.


Copyright (C) 2010-2021 David Heiko Kolf

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--]]

---@alias JsonState { indent : boolean?, keyorder : integer[]?, level : integer?, buffer : string[]?, bufferlen : integer?, tables : table[]?, exception : function? }

-- global dependencies:
local pairs, type, tostring, tonumber, getmetatable, setmetatable, rawset =
    pairs, type, tostring, tonumber, getmetatable, setmetatable, rawset
local error, require, pcall, select = error, require, pcall, select
local floor, huge = math.floor, math.huge
local strrep, gsub, strsub, strbyte, strchar, strfind, strlen, strformat =
    string.rep, string.gsub, string.sub, string.byte, string.char,
    string.find, string.len, string.format
local strmatch = string.match
local concat = table.concat

---@class Json
local json = { version = "dkjson 2.6.1 L" }

local _ENV = nil -- blocking globals in Lua 5.2 and later

json.null = setmetatable({}, {
    __tojson = function() return "null" end
})

local function isarray(tbl)
    local max, n, arraylen = 0, 0, 0
    for k, v in pairs(tbl) do
        if k == 'n' and type(v) == 'number' then
            arraylen = v
            if v > max then
                max = v
            end
        else
            if type(k) ~= 'number' or k < 1 or floor(k) ~= k then
                return false
            end
            if k > max then
                max = k
            end
            n = n + 1
        end
    end
    if max > 10 and max > arraylen and max > n * 2 then
        return false -- don't create an array with too many holes
    end
    return true, max
end

local escapecodes = {
    ["\""] = "\\\"",
    ["\\"] = "\\\\",
    ["\b"] = "\\b",
    ["\f"] = "\\f",
    ["\n"] = "\\n",
    ["\r"] = "\\r",
    ["\t"] = "\\t"
}

local function escapeutf8(uchar)
    local value = escapecodes[uchar]
    if value then
        return value
    end
    local a, b, c, d = strbyte(uchar, 1, 4)
    a, b, c, d = a or 0, b or 0, c or 0, d or 0
    if a <= 0x7f then
        value = a
    elseif 0xc0 <= a and a <= 0xdf and b >= 0x80 then
        value = (a - 0xc0) * 0x40 + b - 0x80
    elseif 0xe0 <= a and a <= 0xef and b >= 0x80 and c >= 0x80 then
        value = ((a - 0xe0) * 0x40 + b - 0x80) * 0x40 + c - 0x80
    elseif 0xf0 <= a and a <= 0xf7 and b >= 0x80 and c >= 0x80 and d >= 0x80 then
        value = (((a - 0xf0) * 0x40 + b - 0x80) * 0x40 + c - 0x80) * 0x40 + d - 0x80
    else
        return ""
    end
    if value <= 0xffff then
        return strformat("\\u%.4x", value)
    elseif value <= 0x10ffff then
        -- encode as UTF-16 surrogate pair
        value = value - 0x10000
        local highsur, lowsur = 0xD800 + floor(value / 0x400), 0xDC00 + (value % 0x400)
        return strformat("\\u%.4x\\u%.4x", highsur, lowsur)
    else
        return ""
    end
end

local function fsub(str, pattern, repl)
    -- gsub always builds a new string in a buffer, even when no match
    -- exists. First using find should be more efficient when most strings
    -- don't contain the pattern.
    if strfind(str, pattern) then
        return gsub(str, pattern, repl)
    else
        return str
    end
end

local function quotestring(value)
    -- based on the regexp "escapable" in https://github.com/douglascrockford/JSON-js
    value = fsub(value, "[%z\1-\31\"\\\127]", escapeutf8)
    if strfind(value, "[\194\216\220\225\226\239]") then
        value = fsub(value, "\194[\128-\159\173]", escapeutf8)
        value = fsub(value, "\216[\128-\132]", escapeutf8)
        value = fsub(value, "\220\143", escapeutf8)
        value = fsub(value, "\225\158[\180\181]", escapeutf8)
        value = fsub(value, "\226\128[\140-\143\168-\175]", escapeutf8)
        value = fsub(value, "\226\129[\160-\175]", escapeutf8)
        value = fsub(value, "\239\187\191", escapeutf8)
        value = fsub(value, "\239\191[\176-\191]", escapeutf8)
    end
    return "\"" .. value .. "\""
end
json.quotestring = quotestring

local function replace(str, o, n)
    local i, j = strfind(str, o, 1, true)
    if i then
        return strsub(str, 1, i - 1) .. n .. strsub(str, j + 1, -1)
    else
        return str
    end
end

-- locale independent num2str and str2num functions
local decpoint, numfilter

local function updatedecpoint()
    decpoint = strmatch(tostring(0.5), "([^05+])")
    -- build a filter that can be used to remove group separators
    numfilter = "[^0-9%-%+eE" .. gsub(decpoint, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0") .. "]+"
end

updatedecpoint()

local function num2str(num)
    return replace(fsub(tostring(num), numfilter, ""), decpoint, ".")
end

local function str2num(str)
    local num = tonumber(replace(str, ".", decpoint))
    if not num then
        updatedecpoint()
        num = tonumber(replace(str, ".", decpoint))
    end
    return num
end

local function addnewline2(level, buffer, buflen)
    buffer[buflen + 1] = "\n"
    buffer[buflen + 2] = strrep("  ", level)
    buflen = buflen + 2
    return buflen
end

function json.addnewline(state)
    if state.indent then
        state.bufferlen = addnewline2(state.level or 0,
            state.buffer, state.bufferlen or #(state.buffer))
    end
end

local encode2 -- forward declaration

local function addpair(key, value, prev, indent, level, buffer, buflen, tables, globalorder, state)
    local kt = type(key)
    if kt ~= 'string' and kt ~= 'number' then
        return nil, "type '" .. kt .. "' is not supported as a key by JSON."
    end
    if prev then
        buflen = buflen + 1
        buffer[buflen] = ","
    end
    if indent then
        buflen = addnewline2(level, buffer, buflen)
    end
    buffer[buflen + 1] = quotestring(key)
    buffer[buflen + 2] = ":"
    return encode2(value, indent, level, buffer, buflen + 2, tables, globalorder, state)
end

local function appendcustom(res, buffer, state)
    local buflen = state.bufferlen
    if type(res) == 'string' then
        buflen = buflen + 1
        buffer[buflen] = res
    end
    return buflen
end

local function exception(reason, value, state, buffer, buflen, defaultmessage)
    defaultmessage = defaultmessage or reason
    local handler = state.exception
    if not handler then
        return nil, defaultmessage
    else
        state.bufferlen = buflen
        local ret, msg = handler(reason, value, state, defaultmessage)
        if not ret then return nil, msg or defaultmessage end
        return appendcustom(ret, buffer, state)
    end
end

function json.encodeexception(reason, value, state, defaultmessage)
    return quotestring("<" .. defaultmessage .. ">")
end

encode2 = function(value, indent, level, buffer, buflen, tables, globalorder, state)
    local valtype = type(value)
    local valmeta = getmetatable(value)
    valmeta = type(valmeta) == 'table' and valmeta -- only tables
    local valtojson = valmeta and valmeta.__tojson
    if valtojson then
        if tables[value] then
            return exception('reference cycle', value, state, buffer, buflen)
        end
        tables[value] = true
        state.bufferlen = buflen
        local ret, msg = valtojson(value, state)
        if not ret then return exception('custom encoder failed', value, state, buffer, buflen, msg) end
        tables[value] = nil
        buflen = appendcustom(ret, buffer, state)
    elseif value == nil then
        buflen = buflen + 1
        buffer[buflen] = "null"
    elseif valtype == 'number' then
        local s
        if value ~= value or value >= huge or -value >= huge then
            -- This is the behaviour of the original JSON implementation.
            s = "null"
        else
            s = num2str(value)
        end
        buflen = buflen + 1
        buffer[buflen] = s
    elseif valtype == 'boolean' then
        buflen = buflen + 1
        buffer[buflen] = value and "true" or "false"
    elseif valtype == 'string' then
        buflen = buflen + 1
        buffer[buflen] = quotestring(value)
    elseif valtype == 'table' then
        if tables[value] then
            return exception('reference cycle', value, state, buffer, buflen)
        end
        tables[value] = true
        level = level + 1
        local isa, n = isarray(value)
        if n == 0 and valmeta and valmeta.__jsontype == 'object' then
            isa = false
        end
        local msg
        if isa then -- JSON array
            buflen = buflen + 1
            buffer[buflen] = "["
            for i = 1, n do
                buflen, msg = encode2(value[i], indent, level, buffer, buflen, tables, globalorder, state)
                if not buflen then return nil, msg end
                if i < n then
                    buflen = buflen + 1
                    buffer[buflen] = ","
                end
            end
            buflen = buflen + 1
            buffer[buflen] = "]"
        else -- JSON object
            local prev = false
            buflen = buflen + 1
            buffer[buflen] = "{"
            local order = valmeta and valmeta.__jsonorder or globalorder
            if order then
                local used = {}
                n = #order
                for i = 1, n do
                    local k = order[i]
                    local v = value[k]
                    if v ~= nil then
                        used[k] = true
                        buflen, msg = addpair(k, v, prev, indent, level, buffer, buflen, tables, globalorder, state)
                        prev = true -- add a seperator before the next element
                    end
                end
                for k, v in pairs(value) do
                    if not used[k] then
                        buflen, msg = addpair(k, v, prev, indent, level, buffer, buflen, tables, globalorder, state)
                        if not buflen then return nil, msg end
                        prev = true -- add a seperator before the next element
                    end
                end
            else -- unordered
                for k, v in pairs(value) do
                    buflen, msg = addpair(k, v, prev, indent, level, buffer, buflen, tables, globalorder, state)
                    if not buflen then return nil, msg end
                    prev = true -- add a seperator before the next element
                end
            end
            if indent then
                buflen = addnewline2(level - 1, buffer, buflen)
            end
            buflen = buflen + 1
            buffer[buflen] = "}"
        end
        tables[value] = nil
    else
        return exception('unsupported type', value, state, buffer, buflen,
            "type '" .. valtype .. "' is not supported by JSON.")
    end
    return buflen
end

---Encodes a lua table to a JSON string.
---@param value any
---@param state JsonState
---@return string|boolean
function json.encode(value, state)
    state = state or {}
    local oldbuffer = state.buffer
    local buffer = oldbuffer or {}
    state.buffer = buffer
    updatedecpoint()
    local ret, msg = encode2(value, state.indent, state.level or 0,
        buffer, state.bufferlen or 0, state.tables or {}, state.keyorder, state)
    if not ret then
        error(msg, 2)
    elseif oldbuffer == buffer then
        state.bufferlen = ret
        return true
    else
        state.bufferlen = nil
        state.buffer = nil
        return concat(buffer)
    end
end

local function loc(str, where)
    local line, pos, linepos = 1, 1, 0
    while true do
        pos = strfind(str, "\n", pos, true)
        if pos and pos < where then
            line = line + 1
            linepos = pos
            pos = pos + 1
        else
            break
        end
    end
    return "line " .. line .. ", column " .. (where - linepos)
end

local function unterminated(str, what, where)
    return nil, strlen(str) + 1, "unterminated " .. what .. " at " .. loc(str, where)
end

local function scanwhite(str, pos)
    while true do
        pos = strfind(str, "%S", pos)
        if not pos then return nil end
        local sub2 = strsub(str, pos, pos + 1)
        if sub2 == "\239\187" and strsub(str, pos + 2, pos + 2) == "\191" then
            -- UTF-8 Byte Order Mark
            pos = pos + 3
        elseif sub2 == "//" then
            pos = strfind(str, "[\n\r]", pos + 2)
            if not pos then return nil end
        elseif sub2 == "/*" then
            pos = strfind(str, "*/", pos + 2)
            if not pos then return nil end
            pos = pos + 2
        else
            return pos
        end
    end
end

local escapechars = {
    ["\""] = "\"",
    ["\\"] = "\\",
    ["/"] = "/",
    ["b"] = "\b",
    ["f"] = "\f",
    ["n"] = "\n",
    ["r"] = "\r",
    ["t"] = "\t"
}

local function unichar(value)
    if value < 0 then
        return nil
    elseif value <= 0x007f then
        return strchar(value)
    elseif value <= 0x07ff then
        return strchar(0xc0 + floor(value / 0x40),
            0x80 + (floor(value) % 0x40))
    elseif value <= 0xffff then
        return strchar(0xe0 + floor(value / 0x1000),
            0x80 + (floor(value / 0x40) % 0x40),
            0x80 + (floor(value) % 0x40))
    elseif value <= 0x10ffff then
        return strchar(0xf0 + floor(value / 0x40000),
            0x80 + (floor(value / 0x1000) % 0x40),
            0x80 + (floor(value / 0x40) % 0x40),
            0x80 + (floor(value) % 0x40))
    else
        return nil
    end
end

local function scanstring(str, pos)
    local lastpos = pos + 1
    local buffer, n = {}, 0
    while true do
        local nextpos = strfind(str, "[\"\\]", lastpos)
        if not nextpos then
            return unterminated(str, "string", pos)
        end
        if nextpos > lastpos then
            n = n + 1
            buffer[n] = strsub(str, lastpos, nextpos - 1)
        end
        if strsub(str, nextpos, nextpos) == "\"" then
            lastpos = nextpos + 1
            break
        else
            local escchar = strsub(str, nextpos + 1, nextpos + 1)
            local value
            if escchar == "u" then
                value = tonumber(strsub(str, nextpos + 2, nextpos + 5), 16)
                if value then
                    local value2
                    if 0xD800 <= value and value <= 0xDBff then
                        -- we have the high surrogate of UTF-16. Check if there is a
                        -- low surrogate escaped nearby to combine them.
                        if strsub(str, nextpos + 6, nextpos + 7) == "\\u" then
                            value2 = tonumber(strsub(str, nextpos + 8, nextpos + 11), 16)
                            if value2 and 0xDC00 <= value2 and value2 <= 0xDFFF then
                                value = (value - 0xD800) * 0x400 + (value2 - 0xDC00) + 0x10000
                            else
                                value2 = nil -- in case it was out of range for a low surrogate
                            end
                        end
                    end
                    value = value and unichar(value)
                    if value then
                        if value2 then
                            lastpos = nextpos + 12
                        else
                            lastpos = nextpos + 6
                        end
                    end
                end
            end
            if not value then
                value = escapechars[escchar] or escchar
                lastpos = nextpos + 2
            end
            n = n + 1
            buffer[n] = value
        end
    end
    if n == 1 then
        return buffer[1], lastpos
    elseif n > 1 then
        return concat(buffer), lastpos
    else
        return "", lastpos
    end
end

local scanvalue -- forward declaration

local function scantable(what, closechar, str, startpos, nullval, objectmeta, arraymeta)
    local tbl, n = {}, 0
    local pos = startpos + 1
    if what == 'object' then
        setmetatable(tbl, objectmeta)
    else
        setmetatable(tbl, arraymeta)
    end
    while true do
        pos = scanwhite(str, pos)
        if not pos then return unterminated(str, what, startpos) end
        local char = strsub(str, pos, pos)
        if char == closechar then
            return tbl, pos + 1
        end
        local val1, err
        val1, pos, err = scanvalue(str, pos, nullval, objectmeta, arraymeta)
        if err then return nil, pos, err end
        pos = scanwhite(str, pos)
        if not pos then return unterminated(str, what, startpos) end
        char = strsub(str, pos, pos)
        if char == ":" then
            if val1 == nil then
                return nil, pos, "cannot use nil as table index (at " .. loc(str, pos) .. ")"
            end
            pos = scanwhite(str, pos + 1)
            if not pos then return unterminated(str, what, startpos) end
            local val2
            val2, pos, err = scanvalue(str, pos, nullval, objectmeta, arraymeta)
            if err then return nil, pos, err end
            tbl[val1] = val2
            pos = scanwhite(str, pos)
            if not pos then return unterminated(str, what, startpos) end
            char = strsub(str, pos, pos)
        else
            n = n + 1
            tbl[n] = val1
        end
        if char == "," then
            pos = pos + 1
        end
    end
end

scanvalue = function(str, pos, nullval, objectmeta, arraymeta)
    pos = pos or 1
    pos = scanwhite(str, pos)
    if not pos then
        return nil, strlen(str) + 1, "no valid JSON value (reached the end)"
    end
    local char = strsub(str, pos, pos)
    if char == "{" then
        return scantable('object', "}", str, pos, nullval, objectmeta, arraymeta)
    elseif char == "[" then
        return scantable('array', "]", str, pos, nullval, objectmeta, arraymeta)
    elseif char == "\"" then
        return scanstring(str, pos)
    else
        local pstart, pend = strfind(str, "^%-?[%d%.]+[eE]?[%+%-]?%d*", pos)
        if pstart then
            local number = str2num(strsub(str, pstart, pend))
            if number then
                return number, pend + 1
            end
        end
        pstart, pend = strfind(str, "^%a%w*", pos)
        if pstart then
            local name = strsub(str, pstart, pend)
            if name == "true" then
                return true, pend + 1
            elseif name == "false" then
                return false, pend + 1
            elseif name == "null" then
                return nullval, pend + 1
            end
        end
        return nil, pos, "no valid JSON value at " .. loc(str, pos)
    end
end

local function optionalmetatables(...)
    if select("#", ...) > 0 then
        return ...
    else
        return { __jsontype = 'object' }, { __jsontype = 'array' }
    end
end

---@param str string
---@param pos integer?
---@param nullval any?
---@param ... table?
function json.decode(str, pos, nullval, ...)
    local objectmeta, arraymeta = optionalmetatables(...)
    return scanvalue(str, pos, nullval, objectmeta, arraymeta)
end

return json

end)
__bundle_register("PAimbot.Common", function(require, _LOADED, __bundle_register, __bundle_modules)
---@diagnostic disable: duplicate-set-field, undefined-field
---@class Common
local Common = {}

--[[require modules]] --
local G = require("PAimbot.Globals")

pcall(UnloadLib) -- if it fails then forget about it it means it wasnt loaded in first place and were clean

-- Unload the module if it's already loaded
if package.loaded["ImMenu"] then
    package.loaded["ImMenu"] = nil
end

local libLoaded, Lib = pcall(require, "LNXlib")
assert(libLoaded, "LNXlib not found, please install it!")
assert(Lib.GetVersion() >= 1.0, "LNXlib version is too old, please update it!")

Common.Lib = Lib
Common.Log = Lib.Utils.Logger.new(G.scriptName)
Common.UI = Lib.UI
Common.Fonts = Common.UI.Fonts
Common.Notify = Common.UI.Notify
Common.TF2 = Common.Lib.TF2
Common.Utils = Common.Lib.Utils
Common.Math, Common.Conversion = Common.Utils.Math, Common.Utils.Conversion
Common.WPlayer, Common.WWeapon, Common.PR = Common.TF2.WPlayer, Common.TF2.WWeapon, Common.TF2.PlayerResource
Common.Helpers = Common.TF2.Helpers
Common.Prediction = Common.TF2.Prediction

-- Boring shit ahead!
Common.CROSS = (function(a, b, c) return (b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1]); end);
Common.CLAMP = (function(a, b, c) return (a < b) and b or (a > c) and c or a; end);
Common.TRACE_HULL = engine.TraceHull;
Common.TRACE_Line = engine.TraceLine;
Common.WORLD2SCREEN = client.WorldToScreen;
Common.POLYGON = draw.TexturedPolygon;
Common.LINE = draw.Line;
Common.COLOR = draw.Color;

-- Vector rotation function (used by projectile data)
Common.VEC_ROT = function(a, b)
    return (b:Forward() * a.x) + (b:Right() * a.y) + (b:Up() * a.z)
end

-- Function to normalize a vector
function Common.Normalize(vector)
    return vector / vector:Length()
end

-- Linear interpolation between two vectors
---@param t number Interpolation factor (0-1)
---@param a Vector3 Start vector
---@param b Vector3 End vector
---@return Vector3 Interpolated vector
function Common.LerpVector(t, a, b)
    return a * (1 - t) + b * t
end

-- Rotate a vector about the Z-axis by a given angle (degrees)
---@param vec Vector3 Vector to rotate
---@param angleDeg number Angle in degrees
---@return Vector3 Rotated vector
function Common.RotateVector(vec, angleDeg)
    local rad = math.rad(angleDeg)
    local cosA = math.cos(rad)
    local sinA = math.sin(rad)
    return Vector3(vec.x * cosA - vec.y * sinA, vec.x * sinA + vec.y * cosA, vec.z)
end

--Returns whether the player is on the ground
---@return boolean
function Common.IsOnGround(player)
    local pFlags = player:GetPropInt("m_fFlags")
    return (pFlags & FL_ONGROUND) ~= 0
end

-- Helper functions can be defined here if needed
function Common.GetHitboxPos(player, hitboxID)
    local hitbox = player:GetHitboxes()[hitboxID]
    if not hitbox then return nil end

    return (hitbox[1] + hitbox[2]) * 0.5
end

-- Validates if a player entity is a valid target
---@param entity Entity The entity to check
---@param checkFriend boolean? Check if the entity is a friend
---@param checkDormant boolean? Check if the entity is dormant
---@param skipEntity Entity? Optional entity to skip
---@return boolean Whether the entity is valid
function Common.IsValidPlayer(entity, checkFriend, checkDormant, skipEntity)
    if not entity or not entity:IsValid() then
        return false
    end

    if skipEntity and entity == skipEntity then
        return false
    end

    if not entity:IsAlive() then
        return false
    end

    if checkDormant and entity:IsDormant() then
        return false
    end

    if checkFriend and entity:GetTeamNumber() == entities.GetLocalPlayer():GetTeamNumber() then
        return false
    end

    return true
end

-- Get SteamID64 for a player
---@param player table The player wrapper
---@return string|number The player's SteamID64
function Common.GetSteamID64(player)
    if not player then return 0 end
    local info = client.GetPlayerInfo(player:GetIndex())
    return info and info.SteamID or 0
end

-- Returns the name of a keycode
---@param key integer
---@return string|nil
function Common.GetKeyName(key)
    return G.KeyNames[key]
end

-- Returns the string value of a keycode
---@param key integer
---@return string|nil
function Common.KeyToChar(key)
    return G.KeyValues[key]
end

-- Returns the keycode of a string value
---@param char string
---@return integer|nil
function Common.CharToKey(char)
    return table.find(G.KeyValues, string.upper(char))
end

-- Returns all currently pressed keys as a table
---@return integer[]
function Common.GetPressedKeys()
    local keys = {}
    for i = KEY_FIRST, KEY_LAST do
        if input.IsButtonDown(i) then table.insert(keys, i) end
    end

    return keys
end

-- Update the GetPressedKey function to check for these additional mouse buttons
function Common.GetPressedKey()
    for i = KEY_FIRST, KEY_LAST do
        if input.IsButtonDown(i) then return i end
    end

    -- Check for standard mouse buttons
    if input.IsButtonDown(MOUSE_LEFT) then return MOUSE_LEFT end
    if input.IsButtonDown(MOUSE_RIGHT) then return MOUSE_RIGHT end
    if input.IsButtonDown(MOUSE_MIDDLE) then return MOUSE_MIDDLE end

    -- Check for additional mouse buttons
    for i = 1, 10 do
        if input.IsButtonDown(MOUSE_FIRST + i - 1) then return MOUSE_FIRST + i - 1 end
    end

    return nil
end

-- Clamp function for projectile calculations
function Common.clamp(a, b, c)
    return (a < b) and b or (a > c) and c or a
end

-- Convert percentage to RGB value
function Common.convertPercentageToRGB(percentage)
    local value = math.floor(percentage / 100 * 255)
    return math.max(0, math.min(255, value))
end

-- Position angles calculation (from original working code)
function Common.PositionAngles(start, endPos)
    local delta = endPos - start
    local yaw = math.atan(delta.y, delta.x) * 180 / math.pi
    local pitch = math.atan(-delta.z, math.sqrt(delta.x * delta.x + delta.y * delta.y)) * 180 / math.pi
    return EulerAngles(pitch, yaw, 0)
end

-- Time to ticks conversion (from original working code)
function Common.TimeToTicks(time)
    return math.floor(time / globals.TickInterval() + 0.5)
end

--[[ Callbacks ]]
local function OnUnload()                        -- Called when the script is unloaded
    pcall(UnloadLib)                             --unloading lualib
    engine.PlaySound("hl1/fvox/deactivated.wav") --deactivated
end

--[[ Unregister previous callbacks ]]                             --
callbacks.Unregister("Unload", G.scriptName .. "_Unload")         -- unregister the "Unload" callback
--[[ Register callbacks ]]                                        --
callbacks.Register("Unload", G.scriptName .. "_Unload", OnUnload) -- Register the "Unload" callback

--[[ Play sound when loaded ]]                                    --
engine.PlaySound("hl1/fvox/activated.wav")

return Common

end)
__bundle_register("PAimbot.Visuals", function(require, _LOADED, __bundle_register, __bundle_modules)
local G = require("PAimbot.Globals")
local Config = require("PAimbot.Config")
local Common = require("PAimbot.Common")
local Prediction = require("PAimbot.Modules.Prediction.Prediction")

function Normalize(vec)
    local length = vec:Length()
    return Vector3(vec.x / length, vec.y / length, vec.z / length)
end

local function L_line(start_pos, end_pos, secondary_line_size)
    if not (start_pos and end_pos) then
        return
    end
    local direction = end_pos - start_pos
    local direction_length = direction:Length()
    if direction_length == 0 then
        return
    end
    local normalized_direction = Normalize(direction)
    local perpendicular = Vector3(normalized_direction.y, -normalized_direction.x, 0) * secondary_line_size
    local w2s_start_pos = client.WorldToScreen(start_pos)
    local w2s_end_pos = client.WorldToScreen(end_pos)
    if not (w2s_start_pos and w2s_end_pos) then
        return
    end
    local secondary_line_end_pos = start_pos + perpendicular
    local w2s_secondary_line_end_pos = client.WorldToScreen(secondary_line_end_pos)
    if w2s_secondary_line_end_pos then
        draw.Line(w2s_start_pos[1], w2s_start_pos[2], w2s_end_pos[1], w2s_end_pos[2])
        draw.Line(w2s_start_pos[1], w2s_start_pos[2], w2s_secondary_line_end_pos[1], w2s_secondary_line_end_pos[2])
    end
end

-- Draw prediction path for a single player
local function drawPlayerPredictionPath(playerIndex, predictionData, selectedStyle)
    local positions = predictionData.positions
    if not positions or type(positions) ~= "table" then
        return
    end

    -- Convert positions table to array format for easier iteration
    local posArray = {}
    for tick = 0, predictionData.maxTick do
        if positions[tick] then
            table.insert(posArray, positions[tick])
        end
    end

    if #posArray < 2 then
        return
    end

    -- Set drawing properties from config
    draw.Color(Config.visuals.line.r, Config.visuals.line.g, Config.visuals.line.b, Config.visuals.line.a)

    -- Draw prediction path based on selected style
    if selectedStyle == 1 then
        -- Style 1: Simple Line
        for i = 1, #posArray - 1 do
            local pos1 = posArray[i]
            local pos2 = posArray[i + 1]

            if pos1 and pos2 then
                local screenPos1 = client.WorldToScreen(pos1)
                local screenPos2 = client.WorldToScreen(pos2)

                if screenPos1 and screenPos2 then
                    draw.Line(screenPos1[1], screenPos1[2], screenPos2[1], screenPos2[2])
                end
            end
        end
    elseif selectedStyle == 2 then
        -- Style 2: Alt Line (L_line with perpendicular)
        for i = 1, #posArray - 1 do
            local pos1 = posArray[i]
            local pos2 = posArray[i + 1]

            if pos1 and pos2 then
                L_line(pos1, pos2, 10) -- 10 is the secondary line size
            end
        end
    elseif selectedStyle == 3 then
        -- Style 3: Dashed Line
        for i = 1, #posArray - 1 do
            local pos1 = posArray[i]
            local pos2 = posArray[i + 1]

            if pos1 and pos2 then
                local screenPos1 = client.WorldToScreen(pos1)
                local screenPos2 = client.WorldToScreen(pos2)

                if screenPos1 and screenPos2 then
                    -- Only draw every other segment for dashed effect
                    if i % 2 == 1 then
                        draw.Line(screenPos1[1], screenPos1[2], screenPos2[1], screenPos2[2])
                    end
                end
            end
        end
    end

    -- Draw outline if enabled
    if Config.visuals.outline.line_and_flags and selectedStyle ~= 2 then -- L_line already has its own styling
        draw.Color(Config.visuals.outline.r, Config.visuals.outline.g, Config.visuals.outline.b, Config.visuals.outline
        .a)
        for i = 1, #posArray - 1 do
            local pos1 = posArray[i]
            local pos2 = posArray[i + 1]

            if pos1 and pos2 then
                local screenPos1 = client.WorldToScreen(pos1)
                local screenPos2 = client.WorldToScreen(pos2)

                if screenPos1 and screenPos2 then
                    -- Draw outline by offsetting the line slightly
                    draw.Line(screenPos1[1] + 1, screenPos1[2], screenPos2[1] + 1, screenPos2[2])
                    draw.Line(screenPos1[1] - 1, screenPos1[2], screenPos2[1] - 1, screenPos2[2])
                    draw.Line(screenPos1[1], screenPos1[2] + 1, screenPos2[1], screenPos2[2] + 1)
                    draw.Line(screenPos1[1], screenPos1[2] - 1, screenPos2[1], screenPos2[2] - 1)
                end
            end
        end
    end

    -- Draw start and end points if enabled
    if Config.visuals.visualizeHitPos and #posArray > 0 then
        local startPos = posArray[1]
        local endPos = posArray[#posArray]

        -- Draw start point (green)
        local startScreen = client.WorldToScreen(startPos)
        if startScreen then
            draw.Color(0, 255, 0, 255)
            draw.FilledRect(startScreen[1] - 2, startScreen[2] - 2, startScreen[1] + 2, startScreen[2] + 2)
        end

        -- Draw end point (red)
        local endScreen = client.WorldToScreen(endPos)
        if endScreen then
            draw.Color(255, 0, 0, 255)
            draw.FilledRect(endScreen[1] - 2, endScreen[2] - 2, endScreen[1] + 2, endScreen[2] + 2)
        end

        -- Draw current tick position if different from end (yellow)
        if predictionData.currentTick > 0 and predictionData.currentTick < predictionData.maxTick then
            local currentPos = positions[predictionData.currentTick]
            if currentPos then
                local currentScreen = client.WorldToScreen(currentPos)
                if currentScreen then
                    draw.Color(255, 255, 0, 255)
                    draw.FilledRect(currentScreen[1] - 2, currentScreen[2] - 2, currentScreen[1] + 2,
                        currentScreen[2] + 2)
                end
            end
        end
    end
end

local function OnDraw()
    -- Check if visuals are enabled
    if not Config.visuals.active or not Config.visuals.visualizePath then
        return
    end

    -- Get all prediction visualization data
    local allPredictionData = Prediction.GetAllVisualizationData()
    if not allPredictionData then
        return
    end

    local selectedStyle = Config.visuals.path_styles_selected or 1

    -- Draw prediction paths for all players with prediction data
    for playerIndex, predictionData in pairs(allPredictionData) do
        -- Only draw if we have prediction data
        if predictionData and predictionData.positions and predictionData.maxTick > 0 then
            drawPlayerPredictionPath(playerIndex, predictionData, selectedStyle)
        end
    end
end

callbacks.Unregister("Draw", "LNX.Aimbot.Draw")
callbacks.Register("Draw", "LNX.Aimbot.Draw", OnDraw)

end)
__bundle_register("PAimbot.Modules.Prediction.Prediction", function(require, _LOADED, __bundle_register, __bundle_modules)
---@class Prediction
local Prediction = {}
Prediction.__index = Prediction

-- Reverse imports:
-- Used by: PAimbot.Aimbot, PAimbot.Movement

local Common = require("PAimbot.Common")
local G = require("PAimbot.Globals")
local HistoryHandler = require("PAimbot.Modules.Prediction.HistoryHandler")

-- Constants and helpers
local vUp = Vector3(0, 0, 1)
local nullVector = Vector3(0, 0, 0)
local ignoreEntities = { "CTFAmmoPack", "CTFDroppedWeapon" }
local MAX_SPEED = 450 -- Default max speed if not provided by player

-- Create a lookup table for faster class checks
local ignoreClassLookup = {}
for _, class in ipairs(ignoreEntities) do
    ignoreClassLookup[class] = true
end

-- Multi-order derivative tracking limits
local POSITION_HISTORY_LIMIT = 10
local VELOCITY_HISTORY_LIMIT = 10
local ACCELERATION_HISTORY_LIMIT = 8
local JERK_HISTORY_LIMIT = 6

-- Player derivative tracking tables
local positionRecords = {}
local velocityRecords = {}
local accelerationRecords = {}
local jerkRecords = {}

--------------------------------------------------------------------------------
-- Visualization Stack System
-- Automatically tracks all predictions made during this tick for visuals
--------------------------------------------------------------------------------

-- Global prediction visualization stack - cleared at start of each CreateMove
G.PredictionVisualizationStack = G.PredictionVisualizationStack or {}

-- Function to clear the visualization stack (called at start of each tick)
local function clearVisualizationStack()
    -- Clear all previous predictions
    for playerIndex, _ in pairs(G.PredictionVisualizationStack) do
        G.PredictionVisualizationStack[playerIndex] = nil
    end
end

-- Function to add a prediction step to the visualization stack
local function addPredictionToStack(playerIndex, tickNumber, position, velocity, onGround)
    if not G.PredictionVisualizationStack[playerIndex] then
        G.PredictionVisualizationStack[playerIndex] = {
            positions = {},
            velocities = {},
            onGroundStates = {},
            maxTick = 0,
            currentTick = 0
        }
    end

    local stack = G.PredictionVisualizationStack[playerIndex]
    stack.positions[tickNumber] = position
    stack.velocities[tickNumber] = velocity
    stack.onGroundStates[tickNumber] = onGround
    stack.maxTick = math.max(stack.maxTick, tickNumber)
    stack.currentTick = tickNumber
end

-- Function to get prediction visualization data for a player (used by visuals)
function Prediction.GetVisualizationData(playerIndex)
    return G.PredictionVisualizationStack[playerIndex]
end

-- Function to get all players with prediction data (used by visuals)
function Prediction.GetAllVisualizationData()
    return G.PredictionVisualizationStack
end

-- Register callback to clear visualization stack at start of each tick
callbacks.Unregister("CreateMove", "Prediction_ClearVisualizationStack")
callbacks.Register("CreateMove", "Prediction_ClearVisualizationStack", clearVisualizationStack)

--------------------------------------------------------------------------------
-- Multi-Order Derivative Prediction System
--------------------------------------------------------------------------------

-- Update position history for a player
local function updatePositionRecords(player, currentTime)
    if not player or not player:IsAlive() then return end

    local playerIndex = player:GetIndex()
    local currentPos = player:GetAbsOrigin()

    if not positionRecords[playerIndex] then
        positionRecords[playerIndex] = {
            lastPos = currentPos,
            lastTime = currentTime,
            positionHistory = {
                { pos = currentPos, time = currentTime }
            }
        }
        return
    end

    local record = positionRecords[playerIndex]

    table.insert(record.positionHistory, { pos = currentPos, time = currentTime })

    if #record.positionHistory > POSITION_HISTORY_LIMIT then
        table.remove(record.positionHistory, 1)
    end

    record.lastPos = currentPos
    record.lastTime = currentTime
end

-- Calculate current velocity from position history
local function getCurrentVelocityFromHistory(player)
    local playerIndex = player:GetIndex()
    local record = positionRecords[playerIndex]

    if not record or not record.positionHistory or #record.positionHistory < 2 then
        return player:EstimateAbsVelocity()
    end

    local lastEntry = record.positionHistory[#record.positionHistory]
    local prevEntry = record.positionHistory[#record.positionHistory - 1]

    -- Add proper nil checks for time fields
    if not lastEntry or not prevEntry or not lastEntry.time or not prevEntry.time then
        return player:EstimateAbsVelocity()
    end

    local p2 = lastEntry.pos
    local t2 = lastEntry.time
    local p1 = prevEntry.pos
    local t1 = prevEntry.time

    local dt = t2 - t1
    if dt <= 0 then return player:EstimateAbsVelocity() end

    return (p2 - p1) / dt
end

-- Update velocity history for a player
local function updateVelocityRecords(player, currentTime)
    if not player or not player:IsAlive() then return end

    local playerIndex = player:GetIndex()
    local currentVel = getCurrentVelocityFromHistory(player)

    if not velocityRecords[playerIndex] then
        velocityRecords[playerIndex] = {
            lastVel = currentVel,
            lastTime = currentTime,
            velocityHistory = {
                { vel = currentVel, time = currentTime }
            }
        }
        return
    end

    local record = velocityRecords[playerIndex]

    table.insert(record.velocityHistory, { vel = currentVel, time = currentTime })

    if #record.velocityHistory > VELOCITY_HISTORY_LIMIT then
        table.remove(record.velocityHistory, 1)
    end

    record.lastVel = currentVel
    record.lastTime = currentTime
end

-- Calculate current acceleration from velocity history
local function getCurrentAcceleration(player)
    local playerIndex = player:GetIndex()
    local record = velocityRecords[playerIndex]

    if not record or not record.velocityHistory or #record.velocityHistory < 2 then
        return Vector3(0, 0, 0)
    end

    local lastEntry = record.velocityHistory[#record.velocityHistory]
    local prevEntry = record.velocityHistory[#record.velocityHistory - 1]

    -- Add proper nil checks for time fields
    if not lastEntry or not prevEntry or not lastEntry.time or not prevEntry.time then
        return Vector3(0, 0, 0)
    end

    local v2 = lastEntry.vel
    local t2 = lastEntry.time
    local v1 = prevEntry.vel
    local t1 = prevEntry.time

    local dt = t2 - t1
    if dt <= 0 then return Vector3(0, 0, 0) end

    return (v2 - v1) / dt
end

-- Update acceleration history for a player
local function updateAccelerationRecords(player, currentTime)
    if not player or not player:IsAlive() then return end

    local playerIndex = player:GetIndex()
    local currentAccel = getCurrentAcceleration(player)

    if not accelerationRecords[playerIndex] then
        accelerationRecords[playerIndex] = {
            lastAccel = currentAccel,
            lastTime = currentTime,
            accelerationHistory = {
                { accel = currentAccel, time = currentTime }
            }
        }
        return
    end

    local record = accelerationRecords[playerIndex]

    table.insert(record.accelerationHistory, { accel = currentAccel, time = currentTime })

    if #record.accelerationHistory > ACCELERATION_HISTORY_LIMIT then
        table.remove(record.accelerationHistory, 1)
    end

    record.lastAccel = currentAccel
    record.lastTime = currentTime
end

-- Calculate current jerk from acceleration history
local function getCurrentJerk(player)
    local playerIndex = player:GetIndex()
    local record = accelerationRecords[playerIndex]

    if not record or not record.accelerationHistory or #record.accelerationHistory < 2 then
        return Vector3(0, 0, 0)
    end

    local lastEntry = record.accelerationHistory[#record.accelerationHistory]
    local prevEntry = record.accelerationHistory[#record.accelerationHistory - 1]

    -- Add proper nil checks for time fields
    if not lastEntry or not prevEntry or not lastEntry.time or not prevEntry.time then
        return Vector3(0, 0, 0)
    end

    local a2 = lastEntry.accel
    local t2 = lastEntry.time
    local a1 = prevEntry.accel
    local t1 = prevEntry.time

    local dt = t2 - t1
    if dt <= 0 then return Vector3(0, 0, 0) end

    return (a2 - a1) / dt
end

-- Update jerk history for a player
local function updateJerkRecords(player, currentTime)
    if not player or not player:IsAlive() then return end

    local playerIndex = player:GetIndex()
    local currentJerk = getCurrentJerk(player)

    if not jerkRecords[playerIndex] then
        jerkRecords[playerIndex] = {
            lastJerk = currentJerk,
            lastTime = currentTime,
            jerkHistory = {
                { jerk = currentJerk, time = currentTime }
            }
        }
        return
    end

    local record = jerkRecords[playerIndex]

    table.insert(record.jerkHistory, { jerk = currentJerk, time = currentTime })

    if #record.jerkHistory > JERK_HISTORY_LIMIT then
        table.remove(record.jerkHistory, 1)
    end

    record.lastJerk = currentJerk
    record.lastTime = currentTime
end

-- Predict future position using Taylor series expansion with derivatives
local function predictPositionWithDerivatives(player, deltaTime)
    local playerIndex = player:GetIndex()

    -- Get current state
    local pos = positionRecords[playerIndex] and positionRecords[playerIndex].lastPos or player:GetAbsOrigin()
    local vel = velocityRecords[playerIndex] and velocityRecords[playerIndex].lastVel or Vector3(0, 0, 0)
    local accel = accelerationRecords[playerIndex] and accelerationRecords[playerIndex].lastAccel or Vector3(0, 0, 0)
    local jerk = jerkRecords[playerIndex] and jerkRecords[playerIndex].lastJerk or Vector3(0, 0, 0)
    local snap = HistoryHandler and HistoryHandler:getSnap(player) or Vector3(0, 0, 0)

    -- Taylor series expansion: p(t) = p₀ + v₀t + ½a₀t² + ⅙j₀t³ + 1/24s₀t⁴
    local dt = deltaTime
    local dt2 = dt * dt
    local dt3 = dt2 * dt
    local dt4 = dt3 * dt

    local predictedPos = pos + vel * dt + accel * (0.5 * dt2) + jerk * (dt3 / 6.0) + snap * (dt4 / 24.0)

    return predictedPos, vel + accel * dt + jerk * (0.5 * dt2) + snap * (dt3 / 6.0)
end

-- Clean up records for invalid or dormant players
local function cleanupDerivativeRecords()
    local FastPlayers = require("PAimbot.Modules.Helpers.FastPlayers")
    local players = FastPlayers.GetAll()
    local validIndices = {}

    for _, player in pairs(players) do
        local playerRaw = player._rawEntity
        if playerRaw and playerRaw:IsAlive() and not playerRaw:IsDormant() then
            validIndices[playerRaw:GetIndex()] = true
        end
    end

    -- Clean up position records
    for index, _ in pairs(positionRecords) do
        if not validIndices[index] then
            positionRecords[index] = nil
        end
    end

    -- Clean up velocity records
    for index, _ in pairs(velocityRecords) do
        if not validIndices[index] then
            velocityRecords[index] = nil
        end
    end

    -- Clean up acceleration records
    for index, _ in pairs(accelerationRecords) do
        if not validIndices[index] then
            accelerationRecords[index] = nil
        end
    end

    -- Clean up jerk records
    for index, _ in pairs(jerkRecords) do
        if not validIndices[index] then
            jerkRecords[index] = nil
        end
    end
end

-- Update all derivative records for a player
local function updateAllDerivativeRecords(player, currentTime)
    updatePositionRecords(player, currentTime)
    updateVelocityRecords(player, currentTime)
    updateAccelerationRecords(player, currentTime)
    updateJerkRecords(player, currentTime)
end

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------
-- Determines if an entity should be considered for collision
---@param entity Entity The entity to check
---@param player Entity The player entity to compare against
---@return boolean Whether the entity should be hit by traces
local function shouldHitEntityFun(entity, player)
    -- Branchless entity collision check using mathematical operations
    local entityClass = entity:GetClass()
    local isIgnoredClass = ignoreClassLookup[entityClass] and 1 or 0
    local isSameEntity = (entity == player) and 1 or 0
    local isSameTeam = (entity:GetTeamNumber() == player:GetTeamNumber()) and 1 or 0

    local pos = entity:GetAbsOrigin() + Vector3(0, 0, 1)
    local contents = engine.GetPointContents(pos)
    local isNotEmpty = (contents ~= CONTENTS_EMPTY) and 1 or 0

    -- Sum all the "should ignore" conditions - if any are true (sum > 0), we ignore
    local ignoreScore = isIgnoredClass + isSameEntity + isSameTeam + isNotEmpty

    -- Return true only if ignoreScore is 0 (no ignore conditions met)
    return ignoreScore == 0
end

-- Clamp velocity components per axis (sv_maxvelocity)
---@param velocity Vector3 The velocity vector to clamp
---@param maxVel number Maximum velocity per axis
---@return Vector3 Clamped velocity vector
local function clampVelocityPerAxis(velocity, maxVel)
    -- Branchless per-axis clamping
    local x = velocity.x
    local y = velocity.y
    local z = velocity.z

    -- Clamp X axis
    local xExceeds = (math.abs(x) > maxVel) and 1 or 0
    local xSign = (x > 0) and 1 or -1
    x = x * (1 - xExceeds) + (maxVel * xSign * xExceeds)

    -- Clamp Y axis
    local yExceeds = (math.abs(y) > maxVel) and 1 or 0
    local ySign = (y > 0) and 1 or -1
    y = y * (1 - yExceeds) + (maxVel * ySign * yExceeds)

    -- Clamp Z axis
    local zExceeds = (math.abs(z) > maxVel) and 1 or 0
    local zSign = (z > 0) and 1 or -1
    z = z * (1 - zExceeds) + (maxVel * zSign * zExceeds)

    return Vector3(x, y, z)
end

--------------------------------------------------------------------------------
-- Prediction State: reset, initialization, and update
--------------------------------------------------------------------------------
---@param self Prediction
function Prediction:reset()
    -- Clear simulation history
    self.currentTick = 0
    self.cachedPredictions = { pos = {}, vel = {}, onGround = {} }

    -- Clear physics variables
    self.gravity = nil
    self.stepHeight = nil
    self.position = nil
    self.velocity = nil
    self.onGround = nil
    self.deltaStrafe = nil
    self.vStep = nil
    self.hitbox = nil
    self.MAX_SPEED = nil
    self.shouldHitEntity = nil
    self.terminalVelocity = nil
    self.maxVelocity = nil

    -- Variables for move intent simulation
    self.moveIntent = nil        -- Current intended movement vector
    self.initialMoveIntent = nil -- Baseline movement vector at start
    self.strafeAngle = 0         -- Smoothed strafe rotation angle (degrees)

    -- Advanced prediction variables
    self.useAdvancedPrediction = true
    self.currentTime = globals.RealTime()
end

-- Update simulation state from the current player's data
---@param self Prediction
---@param player Entity The player entity to simulate
function Prediction:update(player)
    -- Only reset if we don't have cached data or player changed
    if not self.cachedPredictions or not self.cachedPredictions.pos or #self.cachedPredictions.pos == 0 then
        self:reset()
    end

    -- Fetch on-demand motion derivatives from HistoryHandler (velocity, accel, jerk, strafe)
    local derivatives = HistoryHandler:getDerivatives(player)

    -- Get physics constants from game
    self.gravity = client.GetConVar("sv_gravity") or 800
    self.acceleration = client.GetConVar("sv_accelerate") or 10
    self.friction = client.GetConVar("sv_friction") or 4
    self.stepHeight = player:GetPropFloat("localdata", "m_flStepSize") or 18

    -- TF2 Terminal Velocity (based on fall damage plateau at ~3500 HU/s)
    self.terminalVelocity = -3500 -- Negative because downward

    -- TF2 Maximum Velocity per axis (sv_maxvelocity)
    self.maxVelocity = client.GetConVar("sv_maxvelocity") or 3500

    -- Set up hitbox dimensions based on player state
    G.Hitbox.Max.z = Common.IsOnGround(player) and 62 or 82
    self.hitbox = G.Hitbox or { Min = Vector3(-24, -24, 0), Max = Vector3(24, 24, 82) }
    self.vStep = Vector3(0, 0, self.stepHeight)

    -- Get current player state
    self.position = player:GetAbsOrigin()
    self.velocity = player:EstimateAbsVelocity()
    self.onGround = Common.IsOnGround(player)
    self.MAX_SPEED = player:GetPropFloat("m_flMaxspeed") or MAX_SPEED

    -- Set the move intent based on current velocity direction
    local horizontalVel = Vector3(self.velocity.x, self.velocity.y, 0)
    if horizontalVel:Length() > 50 then -- Only if actually moving with decent speed
        self.initialMoveIntent = horizontalVel
        self.moveIntent = horizontalVel
    else
        -- If not moving, no move intent (standing still)
        self.initialMoveIntent = Vector3(0, 0, 0)
        self.moveIntent = Vector3(0, 0, 0)
    end

    self.strafeAngle = 0

    -- Create a closure for entity collision detection
    self.shouldHitEntity = function(entity)
        return shouldHitEntityFun(entity, player)
    end

    local playerIndex = player:GetIndex()
    local motionData = {
        strafeDelta = derivatives.strafeDelta or 0,
        acceleration = derivatives.acceleration or Vector3(0, 0, 0),
        jerk = derivatives.jerk or Vector3(0, 0, 0),
        predictabilityScore = 0.5 -- placeholder until advanced score function integrated
    }

    self.deltaStrafe = motionData.strafeDelta
    self.motionData = motionData
    self.motionData.snap = derivatives.snap or Vector3(0, 0, 0)

    -- Store player reference for advanced prediction
    self.player = player
    self.playerIndex = playerIndex

    -- Clear the current tick counter for fresh prediction
    self.currentTick = 0

    -- Store initial state as tick 0
    self.cachedPredictions.pos[1] = self.position
    self.cachedPredictions.vel[1] = self.velocity
    self.cachedPredictions.onGround[1] = self.onGround

    -- Add initial state to visualization stack
    addPredictionToStack(playerIndex, 0, self.position, self.velocity, self.onGround)
end

--------------------------------------------------------------------------------
-- predictTick: Simulate one tick of prediction.
--
-- This function simulates one physics tick, updating position based on current velocity,
-- applying gravity, friction, and handling collisions. Each tick builds on the previous.
--------------------------------------------------------------------------------
---@param self Prediction
---@return table Result containing position, velocity and ground state
function Prediction:predictTick()
    local dt = G.TickInterval

    -- Start with current simulation state (this accumulates over ticks)
    local pos = self.position
    local vel = self.velocity
    local onGround = self.onGround

    -- Apply gravity if airborne
    if not onGround then
        vel.z = vel.z - self.gravity * dt
    end

    -- Apply terminal velocity clamping
    if vel.z < self.terminalVelocity then
        vel.z = self.terminalVelocity
    end

    -- Update strafe based on enhanced motion data (simulate continuous strafing)
    if self.motionData and self.motionData.strafeDelta ~= 0 then
        local strafeInfluence = self.motionData.strafeDelta

        -- Scale strafe influence by predictability (less predictable = less influence)
        if self.motionData.predictabilityScore then
            strafeInfluence = strafeInfluence * (1.0 - self.motionData.predictabilityScore * 0.3)
        end

        -- Smooth the strafe angle to better model rapid left/right oscillations
        -- Exponential smoothing: keep 80% of previous value, add 20% of new influence
        self.strafeAngle = (self.strafeAngle or 0) * 0.8 + strafeInfluence * 0.2
        self.moveIntent = Common.RotateVector(self.initialMoveIntent, self.strafeAngle)
    end

    -- Apply acceleration if available
    if self.motionData and self.motionData.acceleration then
        -- Apply a portion of acceleration to the velocity prediction
        vel = vel + self.motionData.acceleration * dt * 0.1 -- Scale down to avoid overshoot
    end

    -- Apply jerk (rate-of-change of acceleration) to capture curved movement
    if self.motionData and self.motionData.jerk then
        -- Taylor term: Δv ≈ ½·j·dt² ; we dampen further (0.05) to avoid overshoot
        vel = vel + self.motionData.jerk * (0.5 * dt * dt) * 0.1
    end

    -- Apply snap (change in jerk) if available
    if self.motionData and self.motionData.snap then
        -- Even smaller influence to stabilize
        vel = vel + self.motionData.snap * dt * dt * dt * 0.01 -- dt³ term, heavily damped
    end

    -- Get desired horizontal movement direction
    local desiredDir = Vector3(0, 0, 0)
    local horizontalMoveIntent = Vector3(self.moveIntent.x, self.moveIntent.y, 0)
    if horizontalMoveIntent:Length() > 0 then
        desiredDir = Common.Normalize(horizontalMoveIntent)
    end
    local desiredSpeed = self.MAX_SPEED

    -- Apply friction if on ground
    local currentHorizontal = Vector3(vel.x, vel.y, 0)
    local currentSpeed = currentHorizontal:Length()

    if onGround and currentSpeed > 0 then
        local drop = currentSpeed * self.friction * dt
        local newSpeed = math.max(currentSpeed - drop, 0)
        if currentSpeed > 0 then
            currentHorizontal = currentHorizontal * (newSpeed / currentSpeed)
        end
    end

    -- Apply acceleration toward desired direction
    if desiredDir:Length() > 0 then
        local speedAlongWish = currentHorizontal:Dot(desiredDir)
        local addSpeed = desiredSpeed - speedAlongWish
        if addSpeed > 0 then
            local accelSpeed = math.min(self.acceleration * desiredSpeed * dt, addSpeed)
            currentHorizontal = currentHorizontal + desiredDir * accelSpeed
        end
    end

    -- Clamp horizontal speed
    local horizontalSpeed = currentHorizontal:Length()
    if horizontalSpeed > desiredSpeed then
        currentHorizontal = currentHorizontal * (desiredSpeed / horizontalSpeed)
    end

    -- Update velocity
    vel.x = currentHorizontal.x
    vel.y = currentHorizontal.y

    -- Calculate new position
    local newPos = pos + vel * dt

    -- Wall collision detection
    local wallTrace = Common.TRACE_HULL(
        pos + self.vStep,
        newPos + self.vStep,
        self.hitbox.Min,
        self.hitbox.Max,
        MASK_PLAYERSOLID,
        self.shouldHitEntity
    )

    if wallTrace.fraction < 1.0 then
        -- Hit a wall - slide along it
        local normal = wallTrace.plane
        local dot = vel:Dot(normal)
        if dot < 0 then
            vel = vel - normal * dot -- Remove velocity component into wall
        end
        newPos.x = wallTrace.endpos.x
        newPos.y = wallTrace.endpos.y
        -- Keep Z movement
    end

    -- Ground collision detection
    local downStep = onGround and self.vStep or nullVector
    local groundTrace = Common.TRACE_HULL(
        newPos + self.vStep,
        newPos - downStep,
        self.hitbox.Min,
        self.hitbox.Max,
        MASK_PLAYERSOLID,
        self.shouldHitEntity
    )

    if groundTrace.fraction < 1.0 then
        local groundNormal = groundTrace.plane
        local groundAngle = math.deg(math.acos(math.max(0, math.min(1, groundNormal:Dot(vUp)))))

        if groundAngle < 45 then -- Walkable surface
            newPos = groundTrace.endpos
            onGround = true
            vel.z = 0
        elseif groundAngle >= 45 and groundAngle < 55 then -- Slippery surface
            vel = Vector3(0, 0, 0)                         -- Stop all movement
        else                                               -- Wall-like surface
            local wallDot = vel:Dot(groundNormal)
            vel = vel - groundNormal * wallDot
            onGround = true
        end
    else
        onGround = false -- Not touching ground
    end

    -- Apply sv_maxvelocity clamping per axis
    vel = clampVelocityPerAxis(vel, self.maxVelocity)

    -- Update simulation state for next tick
    self.position = newPos
    self.velocity = vel
    self.onGround = onGround
    self.currentTick = self.currentTick + 1

    -- Cache results
    self.cachedPredictions.pos[self.currentTick + 1] = newPos
    self.cachedPredictions.vel[self.currentTick + 1] = vel
    self.cachedPredictions.onGround[self.currentTick + 1] = onGround

    -- Add this prediction step to the visualization stack
    if self.playerIndex then
        addPredictionToStack(self.playerIndex, self.currentTick, newPos, vel, onGround)
    end

    return { pos = newPos, vel = vel, onGround = onGround }
end

--------------------------------------------------------------------------------
-- Public API for running multiple ticks and rewinding
--------------------------------------------------------------------------------
---@param self Prediction
---@param ticks number Number of ticks to predict forward
---@return table Result containing position, velocity and ground state
function Prediction:predict(ticks)
    ticks = ticks or 1
    for i = 1, ticks do
        self:predictTick()
    end
    return {
        pos = self.cachedPredictions.pos[self.currentTick],
        vel = self.cachedPredictions.vel[self.currentTick],
        onGround = self.cachedPredictions.onGround[self.currentTick]
    }
end

---@param self Prediction
---@param ticks number Number of ticks to rewind
---@return table Result containing position, velocity and ground state
function Prediction:rewind(ticks)
    ticks = ticks or 1
    local targetTick = self.currentTick - ticks
    if targetTick < 0 then targetTick = 0 end
    self.currentTick = targetTick

    -- Update visualization stack current tick pointer (no new predictions generated)
    if self.playerIndex and G.PredictionVisualizationStack[self.playerIndex] then
        G.PredictionVisualizationStack[self.playerIndex].currentTick = targetTick
    end

    -- Also update internal simulation state to match the rewound tick
    if targetTick == 0 then
        -- Return to initial state
        self.position = self.cachedPredictions.pos[1]
        self.velocity = self.cachedPredictions.vel[1]
        self.onGround = self.cachedPredictions.onGround[1]
    else
        self.position = self.cachedPredictions.pos[targetTick + 1]
        self.velocity = self.cachedPredictions.vel[targetTick + 1]
        self.onGround = self.cachedPredictions.onGround[targetTick + 1]
    end

    return {
        pos = self.position,
        vel = self.velocity,
        onGround = self.onGround
    }
end

---@param self Prediction
---@return table Complete prediction history
function Prediction:history()
    return self.cachedPredictions
end

-- Get prediction quality metrics for a player
---@param self Prediction
---@param player Entity The player to get metrics for
---@return table Prediction quality metrics
function Prediction:getPredictionQuality(player)
    if not player then return { quality = 0, dataPoints = 0, method = "none" } end

    local playerIndex = player:GetIndex()
    local posRecord = positionRecords[playerIndex]
    local velRecord = velocityRecords[playerIndex]
    local accelRecord = accelerationRecords[playerIndex]
    local jerkRecord = jerkRecords[playerIndex]

    local posDataPoints = posRecord and #posRecord.positionHistory or 0
    local velDataPoints = velRecord and #velRecord.velocityHistory or 0
    local accelDataPoints = accelRecord and #accelRecord.accelerationHistory or 0
    local jerkDataPoints = jerkRecord and #jerkRecord.jerkHistory or 0

    local totalDataPoints = posDataPoints + velDataPoints + accelDataPoints + jerkDataPoints
    local maxPossibleDataPoints = POSITION_HISTORY_LIMIT + VELOCITY_HISTORY_LIMIT + ACCELERATION_HISTORY_LIMIT +
        JERK_HISTORY_LIMIT

    local quality = totalDataPoints / maxPossibleDataPoints

    local method = "physics"
    if posDataPoints >= 3 and velDataPoints >= 3 and accelDataPoints >= 2 then
        method = "derivatives"
        if jerkDataPoints >= 2 then
            method = "advanced_derivatives"
        end
    end

    return {
        quality = quality,
        dataPoints = totalDataPoints,
        method = method,
        details = {
            position = posDataPoints,
            velocity = velDataPoints,
            acceleration = accelDataPoints,
            jerk = jerkDataPoints
        }
    }
end

-- Update all player derivative records (call this every frame)
---@param self Prediction
function Prediction:updateDerivativeTracking()
    local currentTime = globals.RealTime()
    local FastPlayers = require("PAimbot.Modules.Helpers.FastPlayers")
    local players = FastPlayers.GetEnemies()

    for _, player in pairs(players) do
        local playerRaw = player._rawEntity
        if playerRaw and playerRaw:IsAlive() and not playerRaw:IsDormant() then
            updateAllDerivativeRecords(playerRaw, currentTime)
        end
    end

    -- Clean up records for invalid players
    cleanupDerivativeRecords()
end

-- Enable or disable advanced prediction
---@param self Prediction
---@param enabled boolean Whether to use advanced prediction
function Prediction:setAdvancedPrediction(enabled)
    self.useAdvancedPrediction = enabled
end

-- Get derivative data for debugging
---@param self Prediction
---@param player Entity The player to get data for
---@return table Derivative data
function Prediction:getDerivativeData(player)
    if not player then return {} end

    local playerIndex = player:GetIndex()

    return {
        position = positionRecords[playerIndex],
        velocity = velocityRecords[playerIndex],
        acceleration = accelerationRecords[playerIndex],
        jerk = jerkRecords[playerIndex]
    }
end

-- Get predicted position at a specific time offset
---@param self Prediction
---@param player Entity The player to predict for
---@param timeOffset number Time offset in seconds
---@return Vector3|nil Predicted position
function Prediction:predictPositionAt(player, timeOffset)
    if not player or timeOffset <= 0 then return nil end

    local playerIndex = player:GetIndex()
    local posRecord = positionRecords[playerIndex]
    local velRecord = velocityRecords[playerIndex]
    local accelRecord = accelerationRecords[playerIndex]

    -- Use advanced prediction if we have sufficient data
    if posRecord and velRecord and accelRecord and
        #posRecord.positionHistory >= 3 and
        #velRecord.velocityHistory >= 3 and
        #accelRecord.accelerationHistory >= 2 then
        local predictedPos, _ = predictPositionWithDerivatives(player, timeOffset)
        return predictedPos
    else
        -- Fall back to simple linear prediction
        local currentPos = player:GetAbsOrigin()
        local currentVel = player:EstimateAbsVelocity()
        return currentPos + currentVel * timeOffset
    end
end

-- Reset prediction cache
---@param self Prediction
function Prediction:reset()
    self.cachedPredictions = { pos = {}, vel = {}, onGround = {} }
    self.currentTick = 0
end

-- Get all visualization data for the visuals system
---@return table|nil The complete visualization stack data
function Prediction.GetAllVisualizationData()
    return G.PredictionVisualizationStack
end

-- Clear all visualization data at the start of each tick
function Prediction.ClearVisualizationStack()
    G.PredictionVisualizationStack = {}
end

--------------------------------------------------------------------------------
-- Create and return the singleton Prediction instance
--------------------------------------------------------------------------------
local predictionInstance = setmetatable({}, Prediction)
predictionInstance:reset()
return predictionInstance

end)
__bundle_register("PAimbot.Modules.Helpers.FastPlayers", function(require, _LOADED, __bundle_register, __bundle_modules)
-- FastPlayers.lua ─────────────────────────────────────────────────────────
-- FastPlayers: Simplified per-tick cached player lists.
-- On each CreateMove tick, caches reset; lists built on demand.

--[[ Imports ]]
local G = require("PAimbot.Globals")
local Common = require("PAimbot.Common")
local WPlayer = Common.WPlayer -- Use lnxLib's wrapper directly

--[[ Module Declaration ]]
local FastPlayers = {}

--[[ Local Caches ]]
local cachedAllPlayers
local cachedTeammates
local cachedEnemies
local cachedLocal
local cachedLocalRaw -- Cache raw entity directly

FastPlayers.AllUpdated = false
FastPlayers.TeammatesUpdated = false
FastPlayers.EnemiesUpdated = false

--[[ Private: Reset per-tick caches ]]
local function ResetCaches()
    cachedAllPlayers = nil
    cachedTeammates = nil
    cachedEnemies = nil
    cachedLocal = nil
    cachedLocalRaw = nil
    FastPlayers.AllUpdated = false
    FastPlayers.TeammatesUpdated = false
    FastPlayers.EnemiesUpdated = false
end

--[[ Public API ]]

--- Returns list of valid, non-dormant players once per tick.
---@return WPlayer[]
function FastPlayers.GetAll(excludelocal)
    if FastPlayers.AllUpdated then
        return cachedAllPlayers
    end
    excludelocal = excludelocal and FastPlayers.GetLocal() or nil
    cachedAllPlayers = {}
    for _, ent in pairs(entities.FindByClass("CTFPlayer") or {}) do
        if Common.IsValidPlayer(ent, false, true, excludelocal and excludelocal:GetEntity()) then
            local wrapped = WPlayer.FromEntity(ent)
            if wrapped then
                cachedAllPlayers[#cachedAllPlayers + 1] = wrapped
            end
        end
    end
    FastPlayers.AllUpdated = true
    return cachedAllPlayers
end

--- Returns the local player as a WPlayer instance, cached after first wrap.
---@return WPlayer?
function FastPlayers.GetLocal()
    if not cachedLocal then
        local rawLocal = entities.GetLocalPlayer()
        if rawLocal then
            cachedLocal = WPlayer.FromEntity(rawLocal)
            cachedLocalRaw = rawLocal -- Cache raw entity too
        end
    end
    return cachedLocal
end

--- Returns the local player as a raw Entity, cached for performance.
---@return Entity?
function FastPlayers.GetLocalRaw()
    if not cachedLocalRaw then
        cachedLocalRaw = entities.GetLocalPlayer()
        -- Also cache wrapped version if we don't have it
        if cachedLocalRaw and not cachedLocal then
            cachedLocal = WPlayer.FromEntity(cachedLocalRaw)
        end
    end
    return cachedLocalRaw
end

--- Returns list of teammates, optionally excluding a player (or the local player).
---@param exclude boolean|WPlayer? Pass `true` to exclude the local player, or a WPlayer instance to exclude that specific teammate. Omit/nil to include everyone.
---@return WPlayer[]
function FastPlayers.GetTeammates(exclude)
    if not FastPlayers.TeammatesUpdated then
        if not FastPlayers.AllUpdated then
            FastPlayers.GetAll()
        end

        cachedTeammates = {}

        -- Determine which player (if any) to exclude
        local localPlayer = FastPlayers.GetLocal()
        local excludePlayer = nil
        if exclude == true then
            excludePlayer = localPlayer -- explicitly exclude self
        elseif type(exclude) == "table" then
            excludePlayer = exclude
        end

        -- Use local player's team for filtering
        local myTeam = localPlayer and localPlayer:GetTeamNumber() or nil
        if myTeam then
            for _, wp in ipairs(cachedAllPlayers) do
                if wp:GetTeamNumber() == myTeam and wp ~= excludePlayer then
                    cachedTeammates[#cachedTeammates + 1] = wp
                end
            end
        end

        FastPlayers.TeammatesUpdated = true
    end
    return cachedTeammates
end

--- Returns list of enemies (players on a different team).
---@return WPlayer[]
function FastPlayers.GetEnemies()
    if not FastPlayers.EnemiesUpdated then
        if not FastPlayers.AllUpdated then
            FastPlayers.GetAll()
        end
        cachedEnemies = {}
        local pLocal = FastPlayers.GetLocal()
        if pLocal then
            local myTeam = pLocal:GetTeamNumber()
            for _, wp in ipairs(cachedAllPlayers) do
                if wp:GetTeamNumber() ~= myTeam then
                    cachedEnemies[#cachedEnemies + 1] = wp
                end
            end
        end
        FastPlayers.EnemiesUpdated = true
    end
    return cachedEnemies
end

--[[ Initialization ]]
-- Reset caches at the start of every CreateMove tick.
callbacks.Register("CreateMove", "FastPlayers_ResetCaches", ResetCaches)

return FastPlayers

end)
__bundle_register("PAimbot.Modules.Prediction.HistoryHandler", function(require, _LOADED, __bundle_register, __bundle_modules)
---@class HistoryHandler
local HistoryHandler = {}
HistoryHandler.__index = HistoryHandler

local G = require("PAimbot.Globals")
local Config = require("PAimbot.Config")
local Common = require("PAimbot.Common")

-- Forward declaration for the singleton instance to allow early references
local historyHandlerInstance

--------------------------------------------------------------------------------
-- Kalman Filter Configuration
--------------------------------------------------------------------------------
HistoryHandler.kalmanConfig = {
    processNoise = 0.7,          -- Base process noise (Q)
    baseMeasurementNoise = 0.05, -- Base measurement noise (R)
    minimumHistoryCount = 4,     -- Minimum sample count for dynamic noise computation
}

--------------------------------------------------------------------------------
-- Initialize HistoryHandler storage
--------------------------------------------------------------------------------
function HistoryHandler:init()
    -- Table to store motion data samples per entity:
    -- histories[entityIndex] = {
    --   {strafeDelta = value, velocity = vec, acceleration = vec, jerk = vec, snap = vec, pop = vec, timestamp = time},
    --   ...
    -- }
    self.histories = {}

    -- For computing differences between successive measurements
    self.lastVelocities = {}    -- last recorded velocity for each entity
    self.lastAccelerations = {} -- last recorded acceleration for each entity
    self.lastJerks = {}         -- last recorded jerk for each entity
    self.lastSnaps = {}         -- last recorded snap for each entity
    self.lastPositions = {}     -- last recorded position for each entity

    -- (Optional) Last delta values
    self.lastDelta = {}

    -- Maximum number of history samples to store per entity (configurable)
    self.maxHistoryTicks = Config.advanced.maxPredictionHistory or 66 -- Default 66, range 7-198

    -- Table of Kalman filters for smoothing motion data
    self.kalmanFiltersDelta = {}
    self.kalmanFiltersAccel = {}
    self.kalmanFiltersJerk = {}
    self.kalmanFiltersSnap = {}

    -- Clear the global history table
    G.history = {}
end

--------------------------------------------------------------------------------
-- Compute sample standard deviation of a specific motion component
--------------------------------------------------------------------------------
local function computeStdDev(history, component)
    if not history or #history < 2 then
        return nil
    end

    local sum = 0
    local count = 0
    for _, data in ipairs(history) do
        if data[component] ~= nil then
            if type(data[component]) == "number" then
                sum = sum + data[component]
            else
                -- Vector component - use magnitude
                sum = sum + data[component]:Length()
            end
            count = count + 1
        end
    end

    if count < 2 then return nil end

    local mean = sum / count

    local varianceSum = 0
    for _, data in ipairs(history) do
        if data[component] ~= nil then
            local value = type(data[component]) == "number" and data[component] or data[component]:Length()
            local diff = value - mean
            varianceSum = varianceSum + diff * diff
        end
    end

    local sampleVariance = varianceSum / (count - 1)
    return math.sqrt(sampleVariance)
end

--------------------------------------------------------------------------------
-- Calculate predictability score based on motion consistency
-- Lower values = more predictable movement
--------------------------------------------------------------------------------
function HistoryHandler:calculatePredictabilityScore(entityIndex)
    local history = self.histories[entityIndex]
    if not history or #history < 4 then
        return 1.0 -- High unpredictability if insufficient data
    end

    -- Calculate variance for different motion components
    local strafeVariance = computeStdDev(history, "strafeDelta") or 0
    local accelVariance = computeStdDev(history, "acceleration") or 0
    local jerkVariance = computeStdDev(history, "jerk") or 0
    local snapVariance = computeStdDev(history, "snap") or 0
    local popVariance = computeStdDev(history, "pop") or 0

    -- Weighted combination - higher order derivatives indicate less predictable movement
    local predictabilityScore = (
        strafeVariance * 0.3 + -- 30% weight on strafe consistency
        accelVariance * 0.25 + -- 25% weight on acceleration consistency
        jerkVariance * 0.20 +  -- 20% weight on jerk consistency
        snapVariance * 0.15 +  -- 15% weight on snap consistency
        popVariance * 0.10     -- 10% weight on pop consistency
    )

    -- Normalize to 0-1 range (higher = less predictable)
    return math.min(predictabilityScore / 100.0, 1.0)
end

--------------------------------------------------------------------------------
-- Calculate dynamic measurement noise (R) using the sample variance.
--------------------------------------------------------------------------------
function HistoryHandler:calculateDynamicMeasurementNoise(entityIndex, component)
    local history = self.histories[entityIndex]
    if not history or #history < self.kalmanConfig.minimumHistoryCount then
        return self.kalmanConfig.baseMeasurementNoise
    end

    local stdDev = computeStdDev(history, component or "strafeDelta")
    if not stdDev then
        return self.kalmanConfig.baseMeasurementNoise
    end

    -- Measurement noise R = (stdDev)^2 + baseline noise.
    return (stdDev * stdDev) + self.kalmanConfig.baseMeasurementNoise
end

--------------------------------------------------------------------------------
-- Calculate dynamic process noise (Q) using the sample variance.
--------------------------------------------------------------------------------
function HistoryHandler:calculateDynamicProcessNoise(entityIndex, component)
    local history = self.histories[entityIndex]
    if not history or #history < self.kalmanConfig.minimumHistoryCount then
        return self.kalmanConfig.processNoise
    end

    local stdDev = computeStdDev(history, component or "strafeDelta")
    if not stdDev then
        return self.kalmanConfig.processNoise
    end

    -- Process noise Q = (stdDev)^2 + base process noise.
    return (stdDev * stdDev) + self.kalmanConfig.processNoise
end

--------------------------------------------------------------------------------
-- Generic Kalman update for any motion component
--------------------------------------------------------------------------------
function HistoryHandler:kalmanUpdate(entityIndex, measurement, component, filterTable)
    local filter = filterTable[entityIndex]
    if not filter then
        filter = {
            x = measurement,                            -- initial state
            p = 1,                                      -- initial error covariance
            q = self.kalmanConfig.processNoise,         -- process noise (will be updated dynamically)
            r = self.kalmanConfig.baseMeasurementNoise, -- measurement noise (updated dynamically)
            k = 0,                                      -- Kalman gain (to be computed)
        }
        filterTable[entityIndex] = filter
    end

    -- Update process and measurement noise dynamically
    filter.q = self:calculateDynamicProcessNoise(entityIndex, component)
    filter.r = self:calculateDynamicMeasurementNoise(entityIndex, component)

    -- Predict step: increase the error covariance
    filter.p = filter.p + filter.q

    -- Update step: compute Kalman gain, update the state, and reduce covariance
    filter.k = filter.p / (filter.p + filter.r)
    filter.x = filter.x + filter.k * (measurement - filter.x)
    filter.p = (1 - filter.k) * filter.p

    return filter.x
end

--------------------------------------------------------------------------------
-- Kalman update for strafeDelta (backward compatibility)
--------------------------------------------------------------------------------
function HistoryHandler:kalmanUpdateDelta(entityIndex, measurement)
    return self:kalmanUpdate(entityIndex, measurement, "strafeDelta", self.kalmanFiltersDelta)
end

--------------------------------------------------------------------------------
-- Retrieve weighted motion data for a given entity
--------------------------------------------------------------------------------
function HistoryHandler:getWeightedMotionData(entityIndex)
    local history = self.histories[entityIndex]
    if not history or #history == 0 then
        return {
            strafeDelta = 0,
            acceleration = Vector3(0, 0, 0),
            jerk = Vector3(0, 0, 0),
            predictabilityScore = 1.0
        }
    end

    local mostRecent = history[1]
    local weightedData = {
        strafeDelta = self:kalmanUpdateDelta(entityIndex, mostRecent.strafeDelta or 0),
        acceleration = mostRecent.acceleration or Vector3(0, 0, 0),
        jerk = mostRecent.jerk or Vector3(0, 0, 0),
        snap = mostRecent.snap or Vector3(0, 0, 0),
        pop = mostRecent.pop or Vector3(0, 0, 0),
        predictabilityScore = self:calculatePredictabilityScore(entityIndex)
    }

    -- Apply Kalman filtering to vector magnitudes for acceleration and jerk
    if mostRecent.acceleration then
        local accelMag = mostRecent.acceleration:Length()
        weightedData.accelerationMagnitude = self:kalmanUpdate(entityIndex, accelMag, "acceleration",
            self.kalmanFiltersAccel)
    end

    if mostRecent.jerk then
        local jerkMag = mostRecent.jerk:Length()
        weightedData.jerkMagnitude = self:kalmanUpdate(entityIndex, jerkMag, "jerk", self.kalmanFiltersJerk)
    end

    return weightedData
end

--------------------------------------------------------------------------------
-- Retrieve a weighted (smoothed) strafe delta for a given entity (backward compatibility)
--------------------------------------------------------------------------------
function HistoryHandler:getWeightedStrafeDelta(entityIndex)
    local motionData = self:getWeightedMotionData(entityIndex)
    return motionData.strafeDelta
end

--------------------------------------------------------------------------------
-- Check if a player is a valid target for history tracking.
--------------------------------------------------------------------------------
function HistoryHandler:isValidTarget(player)
    return player and player:IsAlive() and not player:IsDormant()
end

--------------------------------------------------------------------------------
-- Update history for all valid targets with comprehensive motion tracking
--------------------------------------------------------------------------------
function HistoryHandler:update()
    local FastPlayers = require("PAimbot.Modules.Helpers.FastPlayers")
    -- MAJOR OPTIMIZATION: Only process enemies, not all players
    local players = FastPlayers.GetEnemies()
    local currentTime = globals.RealTime()

    for _, player in pairs(players) do
        local playerRaw = player._rawEntity
        if self:isValidTarget(playerRaw) then
            local entityIndex = playerRaw:GetIndex()

            -- Get current motion data
            local currentPos = playerRaw:GetAbsOrigin()
            local currentVel = playerRaw:EstimateAbsVelocity()

            -- Initialize tracking data if not present
            if not self.lastPositions[entityIndex] then
                self.lastPositions[entityIndex] = currentPos
                self.lastVelocities[entityIndex] = currentVel
                self.lastAccelerations[entityIndex] = Vector3(0, 0, 0)
                self.lastJerks[entityIndex] = Vector3(0, 0, 0)
                self.lastSnaps[entityIndex] = Vector3(0, 0, 0)
                goto continue
            end

            -- Calculate only basic motion data for performance
            local dt = globals.TickInterval()

            -- Calculate acceleration (change in velocity)
            local acceleration = (currentVel - self.lastVelocities[entityIndex]) / dt

            -- SIMPLIFIED: Only calculate jerk, skip snap and pop for performance
            local jerk = (acceleration - self.lastAccelerations[entityIndex]) / dt

            -- Calculate strafe delta (change in velocity angle) - simplified
            local strafeDelta = 0
            if currentVel:Length() > 10 and self.lastVelocities[entityIndex]:Length() > 10 then
                local currentAngle = currentVel:Angles().y
                local lastAngle = self.lastVelocities[entityIndex]:Angles().y
                strafeDelta = currentAngle - lastAngle

                -- Normalize strafe delta to [-180, 180]
                while strafeDelta > 180 do strafeDelta = strafeDelta - 360 end
                while strafeDelta < -180 do strafeDelta = strafeDelta + 360 end
            end

            -- Create simplified motion data sample
            local motionSample = {
                strafeDelta = strafeDelta,
                velocity = currentVel,
                acceleration = acceleration,
                jerk = jerk,
                timestamp = currentTime,
                position = currentPos
            }

            -- Insert the new sample at the beginning of the history
            self.histories[entityIndex] = self.histories[entityIndex] or {}
            table.insert(self.histories[entityIndex], 1, motionSample)

            -- Trim history to max length
            if #self.histories[entityIndex] > self.maxHistoryTicks then
                table.remove(self.histories[entityIndex])
            end

            -- Update last values for next iteration
            self.lastPositions[entityIndex] = currentPos
            self.lastVelocities[entityIndex] = currentVel
            self.lastAccelerations[entityIndex] = acceleration
            self.lastJerks[entityIndex] = jerk
            -- Skip snap update for performance

            -- Get simplified motion data and store in global history
            local weightedMotion = self:getSimplifiedMotionData(entityIndex)
            G.history[entityIndex] = weightedMotion

            ::continue::
        end
    end
end

--------------------------------------------------------------------------------
-- Retrieve simplified motion data for a given entity (performance optimized)
--------------------------------------------------------------------------------
function HistoryHandler:getSimplifiedMotionData(entityIndex)
    local history = self.histories[entityIndex]
    if not history or #history == 0 then
        return {
            strafeDelta = 0,
            acceleration = Vector3(0, 0, 0),
            jerk = Vector3(0, 0, 0),
            predictabilityScore = 1.0
        }
    end

    local mostRecent = history[1]

    -- SIMPLIFIED: Skip expensive Kalman filtering for performance
    local weightedData = {
        strafeDelta = mostRecent.strafeDelta or 0,
        acceleration = mostRecent.acceleration or Vector3(0, 0, 0),
        jerk = mostRecent.jerk or Vector3(0, 0, 0),
        snap = mostRecent.snap or Vector3(0, 0, 0),
        predictabilityScore = self:getSimplePredictabilityScore(entityIndex)
    }

    return weightedData
end

--------------------------------------------------------------------------------
-- Simplified predictability score calculation (performance optimized)
--------------------------------------------------------------------------------
function HistoryHandler:getSimplePredictabilityScore(entityIndex)
    local history = self.histories[entityIndex]
    if not history or #history < 3 then
        return 1.0 -- High unpredictability if insufficient data
    end

    -- Use more samples for stable analysis (up to 50 samples instead of 5)
    local recentSamples = math.min(#history, 50) -- Check up to 50 samples for stability
    local strafeDeltaSum = 0
    local accelSum = 0
    local jerkSum = 0

    for i = 1, recentSamples do
        local sample = history[i]
        if sample then
            if sample.strafeDelta then
                strafeDeltaSum = strafeDeltaSum + math.abs(sample.strafeDelta)
            end
            if sample.acceleration then
                accelSum = accelSum + sample.acceleration:Length()
            end
            if sample.jerk then
                jerkSum = jerkSum + sample.jerk:Length()
            end
        end
    end

    local avgStrafeDelta = strafeDeltaSum / recentSamples
    local avgAccel = accelSum / recentSamples
    local avgJerk = jerkSum / recentSamples

    -- Combined predictability score using multiple motion components
    local predictabilityScore = (
        math.min(avgStrafeDelta / 45.0, 1.0) * 0.4 + -- Strafe: 40%
        math.min(avgAccel / 200.0, 1.0) * 0.35 +     -- Acceleration: 35%
        math.min(avgJerk / 500.0, 1.0) * 0.25        -- Jerk: 25%
    )

    return predictabilityScore
end

--------------------------------------------------------------------------------
-- On-demand derivative helpers (lightweight)
--------------------------------------------------------------------------------

-- Return the most recent N motion samples for an entity (up to requested count)
local function getRecentSamples(self, entityIndex, count)
    local hist = self.histories[entityIndex]
    if not hist then return nil end
    local samples = {}
    for i = 1, math.min(count, #hist) do
        samples[i] = hist[i]
    end
    return samples
end

-- Get current velocity (most recent sample or EstimateAbsVelocity fallback)
function HistoryHandler:getVelocity(player)
    if not player then return Vector3(0, 0, 0) end
    local idx = player:GetIndex()
    local hist = self.histories[idx]
    if hist and hist[1] and hist[1].velocity then
        return hist[1].velocity
    end
    return player:EstimateAbsVelocity()
end

-- Compute acceleration from last 2 velocity samples
function HistoryHandler:getAcceleration(player)
    if not player then return Vector3(0, 0, 0) end
    local idx = player:GetIndex()
    local samples = getRecentSamples(self, idx, 2)
    if not samples or #samples < 2 then
        return Vector3(0, 0, 0)
    end
    local v2 = samples[1].velocity
    local v1 = samples[2].velocity
    local dt = globals.TickInterval()
    if dt <= 0 then return Vector3(0, 0, 0) end
    return (v2 - v1) / dt
end

-- Compute jerk from last 3 velocity samples (or 2 accelerations)
function HistoryHandler:getJerk(player)
    if not player then return Vector3(0, 0, 0) end
    local idx = player:GetIndex()
    local samples = getRecentSamples(self, idx, 3)
    if not samples or #samples < 3 then
        return Vector3(0, 0, 0)
    end
    local v3 = samples[1].velocity
    local v2 = samples[2].velocity
    local v1 = samples[3].velocity
    local dt = globals.TickInterval()
    if dt <= 0 then return Vector3(0, 0, 0) end
    local a2 = (v3 - v2) / dt
    local a1 = (v2 - v1) / dt
    return (a2 - a1) / dt
end

-- Compute snap from last 4 jerk samples (or 3 snaps)
function HistoryHandler:getSnap(player)
    if not player then return Vector3(0, 0, 0) end
    local idx = player:GetIndex()
    local samples = getRecentSamples(self, idx, 4) -- need at least 4 samples for snap
    if not samples or #samples < 4 then
        return Vector3(0, 0, 0)
    end
    local j4 = samples[1].jerk or Vector3(0, 0, 0)
    local j3 = samples[2].jerk or Vector3(0, 0, 0)
    local dt = globals.TickInterval()
    if dt <= 0 then return Vector3(0, 0, 0) end
    return (j4 - j3) / dt
end

-- Compute simple strafe delta (change in yaw between last 2 velocity vectors)
function HistoryHandler:getStrafeDelta(player)
    if not player then return 0 end
    local idx = player:GetIndex()
    local samples = getRecentSamples(self, idx, 2)
    if not samples or #samples < 2 then
        return 0
    end
    local v2 = samples[1].velocity
    local v1 = samples[2].velocity
    if v2:Length() < 10 or v1:Length() < 10 then return 0 end
    local yaw2 = v2:Angles().y
    local yaw1 = v1:Angles().y
    local delta = yaw2 - yaw1
    while delta > 180 do delta = delta - 360 end
    while delta < -180 do delta = delta + 360 end
    return delta
end

-- Convenience: return table of derivatives for a player
function HistoryHandler:getDerivatives(player)
    return {
        velocity = self:getVelocity(player),
        acceleration = self:getAcceleration(player),
        jerk = self:getJerk(player),
        snap = (function()
            local snapVec = self:getSnap(player)
            if snapVec:LengthSqr() == 0 then return snapVec end
            local idx = player:GetIndex()
            -- Smooth magnitude via Kalman filter
            local rawMag = snapVec:Length()
            local smoothMag = self:kalmanUpdate(idx, rawMag, "snap", self.kalmanFiltersSnap)
            if smoothMag <= 0 then return Vector3(0, 0, 0) end
            local dir = Common.Normalize(snapVec)
            return dir * smoothMag
        end)(),
        strafeDelta = self:getStrafeDelta(player),
    }
end

--------------------------------------------------------------------------------
-- Update the maximum history length from config
--------------------------------------------------------------------------------
function HistoryHandler:updateMaxHistoryFromConfig()
    local Config = require("PAimbot.Config")
    local newMaxHistory = Config.advanced.maxPredictionHistory or 66
    -- Clamp to valid range (7-198)
    self.maxHistoryTicks = math.max(7, math.min(198, newMaxHistory))
end

--------------------------------------------------------------------------------
-- Update history for specific targets (called by BestTarget.UpdateHistory)
--------------------------------------------------------------------------------
function HistoryHandler:updateTarget(player)
    if not self:isValidTarget(player) then
        return
    end

    -- Update max history from config (in case it changed)
    self:updateMaxHistoryFromConfig()

    local entityIndex = player:GetIndex()
    local currentTick = globals.TickCount()

    -- Get current motion data
    local currentPos = player:GetAbsOrigin()
    local currentVel = player:EstimateAbsVelocity()

    -- Initialize tracking data if not present
    if not self.lastPositions[entityIndex] then
        self.lastPositions[entityIndex] = currentPos
        self.lastVelocities[entityIndex] = currentVel
        self.lastAccelerations[entityIndex] = Vector3(0, 0, 0)
        self.lastJerks[entityIndex] = Vector3(0, 0, 0)
        self.lastSnaps[entityIndex] = Vector3(0, 0, 0)
        return
    end

    -- Calculate only basic motion data for performance
    local dt = globals.TickInterval()

    -- Calculate acceleration (change in velocity)
    local acceleration = (currentVel - self.lastVelocities[entityIndex]) / dt

    -- SIMPLIFIED: Only calculate jerk, skip snap and pop for performance
    local jerk = (acceleration - self.lastAccelerations[entityIndex]) / dt

    -- NEW: calculate snap (change in jerk)
    local snap = (jerk - self.lastJerks[entityIndex]) / dt

    -- Calculate strafe delta (change in velocity angle) - simplified
    local strafeDelta = 0
    if currentVel:Length() > 10 and self.lastVelocities[entityIndex]:Length() > 10 then
        local currentAngle = currentVel:Angles().y
        local lastAngle = self.lastVelocities[entityIndex]:Angles().y
        strafeDelta = currentAngle - lastAngle

        -- Normalize strafe delta to [-180, 180]
        while strafeDelta > 180 do strafeDelta = strafeDelta - 360 end
        while strafeDelta < -180 do strafeDelta = strafeDelta + 360 end
    end

    -- Create simplified motion data sample with TICK COUNT (not time)
    local motionSample = {
        strafeDelta = strafeDelta,
        velocity = currentVel,
        acceleration = acceleration,
        jerk = jerk,
        snap = snap,
        tick = currentTick, -- Store by tick count, not time
        position = currentPos
    }

    -- Insert the new sample at the beginning of the history
    self.histories[entityIndex] = self.histories[entityIndex] or {}
    table.insert(self.histories[entityIndex], 1, motionSample)

    -- Trim history to max length (by tick count limit, not time)
    if #self.histories[entityIndex] > self.maxHistoryTicks then
        table.remove(self.histories[entityIndex])
    end

    -- Update last values for next iteration
    self.lastPositions[entityIndex] = currentPos
    self.lastVelocities[entityIndex] = currentVel
    self.lastAccelerations[entityIndex] = acceleration
    self.lastJerks[entityIndex] = jerk
    self.lastSnaps[entityIndex] = snap

    -- Get simplified motion data and store in global history
    local weightedMotion = self:getSimplifiedMotionData(entityIndex)
    G.history[entityIndex] = weightedMotion
end

--------------------------------------------------------------------------------
-- Clear history for a specific target
--------------------------------------------------------------------------------
function HistoryHandler:clearTarget(player)
    local entityIndex = player:GetIndex()

    -- Clear all tracking data for this target
    self.histories[entityIndex] = nil
    self.lastPositions[entityIndex] = nil
    self.lastVelocities[entityIndex] = nil
    self.lastAccelerations[entityIndex] = nil
    self.lastJerks[entityIndex] = nil
    self.lastSnaps[entityIndex] = nil

    -- Clear Kalman filters
    self.kalmanFiltersDelta[entityIndex] = nil
    self.kalmanFiltersAccel[entityIndex] = nil
    self.kalmanFiltersJerk[entityIndex] = nil
    self.kalmanFiltersSnap[entityIndex] = nil

    -- Clear global history
    G.history[entityIndex] = nil
end

--------------------------------------------------------------------------------
-- NEW: Update history for ALL players each tick (including local player)
--------------------------------------------------------------------------------
function HistoryHandler:updateAll()
    local FastPlayers = require("PAimbot.Modules.Helpers.FastPlayers")
    local players = FastPlayers.GetAll() -- includes local and enemies/teammates

    local me = FastPlayers.GetLocal()

    -- Update history for everyone (but still respect validity checks inside updateTarget)
    for _, player in pairs(players) do
        -- Skip invalid players early
        if player and player:IsAlive() and not player:IsDormant() then
            -- Avoid processing too many players if the config limits tracked targets
            -- Local player is always updated; others limited via config in updateTarget
            self:updateTarget(player)
        end
    end
end

--------------------------------------------------------------------------------
-- Register a per-tick callback to gather basic motion history for all players
--------------------------------------------------------------------------------
callbacks.Unregister("CreateMove", "HistoryHandler_UpdateAll")
callbacks.Register("CreateMove", "HistoryHandler_UpdateAll", function()
    historyHandlerInstance:updateAll()
end)

--------------------------------------------------------------------------------
-- Create and return the singleton instance.
--------------------------------------------------------------------------------
historyHandlerInstance = setmetatable({}, HistoryHandler)
historyHandlerInstance:init()

return historyHandlerInstance

end)
__bundle_register("PAimbot.Modules.Helpers.VariableUpdater", function(require, _LOADED, __bundle_register, __bundle_modules)
local G = require("PAimbot.Globals")

-- Fill the tables
local function D(x) return x, x end
for i = 1, 10 do G.KeyNames[i], G.KeyValues[i] = D(tostring(i - 1)) end -- 0 - 9
for i = KEY_A, KEY_Z do G.KeyNames[i], G.KeyValues[i] = D(string.char(i + 54)) end -- A - Z
for i = KEY_PAD_0, KEY_PAD_9 do G.KeyNames[i], G.KeyValues[i] = "KP_" .. (i - 37), tostring(i - 37) end -- KP_0 - KP_9
for i = 92, 103 do G.KeyNames[i] = "F" .. (i - 91) end
for i = 1, 10 do local mouseButtonName = "MOUSE_" .. i G.KeyNames[MOUSE_FIRST + i - 1] = mouseButtonName G.KeyValues[MOUSE_FIRST + i - 1] = "Mouse Button " .. i end

local function UpdateVariables()
    -- Update the variables
    G.TickCount = globals.TickCount()
    G.TickInterval = globals.TickInterval()

    if not G.Target then return end
end

local function UpdateVariablesSlow()
    G.StepUp = Vector3(0, 0, entities.GetLocalPlayer():GetPropFloat("localdata", "m_flStepSize"))
    G.gravity = client.GetConVar("sv_gravity") -- Example G.gravity value, adjust as needed
end

-- Register the drawing callback for rendering the trajectory
callbacks.Unregister("CreateMove", G.scriptName .. "_UpdateVariables")
-- Register the drawing callback for rendering the trajectory
callbacks.Register("CreateMove", G.scriptName .. "_UpdateVariables", UpdateVariables)

-- Register the drawing callback for rendering the trajectory
callbacks.Unregister("FireGameEvent", G.scriptName .. "_UpdateVariablesSlow")
-- Register the drawing callback for rendering the trajectory
callbacks.Register("FireGameEvent", G.scriptName .. "_UpdateVariablesSlow", UpdateVariablesSlow)

end)
__bundle_register("PAimbot.Modules.Helpers.BestTarget", function(require, _LOADED, __bundle_register, __bundle_modules)
local BestTarget = {}

local Common = require("PAimbot.Common")
local Config = require("PAimbot.Config")
local FastPlayers = require("PAimbot.Modules.Helpers.FastPlayers")

local G = require("PAimbot.Globals")
local eyeOffset = Vector3(0, 0, 75)
local WPlayer = Common.WPlayer

-- Utility function to check if a table contains a specific value
local function TableContains(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

-- Checks if a player should be considered as a valid target
local function IsValidTarget(me, player)
    -- Check if gui.GetValue exists and is callable, otherwise default to 0
    local ignoreCloaked = 0
    if gui and gui.GetValue and type(gui.GetValue) == "function" then
        ignoreCloaked = gui.GetValue("ignore cloaked") or 0
    end

    return player and player:IsAlive()
        and not player:IsDormant()
        and player ~= me
        and (ignoreCloaked == 0 or not player:InCond(4))
end

-- Logarithmic scaling for distance
local function LogarithmicDistanceFactor(distance)
    return math.log(distance + 1) -- Ensures we don't hit log(0)
end

-- Sophisticated target scoring with health, visibility priority, and movement predictability
local function CalculateTargetFactor(player, localPlayerOrigin, localPlayerViewAngles)
    local playerOrigin = player:GetAbsOrigin()
    local distance = (playerOrigin - localPlayerOrigin):Length2D()

    local angles = Common.Math.PositionAngles(localPlayerOrigin, playerOrigin)
    local fov = Common.Math.AngleFov(angles, localPlayerViewAngles)

    if fov > Config.main.aimfov then
        return 0
    end

    -- Distance factor (closer is better, but not too close)
    local distanceFactor = Common.Math.RemapValClamped(distance,
        Config.main.minDistance or 100,
        Config.main.maxDistance or 3000,
        1.0, 0.1)

    -- FOV factor (smaller FOV is much better)
    local fovFactor = Common.Math.RemapValClamped(fov, 0, Config.main.aimfov, 1.0, 0.3)

    -- Visibility check
    local isVisible = Common.Helpers.VisPos(player, localPlayerOrigin + eyeOffset, playerOrigin + eyeOffset)

    -- Targeting mode handling
    local visibilityFactor = 1.0
    if Config.advanced.targetingMode.legit then
        -- Legit mode: Only target visible enemies
        if not isVisible then
            return 0 -- Completely exclude invisible targets in legit mode
        end
        visibilityFactor = 1.0
    else
        -- Blatant mode: Allow hidden targets but prefer visible ones
        visibilityFactor = isVisible and 1.0 or 0.3 -- 70% penalty for hidden targets
    end

    -- Health factor (lower health = higher priority)
    local health = player:GetHealth()
    local maxHealth = player:GetMaxHealth()
    local healthFactor = Common.Math.RemapValClamped(health, 0, maxHealth, 1.2, 0.8)

    -- Movement predictability from history (if available)
    local predictabilityFactor = 1.0
    local playerIndex = player:GetIndex()
    if G.predictionDelta[playerIndex] and G.predictionDelta[playerIndex].entropy then
        local entropy = G.predictionDelta[playerIndex].entropy
        local trustFactor = G.predictionDelta[playerIndex].trustFactor or 0.0

        -- Only apply entropy penalty when we have sufficient trust in the data
        local entropyPenalty = entropy * (0.1 + trustFactor * 0.2) -- 0.1-0.3 penalty based on trust
        predictabilityFactor = 1.0 - entropyPenalty

        -- Bonus for high trust factor (reliable data)
        local trustBonus = trustFactor * 0.1
        predictabilityFactor = predictabilityFactor + trustBonus
    end

    -- Combine factors with weighting (removed hitchance factor)
    local totalFactor = (distanceFactor * 0.25 + -- Distance: 25%
        fovFactor * 0.40 +                       -- FOV: 40%
        visibilityFactor * 0.25 +                -- Visibility: 25%
        healthFactor * 0.05 +                    -- Health: 5%
        predictabilityFactor * 0.05)             -- Predictability: 5%

    return totalFactor
end

-- Main function to find the best target (backward compatible)
function BestTarget.Get()
    local me = FastPlayers.GetLocal()
    if not me then return nil end

    local players = FastPlayers.GetEnemies()
    local bestTarget = nil
    local bestFactor = 0
    local localPlayerOrigin = me:GetAbsOrigin()
    local localPlayerViewAngles = engine.GetViewAngles()

    for _, player in pairs(players) do
        if IsValidTarget(me, player) then
            local factor = CalculateTargetFactor(player, localPlayerOrigin, localPlayerViewAngles)
            if factor > bestFactor then
                bestTarget = player
                bestFactor = factor
            end
        end
    end

    G.Target = bestTarget --visuals and updater data
    return bestTarget
end

-- Advanced entropy calculation with trust factor based on history depth
local function CalculateAdvancedEntropy(player)
    local playerIndex = player:GetIndex()
    if not G.predictionDelta[playerIndex] or not G.predictionDelta[playerIndex].history then
        return { entropy = 0.7, trustFactor = 0.0, samples = 0 } -- Default high entropy, no trust
    end

    local history = G.predictionDelta[playerIndex].history
    local historySize = #history

    if historySize < 3 then
        return { entropy = 0.7, trustFactor = 0.1, samples = historySize }
    end

    -- Use more history for better fidelity (up to 30 frames for very high trust)
    local maxSamples = math.min(historySize, 30)
    local minSamples = math.max(3, maxSamples)

    -- Calculate multiple entropy metrics
    local velocityDeltas = {}
    local angleDeltas = {}
    local accelerationDeltas = {}
    local strafeConsistency = {}

    for i = 2, minSamples do
        local prev = history[i - 1]
        local curr = history[i]

        if prev.velocity and curr.velocity then
            -- Velocity delta (speed changes)
            local velDelta = (curr.velocity - prev.velocity):Length()
            table.insert(velocityDeltas, velDelta)

            -- Acceleration delta (rate of speed change)
            if i > 2 and history[i - 2].velocity then
                local prevVelDelta = (prev.velocity - history[i - 2].velocity):Length()
                local accelDelta = math.abs(velDelta - prevVelDelta)
                table.insert(accelerationDeltas, accelDelta)
            end

            -- Strafe consistency (how consistent is their strafing)
            local currSpeed = curr.velocity:Length2D()
            local prevSpeed = prev.velocity:Length2D()
            if currSpeed > 50 and prevSpeed > 50 then -- Only when actually moving
                local strafeChange = math.abs(currSpeed - prevSpeed) / math.max(currSpeed, prevSpeed)
                table.insert(strafeConsistency, strafeChange)
            end
        end

        if prev.viewAngle and curr.viewAngle then
            -- View angle entropy (mouse movement patterns)
            local yawDelta = math.abs(Common.Math.AngleDifference(curr.viewAngle.y, prev.viewAngle.y))
            local pitchDelta = math.abs(Common.Math.AngleDifference(curr.viewAngle.x, prev.viewAngle.x)) * 0.3
            table.insert(angleDeltas, yawDelta + pitchDelta)
        end
    end

    -- Enhanced standard deviation calculation with outlier detection
    local function calculateAdvancedStdDev(values)
        if #values < 2 then return 0 end

        -- Calculate mean
        local mean = 0
        for _, v in ipairs(values) do
            mean = mean + v
        end
        mean = mean / #values

        -- Calculate variance, but weight recent samples more heavily
        local weightedVariance = 0
        local totalWeight = 0
        for i, v in ipairs(values) do
            local weight = i / #values -- Recent samples get higher weight
            local deviation = (v - mean) ^ 2
            weightedVariance = weightedVariance + (deviation * weight)
            totalWeight = totalWeight + weight
        end
        weightedVariance = weightedVariance / totalWeight

        return math.sqrt(weightedVariance)
    end

    -- Calculate individual entropy components
    local velEntropy = calculateAdvancedStdDev(velocityDeltas) / 150       -- Normalized
    local angleEntropy = calculateAdvancedStdDev(angleDeltas) / 60         -- Normalized
    local accelEntropy = calculateAdvancedStdDev(accelerationDeltas) / 100 -- Normalized
    local strafeEntropy = calculateAdvancedStdDev(strafeConsistency)       -- Already normalized 0-1

    -- Combine entropies with sophisticated weighting
    local combinedEntropy = (
        velEntropy * 0.35 +   -- Movement speed changes: 35%
        angleEntropy * 0.30 + -- View angle changes: 30%
        accelEntropy * 0.20 + -- Acceleration patterns: 20%
        strafeEntropy * 0.15  -- Strafe consistency: 15%
    )

    -- Clamp entropy to reasonable bounds
    combinedEntropy = Common.clamp(combinedEntropy, 0.0, 1.0)

    -- Trust factor based on sample size (more samples = higher trust)
    -- Exponential curve: starts low, rises quickly, then plateaus
    local trustFactor = 1.0 - math.exp(-historySize / 12.0) -- 63% trust at 12 samples, 95% at 36 samples
    trustFactor = Common.clamp(trustFactor, 0.0, 1.0)

    return {
        entropy = combinedEntropy,
        trustFactor = trustFactor,
        samples = historySize,
        components = {
            velocity = velEntropy,
            angle = angleEntropy,
            acceleration = accelEntropy,
            strafe = strafeEntropy
        }
    }
end

-- Advanced hit chance calculation with trust factor scaling
function BestTarget.CalculateHitChance(player, predictionTicks)
    local playerIndex = player:GetIndex()

    -- Calculate advanced entropy with trust factor
    local entropyData = CalculateAdvancedEntropy(player)

    -- Store entropy data for target selection
    if not G.predictionDelta[playerIndex] then
        G.predictionDelta[playerIndex] = {}
    end
    G.predictionDelta[playerIndex].entropy = entropyData.entropy
    G.predictionDelta[playerIndex].trustFactor = entropyData.trustFactor
    G.predictionDelta[playerIndex].samples = entropyData.samples

    -- Base hit chance - scaled by trust factor
    local baseHitChance = 60 + (entropyData.trustFactor * 20) -- 60-80 based on trust

    -- Distance factor
    local me = entities.GetLocalPlayer()
    local distance = me and (player:GetAbsOrigin() - me:GetAbsOrigin()):Length() or 1000
    local distanceFactor = Common.Math.RemapValClamped(distance, 100, 2000, 15, -10)

    -- Visibility factor
    local eyeOffset = Vector3(0, 0, 75)
    local isVisible = me and
        Common.Helpers.VisPos(player, me:GetAbsOrigin() + eyeOffset, player:GetAbsOrigin() + eyeOffset)
    local visibilityBonus = isVisible and 15 or -20

    -- FOV factor
    if me then
        local angles = Common.Math.PositionAngles(me:GetAbsOrigin(), player:GetAbsOrigin())
        local fov = Common.Math.AngleFov(angles, engine.GetViewAngles())
        local fovBonus = Common.Math.RemapValClamped(fov, 0, Config.main.aimfov or 60, 15, -10)

        -- Entropy penalty - scaled by trust factor (more trust = more reliable entropy)
        local entropyPenalty = entropyData.entropy * (20 + entropyData.trustFactor * 15)

        -- Prediction time penalty (longer prediction = less accurate)
        local predictionPenalty = (predictionTicks or 0) * 0.15

        -- Trust bonus - reward high sample counts
        local trustBonus = entropyData.trustFactor * 10

        -- Sample count bonus - immediate benefit from more data
        local sampleBonus = Common.Math.RemapValClamped(entropyData.samples, 3, 30, 0, 8)

        local finalHitChance = baseHitChance + distanceFactor + visibilityBonus + fovBonus + trustBonus + sampleBonus -
            entropyPenalty - predictionPenalty

        -- Ensure minimum hit chance scales with trust (low trust = lower minimum)
        local minHitChance = 5 + (entropyData.trustFactor * 15) -- 5-20 based on trust
        local maxHitChance = 95

        return Common.clamp(finalHitChance, minHitChance, maxHitChance)
    end

    return 30 -- Default if no local player
end

-- Enhanced history update for configurable number of targets (4-8)
function BestTarget.UpdateHistory(me)
    local HistoryHandler = require("PAimbot.Modules.Prediction.HistoryHandler")
    local players = FastPlayers.GetEnemies()
    local localPlayerOrigin = me:GetAbsOrigin()
    local topTargets = {}

    -- Get max targets from config (4-8)
    local maxTargets = Config.advanced.maxTrackedTargets or 8
    maxTargets = Common.clamp(maxTargets, 4, 8)

    -- Iterate through all players to determine valid targets
    for _, player in pairs(players) do
        if IsValidTarget(me, player) then
            local factor = CalculateTargetFactor(player, localPlayerOrigin, engine.GetViewAngles())
            table.insert(topTargets, { player = player, factor = factor })
        end
    end

    -- Sort targets based on their calculated factor (descending)
    table.sort(topTargets, function(a, b) return a.factor > b.factor end)

    -- Keep only the top N targets
    while #topTargets > maxTargets do
        table.remove(topTargets)
    end

    -- Get the list of top players for clearing
    local topPlayerIndices = {}
    for _, target in ipairs(topTargets) do
        local player = target.player
        local playerIndex = player:GetIndex()
        topPlayerIndices[playerIndex] = true

        -- Update the history for this specific target using the new method
        HistoryHandler:updateTarget(player)
    end

    -- Clear history for any player not in the top targets
    for _, player in pairs(players) do
        local playerIndex = player:GetIndex()
        if not topPlayerIndices[playerIndex] then
            -- Clear history for non-tracked players using the new method
            HistoryHandler:clearTarget(player)

            -- Clear prediction data for non-tracked players
            if G.predictionDelta[playerIndex] then
                G.predictionDelta[playerIndex] = nil
            end
        end
    end

    -- Return the top players for reference
    local topPlayers = {}
    for _, target in ipairs(topTargets) do
        table.insert(topPlayers, target.player:GetIndex())
    end
    return topPlayers
end

-- Function to get top N best targets (for optimized prediction)
function BestTarget.GetTopTargets(maxTargets)
    local me = FastPlayers.GetLocal()
    if not me then return {} end

    local players = FastPlayers.GetEnemies()
    local targets = {}
    local localPlayerOrigin = me:GetAbsOrigin()
    local localPlayerViewAngles = engine.GetViewAngles()

    for _, player in pairs(players) do
        if IsValidTarget(me, player) then
            local factor = CalculateTargetFactor(player, localPlayerOrigin, localPlayerViewAngles)
            if factor > 0 then
                table.insert(targets, { player = player, factor = factor })
            end
        end
    end

    -- Sort targets by factor (best first)
    table.sort(targets, function(a, b) return a.factor > b.factor end)

    -- Return only the top N targets
    local topTargets = {}
    for i = 1, math.min(maxTargets, #targets) do
        table.insert(topTargets, targets[i].player)
    end

    return topTargets
end

return BestTarget

end)
return __bundle_require("__root")