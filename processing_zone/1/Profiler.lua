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
    Profiler Library - Main Entry Point
    Author: titaniummachine1
    
    A lightweight performance profiler for Lua applications
    
    Usage:
        local Profiler = require("Profiler")
        
        -- Control visibility
        Profiler.SetVisible(true)
        
        -- Measure performance
        Profiler.StartSystem("system_name")
            Profiler.StartComponent("component_name")
            -- ... your code ...
            Profiler.EndComponent("component_name")
        Profiler.EndSystem("system_name")
        
        -- In draw callback
        Profiler.Draw()
]]

-- Global shared table (from Shared.lua) – retained mode
local Shared = require("Profiler.Shared")

-- RELOAD DETECTION: Check if profiler is already loaded
if Shared.ProfilerInstance and Shared.ProfilerLoaded then
	print("🔄 Microprofiler already loaded - performing full reload...")

	-- Unload existing instance completely
	if Shared.ProfilerInstance.Unload then
		Shared.ProfilerInstance.Unload()
	end

	-- Force clear all package cache (improved pattern)
	local packagesToClear = {
		"Profiler",
		"Profiler.profiler",
		"Profiler.microprofiler",
		"Profiler.ui_top",
		"Profiler.ui_body",
		"Profiler.Shared",
		"Profiler.config",
		"Profiler.Main",
	}

	for _, pkg in ipairs(packagesToClear) do
		if package.loaded[pkg] then
			package.loaded[pkg] = nil
		end
	end

	-- Clear global state
	Shared.ProfilerInstance = nil
	Shared.ProfilerLoaded = false

	-- Re-require Shared to get fresh state
	Shared = require("Profiler.Shared")

	print("📦 All packages cleared - loading fresh profiler...")
end

-- Check if an older version of the profiler is already loaded and unload it
local previouslyLoaded = package.loaded["Profiler"]
if previouslyLoaded and previouslyLoaded.Unload then
	previouslyLoaded.Unload()
end

-- Initialize profiler state flags (now in retained globals)
ProfilerLoaded = false -- Global variable (not local)
ProfilerCallbacksRegistered = false -- Global variable
ProfilerEnabled = false -- Global variable

-- Import core module (does **not** register callbacks on its own)
local ProfilerCore = require("Profiler.profiler")
ProfilerCore.Init()

-- Public API table
local Profiler = {}

-- Re-export core functions (original API)
Profiler.SetVisible = ProfilerCore.SetVisible
Profiler.StartSystem = ProfilerCore.StartSystem
Profiler.StartComponent = ProfilerCore.StartComponent
Profiler.EndComponent = ProfilerCore.EndComponent
Profiler.EndSystem = ProfilerCore.EndSystem
Profiler.Draw = ProfilerCore.Draw

-- New minimalist API for nested scopes
Profiler.Start = ProfilerCore.Start
Profiler.Finish = ProfilerCore.Finish
Profiler.TogglePause = ProfilerCore.TogglePause
Profiler.IsPaused = ProfilerCore.IsPaused
Profiler.ToggleVisibility = ProfilerCore.ToggleVisibility

-- Simplified API - explicit systems, Begin for components
Profiler.BeginSystem = ProfilerCore.BeginSystem
Profiler.EndSystem = ProfilerCore.StopSystem -- No parameters needed
Profiler.Begin = ProfilerCore.Begin -- Always for components
Profiler.End = ProfilerCore.End -- Always for components

-- Config helpers
Profiler.SetSortMode = ProfilerCore.SetSortMode
Profiler.SetWindowSize = ProfilerCore.SetWindowSize
Profiler.SetSmoothingSpeed = ProfilerCore.SetSmoothingSpeed
Profiler.SetSmoothingDecay = ProfilerCore.SetSmoothingDecay
Profiler.SetTextUpdateInterval = ProfilerCore.SetTextUpdateInterval
Profiler.SetSystemMemoryMode = ProfilerCore.SetSystemMemoryMode
Profiler.SetOverheadCompensation = ProfilerCore.SetOverheadCompensation
Profiler.SetAutoHookEnabled = ProfilerCore.SetAutoHookEnabled
Profiler.IsAutoHookEnabled = ProfilerCore.IsAutoHookEnabled
Profiler.SetMeasurementMode = ProfilerCore.SetMeasurementMode
Profiler.GetMeasurementMode = ProfilerCore.GetMeasurementMode
Profiler.Init = ProfilerCore.Init
Profiler.Shutdown = ProfilerCore.Shutdown
Profiler.Reset = ProfilerCore.Reset

-- Metadata constants (Lua 5.4 compatible)
Profiler.VERSION = "1.0.0"
Profiler.AUTHOR = "titaniummachine1"

-- Convenience helpers --------------------------------------------------------
function Profiler.Enable()
	Profiler.SetVisible(true)
	return Profiler
end

function Profiler.Disable()
	Profiler.SetVisible(false)
	return Profiler
end

function Profiler.Setup(cfg)
	cfg = cfg or {}
	if cfg.visible ~= nil then
		Profiler.SetVisible(cfg.visible)
	end
	if cfg.sortMode then
		Profiler.SetSortMode(cfg.sortMode)
	end
	if cfg.windowSize then
		Profiler.SetWindowSize(cfg.windowSize)
	end
	if cfg.smoothingSpeed then
		Profiler.SetSmoothingSpeed(cfg.smoothingSpeed)
	end
	if cfg.smoothingDecay then
		Profiler.SetSmoothingDecay(cfg.smoothingDecay)
	end
	if cfg.textUpdateInterval then
		Profiler.SetTextUpdateInterval(cfg.textUpdateInterval)
	end
	if cfg.systemMemoryMode then
		Profiler.SetSystemMemoryMode(cfg.systemMemoryMode)
	end
	if cfg.compensateOverhead ~= nil then
		Profiler.SetOverheadCompensation(cfg.compensateOverhead)
	end
	return Profiler
end

-- Time helper for quick instrumentation
function Profiler.Time(systemName, componentName, func)
	if not func then
		-- Called as (componentName, func)
		func = componentName
		componentName = systemName
		systemName = "default"
	end
	Profiler.StartSystem(systemName)
	Profiler.StartComponent(componentName)
	local result = func()
	Profiler.EndComponent(componentName)
	Profiler.EndSystem(systemName)
	return result
end

-- Manual reload helper for development
function Profiler.Reload()
	print("🔄 Manual reload requested...")
	Profiler.Unload()
	print("🚀 Run 'lua_load example.lua' again to get fresh profiler!")
end

-- Cleanup helper (enhanced for complete reloading) -------------------------
function Profiler.Unload()
	print("🧹 Unloading Microprofiler...")

	Profiler.Shutdown()
	ProfilerCallbacksRegistered = false

	-- Reset internal state so a fresh load starts clean
	print("   ✓ Internal state reset")

	-- Clear global instance
	Shared.ProfilerInstance = nil
	Shared.ProfilerLoaded = false
	ProfilerLoaded = false
	print("   ✓ Global state cleared")

	-- Remove ALL profiler packages from cache (improved pattern)
	local packages = {
		"Profiler",
		"Profiler.profiler",
		"Profiler.microprofiler",
		"Profiler.ui_top",
		"Profiler.ui_body",
		"Profiler.Shared",
		"Profiler.config",
		"Profiler.Main",
	}

	for _, pkg in ipairs(packages) do
		if package.loaded[pkg] then
			package.loaded[pkg] = nil
			print(string.format("   ✓ Unloaded package: %s", pkg))
		end
	end
	print("   ✓ Package cache cleared")

	print("✅ Microprofiler completely unloaded. Ready for fresh reload.")
end

-- Mark library as loaded (global retained mode)
ProfilerLoaded = true
Shared.ProfilerLoaded = true
Shared.ProfilerInstance = Profiler

print("🚀 Microprofiler singleton initialized!")

-- Return shared instance (store in global for retention) --------------------
return Profiler

end)
__bundle_register("Profiler.profiler", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[
    Core Profiler Module - Simplified Microprofiler
    Coordinates the microprofiler and UI modules
    Used by: Main.lua
]]

-- Imports
local Shared = require("Profiler.Shared") --[[ Imported by: Main ]]
local config = require("Profiler.config")
local MicroProfiler = require("Profiler.microprofiler") --[[ Imported by: profiler ]]
local UITop = require("Profiler.ui_top") --[[ Imported by: profiler ]]
local UIBody = require("Profiler.ui_body_simple") --[[ Imported by: profiler ]]

-- Module declaration
local ProfilerCore = {}

-- Local constants / utilities -------- (Lua 5.4 compatible)
local TOP_BAR_HEIGHT = 60 -- Increased to match ui_top.lua

-- Local variables
local isVisible = config.visible or false
local isInitialized = false

-- Private helpers --------------------

local function initialize()
	if isInitialized then
		return
	end

	-- Initialize UI modules
	UITop.Initialize()
	UIBody.Initialize()

	isInitialized = true
end

local function shutdown()
	if not isInitialized and not isVisible then
		-- Even if we never initialized, make sure runtime data is cleared
		MicroProfiler.Disable()
		MicroProfiler.Reset()
		UIBody.SetVisible(false)
		Shared.ProfilerEnabled = false
		return
	end

	MicroProfiler.Disable()
	MicroProfiler.Reset()
	UIBody.SetVisible(false)
	Shared.ProfilerEnabled = false
	isVisible = false
	isInitialized = false
end

function ProfilerCore.Init()
	initialize()
	return ProfilerCore
end

function ProfilerCore.Shutdown()
	shutdown()
end

-- Public API -------------------------

function ProfilerCore.SetVisible(visible)
	if not isInitialized then
		initialize()
	end

	isVisible = visible
	Shared.ProfilerEnabled = visible

	if visible then
		-- Set RecordingStartTime when profiling starts for fixed coordinate system
		if not Shared.RecordingStartTime and globals and globals.RealTime then
			Shared.RecordingStartTime = globals.RealTime()
			print(string.format("📍 Profiler: RecordingStartTime set to %.6f", Shared.RecordingStartTime))
		end
		MicroProfiler.Enable()
	else
		MicroProfiler.Disable()
		-- Reset RecordingStartTime when profiling stops so next session starts fresh
		Shared.RecordingStartTime = nil
	end

	UIBody.SetVisible(visible)
end

function ProfilerCore.ToggleVisibility()
	ProfilerCore.SetVisible(not isVisible)
	return isVisible
end

function ProfilerCore.IsVisible()
	return isVisible
end

-- Manual profiling API (for custom threads)
function ProfilerCore.Begin(name)
	if not isVisible then
		return
	end
	-- Check if paused via UITop module
	if not isInitialized then
		initialize()
	end
	if UITop.IsPaused() then
		return -- Don't start manual profiling when paused
	end
	MicroProfiler.BeginCustomThread(name)
end

function ProfilerCore.End(name)
	if not isVisible then
		return
	end
	-- Check if paused via UITop module
	if not isInitialized then
		initialize()
	end
	if UITop.IsPaused() then
		return -- Don't end manual profiling when paused
	end

	-- Require name to match Begin
	if not name or name == "" then
		print("❌ Profiler.End(): name is required and must match Begin(name)")
		return
	end

	MicroProfiler.EndCustomThread(name)
end

-- Legacy API support (keeping for compatibility)
function ProfilerCore.StartSystem(name)
	local scopeName = "System: " .. name
	ProfilerCore.Begin(scopeName)
end

function ProfilerCore.EndSystem(name)
	local scopeName = "System: " .. name
	ProfilerCore.End(scopeName)
end

function ProfilerCore.StartComponent(name)
	ProfilerCore.Begin(name)
end

function ProfilerCore.EndComponent(name)
	ProfilerCore.End(name)
end

-- Simplified system API
function ProfilerCore.BeginSystem(name)
	local scopeName = "System: " .. name
	ProfilerCore.Begin(scopeName)
end

function ProfilerCore.StopSystem(name)
	local scopeName = "System: " .. name
	ProfilerCore.End(scopeName)
end

-- New minimalist API
function ProfilerCore.Start(name)
	ProfilerCore.Begin(name)
end

function ProfilerCore.Finish(name)
	ProfilerCore.End(name)
end

