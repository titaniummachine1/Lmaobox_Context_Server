---@param aimbotFov number Degrees
---@param cameraFov number Degrees
local function DrawFovIndicator(aimbotFov, cameraFov)
	if aimbotFov == 0 or cameraFov == 0 then
		return
	end

	local aimFov, camFov
	aimFov = math.rad(aimbotFov)
	camFov = math.rad(cameraFov / 2)

	local w, h = draw.GetScreenSize()
	local radius = math.tan(aimFov) / math.tan(camFov) * w / 2 * (3 / 4)
	draw.Color(255, 255, 255, 255)
	draw.OutlinedCircle(w // 2, h // 2, radius // 1, 64)
end

--could it be helpfull for drawing the fov circle ?
