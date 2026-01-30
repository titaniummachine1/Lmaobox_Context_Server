--[[ 
  ChargeControl.lua

  Improved mouse control while charging as Demoman in TF2.
  Keeps native sensitivity but adds controller‑style strafing assist.
  Author: Terminator (titaniummachine1)
--]]

-- Constants
local TURN_MULTIPLIER = 1.0 -- extra turn speed factor; 1.0 = native mouse
local MAX_ROTATION_PER_FRAME = 73.04 -- prevent absurd flicks while charging
local SIDE_MOVE_VALUE = 450 -- simulate full strafe speed

-- Utility to normalize yaw into [-180,180]
local function normalizeYaw(yaw)
	yaw = yaw % 360
	if yaw > 180 then
		yaw = yaw - 360
	elseif yaw < -180 then
		yaw = yaw + 360
	end
	return yaw
end

-- Clamp helper
local function clamp(x, lo, hi)
	if x < lo then
		return lo
	end
	if x > hi then
		return hi
	end
	return x
end

-- Main CreateMove callback
local function ChargeControl(cmd)
	local player = entities.GetLocalPlayer()
	if not player or not player:IsAlive() then
		return
	end

	-- Only run while charging
	if not player:InCond(17) then
		return
	end

	-- Mouse delta: negative means moving mouse right → we turn left
	local dx = -cmd.mousedx
	if dx == 0 then
		return
	end

	-- Compute how many degrees to turn
	local _, m_yaw = client.GetConVar("m_yaw")
	local turnAmt = dx * (m_yaw or 0) * TURN_MULTIPLIER
	turnAmt = clamp(turnAmt, -MAX_ROTATION_PER_FRAME, MAX_ROTATION_PER_FRAME)

	-- Fetch current view
	local va = engine.GetViewAngles()
	local newYaw = normalizeYaw(va.yaw + turnAmt)

	-- Apply view angles both client‑side (engine.Set…) and server‑side (cmd:Set…)
	engine.SetViewAngles(EulerAngles(va.pitch, newYaw, va.roll))
	cmd:SetViewAngles(va.pitch, newYaw, va.roll)

	-- Simulate A/D strafe based on turn direction
	if turnAmt > 0 then
		cmd:SetSideMove(SIDE_MOVE_VALUE) -- strafe right
	else
		cmd:SetSideMove(-SIDE_MOVE_VALUE) -- strafe left
	end
end

callbacks.Register("CreateMove", "ChargeControl", ChargeControl)