-- Pause/Resume controls
function ProfilerCore.TogglePause()
	if not isInitialized then
		initialize()
	end

	local wasPaused = UITop.IsPaused()
	UITop.SetPaused(not wasPaused)
	return not wasPaused
end

function ProfilerCore.IsPaused()
	if not isInitialized then
		return false
	end
	return UITop.IsPaused()
end

-- Body visibility controls
function ProfilerCore.ToggleBody()
	if not isInitialized then
		initialize()
	end
	return UIBody.ToggleVisible()
end

function ProfilerCore.SetBodyVisible(visible)
	if not isInitialized then
		initialize()
	end
	UIBody.SetVisible(visible)
end

function ProfilerCore.IsBodyVisible()
	if not isInitialized then
		return false
	end
	return UIBody.IsVisible()
end

-- Config helpers (simplified)
function ProfilerCore.SetSortMode(mode)
	config.sortMode = mode
end

function ProfilerCore.SetWindowSize(size)
	config.windowSize = math.max(1, math.min(300, size))
end

function ProfilerCore.SetSmoothingSpeed(speed)
	config.smoothingSpeed = math.max(1, math.min(50, speed))
end

function ProfilerCore.SetSmoothingDecay(decay)
	config.smoothingDecay = math.max(1, math.min(50, decay))
end

function ProfilerCore.SetTextUpdateInterval(interval)
	config.textUpdateInterval = math.max(1, interval)
end

function ProfilerCore.SetSystemMemoryMode(mode)
	config.systemMemoryMode = mode
end

function ProfilerCore.SetOverheadCompensation(enabled)
	-- Placeholder for future implementation
end

-- Reset profiler state
function ProfilerCore.Reset()
	MicroProfiler.Reset()
	if isInitialized then
		UITop.Initialize()
		UIBody.Initialize()
	end
end

-- Main draw function
function ProfilerCore.Draw()
	if not isVisible then
		return
	end
	if not isInitialized then
		initialize()
	end

	-- Update frame counter
	Shared.CurrentFrame = Shared.CurrentFrame + 1

	-- Check for body toggle request from UI
	if Shared.BodyToggleRequested then
		ProfilerCore.ToggleBody()
		Shared.BodyToggleRequested = false
	end

	-- Update and draw top bar
	UITop.Update()
	UITop.Draw()

	-- Draw body whenever there's data (simple system)
	if UIBody.IsVisible() then
		local profilerData = MicroProfiler.GetProfilerData()
		UIBody.Draw(profilerData, TOP_BAR_HEIGHT)
	end

	-- Store last draw time
	Shared.LastDrawTime = globals.RealTime()
end

-- Get profiler data for external use
function ProfilerCore.GetMainTimeline()
	return MicroProfiler.GetMainTimeline()
end

function ProfilerCore.GetCustomThreads()
	return MicroProfiler.GetCustomThreads()
end

function ProfilerCore.GetCallStack()
	return MicroProfiler.GetCallStack()
end

function ProfilerCore.GetProfilerData()
	return MicroProfiler.GetProfilerData()
end

function ProfilerCore.GetStats()
	return MicroProfiler.GetStats()
end

-- Debug functions
function ProfilerCore.PrintStats()
	MicroProfiler.PrintStats()
end

function ProfilerCore.PrintTimeline(maxDepth)
	MicroProfiler.PrintTimeline(maxDepth)
end

-- Camera controls for body
function ProfilerCore.ResetCamera()
	if not isInitialized then
		initialize()
	end
	UIBody.ResetCamera()
end

function ProfilerCore.SetZoom(zoom)
	if not isInitialized then
		initialize()
	end
	UIBody.SetZoom(zoom)
end

function ProfilerCore.GetZoom()
	if not isInitialized then
		return 1.0
	end
	return UIBody.GetZoom()
end

-- Measurement mode (tick vs frame)
function ProfilerCore.SetMeasurementMode(mode)
	if mode == "tick" or mode == "frame" then
		Shared.MeasurementMode = mode
		-- RecordingStartTime is now set when profiling starts, not when mode changes
	end
end

function ProfilerCore.GetMeasurementMode()
	return Shared.MeasurementMode or "frame"
end

-- Initialize if visible by default
if isVisible then
	initialize()
	MicroProfiler.Enable()
end

return ProfilerCore

end)
__bundle_register("Profiler.ui_body_simple", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[
    Simple UI Body Module - Virtual Profiler Board
    All elements positioned on fixed coordinate system, then board is transformed
]]

-- Imports
local Shared = require("Profiler.Shared") --[[ Imported by: profiler ]]
local UILayout = require("Profiler.ui_layout")
local UIRender = require("Profiler.ui_render")

-- Module declaration
local UIBody = {}

-- Constants
local BOARD_WIDTH = 2000 -- Virtual board width in pixels
local BOARD_HEIGHT = 2000 -- Virtual board height in pixels
local FUNCTION_HEIGHT = 20 -- Height of each function bar
local FUNCTION_SPACING = 2 -- Spacing between function levels
local SCRIPT_HEADER_HEIGHT = 25 -- Height of script headers
local SCRIPT_SPACING = 10 -- Spacing between scripts
local TIME_SCALE = 50000 -- Pixels per second (horizontal scale) - makes 1ms = 50px
local RULER_HEIGHT = 30 -- Height of time ruler at top of body

-- Global state (retained mode)
local boardOffsetX = 0 -- Camera position on virtual board
local boardOffsetY = 0 -- Camera position on virtual board
local boardZoom = 1.0 -- Zoom level of the board
local isDragging = false
local lastMouseX, lastMouseY = 0, 0
local currentTopBarHeight = 60 -- Current top bar height (updated each frame)

-- External APIs
local draw = draw
local input = input
local MOUSE_LEFT = MOUSE_LEFT or 107
local KEY_Q = KEY_Q or 18
local KEY_E = KEY_E or 20

-- Safely require external globals library (provides RealTime, FrameTime)
local globals = nil -- External globals library (RealTime, FrameTime)
local ok, globalsModule = pcall(require, "globals")
if ok then
	globals = globalsModule
end

-- Helper functions
-- Use globals.RealTime() directly

-- Convert time to board X coordinate
-- startTime is the reference for the current visible window (usually dataStartTime)
local function timeToBoardX(time, startTime)
	return (time - startTime) * TIME_SCALE
end

-- Convert board coordinates to screen coordinates
-- X is zoom-scaled, Y is NOT zoom-scaled (fixed vertical layout)
local function boardToScreen(boardX, boardY)
	local screenX = (boardX - boardOffsetX) * boardZoom
	-- Y is in screen pixels, not board units - NO zoom scaling on Y axis
	local screenY = currentTopBarHeight + RULER_HEIGHT + boardY
	return screenX, screenY
end

-- Convert screen coordinates to board coordinates
local function screenToBoard(screenX, screenY)
	local boardX = (screenX / boardZoom) + boardOffsetX
	local boardY = (screenY / boardZoom) + boardOffsetY
	return boardX, boardY
end

-- Draw a function bar on the virtual board
local function drawFunctionOnBoard(func, boardX, boardY, boardWidth, screenW, screenH)
	if not func.startTime or not func.endTime or not draw then
		return
	end

	-- Convert board coordinates to screen coordinates
	local screenX, screenY = boardToScreen(boardX, boardY)
	local screenWidth = boardWidth * boardZoom
	-- Y is NOT zoom-scaled - fixed pixel height
	local screenHeight = FUNCTION_HEIGHT

	-- Only draw if visible on screen (use actual screen bounds)
	if
		screenX + screenWidth > 0
		and screenX < screenW
		and screenY + screenHeight > currentTopBarHeight
		and screenY < screenH
	then
		-- Draw function bar
		draw.Color(100, 150, 200, 180)
		draw.FilledRect(
			math.floor(screenX),
			math.floor(screenY),
			math.floor(screenX + screenWidth),
			math.floor(screenY + screenHeight)
		)

		-- Draw vertical grid lines on function bar (segment by milliseconds)
		local duration = func.endTime - func.startTime
		local gridInterval = 0.001 -- 1ms grid
		if duration > 0.01 then
			local gridStart = math.ceil(func.startTime / gridInterval) * gridInterval
			local gridTime = gridStart
			local gridCount = 0
			while gridTime < func.endTime and gridCount < 100 do
				local gridBoardX = timeToBoardX(gridTime, func.startTime) + boardX
				local gridScreenX, _ = boardToScreen(gridBoardX, 0)

				if gridScreenX >= screenX and gridScreenX <= screenX + screenWidth then
					draw.Color(255, 255, 255, 30)
					draw.Line(
						math.floor(gridScreenX),
						math.floor(screenY),
						math.floor(gridScreenX),
						math.floor(screenY + screenHeight)
					)
				end

				gridTime = gridTime + gridInterval
				gridCount = gridCount + 1
			end
		end

		-- Draw border
		draw.Color(255, 255, 255, 100)
		draw.OutlinedRect(
			math.floor(screenX),
			math.floor(screenY),
			math.floor(screenX + screenWidth),
			math.floor(screenY + screenHeight)
		)

		-- Draw function name if it fits (positioned on board, then transformed)
		local name = func.name or "unknown"
		if screenWidth > 50 and screenHeight > 12 then
			-- Position text on board, then transform to screen
			local textBoardX = boardX + 4
			local textBoardY = boardY + 2
			local textScreenX, textScreenY = boardToScreen(textBoardX, textBoardY)

			draw.Color(255, 255, 255, 255)
			draw.Text(math.floor(textScreenX), math.floor(textScreenY), name)
		end

		-- Draw duration if there's space (positioned on board, then transformed)
		if screenWidth > 120 and screenHeight > 24 then
			local durationMs = duration * 1000 -- ms
			local durationText = string.format("%.3fms", durationMs)

			-- Position duration text on board, then transform to screen
			local durationBoardX = boardX + 4
			local durationBoardY = boardY + FUNCTION_HEIGHT - 12
			local durationScreenX, durationScreenY = boardToScreen(durationBoardX, durationBoardY)

			draw.Color(255, 255, 100, 255)
			draw.Text(math.floor(durationScreenX), math.floor(durationScreenY), durationText)
		end
	end
end

