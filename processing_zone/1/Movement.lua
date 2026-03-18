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
--[[
    Movement lua - Improved with smart jump types and glide step
        -smartjump with minimal height selection
        -glide step mechanic for efficient climbing
    Author: Titaniummachine1
]]

--[[ Activate the script Modules ]]
local Common = require("Movement.Common")
local G = require("Movement.Globals")
require("Movement.Config")
require("Movement.Visuals")                             -- wake up the visuals
require("Movement.Menu")                                -- wake up the menu
local SmartJump = require("Movement.Modules.SmartJump") -- Import the improved SmartJump module
local Recorder = require("Movement.Modules.Recorder")   -- Import the Recorder module

-- Add new globals for improved jumping
G.selectedJumpType = nil
G.useGlideStep = false
G.jumpPhase = 0

local function OnCreateMove(cmd)
    -- Get the local player
    G.pLocal = entities.GetLocalPlayer()
    local WLocal = Common.WPlayer.GetLocal()
    if not G.pLocal then return end
    G.playerMins = G.pLocal:GetMins()
    G.playerMaxs = G.pLocal:GetMaxs()

    -- Check if the local player is valid and alive
    if not G.Menu.Enable or not G.pLocal or not G.pLocal:IsAlive() or not WLocal then
        G.jumpState = G.STATE_IDLE -- Reset state if player is not valid or alive
        return
    end

    -- Cache player flags
    G.onGround = Common.isPlayerOnGround(G.pLocal)
    G.Ducking = Common.isPlayerDucking(G.pLocal)

    -- Calculate the strafe angle
    G.strafeAngle = Common.CalcStrafe(WLocal)

    -- Fix the hitbox based on ducking state
    -- No need to manually set hitbox z, use mins/maxs from player entity

    -- Enhanced state machine for different jump types
    if G.jumpState == G.STATE_IDLE then
        -- STATE_IDLE: Waiting for jump commands.
        SmartJump.Execute(cmd) -- Execute smartjump logic which sets G.ShouldJump

        if G.onGround and G.ShouldJump then
            -- Determine which state to transition to based on jump type
            if G.selectedJumpType and G.selectedJumpType.name == "NORMAL" then
                G.jumpState = G.STATE_NORMAL_JUMP  -- Direct jump for normal jumps
            else
                G.jumpState = G.STATE_PREPARE_JUMP -- Preparation needed for other jump types
            end
            G.jumpPhase = 0                        -- Reset jump phase
            G.ShouldJump = false                   -- Reset the flag
        end
    elseif G.jumpState == G.STATE_NORMAL_JUMP then
        -- STATE_NORMAL_JUMP: Execute normal jump without preparation
        SmartJump.ExecuteJumpType(cmd, G.selectedJumpType)
        G.jumpState = G.STATE_ASCENDING -- Transition directly to ascending
        return
    elseif G.jumpState == G.STATE_PREPARE_JUMP then
        -- STATE_PREPARE_JUMP: Prepare for jump based on type
        local jumpResult = SmartJump.ExecuteJumpType(cmd, G.selectedJumpType)

        if jumpResult == "CTAP_PHASE1" or jumpResult == "DUCK_PHASE1" or jumpResult == "CROUCH_HOP_PHASE1" then
            G.jumpState = G.STATE_CTAP -- Move to execution phase
        elseif jumpResult == "NORMAL_JUMP" then
            G.jumpState = G.STATE_ASCENDING
        end
        return
    elseif G.jumpState == G.STATE_CTAP then
        -- STATE_CTAP: Execute the jump
        local jumpResult = SmartJump.ExecuteJumpType(cmd, G.selectedJumpType)

        if jumpResult == "CTAP_PHASE2" or jumpResult == "DUCK_PHASE2" or jumpResult == "CROUCH_HOP_PHASE2" then
            G.jumpState = G.STATE_ASCENDING -- Transition to ascending state
        end
        return
    elseif G.jumpState == G.STATE_ASCENDING then
        -- STATE_ASCENDING: Player is moving upward.
        local velocity = G.pLocal:EstimateAbsVelocity()

        -- Handle glide step during ascent if enabled
        if G.useGlideStep and SmartJump.HandleGlideStep(cmd) then
            -- Glide step handled, maintain current state
        elseif G.selectedJumpType and (G.selectedJumpType.name == "DUCK" or G.selectedJumpType.name == "CROUCH_HOP") then
            -- Maintain crouch for duck jumps and crouch hops
            cmd:SetButtons(cmd.buttons | IN_DUCK)
        end

        -- Transition when upward velocity stops or we start falling
        if velocity.z <= 0 then
            if G.useGlideStep then
                G.jumpState = G.STATE_GLIDE_STEP
            else
                G.jumpState = G.STATE_DESCENDING
            end
        end
        return
    elseif G.jumpState == G.STATE_GLIDE_STEP then
        -- STATE_GLIDE_STEP: Special state for glide stepping
        local handled = SmartJump.HandleGlideStep(cmd)

        if not handled then
            -- If glide step is no longer applicable, transition to descending
            G.jumpState = G.STATE_DESCENDING
        end

        -- Check if we've landed
        if G.onGround then
            G.jumpState = G.STATE_IDLE
            G.useGlideStep = false
        end
        return
    elseif G.jumpState == G.STATE_DESCENDING then
        -- STATE_DESCENDING: Player is falling.
        local velocity = G.pLocal:EstimateAbsVelocity()

        -- Handle different behaviors based on jump type
        if G.selectedJumpType then
            if G.selectedJumpType.name == "CTAP" or G.selectedJumpType.name == "NORMAL" then
                -- For CTAP and normal jumps, unduck while descending
                cmd:SetButtons(cmd.buttons & (~IN_DUCK))
            elseif G.selectedJumpType.name == "DUCK" or G.selectedJumpType.name == "CROUCH_HOP" then
                -- For duck jumps, maintain crouch until close to landing
                local pLocalPos = G.pLocal:GetAbsOrigin()
                local traceDown = engine.TraceHull(pLocalPos, pLocalPos + Vector3(0, 0, -20), G.playerMins, G.playerMaxs,
                    MASK_PLAYERSOLID_BRUSHONLY)

                if traceDown.fraction < 1 and traceDown.fraction > 0.5 then
                    cmd:SetButtons(cmd.buttons & (~IN_DUCK)) -- Unduck close to landing
                else
                    cmd:SetButtons(cmd.buttons | IN_DUCK)    -- Maintain crouch
                end
            end
        else
            -- Default behavior
            cmd:SetButtons(cmd.buttons & (~IN_DUCK))
        end

        -- Prediction for potential chained jumps
        G.PredData = Common.Prediction.Player(WLocal, 1, G.strafeAngle, nil)
        if G.PredData then
            G.PredPos = G.PredData.pos[1]

            -- Check for bunny hop opportunities
            if not G.PredData.onGround[1] or not G.onGround then
                SmartJump.Execute(cmd)
                if G.ShouldJump then
                    -- Chain another jump
                    if G.selectedJumpType and G.selectedJumpType.name == "NORMAL" then
                        G.jumpState = G.STATE_NORMAL_JUMP
                    else
                        G.jumpState = G.STATE_PREPARE_JUMP
                    end
                    G.ShouldJump = false
                end
            else
                -- Landed - reset to idle
                G.jumpState = G.STATE_IDLE
                G.useGlideStep = false
                G.selectedJumpType = nil
            end
        else
            -- No prediction data, check if landed
            if G.onGround then
                G.jumpState = G.STATE_IDLE
                G.useGlideStep = false
                G.selectedJumpType = nil
            end
        end
    end
