-- Instant Stop Movement Controller
-- Automatically stops player movement by toggling PDA state

-- Module declaration
local InstantStop = {}

-- Local constants / utilities --------
-- Ground check constants
local FL_ONGROUND = 256 -- Player flag for being on ground (Source engine standard)

-- Velocity threshold for re-triggering fast stop
local LOW_VELOCITY_THRESHOLD = 0.5 -- Minimum velocity to re-trigger fast stop

-- State machine states
local STATE_DEFAULT = "default"
local STATE_ENDING_FAST_STOP = "ending_fast_stop"
local STATE_COOLDOWN = "cooldown"

-- Cooldown constants
local COOLDOWN_TICKS = 7 -- Number of ticks to wait in cooldown

-- Private state
local currentState = STATE_DEFAULT
local cooldownTicksRemaining = 0
local wasGroundedLastTick = false

-- Private helpers --------------------

local function hasMovementInput(cmd)
	if not cmd then return false end

	-- Check if player has any input (forward move or side move != 0)
	local forwardMove = cmd:GetForwardMove()
	local sideMove = cmd:GetSideMove()

	return forwardMove ~= 0 or sideMove ~= 0
end

local function getLocalPlayer()
	return entities.GetLocalPlayer()
end

local function isPlayerGrounded(player)
	if not player then return false end

	-- Check if player has FL_ONGROUND flag (m_fFlags netprop)
	local flags = player:GetPropInt("m_fFlags")
	if not flags then return false end

	return (flags & FL_ONGROUND) ~= 0
end

local function getPlayerVelocityLength(player)
	if not player then return 0 end

	-- Try EstimateAbsVelocity first (rule 10: API-first)
	if player.EstimateAbsVelocity then
		local velocity = player:EstimateAbsVelocity()
		if velocity then
			-- Return horizontal velocity length
			return velocity:Length()
		end
	end

	return 0
end

local function triggerFastStop()
	-- Open PDA to stop movement
	client.Command("cyoa_pda_open 1", true)

	-- Switch to ending fast stop state
	currentState = STATE_ENDING_FAST_STOP
end

local function processDefaultState(cmd, player)
	-- If I do have movement input, return (do nothing)
	if hasMovementInput(cmd) then return end

	-- If I do not move and on ground, trigger fast stop
	triggerFastStop()

	-- Additional check: if velocity is smaller than 0.5 length(), trigger fast stop again
	local velocityLength = getPlayerVelocityLength(player)
	if velocityLength < LOW_VELOCITY_THRESHOLD then
		-- Low velocity detected, fast stop already triggered
	end
end

local function processEndingFastStopState()
	-- Send cyoa open 0 command
	client.Command("cyoa_pda_open 0", true)

	-- IMMEDIATELY set cooldown state and full duration
	currentState = STATE_COOLDOWN
	cooldownTicksRemaining = COOLDOWN_TICKS -- Set to full 117 ticks
end

local function processCooldownState(cmd, player)
	-- Check if player started moving during cooldown
	if hasMovementInput(cmd) then
		-- Reset cooldown immediately when moving (physically impossible to walk and fast stop)
		currentState = STATE_DEFAULT
		cooldownTicksRemaining = 0
		return
	end

	-- BLOCKING COOLDOWN: Count down ticks, NO commands sent during this period
	cooldownTicksRemaining = cooldownTicksRemaining - 1

	-- Only return to default state after FULL cooldown duration
	if cooldownTicksRemaining <= 0 then
		currentState = STATE_DEFAULT
		cooldownTicksRemaining = 0 -- Reset counter
	end
end

local function processMovementState(cmd)
	if not cmd then return end

	local player = getLocalPlayer()
	if not player then return end

	local isGrounded = isPlayerGrounded(player)

	-- Reset cooldown when ground state changes
	if isGrounded ~= wasGroundedLastTick then
		currentState = STATE_DEFAULT
		cooldownTicksRemaining = 0
	end
	wasGroundedLastTick = isGrounded

	-- Don't send commands when airborne (obviously)
	if not isGrounded then
		return
	end

	-- BLOCKING COOLDOWN STATE MACHINE:
	-- DEFAULT: Can send commands
	-- ENDING_FAST_STOP: Sends close command, immediately enters cooldown
	-- COOLDOWN: NO commands for full 7 ticks, UNLESS player starts moving (reset cooldown)
	if currentState == STATE_DEFAULT then
		processDefaultState(cmd, player)
	elseif currentState == STATE_ENDING_FAST_STOP then
		processEndingFastStopState()
	elseif currentState == STATE_COOLDOWN then
		processCooldownState(cmd, player)
	end
end

-- Public API -------------------------
callbacks.Register("CreateMove", "InstantStopMovementMonitor", processMovementState)

function InstantStop.GetState()
	return currentState
end

function InstantStop.GetCooldownTicks()
	return cooldownTicksRemaining
end

return InstantStop