-- Draw a script section on the virtual board
local function drawScriptOnBoard(scriptName, functions, boardY, dataStartTime, dataEndTime, screenW, screenH)
	if not draw then
		return boardY
	end

	-- Calculate script bounds
	local scriptStartTime = math.huge
	local scriptEndTime = -math.huge

	for _, func in ipairs(functions) do
		if func.startTime and func.endTime then
			scriptStartTime = math.min(scriptStartTime, func.startTime)
			scriptEndTime = math.max(scriptEndTime, func.endTime)
		end
	end

	-- Draw script header - FIXED PIXEL HEIGHT (not zoom-scaled)
	if scriptStartTime ~= math.huge and scriptEndTime ~= -math.huge then
		local headerBoardX = timeToBoardX(scriptStartTime, dataStartTime)
		local headerBoardWidth = timeToBoardX(scriptEndTime, dataStartTime) - headerBoardX
		local headerBoardY = boardY

		-- Convert to screen coordinates
		local headerScreenX, headerScreenY = boardToScreen(headerBoardX, headerBoardY)
		local headerScreenWidth = headerBoardWidth * boardZoom
		local headerScreenHeight = SCRIPT_HEADER_HEIGHT -- Fixed pixel height, no zoom

		-- Only draw if visible (check both horizontal and vertical bounds)
		if
			headerScreenX + headerScreenWidth > 0
			and headerScreenX < screenW
			and headerScreenY + headerScreenHeight > currentTopBarHeight
			and headerScreenY < screenH
		then
			-- Draw header background (all coordinates from board transform)
			draw.Color(60, 120, 60, 200)
			draw.FilledRect(
				math.floor(headerScreenX),
				math.floor(headerScreenY),
				math.floor(headerScreenX + headerScreenWidth),
				math.floor(headerScreenY + headerScreenHeight)
			)

			-- Draw header border (all coordinates from board transform)
			draw.Color(255, 255, 255, 200)
			draw.OutlinedRect(
				math.floor(headerScreenX),
				math.floor(headerScreenY),
				math.floor(headerScreenX + headerScreenWidth),
				math.floor(headerScreenY + headerScreenHeight)
			)

			-- Draw script name (positioned on board, then transformed)
			if headerScreenHeight > 12 then
				-- Position script name on board, then transform to screen
				local nameBoardX = headerBoardX + 4
				local nameBoardY = headerBoardY + 4
				local nameScreenX, nameScreenY = boardToScreen(nameBoardX, nameBoardY)

				draw.Color(255, 255, 255, 255)
				draw.Text(math.floor(nameScreenX), math.floor(nameScreenY), scriptName)

				-- Function count (positioned on board, then transformed)
				local countText = string.format("(%d functions)", #functions)
				local countBoardX = headerBoardX + headerBoardWidth - 80
				local countBoardY = headerBoardY + 4
				local countScreenX, countScreenY = boardToScreen(countBoardX, countBoardY)

				draw.Text(math.floor(countScreenX), math.floor(countScreenY), countText)
			end
		end
	end

	boardY = boardY + SCRIPT_HEADER_HEIGHT + FUNCTION_SPACING

	-- Draw functions with stacking
	local stackLevels = {} -- Track occupied time ranges at each Y level

	for i, func in ipairs(functions) do
		if func.startTime and func.endTime then
			local boardX = timeToBoardX(func.startTime, dataStartTime)
			local boardWidth = timeToBoardX(func.endTime, dataStartTime) - boardX

			-- Find available Y level
			local level = 0
			local foundLevel = false

			while not foundLevel do
				local conflictFound = false

				if stackLevels[level] then
					for _, occupiedRange in ipairs(stackLevels[level]) do
						if not (func.endTime <= occupiedRange.startTime or func.startTime >= occupiedRange.endTime) then
							conflictFound = true
							break
						end
					end
				end

				if not conflictFound then
					if not stackLevels[level] then
						stackLevels[level] = {}
					end
					table.insert(stackLevels[level], { startTime = func.startTime, endTime = func.endTime })
					foundLevel = true
				else
					level = level + 1
				end
			end

			-- Calculate Y position on board
			local functionBoardY = boardY + (level * (FUNCTION_HEIGHT + FUNCTION_SPACING))

			-- Draw function on board
			drawFunctionOnBoard(func, boardX, functionBoardY, boardWidth, screenW, screenH)
		end
	end

	-- Calculate new Y position after all levels
	local maxLevel = 0
	for level, _ in pairs(stackLevels) do
		maxLevel = math.max(maxLevel, level)
	end
	boardY = boardY + ((maxLevel + 1) * (FUNCTION_HEIGHT + FUNCTION_SPACING))

	return boardY + SCRIPT_SPACING
end

-- Draw fractal time ruler with tick/frame boundaries as primary grid
local function drawTimeRuler(screenW, screenH, topBarHeight, dataStartTime, dataEndTime)
	if not draw then
		return
	end

	-- Ruler background
	draw.Color(30, 30, 30, 255)
	draw.FilledRect(0, topBarHeight, screenW, topBarHeight + RULER_HEIGHT)

	-- Measurement mode
	local mode = Shared.MeasurementMode or "frame"

	-- Get frame/tick time
	local frameTime = (globals and globals.FrameTime and globals.FrameTime()) or 0.015
	if frameTime <= 0 then
		frameTime = 0.015
	end

	-- PRIMARY GRID: Tick/Frame boundaries (bold lines with T/F labels)
	local framePixelSpacing = frameTime * TIME_SCALE * boardZoom
	local shouldDrawFrameBoundaries = framePixelSpacing >= 3

	-- dataStartTime is already aligned to first frame boundary by caller
	local tickStart = dataStartTime

	if shouldDrawFrameBoundaries then
		local tickTime = tickStart
		local tickIndex = 0
		local lastDrawnX = -1000

		while tickTime <= dataEndTime + frameTime and tickIndex < 1000 do
			local boardX = timeToBoardX(tickTime, dataStartTime)
			local screenX, _ = boardToScreen(boardX, 0)
			local intScreenX = math.floor(screenX + 0.5)

			-- Only draw if on screen and not too close to last line
			if screenX >= -10 and screenX <= screenW + 10 and (intScreenX - lastDrawnX) >= 2 then
				-- Bold tick/frame boundary line
				draw.Color(150, 150, 200, 255)
				draw.Line(intScreenX, topBarHeight, intScreenX, topBarHeight + RULER_HEIGHT)

				-- Extend through content area
				draw.Color(100, 100, 150, 80)
				draw.Line(intScreenX, topBarHeight + RULER_HEIGHT, intScreenX, screenH)

				-- Label with T# or F# (always show, based on tick index from start)
				if framePixelSpacing >= 25 then
					local label
					if mode == "tick" then
						label = string.format("T%d", tickIndex)
					else
						label = string.format("F%d", tickIndex)
					end
					draw.Color(200, 200, 255, 255)
					draw.Text(intScreenX + 2, topBarHeight + 2, label)
				end

				lastDrawnX = intScreenX
			end

			tickTime = tickTime + frameTime
			tickIndex = tickIndex + 1
		end
	end

	-- SECONDARY GRID: Time subdivisions with CLEAN distinct labels
	-- Show absolute time from recording start (never duplicates)

	local minPixelSpacing = 40 -- Wider spacing for cleaner labels
	local minInterval = 0.0001 -- 100µs minimum

	-- Pick ONE best interval based on zoom
	local targetPixelSpacing = 60
	local bestInterval = minInterval
	local base = minInterval

	while base < 10.0 do
		for _, scale in ipairs({ 1, 2, 5 }) do
			local mag = base * scale
			local pixelSpacing = mag * TIME_SCALE * boardZoom
			if pixelSpacing >= minPixelSpacing and pixelSpacing <= 120 then
				if
					math.abs(pixelSpacing - targetPixelSpacing)
					< math.abs(bestInterval * TIME_SCALE * boardZoom - targetPixelSpacing)
				then
					bestInterval = mag
				end
			end
		end
		base = base * 10
	end

	local interval = bestInterval
	local pixelsPerInterval = interval * TIME_SCALE * boardZoom

	-- Only draw if spacing is reasonable
	if pixelsPerInterval >= minPixelSpacing then
		-- Start from first interval mark at or after dataStartTime
		local firstMark = math.ceil(dataStartTime / interval) * interval
		local time = firstMark
		local lastLabelEndX = -1000

		while time <= dataEndTime and time - dataStartTime < 100.0 do
			local boardX = timeToBoardX(time, dataStartTime)
			local screenX, _ = boardToScreen(boardX, 0)

			if screenX >= -10 and screenX <= screenW + 10 then
				local intScreenX = math.floor(screenX + 0.5)

				-- Subdivision line
				draw.Color(100, 100, 100, 120)
				draw.Line(intScreenX, topBarHeight, intScreenX, topBarHeight + RULER_HEIGHT)
				draw.Color(80, 80, 80, 30)
				draw.Line(intScreenX, topBarHeight + RULER_HEIGHT, intScreenX, screenH)

				-- ABSOLUTE time from recording start (distinct values)
				local absoluteTime = time - dataStartTime
				local label

				-- Clean distinct intervals: 1,2,3 or 10,20,30 or 100,200,300
				local timeInMs = absoluteTime * 1000
				local timeInUs = absoluteTime * 1000000

				if interval >= 0.01 then
					-- Milliseconds: show whole numbers when >= 10ms
					if timeInMs >= 10 then
						label = string.format("%dms", math.floor(timeInMs + 0.5))
					else
						label = string.format("%.1fms", timeInMs)
					end
				else
					-- Microseconds: show whole numbers when >= 10µs
					if timeInUs >= 10 then
						label = string.format("%dµs", math.floor(timeInUs + 0.5))
					else
						label = string.format("%.1fµs", timeInUs)
					end
				end

				-- Draw label if not overlapping
				local estimatedWidth = #label * 7 + 10
				if (intScreenX - lastLabelEndX) > estimatedWidth then
					draw.Color(180, 180, 200, 220)
					draw.Text(intScreenX + 2, topBarHeight + 15, label)
					lastLabelEndX = intScreenX + estimatedWidth
				end
			end

			time = time + interval
		end
	end
end

-- Handle input for board navigation
local function handleBoardInput(screenW, screenH, topBarHeight)
	if not input or not input.GetMousePos then
		return
	end

	local pos = input.GetMousePos()
	local mx, my = pos[1] or 0, pos[2] or 0

	-- Only handle input in body area
	if my < topBarHeight then
		return
	end

	local bodyMy = my - topBarHeight

	-- Handle dragging - move the board
	local currentlyDragging = input.IsButtonDown and input.IsButtonDown(MOUSE_LEFT)

	if currentlyDragging and not isDragging then
		-- Start drag
		isDragging = true
		lastMouseX = mx
		lastMouseY = bodyMy
	elseif currentlyDragging and isDragging then
		-- Continue drag - move board in opposite direction of mouse
		local deltaX = mx - lastMouseX
		local deltaY = bodyMy - lastMouseY

		-- Calculate new offset
		local newOffsetX = boardOffsetX - (deltaX / boardZoom)
		local newOffsetY = boardOffsetY - (deltaY / boardZoom)

		-- Clamp Y offset - prevent scrolling zones ABOVE top bar
		-- Maximum Y offset is 0 (negative values = scroll down, positive = scroll up over top bar)
		newOffsetY = math.min(0, newOffsetY)

		boardOffsetX = newOffsetX
		boardOffsetY = newOffsetY

		lastMouseX = mx
		lastMouseY = bodyMy
	elseif not currentlyDragging and isDragging then
		-- End drag
		isDragging = false
	end

	-- Handle zoom with Q/E keys - zoom towards mouse position
	if input.IsButtonDown then
		local qPressed = input.IsButtonDown(KEY_Q)
		local ePressed = input.IsButtonDown(KEY_E)

		if qPressed or ePressed then
			local oldZoom = boardZoom

			if qPressed then
				boardZoom = boardZoom * 1.1 -- Zoom in
			elseif ePressed then
				boardZoom = boardZoom / 1.1 -- Zoom out
			end

			-- Clamp zoom based on RealTime precision
			-- Lua doubles have ~15-17 significant digits
			-- At 4722s, smallest delta is ~0.0001s (100μs precision)
			-- Max useful zoom: 3px = 0.0001s * TIME_SCALE * zoom
			-- zoom = 3 / (0.0001 * 50000) = 0.6 is too low
			-- Use 100μs precision -> max zoom ~1000x for 3px spacing at 100μs
			local maxZoom = 1000.0
			boardZoom = math.max(0.01, math.min(maxZoom, boardZoom))

			-- Zoom towards mouse position - keep the point under mouse cursor fixed
			-- Convert mouse screen position to board position BEFORE zoom change
			local mouseBoardX = (mx / oldZoom) + boardOffsetX
			local mouseBoardY = (bodyMy / oldZoom) + boardOffsetY

			-- Adjust offsets so the same board point stays under the mouse cursor
			local newOffsetX = mouseBoardX - (mx / boardZoom)
			local newOffsetY = mouseBoardY - (bodyMy / boardZoom)

			-- Clamp Y offset - prevent scrolling zones ABOVE top bar
			newOffsetY = math.min(0, newOffsetY)

			-- Apply offsets
			boardOffsetX = newOffsetX
			boardOffsetY = newOffsetY
		end
	end
end

-- Public API
function UIBody.Initialize()
	boardOffsetX = 0
	boardOffsetY = 0
	boardZoom = 1.0
	isDragging = false
	print("🎨 UIBody initialized - TIME_SCALE = 50000 px/s (1ms = 50px)")
end

function UIBody.SetVisible(visible)
	Shared.UIBodyVisible = visible
end

function UIBody.IsVisible()
	return Shared.UIBodyVisible or false
end

function UIBody.ToggleVisible()
	local newVisibility = not (Shared.UIBodyVisible or false)
	UIBody.SetVisible(newVisibility)
	return newVisibility
end

function UIBody.Draw(profilerData, topBarHeight)
	if not draw or not profilerData then
		return
	end

	local screenW, screenH = draw.GetScreenSize()

	-- Draw background
	draw.Color(20, 20, 20, 240)
	draw.FilledRect(0, topBarHeight, screenW, screenH)

	-- Get frame time
	local frameTime = (globals and globals.FrameTime and globals.FrameTime()) or 0.015
	if frameTime <= 0 then
		frameTime = 0.015
	end

	-- SLIDING WINDOW APPROACH: Show last N frames/ticks worth of time
	-- Calculate time range from ACTUAL work data (oldest to newest)
	local dataStartTime = math.huge
	local dataEndTime = -math.huge

	if profilerData.scriptTimelines then
		for _, scriptData in pairs(profilerData.scriptTimelines) do
			if scriptData.functions then
				for _, func in ipairs(scriptData.functions) do
					if func.startTime and func.endTime then
						dataStartTime = math.min(dataStartTime, func.startTime)
						dataEndTime = math.max(dataEndTime, func.endTime)
					end
				end
			end
		end
	end

	-- Fallback if no data
	if dataStartTime == math.huge then
		if globals and globals.RealTime then
			local now = globals.RealTime()
			dataStartTime = now - (66 * frameTime) -- Last 66 frames
			dataEndTime = now
		else
			dataStartTime = 0
			dataEndTime = 66 * frameTime
		end
	end

	-- Add padding to the right (show extra time after last work)
	local padding = frameTime * 5 -- Show 5 extra frames worth of space
	dataEndTime = dataEndTime + padding

	-- Align to frame boundary (origin is OLDEST work, not recording start)
	local alignedOrigin = math.floor(dataStartTime / frameTime) * frameTime

	-- Create dual-zone layout
	local layout = UILayout.CreateLayout(profilerData, topBarHeight, screenH)

	-- Draw tick zone
	if layout.tickZone then
		UIRender.DrawZone(
			layout.tickZone,
			"tick",
			0,
			layout.tickZone.startY,
			screenW,
			screenH,
			alignedOrigin,
			dataEndTime,
			frameTime,
			boardZoom,
			boardOffsetX,
			boardOffsetY
		)
	end

	-- Draw frame zone
	if layout.frameZone then
		UIRender.DrawZone(
			layout.frameZone,
			"frame",
			0,
			layout.frameZone.startY,
			screenW,
			screenH,
			alignedOrigin,
			dataEndTime,
			frameTime,
			boardZoom,
			boardOffsetX,
			boardOffsetY
		)
	end

	-- Debug info
	draw.Color(255, 255, 255, 255)
	draw.Text(
		10,
		screenH - 65,
		string.format("Zoom: %.2fx | Offset: X=%.0f Y=%.0f", boardZoom, boardOffsetX, boardOffsetY)
	)
	draw.Text(10, screenH - 50, "Drag=Pan (X+Y) | Q=Zoom In | E=Zoom Out")
	draw.Text(10, screenH - 35, string.format("Time: %.3fs - %.3fs", alignedOrigin, dataEndTime))

	-- Handle input
	handleBoardInput(screenW, screenH, topBarHeight)
end

-- Camera controls
function UIBody.ResetCamera()
	boardOffsetX = 0
	boardOffsetY = 0
	boardZoom = 1.0
end

function UIBody.SetZoom(newZoom)
	local maxZoom = 1000.0 -- Based on RealTime precision (~100μs)
	boardZoom = math.max(0.01, math.min(maxZoom, newZoom))
end

function UIBody.GetZoom()
	return boardZoom
end

function UIBody.CenterOnTimestamp(timestamp)
	-- Center the board on the given timestamp
	if timestamp then
		-- Calculate board X position for this timestamp
		local boardX = timestamp * TIME_SCALE
		-- Center it on screen (assuming screen width of ~1920)
		boardOffsetX = boardX - (960 / boardZoom)
	end
end

return UIBody

end)
__bundle_register("Profiler.ui_render", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[
    UI Render Module - Clean Dual-Zone Profiler Rendering
    Separates tick work and frame work with independent rulers
]]