end

callbacks.Unregister("CreateMove", "jumpbughanddd")
callbacks.Register("CreateMove", "jumpbughanddd", OnCreateMove)
callbacks.Unregister("CreateMove", "jumpbughanddd")
callbacks.Register("CreateMove", "jumpbughanddd", OnCreateMove)
callbacks.Unregister("CreateMove", "jumpbughanddd")
callbacks.Register("CreateMove", "jumpbughanddd", OnCreateMove)
callbacks.Unregister("CreateMove", "jumpbughanddd")
callbacks.Register("CreateMove", "jumpbughanddd", OnCreateMove)
callbacks.Unregister("CreateMove", "jumpbughanddd")
callbacks.Register("CreateMove", "jumpbughanddd", OnCreateMove)

end)
__bundle_register("Movement.Modules.Recorder", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[ Movement Recorder ]]
--[[Credits to:lnx for lnxlib,menu and the base of the recorder]]

---@type boolean, lnxLib
local libLoaded, lnxLib = pcall(require, "lnxLib")
assert(libLoaded, "lnxLib not found, please install it!")
assert(lnxLib.GetVersion() >= 0.965, "lnxLib version is too old, please update it!")

local Fonts = lnxLib.UI.Fonts

---@type boolean, ImMenu
local menuLoaded, ImMenu = pcall(require, "ImMenu")
assert(menuLoaded, "ImMenu not found, please install it!")
assert(ImMenu.GetVersion() >= 0.66, "ImMenu version is too old, please update it!")

local Common = require("Movement.Common")
local G = require("Movement.Globals")
local Config = require("Movement.Config")

local Recorder = {}

-- Constants for minimum and maximum speed
local MIN_SPEED = 100  -- Minimum speed to avoid jittery movements
local MAX_SPEED = 450 -- Maximum speed the player can move

-- Function to compute the move direction
local function ComputeMove(pCmd, a, b)
    local diff = (b - a)
    if diff:Length() == 0 then return Vector3(0, 0, 0) end

    local x = diff.x
    local y = diff.y
    local vSilent = Vector3(x, y, 0)

    local ang = vSilent:Angles()
    local cPitch, cYaw, cRoll = pCmd:GetViewAngles()
    local yaw = math.rad(ang.y - cYaw)
    local pitch = math.rad(ang.x - cPitch)
    local move = Vector3(math.cos(yaw) * MAX_SPEED, -math.sin(yaw) * MAX_SPEED, -math.cos(pitch) * MAX_SPEED)

    return move
end

-- Function to make the player walk to a destination smoothly
local function WalkTo(pCmd, pLocal, pDestination)
    local localPos = pLocal:GetAbsOrigin()
    local distVector = pDestination - localPos
    local dist = distVector:Length()
    local velocity = pLocal:EstimateAbsVelocity():Length()

    -- If distance is greater than 1, proceed with walking
    if dist > 1 then
        local result = ComputeMove(pCmd, localPos, pDestination)
        -- If distance is less than 10, scale down the speed further
        if dist < 10 + velocity then
            local scaleFactor = dist / 100
            pCmd:SetForwardMove(result.x * scaleFactor)
            pCmd:SetSideMove(result.y * scaleFactor)
        else
            pCmd:SetForwardMove(result.x)
            pCmd:SetSideMove(result.y)
        end
    end
end

Recorder.currentTick = 0
Recorder.currentData = {}
Recorder.currentSize = 1

Recorder.isRecording = false
Recorder.isPlaying = false

Recorder.doRepeat = false
Recorder.doViewAngles = true

Recorder.recordings = {}
Recorder.selectedRecording = nil

local vHitbox = {Min = Vector3(-23, -23, 0), Max = Vector3(23, 23, 81)}
local setuptimer = 128
local AtRightPos = false

