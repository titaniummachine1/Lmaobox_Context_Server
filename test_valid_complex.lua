local G = {}

local function normalize(v)
	return v / v:Length()
end

local function calculate()
	assert(G.LocalPlayer, "No LocalPlayer")
	local pos = Vector3(10, 20, 30)
	return normalize(pos)
end

return { calculate = calculate }