local Shared = require("Profiler.Shared")

local UIRender = {}

-- Constants
local TIME_SCALE = 50000 -- 1ms = 50px
local RULER_HEIGHT = 30
local ZONE_LABEL_HEIGHT = 20
local WORK_HEIGHT = 18
local WORK_INDENT = 20
local PROCESS_SPACING = 25

-- Helper: timeToBoardX
local function timeToBoardX(time, origin)
	return (time - origin) * TIME_SCALE
end

-- Clamp coordinates to valid integer range
local function clampCoord(value)
	if not value or value ~= value then
		return 0
	end -- NaN check
	if value == math.huge or value == -math.huge then
		return 0
	end -- Infinity check
	return math.max(-100000, math.min(100000, math.floor(value + 0.5)))
end

-- Draw ruler for a zone (tick or frame)
local function drawRuler(mode, screenX, screenY, screenW, dataStart, dataEnd, frameTime, zoom, offsetX)
	if not draw then
		return
	end

	-- Background (clamped)
	local x1 = clampCoord(screenX)
	local y1 = clampCoord(screenY)
	local x2 = clampCoord(screenX + screenW)
	local y2 = clampCoord(screenY + RULER_HEIGHT)

	draw.Color(30, 30, 30, 255)
	draw.FilledRect(x1, y1, x2, y2)

	-- Frame boundaries (T0, T1 or F0, F1)
	local visibleStartTime = dataStart + (offsetX / TIME_SCALE)
	if visibleStartTime < dataStart then
		visibleStartTime = dataStart
	end

	local visibleEndTime = visibleStartTime + (screenW / (TIME_SCALE * zoom))
	if visibleEndTime > dataEnd then
		visibleEndTime = dataEnd
	end

	local firstBoundary = math.floor(visibleStartTime / frameTime) * frameTime
	local boundaryTime = firstBoundary
	local index = math.floor((boundaryTime - dataStart) / frameTime)

	while boundaryTime <= visibleEndTime and index < 200 do
		local boardX = timeToBoardX(boundaryTime, dataStart)
		local screenXPos = screenX + (boardX * zoom) - (offsetX * zoom)

		if screenXPos >= screenX - 10 and screenXPos <= screenX + screenW + 10 then
			local intX = clampCoord(screenXPos)
			local lineY1 = clampCoord(screenY)
			local lineY2 = clampCoord(screenY + RULER_HEIGHT)

			-- Boundary line
			draw.Color(150, 150, 200, 255)
			draw.Line(intX, lineY1, intX, lineY2)

			-- Label
			local label = mode == "tick" and string.format("T%d", index) or string.format("F%d", index)
			draw.Color(200, 200, 255, 255)
			draw.Text(intX + 2, lineY1 + 2, label)
		end

		boundaryTime = boundaryTime + frameTime
		index = index + 1
	end

	-- Time subdivisions (clean intervals) - support microsecond precision
	local minPixelSpacing = 40
	local targetPixelSpacing = 60
	local bestInterval = 0.000001 -- Start from 1µs
	local base = 0.000001 -- 1 microsecond

	while base < 10.0 do
		for _, scale in ipairs({ 1, 2, 5 }) do
			local mag = base * scale
			local pixelSpacing = mag * TIME_SCALE * zoom
			if pixelSpacing >= minPixelSpacing and pixelSpacing <= 120 then
				if
					math.abs(pixelSpacing - targetPixelSpacing)
					< math.abs(bestInterval * TIME_SCALE * zoom - targetPixelSpacing)
				then
					bestInterval = mag
				end
			end
		end
		base = base * 10
	end

	if bestInterval * TIME_SCALE * zoom >= minPixelSpacing then
		local firstMark = math.ceil(visibleStartTime / bestInterval) * bestInterval
		local time = firstMark
		local lastLabelX = -1000 -- Track last label position to prevent overlap
		local maxIterations = 200 -- Safety limit

		local iterations = 0
		while time <= visibleEndTime and iterations < maxIterations do
			iterations = iterations + 1

			local boardX = timeToBoardX(time, dataStart)
			local screenXPos = screenX + (boardX * zoom) - (offsetX * zoom)

			-- Only draw if visible on screen
			if screenXPos >= screenX - 10 and screenXPos <= screenX + screenW + 10 then
				local intX = clampCoord(screenXPos)
				local lineY1 = clampCoord(screenY)
				local lineY2 = clampCoord(screenY + RULER_HEIGHT)

				-- Subdivision line
				draw.Color(100, 100, 100, 120)
				draw.Line(intX, lineY1, intX, lineY2)

				-- Frame-relative time label (time since start of current frame)
				local frameNumber = math.floor((time - dataStart) / frameTime)
				local frameStartTime = dataStart + (frameNumber * frameTime)
				local timeInFrame = time - frameStartTime

				local label
				if bestInterval >= 0.001 then
					-- Milliseconds
					label = string.format("%.1fms", timeInFrame * 1000)
				elseif bestInterval >= 0.000001 then
					-- Microseconds
					label = string.format("%.0fµs", timeInFrame * 1000000)
				else
					-- Nanoseconds (extreme zoom)
					label = string.format("%.0fns", timeInFrame * 1000000000)
				end

				-- Only draw label if not overlapping with previous label
				local labelWidth = #label * 7 + 10
				if (intX - lastLabelX) > labelWidth then
					draw.Color(180, 180, 200, 220)
					draw.Text(intX + 2, lineY1 + 15, label)
					lastLabelX = intX
				end
			end

			time = time + bestInterval
		end
	end
end

-- Draw work bar hierarchically
local function drawWork(work, depth, screenX, screenY, dataStart, zoom, offsetX, zoneEndY)
	if not draw or not work.startTime or not work.endTime then
		return
	end

	local boardX = timeToBoardX(work.startTime, dataStart)
	local boardWidth = timeToBoardX(work.endTime, dataStart) - boardX

	local screenXPos = screenX + (boardX * zoom) - (offsetX * zoom)
	local screenWidth = boardWidth * zoom

	-- Only draw if visible
	if screenXPos + screenWidth < screenX or screenXPos > screenX + 1920 then
		return
	end

	-- Indent based on depth
	local indentX = depth * WORK_INDENT

	-- Work bar
	draw.Color(80, 200, 120, 255)
	draw.FilledRect(
		math.floor(screenXPos + indentX),
		math.floor(screenY),
		math.floor(screenXPos + screenWidth),
		math.floor(screenY + WORK_HEIGHT)
	)

	-- Border
	draw.Color(255, 255, 255, 200)
	draw.OutlinedRect(
		math.floor(screenXPos + indentX),
		math.floor(screenY),
		math.floor(screenXPos + screenWidth),
		math.floor(screenY + WORK_HEIGHT)
	)

	-- Label
	if screenWidth > 30 then
		draw.Color(255, 255, 255, 255)
		draw.Text(math.floor(screenXPos + indentX + 2), math.floor(screenY + 2), work.name or "Work")
	end

	-- Grid line extension (only within zone)
	if screenY + WORK_HEIGHT < zoneEndY then
		local lineX = clampCoord(screenXPos)
		local lineY1 = clampCoord(screenY + WORK_HEIGHT)
		local lineY2 = clampCoord(zoneEndY)

		draw.Color(80, 80, 80, 30)
		draw.Line(lineX, lineY1, lineX, lineY2)
	end
end

-- Render a zone (tick or frame)
function UIRender.DrawZone(
	zone,
	mode,
	screenX,
	screenY,
	screenW,
	screenH,
	dataStart,
	dataEnd,
	frameTime,
	zoom,
	offsetX,
	offsetY
)
	if not draw or not zone then
		return
	end

	-- Apply vertical offset for scrolling
	local adjustedScreenY = screenY - (offsetY * zoom)

	-- Clamp all coordinates
	local x1 = clampCoord(screenX)
	local y1 = clampCoord(adjustedScreenY)
	local x2 = clampCoord(screenX + screenW)
	local y2 = clampCoord(adjustedScreenY + zone.height)
	local labelY2 = clampCoord(adjustedScreenY + ZONE_LABEL_HEIGHT)

	-- Zone background
	draw.Color(25, 25, 25, 255)
	draw.FilledRect(x1, y1, x2, y2)

	-- Zone label
	draw.Color(40, 40, 40, 255)
	draw.FilledRect(x1, y1, x2, labelY2)
	draw.Color(200, 200, 220, 255)
	local label = mode == "tick" and "TICK-BASED WORK" or "FRAME-BASED WORK"
	draw.Text(x1 + 10, y1 + 4, label)

	-- Ruler
	drawRuler(mode, screenX, adjustedScreenY + ZONE_LABEL_HEIGHT, screenW, dataStart, dataEnd, frameTime, zoom, offsetX)

	-- Work items (hierarchical)
	if zone.work then
		for _, item in ipairs(zone.work) do
			local workY = adjustedScreenY + ZONE_LABEL_HEIGHT + RULER_HEIGHT + (item.y - zone.workY)
			drawWork(item.work, item.depth, screenX, workY, dataStart, zoom, offsetX, adjustedScreenY + zone.height)
		end
	end

	-- Zone border
	local borderX1 = clampCoord(screenX)
	local borderY1 = clampCoord(adjustedScreenY)
	local borderX2 = clampCoord(screenX + screenW)
	local borderY2 = clampCoord(adjustedScreenY + zone.height)

	draw.Color(60, 60, 80, 255)
	draw.OutlinedRect(borderX1, borderY1, borderX2, borderY2)