---@param userCmd UserCmd
local function OnCreateMove(userCmd)
    local pLocal = entities.GetLocalPlayer()
    if not pLocal or not pLocal:IsAlive() then return end

    if Recorder.isRecording then
        AtRightPos = false
        local yaw, pitch, roll = userCmd:GetViewAngles()
        Recorder.currentData[Recorder.currentTick] = {
            viewAngles = EulerAngles(yaw, pitch, roll),
            forwardMove = userCmd:GetForwardMove(),
            sideMove = userCmd:GetSideMove(),
            buttons = userCmd:GetButtons(),
            position =  pLocal:GetAbsOrigin(),
        }

        Recorder.currentSize = Recorder.currentSize + 1
        Recorder.currentTick = Recorder.currentTick + 1
    elseif Recorder.isPlaying then
        if userCmd.forwardmove ~= 0 or userCmd.sidemove ~= 0 then return end --input bypass

        if Recorder.currentTick >= Recorder.currentSize - 1 or Recorder.currentTick >= Recorder.currentSize + 1 then
            if Recorder.doRepeat then
                Recorder.currentTick = 0
                AtRightPos = false
            else
                AtRightPos = false
                Recorder.isPlaying = false
            end
        end

        local data = Recorder.currentData[Recorder.currentTick]
        if Recorder.currentData[Recorder.currentTick] == nil then return end --dont do anyyhign if data is inalid

            userCmd:SetViewAngles(data.viewAngles:Unpack())
            userCmd:SetForwardMove(data.forwardMove)
            userCmd:SetSideMove(data.sideMove)
            userCmd:SetButtons(data.buttons)

            if Recorder.doViewAngles then
                engine.SetViewAngles(data.viewAngles)
            end

            local distance = (pLocal:GetAbsOrigin() - data.position):Length()
            local velocityLength = pLocal:EstimateAbsVelocity():Length()

            velocityLength = math.max(0.1, math.min(velocityLength, 50))

            if not AtRightPos then
                WalkTo(userCmd, pLocal, data.position)
                if distance > velocityLength then
                    setuptimer = setuptimer - 1
                    if setuptimer < 1 and velocityLength < 5 or setuptimer < 66 and velocityLength < 1 then --or AntiStucktrace.fraction < 1 and setuptimer < 1 and velocityLength < 5 then
                        AtRightPos = true
                        setuptimer = 128
                    end
                    return
                end
            else
                if (distance < pLocal:EstimateAbsVelocity():Length() + 50) then
                    WalkTo(userCmd, pLocal, data.position)
                    if velocityLength < 1 then--or AntiStucktrace.fraction < 1 and velocityLength < 5 then
                        AtRightPos = true
                    end
                else
                    setuptimer = 128
                    AtRightPos = false
                end
            end

            --local AntiStucktrace = engine.TraceHull(pLocal:GetAbsOrigin(), data.position, vHitbox.Min, vHitbox.Max, MASK_PLAYERSOLID_BRUSHONLY)
            --f AntiStucktrace.fraction < 1 zthen
                Recorder.currentTick = Recorder.currentTick + 1
            --else
            --    Recorder.currentTick = Recorder.currentTick - 1
            --end
    end
end

function Recorder.Reset()
    AtRightPos = false
    Recorder.isRecording = false
    Recorder.isPlaying = false
    Recorder.currentTick = 0
    Recorder.currentData = {}
    Recorder.currentSize = 1
end

function Recorder.GetRecordings()
    local names = {}
    for name, _ in pairs(Recorder.recordings) do
        table.insert(names, name)
    end
    return names
end

function Recorder.GetSelectedRecording()
    return Recorder.selectedRecording
end

function Recorder.SelectRecording(name)
    if Recorder.recordings[name] then
        Recorder.selectedRecording = name
        Recorder.currentData = Recorder.recordings[name].data
        Recorder.currentSize = #Recorder.currentData
        Recorder.currentTick = 0
    end
end

function Recorder.StartNewRecording()
    local name = "Recording " .. tostring(#Recorder.recordings + 1)
    Recorder.recordings[name] = { data = {} }
    Recorder.SelectRecording(name)
    Recorder.isRecording = true
    Recorder.isPlaying = false
end

function Recorder.DeleteSelectedRecording()
    if Recorder.selectedRecording then
        Recorder.recordings[Recorder.selectedRecording] = nil
        Recorder.selectedRecording = nil
        Recorder.Reset()
    end
end

function Recorder.ToggleRecording()
    if Recorder.isRecording then
        Recorder.isRecording = false
        if Recorder.selectedRecording then
            Recorder.recordings[Recorder.selectedRecording].data = Recorder.currentData
        end
    else
        Recorder.isRecording = true
        Recorder.isPlaying = false
    end
end

function Recorder.TogglePlayback()
    if Recorder.isRecording then
        Recorder.isRecording = false
        if Recorder.selectedRecording then
            Recorder.recordings[Recorder.selectedRecording].data = Recorder.currentData
        end
    end
    Recorder.isPlaying = not Recorder.isPlaying
end

-- Save recordings to file
function Recorder.SaveRecordings()
    Config:Save("recordings.json")
end

-- Load recordings from file
function Recorder.LoadRecordings()
    Config:Load("recordings.json")
end

callbacks.Unregister("CreateMove", "LNX.Recorder.CreateMove")
callbacks.Register("CreateMove", "LNX.Recorder.CreateMove", OnCreateMove)

return Recorder

end)
__bundle_register("Movement.Config", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[ Imports ]]
local Config = {}

local Common = require("Movement.Common")
local G = require("Movement.Globals")
local json = require("Movement.Json")

local Log = Common.Log
local Notify = Common.Notify
Log.Level = 0

local Lua__fullPath = GetScriptName()
local Lua__fileName = Lua__fullPath:match("\\([^\\]-)$"):gsub("%.lua$", "")
local folder_name = string.format([[Lua %s]], Lua__fileName)

-- Ensure the folder exists
local _, fullPath = filesystem.CreateDirectory(folder_name) --succes shows if folder was created not if it exists or action suceeded

local configFilePath = fullPath .. "/config.json"
local recordingsFilePath = fullPath .. "/recordings.json"

-- Default configuration table
local defaultConfig = {
    Menu = G.Default_Menu,
    -- Add other default configurations here
}

