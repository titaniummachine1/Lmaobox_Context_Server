-- DEBUG TRACER MODULE
-- Simple execution tracker that logs which numbered probe points execute each tick
-- Easy to enable/disable and completely removes without affecting logic

local DebugTracer = {}

-- Toggle debug tracing on/off
DebugTracer.ENABLED = true

-- Internal state
local lastProbeTick = 0
local lastProbeNumber = nil
local currentTick = 0

-- Probe counter (auto-increments)
DebugTracer.probeCount = 0

-- Mark a numbered execution point
-- Usage: DebugTracer.Probe(1, "function name or location")
function DebugTracer.Probe(probeNumber, label)
	if not DebugTracer.ENABLED then
		return
	end

	local tick = globals.TickCount()

	-- New tick detected, print the last probe from previous tick
	if tick ~= currentTick then
		if lastProbeNumber then
			print(string.format("[DEBUG] Tick %d: Last probe = #%d", lastProbeTick, lastProbeNumber))
		end
		currentTick = tick
	end

	-- Update the last probe for this tick
	lastProbeNumber = probeNumber
	lastProbeTick = tick
end

-- Reset tracer (useful for testing)
function DebugTracer.Reset()
	lastProbeTick = 0
	lastProbeNumber = nil
	currentTick = 0
end

-- Get status info
function DebugTracer.GetStatus()
	return string.format("Tick: %d, Last Probe: %s", lastProbeTick, tostring(lastProbeNumber))
end

return DebugTracer