end

return UIRender

end)
__bundle_register("Profiler.Shared", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[
    Shared Module - Shared Runtime Data (Retained Mode)
    Used by: Main.lua, profiler.lua, microprofiler.lua, ui_body.lua, ui_body_simple.lua, ui_top.lua
    
    This module provides shared retained state to prevent multiple instances.
    NOTE: This is NOT the external 'globals' library that provides RealTime() and FrameTime().
    That external library is safely required in each module that needs it.
    
    File renamed from globals.lua to Shared.lua to avoid naming conflicts.
]]

-- Module declaration
local Shared = {
	-- Profiler shared data
	ProfilerEnabled = false,
	CurrentFrame = 0,
	LastDrawTime = 0,
	BodyToggleRequested = false,

	-- UI State
	UITopVisible = true, -- Top bar visible by default
	UIBodyVisible = true, -- Body visible by default

	-- Measurement mode
	MeasurementMode = "frame", -- "tick" or "frame"
	RecordingStartTime = nil, -- Start time for tick counting

	-- Instance control
	ProfilerInstance = nil,
	ProfilerLoaded = false,

	-- Debug settings
	DEBUG = false,
}

-- Return the module
return Shared

end)
__bundle_register("Profiler.ui_layout", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[
    UI Layout Module - Dual-Zone Profiler Layout (Tick + Frame)
    Implements Roblox-style MicroProfiler layout with hierarchical stacking
]]

local Shared = require("Profiler.Shared")

local UILayout = {}

-- Constants
local RULER_HEIGHT = 30
local ZONE_HEADER_HEIGHT = 20
local PROCESS_HEADER_HEIGHT = 18
local WORK_HEIGHT = 16
local WORK_SPACING = 2
local TIME_SCALE = 50000 -- px/s (1ms = 50px)

-- Layout work items with horizontal packing (Roblox style)
-- Items share lanes when they don't overlap in time
local function layoutHorizontalPacking(workItems, startY)
	local layout = {}
	local stackLevels = {} -- Track occupied time ranges at each Y level

	-- Flatten all work items (including children)
	local allWork = {}
	local function flatten(work)
		table.insert(allWork, work)
		if work.children and #work.children > 0 then
			for _, child in ipairs(work.children) do
				flatten(child)
			end
		end
	end

	for _, work in ipairs(workItems) do
		flatten(work)
	end

	-- Sort by start time to ensure stable packing order
	table.sort(allWork, function(a, b)
		local aStart = a.startTime or -math.huge
		local bStart = b.startTime or -math.huge
		if aStart == bStart then
			local aEnd = a.endTime or aStart
			local bEnd = b.endTime or bStart
			return aEnd < bEnd
		end
		return aStart < bStart
	end)

	-- Find available Y level for each work item based on time overlap
	for _, work in ipairs(allWork) do
		if work.startTime and work.endTime then
			local level = 0
			local foundLevel = false

			-- Find first available level where this work doesn't overlap
			while not foundLevel do
				local conflictFound = false

				if stackLevels[level] then
					for _, occupiedRange in ipairs(stackLevels[level]) do
						-- Check if time ranges overlap
						if not (work.endTime <= occupiedRange.startTime or work.startTime >= occupiedRange.endTime) then
							conflictFound = true
							break
						end
					end
				end

				if not conflictFound then
					-- This level is available
					if not stackLevels[level] then
						stackLevels[level] = {}
					end
					table.insert(stackLevels[level], { startTime = work.startTime, endTime = work.endTime })
					foundLevel = true
				else
					level = level + 1
				end
			end

			-- Add to layout
			table.insert(layout, {
				work = work,
				y = startY + (level * (WORK_HEIGHT + WORK_SPACING)),
				height = WORK_HEIGHT,
				depth = 0, -- No indentation in horizontal packing
			})
		end
	end

	-- Calculate total height
	local maxLevel = 0
	for level, _ in pairs(stackLevels) do
		maxLevel = math.max(maxLevel, level)
	end
	local endY = startY + ((maxLevel + 1) * (WORK_HEIGHT + WORK_SPACING))

	return layout, endY
end

-- Group work by measurement mode (tick vs frame)
function UILayout.GroupByMode(profilerData)
	local tickWork = {}
	local frameWork = {}

	if profilerData.scriptTimelines then
		for processName, processData in pairs(profilerData.scriptTimelines) do
			if processData.functions and #processData.functions > 0 then
				for _, work in ipairs(processData.functions) do
					local mode = work.measurementMode or "frame"
					if mode == "tick" then
						table.insert(tickWork, work)
					else
						table.insert(frameWork, work)
					end
				end
			end
		end
	end

	return tickWork, frameWork
end

-- Create layout for entire profiler (tick zone + frame zone)
function UILayout.CreateLayout(profilerData, topBarHeight, screenH)
	local layout = {
		tickZone = nil,
		frameZone = nil,
		totalHeight = 0,
	}

	local tickWork, frameWork = UILayout.GroupByMode(profilerData)

	local currentY = topBarHeight

	-- TICK ZONE
	if #tickWork > 0 then
		local zoneY = currentY
		currentY = currentY + ZONE_HEADER_HEIGHT + RULER_HEIGHT

		local workLayout, endY = layoutHorizontalPacking(tickWork, currentY)

		layout.tickZone = {
			startY = zoneY,
			rulerY = zoneY + ZONE_HEADER_HEIGHT,
			workY = currentY,
			endY = endY,
			height = endY - zoneY,
			work = workLayout,
			mode = "tick",
		}

		currentY = endY + 20 -- Spacing between zones
	end

	-- FRAME ZONE
	if #frameWork > 0 then
		local zoneY = currentY
		currentY = currentY + ZONE_HEADER_HEIGHT + RULER_HEIGHT

		local workLayout, endY = layoutHorizontalPacking(frameWork, currentY)

		layout.frameZone = {
			startY = zoneY,
			rulerY = zoneY + ZONE_HEADER_HEIGHT,
			workY = currentY,
			endY = endY,
			height = endY - zoneY,
			work = workLayout,
			mode = "frame",
		}

		currentY = endY
	end

	layout.totalHeight = currentY - topBarHeight

	return layout
end

return UILayout

end)
__bundle_register("Profiler.ui_top", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[
    UI Top Module - Timeline and Controls
    Handles the top bar with frame timeline and control buttons
    Used by: profiler.lua
]]

-- Imports
local Shared = require("Profiler.Shared") --[[ Imported by: profiler ]]
local config = require("Profiler.config")

-- Safely require external globals library (provides RealTime, FrameTime)
local globals = nil -- External globals library (RealTime, FrameTime)
local ok, globalsModule = pcall(require, "globals")
if ok then
	globals = globalsModule
end

-- Module declaration
local UITop = {}

-- Local constants / utilities -------- (Lua 5.4 compatible)
local TIMELINE_HEIGHT = 60 -- Increased height for better button fit
local FRAME_RECORDING_TIME = 5 -- 5 seconds of frames (reduced for stability)
local BUTTON_WIDTH = 70 -- Slightly smaller buttons
local BUTTON_HEIGHT = 18
local BUTTON_SPACING = 3
local MAX_FRAMES = 150 -- Reduced frame storage

-- Global variables for retained mode (not local)
frames = frames or {} -- { dt = frameTime, timestamp = realTime }
selectedFrameIndex = selectedFrameIndex or nil
isPaused = isPaused or false
isCapturingKey = isCapturingKey or false
bodyKey = bodyKey or nil
totalRecordedTime = totalRecordedTime or 0

-- Key constants with fallbacks (Lua 5.4 compatible)
local KEY_P = KEY_P or 26
local MOUSE_LEFT = MOUSE_LEFT or 107

-- Click state tracking (global for retained mode)
clickState = clickState or {}
keyState = keyState or {}

-- Font (global for retained mode)
topBarFont = topBarFont or nil

-- Private helpers --------------------

-- Safe coordinate conversion for drawing API
local function safeCoord(value)
	-- Handle NaN, infinity, and nil
	if not value or value ~= value or value == math.huge or value == -math.huge then
		return 0
	end

	-- Convert to integer and clamp to reasonable screen bounds
	local coord = math.floor(value + 0.5)
	return math.max(-10000, math.min(10000, coord))
end

-- Safe rectangle drawing with bounds checking
local function safeFilledRect(x1, y1, x2, y2)
	if not draw or not draw.FilledRect then
		return
	end

	local sx1 = safeCoord(x1)
	local sy1 = safeCoord(y1)
	local sx2 = safeCoord(x2)
	local sy2 = safeCoord(y2)

	-- Ensure x1 <= x2 and y1 <= y2
	if sx1 > sx2 then
		sx1, sx2 = sx2, sx1
	end
	if sy1 > sy2 then
		sy1, sy2 = sy2, sy1
	end

	-- Only draw if dimensions are reasonable
	if (sx2 - sx1) > 0 and (sy2 - sy1) > 0 and (sx2 - sx1) < 10000 and (sy2 - sy1) < 10000 then
		draw.FilledRect(sx1, sy1, sx2, sy2)
	end
end

local function initializeFont()
	if not topBarFont and draw and draw.CreateFont then
		-- Create a large, crisp, readable font
		topBarFont = draw.CreateFont("Verdana", 16, 800) -- Much larger and bolder
	end
end

-- Remove these functions - use globals.RealTime() and globals.FrameTime() directly

local function clamp(value, min, max)
	if value < min then
		return min
	end
	if value > max then
		return max
	end
	return value
end

-- Smart click handling (prevents double clicks, captures hold-to-press)
local function consumeClick(id, hovered)
	if not input then
		return false
	end

	local currentlyDown = hovered and input.IsButtonDown and input.IsButtonDown(MOUSE_LEFT)
	local wasDown = clickState[id] or false

	-- Smart detection: capture click OR sudden hold
	if currentlyDown and not wasDown then
		-- Either clicked OR started holding (both count as press)
		clickState[id] = true
		return true
	elseif not currentlyDown and wasDown then
		-- Released - reset state for next interaction
		clickState[id] = false
	end

	return false
end

-- Smart key handling (prevents double presses, captures hold-to-press)
local function consumeKeyPress(keyId)
	if not input then
		return false
	end

	local currentlyDown = input.IsButtonDown and input.IsButtonDown(keyId)
	local wasDown = keyState[keyId] or false

	-- Smart detection: capture press OR sudden hold
	if currentlyDown and not wasDown then
		-- Either pressed OR started holding (both count as press)
		keyState[keyId] = true
		return true
	elseif not currentlyDown and wasDown then
		-- Released - reset state for next interaction
		keyState[keyId] = false
	end

	return false
end

-- Get key name for display
local function getKeyName(keyId)
	if keyId >= 11 and keyId <= 36 then
		return string.char(string.byte("A") + (keyId - 11))
	end
	if keyId >= 2 and keyId <= 10 then
		local d = (keyId - 1) % 10
		return tostring(d)
	end

	local names = {
		[65] = "SPACE",
		[64] = "ENTER",
		[67] = "TAB",
		[70] = "ESC",
		[79] = "LSHIFT",
		[80] = "RSHIFT",
		[83] = "LCTRL",
		[84] = "RCTRL",
		[81] = "LALT",
		[82] = "RALT",
	}

	if names[keyId] then
		return names[keyId]
	end
	if keyId >= 92 and keyId <= 103 then
		return "F" .. tostring(keyId - 91)
	end
	return tostring(keyId)
end