-- Helper function: copyMatchingKeys
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

-- Utility: recursively check that every key in 'expected' exists in 'loaded'.
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

-- Save data to file (in JSON format)
local function SaveToFile(filePath, data, successMessage, errorMessage)
    local file = io.open(filePath, "w")
    if file then
        local content = json.encode(data)
        file:write(content)
        file:close()
        printc(100, 183, 0, 255, successMessage .. ": " .. filePath)
        Notify.Simple("Success! " .. successMessage, filePath, 5)
    else
        printc(255, 0, 0, 255, errorMessage .. ": " .. filePath)
        Notify.Simple("Error", errorMessage .. ": " .. filePath, 5)
    end
end

-- Load data from file
local function LoadFromFile(filePath, defaultData, successMessage, errorMessage)
    local file = io.open(filePath, "r")
    if file then
        local content = file:read("*a")
        file:close()
        local loadedData, decodeErr = json.decode(content)
        if loadedData and deepCheck(defaultData, loadedData) and not input.IsButtonDown(KEY_LSHIFT) then
            for key, value in pairs(loadedData) do
                G[key] = value
            end
            printc(100, 183, 0, 255, successMessage .. ": " .. filePath)
            Notify.Simple("Success! " .. successMessage, filePath, 5)
        else
            local warnMsg = decodeErr or "Data is outdated or invalid. Creating a new file."
            printc(255, 0, 0, 255, warnMsg)
            Notify.Simple("Warning", warnMsg, 5)
            SaveToFile(filePath, defaultData, successMessage, errorMessage)
        end
    else
        local warnMsg = "File not found. Creating a new file."
        printc(255, 0, 0, 255, warnMsg)
        Notify.Simple("Warning", warnMsg, 5)
        SaveToFile(filePath, defaultData, successMessage, errorMessage)
    end
end

-- Save the current configuration to file
function Config:Save(fileName)
    local filePath = fullPath .. "/" .. fileName
    SaveToFile(filePath, copyMatchingKeys(G, defaultConfig), "Saved to", "Failed to open file for writing")
end

-- Load configuration from file
function Config:Load(fileName)
    local filePath = fullPath .. "/" .. fileName
    LoadFromFile(filePath, defaultConfig, "Loaded from", "Failed to load")
end

local function OnUnload()
    Config:Save("config.json")
    Config:Save("recordings.json")
end

callbacks.Unregister("Unload", "Movement_Unload")
callbacks.Register("Unload", "Movement_Unload", OnUnload)

-- Auto-load the configuration and recordings when the module is required.
Config:Load("config.json")
Config:Load("recordings.json")

