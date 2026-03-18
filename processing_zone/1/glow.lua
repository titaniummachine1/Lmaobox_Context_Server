--- I am not smart enough to make this by myself
--- Source: https://www.unknowncheats.me/forum/team-fortress-2-a/700159-simple-glow-outline.html

--- make the lsp stop complaining about nil shit
---@diagnostic disable: param-type-mismatch

--- config
local stencil = 1
local glow = 2

--- enum fallbacks (Lmaobox types do not ship these)
local STENCIL_COMPARE_ALWAYS = (
	rawget(_G, "E_StencilComparisonFunction") and E_StencilComparisonFunction.STENCILCOMPARISONFUNCTION_ALWAYS
) or 8
local STENCIL_COMPARE_NOTEQUAL = (
	rawget(_G, "E_StencilComparisonFunction") and E_StencilComparisonFunction.STENCILCOMPARISONFUNCTION_NOTEQUAL
) or 6
local STENCIL_OP_KEEP = (rawget(_G, "E_StencilOperation") and E_StencilOperation.STENCILOPERATION_KEEP) or 1
local STENCIL_OP_REPLACE = (rawget(_G, "E_StencilOperation") and E_StencilOperation.STENCILOPERATION_REPLACE) or 3
local FRAME_STAGE_RENDER_START = rawget(_G, "FRAME_RENDER_START") or 5
local FRAME_STAGE_RENDER_END = rawget(_G, "FRAME_RENDER_END") or 6

local shouldRenderGlow = false
local lastRenderFrame = -1

--- materials
local m_pMatGlowColor = nil
local m_pMatHaloAddToScreen = nil
local m_pMatBlurX = nil
local m_pMatBlurY = nil
local pRtFullFrame = nil
local m_pGlowBuffer1 = nil
local m_pGlowBuffer2 = nil

local function InitMaterials()
	if m_pMatGlowColor == nil then
		m_pMatGlowColor = materials.Find("dev/glow_color")
	end

	if m_pMatHaloAddToScreen == nil then
		m_pMatHaloAddToScreen = materials.Create(
			"GlowMaterialHalo",
			[[UnlitGeneric
		{
			$basetexture "GlowBuffer1"
			$additive "1"
		}]]
		)
	end

	if m_pMatBlurX == nil then
		m_pMatBlurX = materials.Create(
			"GlowMatBlurX",
			[[BlurFilterX
		{
			$basetexture "GlowBuffer1"
		}]]
		)
	end

	if m_pMatBlurY == nil then
		m_pMatBlurY = materials.Create(
			"GlowMatBlurY",
			[[BlurFilterY
		{
			$basetexture "GlowBuffer2"
		}]]
		)
	end

	if pRtFullFrame == nil then
		pRtFullFrame = materials.FindTexture("_rt_FullFrameFB", "RenderTargets", true)
	end

	if m_pGlowBuffer1 == nil then
		m_pGlowBuffer1 = materials.CreateTextureRenderTarget(
			"GlowBuffer1",
			pRtFullFrame:GetActualWidth(),
			pRtFullFrame:GetActualHeight()
		)
	end

	if m_pGlowBuffer2 == nil then
		m_pGlowBuffer2 = materials.CreateTextureRenderTarget(
			"GlowBuffer2",
			pRtFullFrame:GetActualWidth(),
			pRtFullFrame:GetActualHeight()
		)
	end
end

local STUDIO_RENDER = 0x00000001
local STUDIO_NOSHADOWS = 0x00000080

local function GetGuiColor(option)
	local value = gui.GetValue(option)
	if value == nil then
		return nil
	end
	if value == 255 then
		return nil
	elseif value == -1 then
		return { 1, 1, 1, 1 }
	end

	-- convert signed 32-bit int to unsigned 32-bit
	if value < 0 then
		value = value + 0x100000000
	end

	local r = (value >> 24) & 0xFF
	local g = (value >> 16) & 0xFF
	local b = (value >> 8) & 0xFF
	local a = value & 0xFF

	return { r * 0.003921, g * 0.003921, b * 0.003921, a * 0.003921 }
end

local function GetColor(entity)
	if entity:GetClass() == "CBaseAnimating" then
		local modelName = models.GetModelName(entity:GetModel())
		if string.find(modelName, "ammopack") then
			return { 1.0, 1.0, 1.0, 1.0 }
		elseif string.find(modelName, "medkit") then
			return { 0.15294117647059, 0.96078431372549, 0.32941176470588, 1.0 }
		end
	end

	local color = GetGuiColor("aimbot target color")
	if aimbot.GetAimbotTarget() == entity:GetIndex() and color then
		return color
	end

	if playerlist.GetPriority(entity) > 0 then
		return { 1, 1, 0.0, 1 }
	elseif playerlist.GetPriority(entity) < 0 then
		return { 0, 1, 0.501888, 1 }
	end

	if entity:GetTeamNumber() == 3 then
		return GetGuiColor("blue team color") or { 0.145077, 0.58815, 0.74499, 1 }
	else
		return GetGuiColor("red team color") or { 0.929277, 0.250944, 0.250944, 1 }
	end