-- Update frame recording
local function updateFrameRecording()
	if isPaused then
		return
	end

	local dt = 0
	local timestamp = 0
	if globals then
		if globals.FrameTime then
			dt = globals.FrameTime()
		end
		if globals.RealTime then
			timestamp = globals.RealTime()
		end
	end

	-- Add new frame
	table.insert(frames, {
		dt = dt,
		timestamp = timestamp,
		index = #frames + 1,
	})

	totalRecordedTime = totalRecordedTime + dt

	-- Remove frames older than FRAME_RECORDING_TIME seconds
	while totalRecordedTime > FRAME_RECORDING_TIME and #frames > 0 do
		local removedFrame = table.remove(frames, 1)
		totalRecordedTime = totalRecordedTime - removedFrame.dt

		-- Adjust selected frame index
		if selectedFrameIndex then
			selectedFrameIndex = selectedFrameIndex - 1
			if selectedFrameIndex <= 0 then
				selectedFrameIndex = nil
			end
		end
	end

	-- Also enforce MAX_FRAMES limit for performance
	while #frames > MAX_FRAMES do
		local removedFrame = table.remove(frames, 1)
		totalRecordedTime = totalRecordedTime - removedFrame.dt

		-- Adjust selected frame index
		if selectedFrameIndex then
			selectedFrameIndex = selectedFrameIndex - 1
			if selectedFrameIndex <= 0 then
				selectedFrameIndex = nil
			end
		end
	end

	-- Auto-select latest frame if none selected
	if not selectedFrameIndex and #frames > 0 then
		selectedFrameIndex = #frames
	end
end