return Config
end)
__bundle_register("Movement.Json", function(require, _LOADED, __bundle_register, __bundle_modules)
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
__bundle_register("Movement.Globals", function(require, _LOADED, __bundle_register, __bundle_modules)
local G = {}

G.lastAngle = nil ---@type number
G.vHitbox = { Vector3(-23.99, -23.99, 0), Vector3(23.99, 23.99, 82) }
G.pLocal = entities.GetLocalPlayer()
G.onGround = true
G.Ducking = false
G.PredPos = Vector3(0, 0, 0)
G.PredData = {}
G.JumpPeekPos = Vector3(0, 0, 0)
G.ShouldJump = false
G.lastAngle = 0
G.strafeAngle = 0

-- New variables for improved jump system
G.selectedJumpType = nil -- Stores the selected jump type
G.useGlideStep = false   -- Flag for glide step mechanic
G.jumpPhase = 0          -- Current phase of the jump

-- State Definitions
G.STATE_IDLE = "STATE_IDLE"
G.STATE_PREPARE_JUMP = "STATE_PREPARE_JUMP"
G.STATE_CTAP = "STATE_CTAP"
G.STATE_ASCENDING = "STATE_ASCENDING"
G.STATE_DESCENDING = "STATE_DESCENDING"
G.STATE_GLIDE_STEP = "STATE_GLIDE_STEP"   -- New state for glide stepping
G.STATE_NORMAL_JUMP = "STATE_NORMAL_JUMP" -- New state for normal jumps

-- Initial state
G.jumpState = G.STATE_IDLE

-- Constants for different jump types and mechanics
G.MAX_JUMP_HEIGHT = Vector3(0, 0, 72) -- Maximum jump height vector (for duck jump)
G.MAX_WALKABLE_ANGLE = 45             -- Maximum angle considered walkable
G.gravity = 800                       -- Gravity per second
G.jumpForce = 277                     -- Initial vertical boost for a duck jump (legacy, now calculated per jump type)

-- Step height constant (maximum height the player can step up)
G.STEP_HEIGHT = 18

-- Jump height constants (in units)
G.JUMP_HEIGHTS = {
    NORMAL = 45,      -- Normal jump height
    CTAP = 32.2,      -- CTAP jump height
    DUCK = 72.2,      -- Duck jump height
    CROUCH_HOP = 72.9 -- Crouch hop height
}

-- Glide step constants
G.GLIDE_STEP_HEIGHT_THRESHOLD = 20   -- Maximum height difference for glide step
G.GLIDE_STEP_DISTANCE_THRESHOLD = 30 -- Distance threshold to activate glide step

G.Default_Menu = {
    Enable = true,
    DuckJump = true,
    SmartJump = true,
    EdgeJump = true,
    Visuals = true,
    GlideStep = true, -- New option for glide step
}

G.Menu = {
    Enable = true,
    DuckJump = true,
    SmartJump = true,
    EdgeJump = true,
    Visuals = true,
    GlideStep = true, -- New option for glide step
}

-- Table to store recordings
G.Recordings = {}

-- Debug information for jump system
G.Debug = {
    selectedJumpType = nil,
    obstacleHeight = 0,
    shouldUseGlideStep = false,
    currentState = G.STATE_IDLE
}

return G

end)
__bundle_register("Movement.Common", function(require, _LOADED, __bundle_register, __bundle_modules)
---@diagnostic disable: duplicate-set-field, undefined-field
---@class Common
local Common = {}

pcall(UnloadLib) -- if it fails then forget about it it means it wasnt loaded in first place and were clean

local libLoaded, Lib = pcall(require, "LNXlib")
assert(libLoaded, "LNXlib not found, please install it!")
assert(Lib.GetVersion() >= 1.0, "LNXlib version is too old, please update it!")

Common.Lib = Lib
Common.Log = Lib.Utils.Logger.new("Movement")
Common.Notify = Lib.UI.Notify
Common.TF2 = Common.Lib.TF2
Common.Math, Common.Conversion = Common.Lib.Utils.Math, Common.Lib.Utils.Conversion
Common.WPlayer, Common.PR = Common.TF2.WPlayer, Common.TF2.PlayerResource
Common.Prediction = Common.TF2.Prediction
Common.Helpers = Common.TF2.Helpers

local G = require("Movement.Globals")


-- Function to normalize a vector
function Common.Normalize(vector)
    local length = vector:Length()
    return Vector3(vector.x / length, vector.y / length, vector.z / length)
end


function Common.RotateVectorByYaw(vector, yaw)
    local rad = math.rad(yaw)
    local cos, sin = math.cos(rad), math.sin(rad)

    return Vector3(
        cos * vector.x - sin * vector.y,
        sin * vector.x + cos * vector.y,
        vector.z
    )
end

-- Function to check the angle of the surface
function Common.isSurfaceWalkable(normal)
    local vUp = Vector3(0, 0, 1)
    local angle = math.deg(math.acos(normal:Dot(vUp)))
    return angle < G.MAX_WALKABLE_ANGLE
end

-- Helper function to check if the player is on the ground
function Common.isPlayerOnGround(player)
    local pFlags = player:GetPropInt("m_fFlags")
    return (pFlags & FL_ONGROUND) == FL_ONGROUND
end

-- Helper function to check if the player is on the ground
function Common.isPlayerDucking(player)
    return (player:GetPropInt("m_fFlags") & FL_DUCKING) == FL_DUCKING
end

---@param me WPlayer?
function Common.CalcStrafe(me)
    if not me then return end --nil check

    -- Reset data for dormant or dead players and teammates
    local angle = me:EstimateAbsVelocity():Angles() -- get angle of velocity vector

    -- Calculate the delta angle
    local delta = 0
    if G.lastAngle then
        delta = angle.y - G.lastAngle
        delta = Common.Math.NormalizeAngle(delta)
    end

    return delta
end

-- Function to calculate the jump peak
function Common.GetJumpPeak(horizontalVelocityVector, startPos)

    -- Calculate the time to reach the jump peak
    local timeToPeak = G.jumpForce / G.gravity

    -- Calculate horizontal velocity length
    local horizontalVelocity = horizontalVelocityVector:Length()

    -- Calculate distance traveled horizontally during time to peak
    local distanceTravelled = horizontalVelocity * timeToPeak

    -- Calculate peak position vector
    local peakPosVector = startPos + Common.Normalize(horizontalVelocityVector) * distanceTravelled

    -- Calculate direction to peak position
    local directionToPeak = Common.Normalize(peakPosVector - startPos)

    return peakPosVector, directionToPeak
end

--make the velocity adjusted towards direction we wanna walk
function Common.SmartVelocity(cmd)
    if not G.pLocal then return end --nil check

    -- Calculate the player's movement direction
    local moveDir = Vector3(cmd.forwardmove, -cmd.sidemove, 0)
    local viewAngles = engine.GetViewAngles()
    local rotatedMoveDir = Common.RotateVectorByYaw(moveDir, viewAngles.yaw)
    local normalizedMoveDir = Common.Normalize(rotatedMoveDir)
    local vel = G.pLocal:EstimateAbsVelocity()

    -- Normalize moveDir if its length isn't 0, then ensure velocity matches the intended movement direction
    if moveDir:Length() > 0 then
        if G.onGround then
        -- Calculate the intended speed based on input magnitude. This could be a fixed value or based on current conditions like player's max speed.
        local intendedSpeed = math.max(1, vel:Length()) -- Ensure the speed is at least 1

        -- Adjust the player's velocity to match the intended direction and speed
        vel = normalizedMoveDir * intendedSpeed
        end
    else
        -- If there's no input, you might want to handle the case where the player should stop or maintain current velocity
        vel = Vector3(0, 0, 0)
    end
    return vel
end

-- Smart jump logic moved to a separate module

--[[ Callbacks ]]
local function OnUnload() -- Called when the script is unloaded
    pcall(UnloadLib) --unloading lualib
    client.Command('play "ui/buttonclickrelease"', true) -- Play the "buttonclickrelease" sound
end

--[[ Unregister previous callbacks ]]--
callbacks.Unregister("Unload", "Movement_Unload")                                -- unregister the "Unload" callback
--[[ Register callbacks ]]--
callbacks.Register("Unload", "Movement_Unload", OnUnload)                         -- Register the "Unload" callback

return Common
end)
__bundle_register("Movement.Modules.SmartJump", function(require, _LOADED, __bundle_register, __bundle_modules)
---@diagnostic disable: duplicate-set-field, undefined-field
---@class SmartJump
local SmartJump = {}

local Common = require("Movement.Common")
local G = require("Movement.Globals")

-- Jump type constants
local JUMP_TYPES = {
    NORMAL = { height = 52, name = "NORMAL" },          -- Normal jump ~52 units
    CTAP = { height = 32.2, name = "CTAP" },            -- Crouch-tap jump ~32.2 units
    DUCK = { height = 72.2, name = "DUCK" },            -- Duck jump ~72.2 units
    CROUCH_HOP = { height = 72.9, name = "CROUCH_HOP" } -- Crouch hop ~72.9 units
}

-- Add new states to globals
G.STATE_GLIDE_STEP = "STATE_GLIDE_STEP"
G.STATE_NORMAL_JUMP = "STATE_NORMAL_JUMP"

-- Function to determine the minimal jump type needed
local function DetermineJumpType(obstacleHeight)
    -- Add small buffer to ensure we clear the obstacle
    local requiredHeight = obstacleHeight + 2

    -- Choose minimal jump type that can clear the obstacle
    if requiredHeight <= JUMP_TYPES.CTAP.height then
        return JUMP_TYPES.CTAP
    elseif requiredHeight <= JUMP_TYPES.NORMAL.height then
        return JUMP_TYPES.NORMAL
    elseif requiredHeight <= JUMP_TYPES.DUCK.height then
        return JUMP_TYPES.DUCK
    else
        return JUMP_TYPES.CROUCH_HOP
    end
end

-- Function to calculate obstacle height at jump peak
local function CalculateObstacleHeight(startPos, peakPos, hitbox)
    -- Trace from start to peak to find obstacle
    local trace = engine.TraceHull(startPos, peakPos, hitbox[1], hitbox[2], MASK_PLAYERSOLID_BRUSHONLY)

    if trace.fraction >= 1 then
        return 0 -- No obstacle
    end

    -- Calculate the height difference to clear the obstacle
    local obstaclePoint = trace.endpos
    local heightDifference = obstaclePoint.z - startPos.z

    return math.max(0, heightDifference)
end

-- Function to check if glide step is beneficial
local function ShouldGlideStep(currentPos, landingPos)
    -- Glide step is beneficial when we're slightly above a surface
    local heightDifference = currentPos.z - landingPos.z
    return heightDifference > 0 and heightDifference < 20 -- Small height difference
end

-- Function to calculate the jump peak for different jump types
local function GetJumpPeak(horizontalVelocityVector, startPos, jumpType)
    local jumpHeight = jumpType.height
    local jumpForce = math.sqrt(2 * G.gravity * jumpHeight) -- Calculate required initial velocity

    -- Calculate the time to reach the jump peak
    local timeToPeak = jumpForce / G.gravity

    -- Calculate horizontal velocity length
    local horizontalVelocity = horizontalVelocityVector:Length()

    -- Calculate distance traveled horizontally during time to peak
    local distanceTravelled = horizontalVelocity * timeToPeak

    -- Calculate peak position vector
    local peakPosVector = startPos + Common.Normalize(horizontalVelocityVector) * distanceTravelled
    peakPosVector.z = startPos.z + jumpHeight

    -- Calculate direction to peak position
    local directionToPeak = Common.Normalize(peakPosVector - startPos)

    return peakPosVector, directionToPeak, timeToPeak
end

-- Smart jump logic with multiple jump types
function SmartJump.Execute(cmd)
    if not G.pLocal or not G.pLocal:IsAlive() then return end

    -- Get the player's data
    local pLocalPos = G.pLocal:GetAbsOrigin()
    local vel = Common.SmartVelocity(cmd)
    -- Use G.pLocal.min and G.pLocal.max for hitbox bounds

    G.ShouldJump = false
    G.selectedJumpType = nil

    if G.Menu.SmartJump and G.onGround then
        local jumpTypesToTry = { JUMP_TYPES.CTAP, JUMP_TYPES.NORMAL, JUMP_TYPES.DUCK, JUMP_TYPES.CROUCH_HOP }
        for _, jumpType in ipairs(jumpTypesToTry) do
            -- Original logic below, but using jumpType in place of selectedJumpType
            local testJumpPeak, testDirection = GetJumpPeak(vel, pLocalPos, jumpType)
            local obstacleHeight = CalculateObstacleHeight(pLocalPos, testJumpPeak, { G.playerMins, G.playerMaxs })

            if obstacleHeight > 0 then
                -- Recalculate with this jump type
                local jumpPeakPos, jumpDirection = GetJumpPeak(vel, pLocalPos, jumpType)
                local trace = engine.TraceHull(pLocalPos, jumpPeakPos, G.playerMins, G.playerMaxs,
                    MASK_PLAYERSOLID_BRUSHONLY)
                local peakPos = trace.endpos

                if trace.fraction < 1 then
                    -- Move up by jump height
                    local jumpHeightVector = Vector3(0, 0, jumpType.height)
                    local startrace = trace.endpos + jumpHeightVector
                    local endtrace = startrace + jumpDirection * 1

                    -- Forward trace to check for sliding on possible walls
                    local forwardTrace = engine.TraceHull(startrace, endtrace, G.playerMins, G.playerMaxs,
                        MASK_PLAYERSOLID_BRUSHONLY)
                    local forwardPos = forwardTrace.endpos

                    -- Trace down to find landing position
                    local traceDown = engine.TraceHull(forwardPos, forwardPos - jumpHeightVector, G.playerMins,
                        G.playerMaxs,
                        MASK_PLAYERSOLID_BRUSHONLY)
                    local landingPos = traceDown.endpos

                    if traceDown.fraction > 0 then
                        local normal = traceDown.plane
                        if Common.isSurfaceWalkable(normal) then
                            -- Check if we should use glide step
                            if ShouldGlideStep(forwardPos, traceDown.endpos) then
                                G.useGlideStep = true
                            else
                                G.useGlideStep = false
                            end
                            local heightGain = landingPos.z - pLocalPos.z
                            if heightGain > G.STEP_HEIGHT then
                                G.selectedJumpType = jumpType
                                G.JumpPeekPos = peakPos
                                G.ShouldJump = true
                                break
                            end
                        end
                    end
                end
            end
        end
    elseif input.IsButtonDown(KEY_SPACE) then
        -- Manual jump - use normal jump
        G.selectedJumpType = JUMP_TYPES.NORMAL
        G.ShouldJump = true
    else
        G.ShouldJump = false
    end
end

-- Function to execute the selected jump type
function SmartJump.ExecuteJumpType(cmd, jumpType)
    if not jumpType then jumpType = JUMP_TYPES.NORMAL end

    if jumpType.name == "CTAP" then
        -- CTAP: Quick crouch then jump
        if G.jumpState == G.STATE_PREPARE_JUMP then
            cmd:SetButtons(cmd.buttons | IN_DUCK)
            cmd:SetButtons(cmd.buttons & (~IN_JUMP))
            return "CTAP_PHASE1"
        elseif G.jumpState == G.STATE_CTAP then
            cmd:SetButtons(cmd.buttons & (~IN_DUCK))
            cmd:SetButtons(cmd.buttons | IN_JUMP)
            return "CTAP_PHASE2"
        end
    elseif jumpType.name == "NORMAL" then
        -- Normal jump: Just jump without crouch
        cmd:SetButtons(cmd.buttons | IN_JUMP)
        cmd:SetButtons(cmd.buttons & (~IN_DUCK))
        return "NORMAL_JUMP"
    elseif jumpType.name == "DUCK" then
        -- Duck jump: Crouch then jump and maintain crouch
        if G.jumpState == G.STATE_PREPARE_JUMP then
            cmd:SetButtons(cmd.buttons | IN_DUCK)
            cmd:SetButtons(cmd.buttons & (~IN_JUMP))
            return "DUCK_PHASE1"
        else
            cmd:SetButtons(cmd.buttons | IN_DUCK)
            cmd:SetButtons(cmd.buttons | IN_JUMP)
            return "DUCK_PHASE2"
        end
    elseif jumpType.name == "CROUCH_HOP" then
        -- Crouch hop: Similar to duck but with specific timing
        if G.jumpState == G.STATE_PREPARE_JUMP then
            cmd:SetButtons(cmd.buttons | IN_DUCK)
            cmd:SetButtons(cmd.buttons & (~IN_JUMP))
            return "CROUCH_HOP_PHASE1"
        else
            cmd:SetButtons(cmd.buttons | IN_DUCK)
            cmd:SetButtons(cmd.buttons | IN_JUMP)
            return "CROUCH_HOP_PHASE2"
        end
    end
end

-- Glide step logic - unduck when close to ground to grab onto surface
function SmartJump.HandleGlideStep(cmd)
    if not G.useGlideStep then return false end

    local pLocalPos = G.pLocal:GetAbsOrigin()
    local velocity = G.pLocal:EstimateAbsVelocity()

    -- Check distance to predicted landing
    local distanceToLanding = (G.JumpPeekPos - pLocalPos):Length()

    -- Check if we're close to landing and falling
    if velocity.z <= 0 and distanceToLanding < 30 then
        -- Trace down to see how close we are to ground
        local traceDown = engine.TraceHull(pLocalPos, pLocalPos + Vector3(0, 0, -50), G.vHitbox[1], G.vHitbox[2],
            MASK_PLAYERSOLID_BRUSHONLY)

        -- If we're close to ground, unduck to grab onto it
        if traceDown.fraction < 1 and traceDown.fraction > 0.3 then
            cmd:SetButtons(cmd.buttons & (~IN_DUCK)) -- Unduck to grab ground
            return true
        end
    end

    return false
end

return SmartJump

end)
__bundle_register("Movement.Menu", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[ Imports ]]
local Common = require("Movement.Common")
local G = require("Movement.Globals")
local Recorder = require("Movement.Modules.Recorder")

local Menu = {}

local Lib = Common.Lib
local Fonts = Lib.UI.Fonts

---@type boolean, ImMenu
local menuLoaded, ImMenu = pcall(require, "ImMenu")
assert(menuLoaded, "ImMenu not found, please install it!")
assert(ImMenu.GetVersion() >= 0.66, "ImMenu version is too old, please update it!")

G.Default_Menu = {
    Enable = true,
    DuckJump = true,
    SmartJump = true,
    EdgeJump = true,
    Visuals = true,
}

local function DrawMainMenu()
    if ImMenu.Begin("Movement", true) then
        draw.SetFont(Fonts.Verdana)
        draw.Color(255, 255, 255, 255)

        -- Enable_bhop
        ImMenu.BeginFrame(1)
            G.Menu.Enable = ImMenu.Checkbox("Enable", G.Menu.Enable)
        ImMenu.EndFrame()

        -- Enable_SmartJump
        ImMenu.BeginFrame(1)
            G.Menu.SmartJump = ImMenu.Checkbox("SmartJump", G.Menu.SmartJump)
        ImMenu.EndFrame()

        -- Enable_Visuals
        ImMenu.BeginFrame(1)
            G.Menu.Visuals = ImMenu.Checkbox("Visuals", G.Menu.Visuals)
        ImMenu.EndFrame()

        ImMenu.End()
    end
end

local function DrawRecorderMenu()
    if ImMenu.Begin("Movement Recorder", true) then
        -- Progress bar
        ImMenu.BeginFrame(1)
        ImMenu.PushStyle("ItemSize", { 385, 30 })

        local MaxSize = (Recorder.currentSize > 0 and Recorder.currentSize < 1000 and Recorder.isRecording and not Recorder.isPlaying) and 1000 or Recorder.currentSize
        if Recorder.isRecording and (Recorder.currentSize > MaxSize or Recorder.currentTick > MaxSize) then
            MaxSize = math.max(Recorder.currentSize, Recorder.currentTick)
        end
        if Recorder.isRecording then
            Recorder.currentTick = ImMenu.Slider("Tick", Recorder.currentTick, 0, MaxSize)
        else
            Recorder.currentTick = ImMenu.Slider("Tick", Recorder.currentTick, 0, Recorder.currentSize)
        end

        ImMenu.PopStyle()
        ImMenu.EndFrame()

        -- Buttons
        ImMenu.BeginFrame(1)
        ImMenu.PushStyle("ItemSize", { 125, 30 })

            local recordButtonText = Recorder.isRecording and "Stop Recording" or "Start Recording"
            if ImMenu.Button(recordButtonText) then
                Recorder.isRecording = not Recorder.isRecording
                if Recorder.isRecording then
                    Recorder.isPlaying = false
                    Recorder.currentTick = 0
                    Recorder.currentData = {}
                    Recorder.currentSize = 1
                else
                    Recorder.isPlaying = true
                end
            end

            local playButtonText
            if Recorder.currentData[Recorder.currentTick] == nil and Recorder.currentTick == 0 then
                playButtonText = "No Record"
            elseif Recorder.isPlaying then
                playButtonText = "Pause"
            else
                playButtonText = "Play"
            end

            if ImMenu.Button(playButtonText) then
                if Recorder.isRecording then
                    Recorder.isRecording = false
                    Recorder.isPlaying = true
                    Recorder.currentTick = 0
                elseif Recorder.isPlaying then
                    Recorder.isPlaying = false
                else
                    Recorder.isPlaying = true
                    Recorder.currentTick = 0
                end
            end

            if ImMenu.Button("Reset") then
                Recorder.Reset()
            end

        ImMenu.PopStyle()
        ImMenu.EndFrame()

        -- Options
        ImMenu.BeginFrame(1)

            Recorder.doRepeat = ImMenu.Checkbox("Auto Repeat", Recorder.doRepeat)
            Recorder.doViewAngles = ImMenu.Checkbox("Apply View Angles", Recorder.doViewAngles)

        ImMenu.EndFrame()

        ImMenu.End()
    end
end

local function DrawMenu()
    if gui.IsMenuOpen() then
        DrawMainMenu()
        DrawRecorderMenu()
    end
end

--[[ Callbacks ]]
callbacks.Unregister("Draw", "Menu-MCT_Draw")                                   -- unregister the "Draw" callback
callbacks.Register("Draw", "Menu-MCT_Draw", DrawMenu)                              -- Register the "Draw" callback 

return Menu
end)
__bundle_register("Movement.Visuals", function(require, _LOADED, __bundle_register, __bundle_modules)
local G = require("Movement.Globals")
local function OnDraw()
    -- Inside your OnDraw function
    G.pLocal = entities.GetLocalPlayer()
    if not G.Menu.Visuals or not G.pLocal then return end
    draw.Color(255, 0, 0, 255)
    local screenPos = client.WorldToScreen(G.PredPos)
    local screenpeekpos = client.WorldToScreen(G.JumpPeekPos)
    if screenPos then
        draw.Color(255, 0, 0, 255) -- Red color for backstab position
        draw.FilledRect(screenPos[1] - 5, screenPos[2] - 5, screenPos[1] + 5, screenPos[2] + 5)
    end
    if screenpeekpos then
        draw.Color(0, 255, 0, 255) -- Red color for backstab position
        draw.FilledRect(screenpeekpos[1] - 5, screenpeekpos[2] - 5, screenpeekpos[1] + 5, screenpeekpos[2] + 5)
    end

    -- Calculate min and max points
    local minPoint = G.playerMins + G.JumpPeekPos
    local maxPoint = G.playerMaxs + G.JumpPeekPos

    -- Calculate vertices of the AABB
    -- Assuming minPoint and maxPoint are the minimum and maximum points of the AABB:
    local vertices = {
        Vector3(minPoint.x, minPoint.y, minPoint.z), -- Bottom-back-left
        Vector3(minPoint.x, maxPoint.y, minPoint.z), -- Bottom-front-left
        Vector3(maxPoint.x, maxPoint.y, minPoint.z), -- Bottom-front-right
        Vector3(maxPoint.x, minPoint.y, minPoint.z), -- Bottom-back-right
        Vector3(minPoint.x, minPoint.y, maxPoint.z), -- Top-back-left
        Vector3(minPoint.x, maxPoint.y, maxPoint.z), -- Top-front-left
        Vector3(maxPoint.x, maxPoint.y, maxPoint.z), -- Top-front-right
        Vector3(maxPoint.x, minPoint.y, maxPoint.z)  -- Top-back-right
    }

    -- Convert 3D coordinates to 2D screen coordinates
    for i, vertex in ipairs(vertices) do
        vertices[i] = client.WorldToScreen(vertex)
    end

    -- Draw lines between vertices to visualize the box
    if vertices[1] and vertices[2] and vertices[3] and vertices[4] and vertices[5] and vertices[6] and vertices[7] and vertices[8] then
        -- Draw front face
        draw.Line(vertices[1][1], vertices[1][2], vertices[2][1], vertices[2][2])
        draw.Line(vertices[2][1], vertices[2][2], vertices[3][1], vertices[3][2])
        draw.Line(vertices[3][1], vertices[3][2], vertices[4][1], vertices[4][2])
        draw.Line(vertices[4][1], vertices[4][2], vertices[1][1], vertices[1][2])

        -- Draw back face
        draw.Line(vertices[5][1], vertices[5][2], vertices[6][1], vertices[6][2])
        draw.Line(vertices[6][1], vertices[6][2], vertices[7][1], vertices[7][2])
        draw.Line(vertices[7][1], vertices[7][2], vertices[8][1], vertices[8][2])
        draw.Line(vertices[8][1], vertices[8][2], vertices[5][1], vertices[5][2])

        -- Draw connecting lines
        draw.Line(vertices[1][1], vertices[1][2], vertices[5][1], vertices[5][2])
        draw.Line(vertices[2][1], vertices[2][2], vertices[6][1], vertices[6][2])
        draw.Line(vertices[3][1], vertices[3][2], vertices[7][1], vertices[7][2])
        draw.Line(vertices[4][1], vertices[4][2], vertices[8][1], vertices[8][2])
    end
end

callbacks.Unregister("Draw", "accuratemoveD.Draw")
callbacks.Register("Draw", "accuratemoveD", OnDraw)

end)
return __bundle_require("__root")