end

local function DrawEntities(players)
	for index, color in pairs(players) do
		local player = entities.GetByIndex(index)
		if player then
			render.SetColorModulation(table.unpack(color))
			player:DrawModel(STUDIO_RENDER | STUDIO_NOSHADOWS)
		end
	end
end

local function GetPlayers(outTable)
	local count = 0
	local index = client.GetLocalPlayerIndex()
	for _, player in pairs(entities.FindByClass("CTFPlayer")) do
		if player:GetIndex() ~= index and player:ShouldDraw() and player:IsDormant() == false then
			local color = GetColor(player)
			outTable[player:GetIndex()] = color
			local child = player:GetMoveChild()
			while child ~= nil do
				if gui.GetValue("glow weapon") == 1 and (child:IsShootingWeapon() or child:IsMeleeWeapon()) then
					outTable[child:GetIndex()] = { 1, 1, 1, 1 }
				else
					outTable[child:GetIndex()] = color
				end
				count = count + 1
				child = child:GetMovePeer()
			end

			count = count + 1
		end
	end
	return count
end

local function GetClass(className, outTable)
	local count = 0
	for _, building in pairs(entities.FindByClass(className)) do
		if building:ShouldDraw() and building:IsDormant() == false then
			outTable[building:GetIndex()] = GetColor(building)
			count = count + 1
		end
	end
	return count
end

local function GetViewportSize(view)
	if view then
		-- ViewSetup may expose width/height as numbers or methods depending on runtime
		local vw = view.width
		if type(vw) == "function" then
			vw = vw(view)
		end

		local vh = view.height
		if type(vh) == "function" then
			vh = vh(view)
		end

		if type(vw) == "number" and type(vh) == "number" then
			return vw, vh
		end
	end

	return draw.GetScreenSize()
end

