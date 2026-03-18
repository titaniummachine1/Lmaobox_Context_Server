--[[
    warp.lua   –  lightweight manual tick-shift helper for Lmaobox
    Re-implements the basic "double-tap / dash" mechanic without any key.
    Author: o3-assistant (adapted from Navet's SmoothWarp snippet)

    Exposes:
        warp.CanWarp(need)        → bool
        warp.GetChargedTicks()    → int
        warp.TriggerWarp(ticks)   – request a warp of <ticks> (defaults to 13)
        warp.TriggerCharge(ticks) – start passive recharge until we have <ticks> (defaults max)
        warp.IsWarping()          → bool (currently shifting)
        warp.GetStatus()          → table (status info for display)
]]

local warp = {}

--------------------------------------------------
-- CONFIG
--------------------------------------------------
local DEFAULT_MAX = 24 -- safe default when cvar missing
local CHARGE_RATE = 1 -- ticks gained per choked packet
local RECHARGE_DELAY = 0 -- every tick (can be tuned)
local MAX_WARP_ONCE = 20 -- never request more than this at once (safety)

--------------------------------------------------
-- STATE
--------------------------------------------------
local charged = 0 -- stored ticks
local maxTicks = DEFAULT_MAX -- server limit
local warpTicksLeft = 0 -- ticks still to shift for current warp
local charging = false -- actively re-charging
local lastRechargeTick = 0 -- cooldown for recharge

--------------------------------------------------
local function refreshServerLimit()
	local cvar = client.GetConVar("sv_maxusrcmdprocessticks")
	if cvar and cvar > 0 then
		maxTicks = cvar
	else
		maxTicks = DEFAULT_MAX
	end
end

--------------------------------------------------
-- PUBLIC HELPERS
--------------------------------------------------
function warp.GetChargedTicks()
	return charged
end

function warp.CanWarp(need)
	need = need or 1
	return charged >= need and warpTicksLeft == 0
end

function warp.IsWarping()
	return warpTicksLeft > 0
end

function warp.TriggerWarp(ticks)
	ticks = math.floor(ticks or 13)
	ticks = math.min(ticks, MAX_WARP_ONCE)
	if charged <= 0 then
		return false
	end
	warpTicksLeft = math.min(ticks, charged)
	charging = false -- stop any ongoing recharge
	return true
end

-- Begin passive recharge until we have at least <ticks> stored (or full)
function warp.TriggerCharge(target)
	target = target or maxTicks
	charging = true
	lastRechargeTick = 0
end

-- Get status info for display
function warp.GetStatus()
	return {
		charged = charged,
		maxTicks = maxTicks,
		charging = charging,
		warping = warpTicksLeft > 0,
	}
end

--------------------------------------------------
-- INTERNAL CALLBACKS
--------------------------------------------------

-- Unregister existing callbacks before registering new ones
callbacks.Unregister("SendNetMsg", "warp_refresh_signon")
callbacks.Unregister("CreateMove", "warp_logic")

callbacks.Register("SendNetMsg", "warp_refresh_signon", function(msg)
	-- 6 == signonstate, refresh server tick limit when we join map
	if msg:GetType() == 6 then
		refreshServerLimit()
		charged = 0
		warpTicksLeft = 0
		charging = false
	end
end)

callbacks.Register("CreateMove", "warp_logic", function(cmd)
	-- update server limit occasionally (once a second)
	if globals.TickCount() % 66 == 0 then
		refreshServerLimit()
	end

	-- Get local player for automatic recharging logic
	local localPlayer = entities.GetLocalPlayer()
	local playerAlive = localPlayer and localPlayer:IsAlive()

	-- Automatic recharge when dead or standing still (like SmoothWarp)
	if not playerAlive or (localPlayer and localPlayer:EstimateAbsVelocity():Length() <= 0) then
		if charged < maxTicks and globals.TickCount() >= lastRechargeTick then
			cmd.sendpacket = false
			charged = math.min(charged + CHARGE_RATE, maxTicks)
			lastRechargeTick = globals.TickCount() + RECHARGE_DELAY
		end
		return
	end

	-- Warp in progress: choke outgoing packet until we consumed requested ticks
	if warpTicksLeft > 0 then
		cmd.sendpacket = false
		warpTicksLeft = warpTicksLeft - 1
		charged = math.max(charged - 1, 0)
		return
	end

	-- Passive recharge logic - allow recharging regardless of velocity
	if charging and charged < maxTicks then
		if globals.TickCount() >= lastRechargeTick then
			cmd.sendpacket = false -- choke this packet – adds one charged tick
			charged = math.min(charged + CHARGE_RATE, maxTicks)
			lastRechargeTick = globals.TickCount() + RECHARGE_DELAY
		end
	end
end)

return warp