-- Draw frame pillars (ACTUAL PILLARS - thin and tall)
local function drawFramePillars(screenW)
	if #frames == 0 then
		return
	end

	local maxMs = 33.3 -- ~30 FPS baseline
	local infoWidth = 100 -- Space for left side info
	local buttonSpace = BUTTON_WIDTH + 20 -- Space for right side buttons
	local frameAreaWidth = screenW - infoWidth - buttonSpace
	local frameAreaStart = infoWidth

	if frameAreaWidth <= 0 then
		return -- Not enough space
	end

	-- PILLAR SETUP: Fixed narrow width, spacing controlled
	local pillarWidth = 3 -- Thin pillars!
	local pillarSpacing = 2 -- Gap between pillars
	local totalPillarSpace = pillarWidth + pillarSpacing
	local maxPillars = math.floor(frameAreaWidth / totalPillarSpace)

	-- Only show recent frames that fit
	local startFrame = math.max(1, #frames - maxPillars + 1)
	local x = frameAreaStart

	-- Draw frames as thin pillars (newest frames from left to right)
	for i = startFrame, #frames do
		local frame = frames[i]

		-- Safe validation and calculations
		if frame and frame.dt then
			local ms = frame.dt * 1000

			-- Only proceed if ms is valid
			if ms == ms and ms ~= math.huge and ms ~= -math.huge then
				-- Height based on frame time (taller = slower frame)
				local heightNorm = clamp(ms / maxMs, 0, 1)
				if heightNorm ~= heightNorm then
					heightNorm = 0
				end
				local height = math.max(4, safeCoord(heightNorm * (TIMELINE_HEIGHT - 10)))

				-- Color based on performance (green=good, yellow=ok, red=bad)
				local r, g, b
				if heightNorm < 0.3 then
					-- Good performance - green
					r, g, b = 50, 255, 50
				elseif heightNorm < 0.7 then
					-- OK performance - yellow
					r, g, b = 255, 255, 50
				else
					-- Bad performance - red
					r, g, b = 255, 50, 50
				end

				-- Highlight selected frame
				if selectedFrameIndex == i then
					r = math.min(255, r + 50)
					g = math.min(255, g + 50)
					b = math.min(255, b + 50)
				end

				-- Draw thin pillar
				local rectX = safeCoord(x)
				local rectY = safeCoord(TIMELINE_HEIGHT - height - 2)

				if draw and height > 0 and rectX + pillarWidth < screenW - buttonSpace then
					draw.Color(r, g, b, 255)
					safeFilledRect(rectX, rectY, rectX + pillarWidth, TIMELINE_HEIGHT - 2)

					-- Store click region for interaction
					frame._clickRegion = {
						x = rectX,
						y = rectY,
						w = pillarWidth,
						h = height + 2,
					}
				end

				x = x + totalPillarSpace
			end
		end
	end
end

-- Draw control buttons (stacked vertically on right)
local function drawControls(screenW)
	local buttonX = screenW - BUTTON_WIDTH - 8
	local pauseY = 4
	local bindY = pauseY + BUTTON_HEIGHT + BUTTON_SPACING

	-- Pause/Resume button
	local pauseLabel = isPaused and "Resume [P]" or "Pause [P]"

	if draw then
		-- Pause button background
		draw.Color(45, 45, 45, 255)
		safeFilledRect(buttonX, pauseY, buttonX + BUTTON_WIDTH, pauseY + BUTTON_HEIGHT)
		draw.Color(110, 110, 110, 255)
		draw.OutlinedRect(buttonX, pauseY, buttonX + BUTTON_WIDTH, pauseY + BUTTON_HEIGHT)

		-- Pause button text (integer coordinates)
		draw.Color(230, 230, 230, 255)
		draw.Text(math.floor(buttonX + 4), math.floor(pauseY + 2), pauseLabel)

		-- Keybind button background
		draw.Color(45, 45, 45, 255)
		safeFilledRect(buttonX, bindY, buttonX + BUTTON_WIDTH, bindY + BUTTON_HEIGHT)
		draw.Color(110, 110, 110, 255)
		draw.OutlinedRect(buttonX, bindY, buttonX + BUTTON_WIDTH, bindY + BUTTON_HEIGHT)

		-- Keybind button text (integer coordinates)
		local bindLabel = isCapturingKey and "Press key..." or ("Bind [" .. getKeyName(bodyKey or 25) .. "]")
		draw.Color(230, 230, 230, 255)
		draw.Text(math.floor(buttonX + 4), math.floor(bindY + 2), bindLabel)
	end

	return buttonX, pauseY, bindY
end

-- Handle input
local function handleInput(screenW, buttonX, pauseY, bindY)
	if not input or not input.GetMousePos then
		return
	end

	local pos = input.GetMousePos()
	local mx, my = pos[1] or 0, pos[2] or 0

	-- Button clicks
	local hoveredPause = mx >= buttonX
		and mx <= buttonX + BUTTON_WIDTH
		and my >= pauseY
		and my <= pauseY + BUTTON_HEIGHT
	local hoveredBind = mx >= buttonX and mx <= buttonX + BUTTON_WIDTH and my >= bindY and my <= bindY + BUTTON_HEIGHT

	if consumeClick("pause_button", hoveredPause) then
		isPaused = not isPaused
		-- Sync pause state with microprofiler
		local MicroProfiler = require("Profiler.microprofiler")
		MicroProfiler.SetPaused(isPaused)
		return -- Don't process frame selection when clicking buttons
	end

	if consumeClick("bind_button", hoveredBind) then
		isCapturingKey = true
		return
	end

	-- Frame selection (only when paused and not clicking buttons)
	if isPaused and my >= 0 and my <= TIMELINE_HEIGHT and not hoveredPause and not hoveredBind then
		if consumeClick("frame_select", true) then
			-- Find clicked frame and center body on its time
			for i, frame in ipairs(frames) do
				if frame._clickRegion then
					local region = frame._clickRegion
					if
						mx >= region.x
						and mx <= region.x + region.w
						and my >= region.y
						and my <= region.y + region.h
					then
						selectedFrameIndex = i
						-- Frame selected (timeline centering removed - not implemented)
						break
					end
				end
			end
		end
	end
end

-- Handle key capture and shortcuts
local function handleKeys()
	if not input then
		return
	end

	-- Key capture mode
	if isCapturingKey and input.IsButtonPressed then
		for keyId = 0, 113 do
			if input.IsButtonPressed(keyId) and keyId ~= MOUSE_LEFT then
				bodyKey = keyId
				isCapturingKey = false
				break
			end
		end
	end

	-- Pause shortcut
	if consumeKeyPress(KEY_P) then
		isPaused = not isPaused
		-- Sync pause state with microprofiler
		local MicroProfiler = require("Profiler.microprofiler")
		MicroProfiler.SetPaused(isPaused)
	end

	-- Body visibility shortcut
	if bodyKey and consumeKeyPress(bodyKey) then
		-- This will be handled by the main profiler
		Shared.BodyToggleRequested = true
	end
end

-- Public API -------------------------

function UITop.Initialize()
	initializeFont()
	isPaused = false
	isCapturingKey = false
	bodyKey = 25 -- Default to 'O' key
	selectedFrameIndex = nil
	frames = {}
	totalRecordedTime = 0
end

function UITop.Update()
	updateFrameRecording()
end

function UITop.Draw()
	if not draw then
		return
	end

	local screenW, _ = draw.GetScreenSize()

	-- Set font
	if topBarFont and draw.SetFont then
		draw.SetFont(topBarFont)
	end

	-- Draw background
	draw.Color(18, 18, 18, 200)
	safeFilledRect(0, 0, screenW, TIMELINE_HEIGHT)
	draw.Color(70, 70, 70, 255)
	draw.OutlinedRect(0, 0, screenW, TIMELINE_HEIGHT)

	-- Draw left side info (integer coordinates for crisp text, larger font spacing)
	local dt = 0
	if globals and globals.FrameTime then
		dt = globals.FrameTime()
	end
	local fps = dt > 0 and math.floor(1 / dt + 0.5) or 0
	draw.Color(230, 230, 230, 255)
	draw.Text(8, 6, "FPS: " .. tostring(fps))

	-- Draw profiler status
	local status = isPaused and "PAUSED" or "RECORDING"
	if isPaused then
		draw.Color(255, 200, 0, 255)
	else
		draw.Color(0, 255, 0, 255)
	end
	draw.Text(8, 26, status)

	-- Draw frame count info
	draw.Color(180, 180, 180, 255)
	draw.Text(8, 46, "Frames: " .. tostring(#frames))

	-- Draw frame pillars
	drawFramePillars(screenW)

	-- Draw controls
	local buttonX, pauseY, bindY = drawControls(screenW)

	-- Handle input
	handleInput(screenW, buttonX, pauseY, bindY)
	handleKeys()

	-- Draw selected frame cursor
	if selectedFrameIndex and frames[selectedFrameIndex] and frames[selectedFrameIndex]._clickRegion then
		local region = frames[selectedFrameIndex]._clickRegion
		local cursorX = region.x + region.w / 2
		draw.Color(0, 255, 0, 255)
		safeFilledRect(cursorX - 1, 0, cursorX + 1, TIMELINE_HEIGHT)
	end
end

function UITop.SetPaused(paused)
	isPaused = paused
	-- Also set pause state in microprofiler
	local MicroProfiler = require("Profiler.microprofiler")
	MicroProfiler.SetPaused(paused)
end

function UITop.IsPaused()
	return isPaused
end

function UITop.GetSelectedFrame()
	if selectedFrameIndex and frames[selectedFrameIndex] then
		return frames[selectedFrameIndex]
	end
	return nil
end

function UITop.GetFrames()
	return frames
end

function UITop.SetBodyKey(keyId)
	bodyKey = keyId
end

function UITop.GetBodyKey()
	return bodyKey
end

return UITop

end)
__bundle_register("Profiler.microprofiler", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[
    Microprofiler Module - Automatic Function Hooking
    Implements automatic function profiling like Roblox microprofiler
    Used by: profiler.lua
]]

-- Imports
local Shared = require("Profiler.Shared") --[[ Imported by: profiler ]]

-- Module declaration
local MicroProfiler = {}

-- Local constants / utilities --------
-- Immutable constants (Lua 5.4 compatible)
local PROFILER_SOURCES = {
	"profiler.lua",
	"microprofiler.lua",
	"ui_top.lua",
	"ui_body.lua",
	"Main.lua",
	"globals.lua",
	"config.lua",
	"Profiler.lua", -- Bundled version
}

-- API guard to prevent recursion
local inProfilerAPI = false
local autoHookDesired = false

-- Performance limits (MINIMAL for performance)
local MAX_RECORD_TIME = 5.0 -- Keep records for 5 seconds max (as requested)
local MAX_TIMELINE_SIZE = 66 -- Show last 66 frames/ticks (sliding window)
local MAX_CUSTOM_THREADS = 10 -- Increase custom threads limit
local CLEANUP_INTERVAL = 1.0 -- Clean up every 1 second

-- Global variables for retained mode (not local)
isEnabled = false
isHooked = false
isPaused = isPaused or false -- Add pause state
callStack = callStack or {}
mainTimeline = mainTimeline or {}
customThreads = customThreads or {}
activeNamedScopes = activeNamedScopes or {} -- Map: { [name] = { stack of threads } }
lastCleanupTime = lastCleanupTime or 0

-- Script-separated timelines for better organization
scriptTimelines = scriptTimelines or {} -- { [scriptName] = { functions = {}, name = scriptName } }

-- External APIs (Lua 5.4 compatible)
-- Use external globals library (RealTime, FrameTime) directly since it's globally available

-- Private helpers --------------------

-- Forward declaration so later calls see the local, not a global
local autoDisableIfIdle

-- Use globals.RealTime() directly

-- Get memory usage in KB
local function getMemory()
	return collectgarbage("count")
end

-- Track when profiler was paused for cleanup reference
local pauseStartTime = nil

-- Cleanup old records - ONLY when NOT paused to preserve navigation data
local function cleanupOldRecords()
	-- DON'T cleanup when paused - keep ALL data for navigation
	if isPaused then
		return
	end

	local currentTime = globals.RealTime()

	-- Skip if not enough time has passed
	if currentTime - lastCleanupTime < CLEANUP_INTERVAL then
		return
	end

	lastCleanupTime = currentTime
	local functionsRemoved = 0

	-- Clean main timeline - remove records older than MAX_RECORD_TIME
	local i = 1
	while i <= #mainTimeline do
		local record = mainTimeline[i]
		if record.endTime and (currentTime - record.endTime) > MAX_RECORD_TIME then
			table.remove(mainTimeline, i)
			functionsRemoved = functionsRemoved + 1
		else
			i = i + 1
		end
	end

	-- Clean custom threads
	local j = 1
	while j <= #customThreads do
		local thread = customThreads[j]
		if thread.endTime and (currentTime - thread.endTime) > MAX_RECORD_TIME then
			table.remove(customThreads, j)
			functionsRemoved = functionsRemoved + 1
		else
			j = j + 1
		end
	end

	-- Clean script timelines
	for scriptName, scriptData in pairs(scriptTimelines) do
		local m = 1
		while m <= #scriptData.functions do
			local func = scriptData.functions[m]
			if func.endTime and (currentTime - func.endTime) > MAX_RECORD_TIME then
				table.remove(scriptData.functions, m)
				functionsRemoved = functionsRemoved + 1
			else
				m = m + 1
			end
		end

		-- Remove empty script timelines
		if #scriptData.functions == 0 then
			scriptTimelines[scriptName] = nil
		end
	end

	-- Only report if significant cleanup happened
	if functionsRemoved > 10 then
		print(string.format("🧹 Cleanup: removed %d old functions while running", functionsRemoved))
	end
end

-- Check if we should profile this function (FIXED: Not too aggressive)
local function shouldProfile(info)
	-- Guard against profiler API recursion
	if inProfilerAPI then
		return false
	end

	if not info or not info.short_src then
		return false
	end

	-- Enhanced string matching
	local source = info.short_src
	local name = info.name or ""

	-- Skip built-in Lua functions and C functions FIRST
	if source == "=[C]" or source == "=[string]" or source == "" then
		return false
	end

	-- Skip common built-in function names that cause overhead
	if
		name == "pairs"
		or name == "ipairs"
		or name == "next"
		or name == "type"
		or name == "tostring"
		or name == "tonumber"
		or name == "getmetatable"
		or name == "setmetatable"
		or name == "rawget"
		or name == "rawset"
		or name == "pcall"
		or name == "xpcall"
		or name == "require"
		or name == "sethook"
		or name == "getinfo"
	then
		return false
	end

	-- ONLY skip actual profiler internal functions by name
	if
		name
		and (
			name:find("profileHook", 1, true)
			or name:find("shouldProfile", 1, true)
			or name:find("createFunctionRecord", 1, true)
			or name:find("cleanupOldRecords", 1, true)
			or name:find("enableHook", 1, true)
			or name:find("disableHook", 1, true)
			or name:find("testHook", 1, true)
		)
	then
		return false
	end

	-- COMPLETELY FILTER OUT "Local//Profiler" functions
	-- Use GetScriptName to determine real script
	local scriptName = "Unknown"
	if GetScriptName then
		local fullPath = GetScriptName()
		if fullPath then
			scriptName = fullPath:match("\\([^\\]-)$") or fullPath:match("/([^/]-)$") or fullPath
			if scriptName:match("%.lua$") then
				scriptName = scriptName:gsub("%.lua$", "")
			end
		end
	end

	-- STRICT FILTERING: Only allow actual user scripts, block profiler completely
	if scriptName:find("Profiler", 1, true) or scriptName == "Local" then
		return false -- Skip profiler-related scripts
	end

	-- Allow ALL user scripts (including unknown ones) for auto-hooking
	-- Debug: Show what scripts we're profiling (always show for debugging)
	if scriptName ~= "Unknown" then
		print(string.format("🔍 Auto-profiling script: %s (function: %s)", scriptName, name or "unnamed"))
	end

	-- Skip internal profiler functions by name
	if
		name
		and (
			name:find("MicroProfiler", 1, true)
			or name:find("UITop", 1, true)
			or name:find("UIBody", 1, true)
			or name:find("ProfilerCore", 1, true)
			or name:find("safeCoord", 1, true)
			or name:find("safeFilledRect", 1, true)
		)
	then
		return false
	end

	return true
end

-- Create function record with script separation
local function createFunctionRecord(info)
	local name = info.name or "anonymous"
	local source = info.short_src or "unknown"
	local line = info.linedefined or 0

	-- Use lmaobox GetScriptName() with proper Windows path handling
	local scriptName = "Unknown Script"
	if GetScriptName then
		local fullPath = GetScriptName()
		if fullPath then
			-- Extract filename from Windows path and remove .lua extension for display
			scriptName = fullPath:match("\\([^\\]-)$") or fullPath:match("/([^/]-)$") or fullPath
			if scriptName:match("%.lua$") then
				scriptName = scriptName:gsub("%.lua$", "")
			end
		end
	else
		-- Fallback: Extract script name from source
		scriptName = source:match("[^/\\]+$") or source
		if scriptName == "" or scriptName == "unknown" then
			scriptName = "Unknown Script"
		end
		if scriptName:match("%.lua$") then
			scriptName = scriptName:gsub("%.lua$", "")
		end
	end

	-- Clean up bundled script names
	if scriptName == "Profiler" then
		scriptName = "example" -- User's actual script when bundled
	end

	-- Create a more readable key (Lua 5.4 enhanced)
	local key = name
	if name == "anonymous" then
		key = string.format("%s:%d", scriptName, line)
	end

	return {
		key = key,
		name = name,
		source = source,
		scriptName = scriptName,
		line = line,
		startTime = globals.RealTime(),
		memStart = getMemory(),
		endTime = nil,
		memDelta = 0,
		duration = 0,
		children = {},
	}
end

-- Hook function for automatic profiling (SIMPLIFIED for performance)
local function profileHook(event)
	if not isEnabled or inProfilerAPI then
		return
	end

	-- Skip profiling if paused
	if isPaused then
		return -- Don't profile when paused = instant lag fix
	end

	-- Only cleanup when NOT paused to keep data available for navigation
	local currentTime = globals.RealTime()
	if currentTime - lastCleanupTime > CLEANUP_INTERVAL then
		cleanupOldRecords()
		autoDisableIfIdle()
	end

	-- MINIMAL info gathering for performance
	local info = debug.getinfo(2, "nS")
	if not info then
		return
	end

	if not shouldProfile(info) then
		return
	end

	if event == "call" then
		-- Limit call stack depth to prevent excessive nesting overhead
		if #callStack > 20 then
			return
		end

		local record = createFunctionRecord(info)

		-- Add to parent if we're nested
		if #callStack > 0 then
			table.insert(callStack[#callStack].children, record)
		end

		table.insert(callStack, record)
	elseif event == "return" then
		local record = table.remove(callStack)
		if not record then
			return
		end

		-- Complete the record
		record.endTime = globals.RealTime()
		record.memDelta = getMemory() - record.memStart
		record.duration = record.endTime - record.startTime

		-- Validate timing
		if record.duration < 0 then
			record.duration = 0
		end

		-- If this is a top-level function, add to both main timeline and script timeline
		if #callStack == 0 then
			table.insert(mainTimeline, record)

			-- DEBUG: Print when we add functions to timeline
			if not _timelineDebugCount then
				_timelineDebugCount = 0
			end
			_timelineDebugCount = _timelineDebugCount + 1

			if _timelineDebugCount <= 3 then -- Show first 3 functions added
				print(
					string.format(
						"✅ Added to timeline: %s (%.3fms) from %s",
						record.name or "unnamed",
						record.duration * 1000,
						record.scriptName or "unknown"
					)
				)
			end

			-- Limit timeline size more aggressively
			if #mainTimeline > MAX_TIMELINE_SIZE then
				table.remove(mainTimeline, 1)
			end

			-- Add to script-specific timeline
			local scriptName = record.scriptName
			if not scriptTimelines[scriptName] then
				scriptTimelines[scriptName] = {
					name = scriptName,
					functions = {},
					type = "script",
				}
			end

			-- Add copy to script timeline
			local scriptRecord = {
				key = record.key,
				name = record.name,
				source = record.source,
				scriptName = record.scriptName,
				line = record.line,
				startTime = record.startTime,
				endTime = record.endTime,
				duration = record.duration,
				memDelta = record.memDelta,
				children = record.children, -- Reference to same children
			}
			table.insert(scriptTimelines[scriptName].functions, scriptRecord)

			-- Limit script timeline size
			if #scriptTimelines[scriptName].functions > MAX_TIMELINE_SIZE then
				table.remove(scriptTimelines[scriptName].functions, 1)
			end
		end

		-- Copy to active named scopes if within their timeframe
		for scopeName, scopeStack in pairs(activeNamedScopes) do
			for _, thread in ipairs(scopeStack) do
				if
					record.startTime >= thread.startTime and (not thread.endTime or record.endTime <= thread.endTime)
				then
					-- Create a copy for the custom thread (only if thread isn't full)
					if #thread.children < 100 then -- Limit children per thread
						local copy = {
							key = record.key,
							name = record.name,
							source = record.source,
							line = record.line,
							startTime = record.startTime,
							endTime = record.endTime,
							duration = record.duration,
							memDelta = record.memDelta,
							children = record.children, -- Shallow copy of children
						}
						table.insert(thread.children, copy)
					end
				end
			end
		end
	end
end

-- Enable automatic profiling hook
local function enableHook()
	if not autoHookDesired or isHooked or not isEnabled then
		return
	end

	if not debug or not debug.sethook then
		print("❌ WARNING: debug.sethook is not available. Auto-hooking remains disabled; manual profiling only.")
		return
	end

	local success, err = pcall(function()
		debug.sethook(profileHook, "cr")
	end)

	if not success then
		print("❌ ERROR: Failed to set debug hook: " .. tostring(err))
		print("   Automatic profiling disabled. Manual profiling still works.")
		return
	end

	isHooked = true
	print("✅ Debug hook enabled (manual opt-in)")
end

-- Disable automatic profiling hook
local function disableHook()
	if isHooked then
		debug.sethook(nil, "")
		isHooked = false
	end
end

-- Public API -------------------------

function MicroProfiler.Enable()
	isEnabled = true

	if autoHookDesired then
		enableHook()
	else
		disableHook()
	end
end

function MicroProfiler.Disable()
	isEnabled = false
	disableHook()
end

-- Auto-disable when idle (no data and not paused) - to avoid lingering hooks
function autoDisableIfIdle()
	if not isEnabled or isPaused then
		return
	end
	local hasData = (#mainTimeline > 0) or (#customThreads > 0)
	if not hasData then
		for _ in pairs(scriptTimelines) do
			hasData = true
			break
		end
	end
	if not hasData then
		disableHook()
	end
end

function MicroProfiler.IsEnabled()
	return isEnabled
end

function MicroProfiler.IsHooked()
	return isHooked
end

function MicroProfiler.SetAutoHookEnabled(enabled)
	autoHookDesired = not not enabled
	if not autoHookDesired then
		disableHook()
	elseif isEnabled then
		enableHook()
	end
end

function MicroProfiler.IsAutoHookEnabled()
	return autoHookDesired
end

function MicroProfiler.SetPaused(paused)
	local wasPaused = isPaused
	isPaused = paused

	if paused and not wasPaused then
		-- Just paused - STOP cleanup to preserve data for navigation
		print("⏸️ Profiler PAUSED - recording stopped, data preserved for navigation")
	elseif not paused and wasPaused then
		-- Just resumed - resume cleanup
		print("▶️ Profiler RESUMED - recording started, cleanup resumed")
		-- Ensure hook is enabled when resuming
		if isEnabled and not isHooked then
			enableHook()
		end
	end
end

function MicroProfiler.IsPaused()
	return isPaused
end

-- Manual profiling for custom threads (with API guards and named scope tracking)
function MicroProfiler.BeginCustomThread(name)
	if not isEnabled or inProfilerAPI or isPaused then
		return
	end

	-- DOUBLE CHECK: Make sure we're really not paused
	if isPaused then
		return
	end

	-- Validate name
	if not name or name == "" then
		print("❌ BeginCustomThread: name is required")
		return
	end

	-- Set API guard to prevent recursion
	inProfilerAPI = true

	-- Walk the callstack to find the REAL calling script (not Profiler itself)
	local scriptName = "Manual Thread"
	for level = 3, 10 do
		local info = debug.getinfo(level, "S")
		if not info then
			break
		end
		local source = info.source or ""
		-- Extract script name from source path
		local fileName = source:match("\\([^\\]-)$") or source:match("/([^/]-)$") or source
		if fileName:match("%.lua$") then
			fileName = fileName:gsub("%.lua$", "")
		end
		-- Skip profiler internals, use first user script we find
		if fileName ~= "Profiler" and fileName ~= "" and fileName ~= "[C]" and fileName ~= "[string]" then
			scriptName = fileName
			break
		end
	end

	-- Capture tick/frame context at Begin
	local currentTickCount = (globals and globals.TickCount and globals.TickCount()) or 0
	local currentFrameCount = (globals and globals.FrameCount and globals.FrameCount()) or 0
	local measurementMode = Shared.MeasurementMode or "frame"

	local thread = {
		name = name,
		scriptName = scriptName,
		startTime = globals.RealTime(),
		tickCount = currentTickCount,
		frameCount = currentFrameCount,
		measurementMode = measurementMode,
		memStart = getMemory(),
		endTime = nil,
		memDelta = 0,
		duration = 0,
		children = {},
		type = "custom",
	}

	-- Add to customThreads for cleanup tracking
	table.insert(customThreads, thread)

	-- Limit custom threads more aggressively
	while #customThreads > MAX_CUSTOM_THREADS do
		table.remove(customThreads, 1)
	end

	-- Initialize stack for this name if needed
	if not activeNamedScopes[name] then
		activeNamedScopes[name] = {}
	end

	-- Push thread onto named scope stack
	table.insert(activeNamedScopes[name], thread)

	-- Clear API guard
	inProfilerAPI = false
end

function MicroProfiler.EndCustomThread(name)
	if not isEnabled or inProfilerAPI or isPaused then
		return
	end

	-- DOUBLE CHECK: Make sure we're really not paused
	if isPaused then
		return
	end

	-- Validate name
	if not name or name == "" then
		print("❌ EndCustomThread: name is required")
		return
	end

	-- Set API guard to prevent recursion
	inProfilerAPI = true

	-- Get the stack for this name
	local scopeStack = activeNamedScopes[name]
	if not scopeStack or #scopeStack == 0 then
		print(string.format("❌ EndCustomThread('%s'): No matching Begin found!", name))
		inProfilerAPI = false
		return
	end

	-- Pop thread from named scope stack
	local thread = table.remove(scopeStack)

	-- Clean up empty scope stacks
	if #scopeStack == 0 then
		activeNamedScopes[name] = nil
	end

	thread.endTime = globals.RealTime()
	thread.memDelta = getMemory() - thread.memStart
	thread.duration = thread.endTime - thread.startTime

	-- Validate timing
	if thread.duration < 0 then
		thread.duration = 0
	end

	local threadRecord = {
		key = thread.name,
		name = thread.name,
		source = "manual",
		scriptName = thread.scriptName,
		line = 0,
		startTime = thread.startTime,
		endTime = thread.endTime,
		duration = thread.duration,
		memDelta = thread.memDelta,
		tickCount = thread.tickCount,
		frameCount = thread.frameCount,
		measurementMode = thread.measurementMode,
		children = thread.children,
	}

	-- Check if this thread belongs to a parent scope (any active scope)
	local hasParent = false
	for parentName, parentStack in pairs(activeNamedScopes) do
		if #parentStack > 0 then
			local parentThread = parentStack[#parentStack]
			-- If parent started before this thread, add as child
			if parentThread.startTime < thread.startTime then
				parentThread.children = parentThread.children or {}
				table.insert(parentThread.children, threadRecord)
				hasParent = true
				break
			end
		end
	end

	-- If no parent, add to main timeline
	if not hasParent then
		table.insert(mainTimeline, threadRecord)
		if #mainTimeline > MAX_TIMELINE_SIZE then
			table.remove(mainTimeline, 1)
		end

		-- Organize by PROCESS (extracted from work name), not by script
		-- Extract process from work name: "Physics.Step" -> "Physics", "Network.Poll" -> "Network"
		local processName = thread.name:match("^([^%.]+)") or thread.name or "Other"

		if not scriptTimelines[processName] then
			scriptTimelines[processName] = {
				name = processName,
				functions = {},
				type = "process",
			}
		end
		table.insert(scriptTimelines[processName].functions, threadRecord)
		if #scriptTimelines[processName].functions > MAX_TIMELINE_SIZE then
			table.remove(scriptTimelines[processName].functions, 1)
		end
	end

	-- Clear API guard
	inProfilerAPI = false
end

-- Get profiler data
function MicroProfiler.GetMainTimeline()
	return mainTimeline
end

function MicroProfiler.GetCustomThreads()
	return customThreads
end

function MicroProfiler.GetScriptTimelines()
	return scriptTimelines
end

function MicroProfiler.GetCallStack()
	return callStack
end

function MicroProfiler.GetProfilerData()
	return {
		mainTimeline = mainTimeline,
		customThreads = customThreads,
		scriptTimelines = scriptTimelines,
		callStack = callStack,
		isEnabled = isEnabled,
		isHooked = isHooked,
		manualTimeline = mainTimeline,
	}
end

-- Clear collected data
function MicroProfiler.ClearData()
	mainTimeline = {}
	customThreads = {}
	activeNamedScopes = {}
	callStack = {}
	scriptTimelines = {}
end

-- Reset profiler state
function MicroProfiler.Reset()
	disableHook()
	MicroProfiler.ClearData()
	isEnabled = false
	isHooked = false
	isPaused = false
	inProfilerAPI = false
	lastCleanupTime = 0
end

-- Get statistics
function MicroProfiler.GetStats()
	local totalFunctions = #mainTimeline
	local totalCustomThreads = #customThreads

	-- Count active scopes across all named scopes
	local activeCustoms = 0
	for scopeName, scopeStack in pairs(activeNamedScopes) do
		activeCustoms = activeCustoms + #scopeStack
	end

	local callStackDepth = #callStack

	-- Calculate total time covered
	local totalTime = 0
	local totalMemory = 0

	for _, func in ipairs(mainTimeline) do
		totalTime = totalTime + (func.duration or 0)
		totalMemory = totalMemory + (func.memDelta or 0)
	end

	for _, thread in ipairs(customThreads) do
		totalTime = totalTime + (thread.duration or 0)
		totalMemory = totalMemory + (thread.memDelta or 0)
	end

	-- DEBUG: Print status every 5 seconds (guarded by DEBUG)
	if not _lastStatsTime then
		_lastStatsTime = 0
	end
	local currentTime = globals.RealTime()
	if (Shared and Shared.DEBUG) and (currentTime - _lastStatsTime > 5.0) then
		_lastStatsTime = currentTime
		-- Count script timelines
		local scriptCount = 0
		for _ in pairs(scriptTimelines) do
			scriptCount = scriptCount + 1
		end

		print(
			string.format(
				"📊 Profiler Status: %d functions in timeline, %d script timelines, enabled=%s, hooked=%s",
				totalFunctions,
				scriptCount,
				tostring(isEnabled),
				tostring(isHooked)
			)
		)
	end

	return {
		totalFunctions = totalFunctions,
		totalCustomThreads = totalCustomThreads,
		activeCustoms = activeCustoms,
		callStackDepth = callStackDepth,
		totalTime = totalTime,
		totalMemory = totalMemory,
		isEnabled = isEnabled,
		isHooked = isHooked,
	}
end

-- Debug information
function MicroProfiler.PrintStats()
	local stats = MicroProfiler.GetStats()
	print("=== MicroProfiler Stats ===")
	print("Enabled:", stats.isEnabled)
	print("Hooked:", stats.isHooked)
	print("Main timeline functions:", stats.totalFunctions)
	print("Custom threads:", stats.totalCustomThreads)
	print("Active custom threads:", stats.activeCustoms)
	print("Call stack depth:", stats.callStackDepth)
	-- Using Lua 5.4 enhanced string formatting
	print(string.format("Total time: %.6fs", stats.totalTime))
	print(string.format("Total memory: %.2fKB", stats.totalMemory))
end

-- Print timeline hierarchy (for debugging)
function MicroProfiler.PrintTimeline(maxDepth)
	maxDepth = maxDepth or 3

	local function printNode(node, depth, prefix)
		if depth > maxDepth then
			return
		end

		local indent = string.rep("  ", depth)
		local name = node.name or node.key or "unknown"
		local duration = node.duration and string.format("%.3fms", node.duration * 1000) or "0ms"
		local memory = node.memDelta and string.format("%.1fKB", node.memDelta) or "0KB"

		-- Using Lua 5.4 enhanced string formatting
		print(string.format("%s%s%s | %s | %s", indent, prefix, name, duration, memory))

		if node.children then
			for i, child in ipairs(node.children) do
				local childPrefix = (i == #node.children) and "└─ " or "├─ "
				printNode(child, depth + 1, childPrefix)
			end
		end
	end

	print("=== Main Timeline ===")
	for i, func in ipairs(mainTimeline) do
		local prefix = (i == #mainTimeline) and "└─ " or "├─ "
		printNode(func, 0, prefix)
	end

	print("=== Custom Threads ===")
	for i, thread in ipairs(customThreads) do
		print("Thread: " .. (thread.name or "Unnamed"))
		for j, func in ipairs(thread.children) do
			local prefix = (j == #thread.children) and "└─ " or "├─ "
			printNode(func, 0, prefix)
		end
	end
end

-- Self-initialization
-- Don't auto-enable, let the main profiler control this

return MicroProfiler

end)
__bundle_register("Profiler.config", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[
    Profiler Configuration File
    Modify these values to customize profiler behavior
]]

return {
	-- Display settings
	visible = true, -- Start with profiler visible or hidden
	windowSize = 60, -- Number of frames to average over (1-300)
	sortMode = "size", -- "size" (biggest first), "static" (measurement order), "reverse" (smallest first)
	systemHeight = 48, -- Height of each system bar in pixels
	fontSize = 12, -- Font size for text
	maxSystems = 20, -- Maximum number of systems to display
	textPadding = 6, -- Padding around text in components
	smoothingSpeed = 2.5, -- Percentage of width to move per frame towards target (1-50%, higher = less smooth but more responsive)
	smoothingDecay = 1.5, -- Percentage of width to move per frame when decaying (1-50%, lower = slower decay, peaks stay longer)
	textUpdateInterval = 20, -- Update text every N frames (20 frames = 333ms at 60fps, 3 times per second max)
	systemMemoryMode = "system", -- "system" (actual system memory usage) or "components" (sum of component memory)
}

end)
return __bundle_require("__root")