local function RenderGlow(view)
	shouldRenderGlow = false
	local frame = globals.FrameCount()
	if frame == lastRenderFrame then
		return
	end
	lastRenderFrame = frame

	if engine.IsTakingScreenshot() then
		return
	end

	if clientstate.GetNetChannel() == nil then
		return
	end

	InitMaterials()

	local glowEnts = {}
	local entCount = 0
	entCount = entCount + GetPlayers(glowEnts)
	entCount = entCount + GetClass("CObjectSentrygun", glowEnts)
	entCount = entCount + GetClass("CObjectDispenser", glowEnts)
	entCount = entCount + GetClass("CObjectTeleporter", glowEnts)
	entCount = entCount + GetClass("CBaseAnimating", glowEnts)

	if entCount == 0 then
		return
	end

	local origGlowVal = gui.GetValue("glow")
	gui.SetValue("glow", 0)

	local w, h = GetViewportSize(view)
	if render.OverrideDepthEnable then
		render.OverrideDepthEnable(true, false)
	end

	--- Stencil Pass
	do
		render.SetStencilEnable(true)

		render.ForcedMaterialOverride(m_pMatGlowColor)
		local savedBlend = render.GetBlend()
		render.SetBlend(0)

		render.SetStencilReferenceValue(1)
		render.SetStencilCompareFunction(STENCIL_COMPARE_ALWAYS)
		render.SetStencilPassOperation(STENCIL_OP_REPLACE)
		render.SetStencilFailOperation(STENCIL_OP_KEEP)
		render.SetStencilZFailOperation(STENCIL_OP_REPLACE)

		DrawEntities(glowEnts)

		render.SetBlend(savedBlend)
		render.ForcedMaterialOverride(nil)
		render.SetStencilEnable(false)
	end

	--- Color pass
	do
		render.PushRenderTargetAndViewport()

		local r, g, b = render.GetColorModulation()

		local savedBlend = render.GetBlend()
		render.SetBlend(1.0)

		render.SetRenderTarget(m_pGlowBuffer1)
		render.Viewport(0, 0, w, h)

		render.ClearColor3ub(0, 0, 0)
		render.ClearBuffers(true, false, false)

		render.ForcedMaterialOverride(m_pMatGlowColor)

		DrawEntities(glowEnts)

		render.ForcedMaterialOverride(nil)
		render.SetColorModulation(r, g, b)
		render.SetBlend(savedBlend)

		render.PopRenderTargetAndViewport()
	end

	--- Blur pass
	if glow > 0 then
		render.PushRenderTargetAndViewport()
		render.Viewport(0, 0, w, h)

		-- More blur iterations = blurrier (does this word exist?) glow
		for i = 1, glow do
			render.SetRenderTarget(m_pGlowBuffer2)
			render.DrawScreenSpaceRectangle(m_pMatBlurX, 0, 0, w, h, 0, 0, w - 1, h - 1, w, h)
			render.SetRenderTarget(m_pGlowBuffer1)
			render.DrawScreenSpaceRectangle(m_pMatBlurY, 0, 0, w, h, 0, 0, w - 1, h - 1, w, h)
		end

		render.PopRenderTargetAndViewport()
	end

	--- Final pass
	do
		render.SetStencilEnable(true)
		render.SetStencilWriteMask(0)
		render.SetStencilTestMask(0xFF)

		render.SetStencilReferenceValue(1)
		render.SetStencilCompareFunction(STENCIL_COMPARE_NOTEQUAL)

		render.SetStencilPassOperation(STENCIL_OP_KEEP)
		render.SetStencilFailOperation(STENCIL_OP_KEEP)
		render.SetStencilZFailOperation(STENCIL_OP_KEEP)

		--- my code to make the glow work
		--- not used anymore :(
		--[[render.DrawScreenSpaceRectangle(
			m_pMatHaloAddToScreen,
			0, 0,
			w, h,
			0, 0,
			w - 1, h - 1,
			w, h
		)]]

		--- pasted from amalgam
		--- https://github.com/rei-2/Amalgam/blob/fce4740bf3af0799064bf6c8fbeaa985151b708c/Amalgam/src/Features/Visuals/Glow/Glow.cpp#L65
		if stencil > 0 then
			local iSide = (stencil + 1) // 2
			render.DrawScreenSpaceRectangle(m_pMatHaloAddToScreen, -iSide, 0, w, h, 0, 0, w - 1, h - 1, w, h)
			render.DrawScreenSpaceRectangle(m_pMatHaloAddToScreen, 0, -iSide, w, h, 0, 0, w - 1, h - 1, w, h)
			render.DrawScreenSpaceRectangle(m_pMatHaloAddToScreen, iSide, 0, w, h, 0, 0, w - 1, h - 1, w, h)
			render.DrawScreenSpaceRectangle(m_pMatHaloAddToScreen, 0, iSide, w, h, 0, 0, w - 1, h - 1, w, h)
			local iCorner = stencil // 2
			if iCorner > 0 then
				render.DrawScreenSpaceRectangle(
					m_pMatHaloAddToScreen,
					-iCorner,
					-iCorner,
					w,
					h,
					0,
					0,
					w - 1,
					h - 1,
					w,
					h
				)
				render.DrawScreenSpaceRectangle(m_pMatHaloAddToScreen, iCorner, iCorner, w, h, 0, 0, w - 1, h - 1, w, h)
				render.DrawScreenSpaceRectangle(
					m_pMatHaloAddToScreen,
					iCorner,
					-iCorner,
					w,
					h,
					0,
					0,
					w - 1,
					h - 1,
					w,
					h
				)
				render.DrawScreenSpaceRectangle(
					m_pMatHaloAddToScreen,
					-iCorner,
					iCorner,
					w,
					h,
					0,
					0,
					w - 1,
					h - 1,
					w,
					h
				)
			end
		end

		if glow > 0 then
			render.DrawScreenSpaceRectangle(m_pMatHaloAddToScreen, 0, 0, w, h, 0, 0, w - 1, h - 1, w, h)
		end

		render.SetStencilEnable(false)
	end

	if render.OverrideDepthEnable then
		render.OverrideDepthEnable(false, false)
	end

	gui.SetValue("glow", origGlowVal)
end

---@param ctx DrawModelContext
--local function OnDrawModel(ctx) end

local function OnFrameStageNotify(stage)
	if stage == FRAME_STAGE_RENDER_START then
		shouldRenderGlow = true
	end

	if stage == FRAME_STAGE_RENDER_END then
		shouldRenderGlow = true
	end
end

local function OnPostRenderView(view)
	if shouldRenderGlow == false then
		return
	end

	RenderGlow(view)
end

local function OnDoPostScreenSpaceEffects()
	RenderGlow(nil)
end

callbacks.Register("FrameStageNotify", OnFrameStageNotify)
callbacks.Register("PostRenderView", OnPostRenderView)
callbacks.Register("DoPostScreenSpaceEffects", OnDoPostScreenSpaceEffects)
--callbacks.Register("DrawModel", OnDrawModel)
