--[[ Made by navet ]]
-- Bundled by luabundle {"version":"1.7.0"}
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
--- just to be sure
filesystem.CreateDirectory("Garlic Bread")

require("src.welcome")
require("src.globals")
require("src.commands")
require("src.settings")
require("src.bitbuf")

--- make them run before tickshift so we dont return before it
require("src.anticheat")

local watermark = require("src.watermark")
local gui = require("src.gui")
local spoof = require("src.spoof_convars")
local spectators = require("src.spectatorlist")
local antiaim = require("src.antiaim")
local aimbot = require("src.aimbot")
local triggerbot = require("src.triggerbot")
local esp = require("src.esp")
local tickshift = require("src.tickshift")
local fakelag = require("src.fakelag")
local visuals = require("src.visuals")
local movement = require("src.movement")
local chams = require("src.chams")
local binds = require("src.binds")
local mats = require("src.custom materials")
local outline = require("src.outline")

require("src.convars")
require("src.background")

local function clamp(value, min, max)
    return math.min(math.max(value, min), max)
end

--- i just dont like having to deal with LSP bullshit
---@param msg NetMessage
local function SendNetMsg(msg)
    local returnval = { ret = true }

    local buffer = BitBuffer()
    buffer:SetCurBit(0)

    local chokedcommands = clientstate:GetChokedCommands()
    local newcmds, backupcmds
    newcmds = 1 + chokedcommands
    newcmds = clamp(newcmds, 0, 15)

    local extracmds = chokedcommands + 1 - newcmds
    backupcmds = math.max(2, extracmds)
    backupcmds = clamp(backupcmds, 0, 7)

    buffer:WriteInt(newcmds, 4)
    buffer:WriteInt(backupcmds, 3)

    returnval.newcmds = newcmds
    returnval.backupcmds = backupcmds

    spoof.SendNetMsg(msg, returnval)
    fakelag.SendNetMsg(msg, buffer, returnval)
    tickshift.SendNetMsg(msg, buffer, returnval)

    --- tables and objects (userdata?) are the only ones lua passes by reference and not by value!
    return returnval.ret
end
callbacks.Register("SendNetMsg", "NETMSG garlic bread", SendNetMsg)

callbacks.Register("Draw", "DRAW garlic bread", function()
    if engine:Con_IsVisible() or engine:IsGameUIVisible() then return end
    if engine:IsTakingScreenshot() and GB_SETTINGS.privacy.stop_when_taking_screenshot then return end

    aimbot.Draw()
    esp.Draw()
    tickshift.Draw()
    antiaim.Draw()
    spectators.Draw()
    watermark.Draw()
    visuals.Draw()
end)

---@param setup ViewSetup
callbacks.Register("RenderView", "RV garlic bread", function(setup)
    if engine:IsTakingScreenshot() and GB_SETTINGS.privacy.stop_when_taking_screenshot then return end
    GB_GLOBALS.nPreAspectRatio = setup.aspectRatio
    visuals.RenderView(setup)
end)

callbacks.Register("FrameStageNotify", "FSN garlic bread", function(stage)
    triggerbot.FrameStageNotify(stage)
    visuals.FrameStageNotify(stage)
    spectators.FrameStageNotify(stage)
end)

---@param context DrawModelContext
callbacks.Register("DrawModel", "DME garlic bread", function(context)
    if engine:IsTakingScreenshot() and GB_SETTINGS.privacy.stop_when_taking_screenshot then return end

    local entity = context:GetEntity()
    local modelname = context:GetModelName()

    fakelag.DrawModel(context, entity, modelname)
    chams.DrawModel(context, entity, modelname)
    outline.DrawModel(context, entity)
end)

---@param info StaticPropRenderInfo
callbacks.Register("DrawStaticProps", "DSP garlic bread", function(info)
    if engine:IsTakingScreenshot() and GB_SETTINGS.privacy.stop_when_taking_screenshot then return end
    mats.DrawStaticProps(info)
end)

---@param event GameEvent
callbacks.Register("FireGameEvent", "GE garlic bread", function(event)
    binds.FireGameEvent(event)
    visuals.FireGameEvent(event)
end)

---@param usercmd UserCmd
callbacks.Register("CreateMove", "CM garlic bread", function(usercmd)
    if engine:IsChatOpen() then return end
    if engine:Con_IsVisible() or engine:IsGameUIVisible() then return end

    local player = entities:GetLocalPlayer()
    if not player then return end
    if not player:IsAlive() then return end

    local weapon = player:GetPropEntity("m_hActiveWeapon")

    triggerbot.CreateMove(usercmd)
    aimbot.CreateMove(usercmd, player, weapon)
    fakelag.CreateMove(usercmd)
    tickshift.CreateMove(usercmd, player)
    antiaim.CreateMove(usercmd)
    movement.CreateMove(usercmd, player)
    binds.CreateMove(usercmd)
    chams.CreateMove()
end)

callbacks.Register("Unload", "UL garlic bread unload", function()
    callbacks.Unregister("SendNetMsg", "NETMSG garlic bread")
    callbacks.Unregister("Draw", "DRAW garlic bread")
    callbacks.Unregister("RenderView", "RV garlic bread")
    callbacks.Unregister("FrameStageNotify", "FSN garlic bread")
    callbacks.Unregister("DrawModel", "DME garlic bread")
    callbacks.Unregister("FireGameEvent", "GE garlic bread")
    callbacks.Unregister("CreateMove", "CM garlic bread")
    callbacks.Unregister("DrawStaticProps", "DSP garlic bread")

    antiaim.unload()
    spectators.unload()
    aimbot.unload()
    tickshift.unload()
    antiaim.unload()
    visuals.unload()
    movement.unload()
    chams.unload()
    binds.unload()
    esp.unload()
    fakelag.unload()
    gui.unload()
    spoof.unload()
    mats.unload()
    watermark.unload()
    outline.unload()

    GB_SETTINGS = nil
    GB_GLOBALS = nil

    collectgarbage("collect")
end)

end)
__bundle_register("src.background", function(require, _LOADED, __bundle_register, __bundle_modules)
local function Background()
	if clientstate:GetNetChannel() then
		Players = entities.FindByClass("CTFPlayer")
		Sentries = entities.FindByClass("CObjectSentrygun")
		Dispensers = entities.FindByClass("CObjectDispenser")
		Teleporters = entities.FindByClass("CObjectTeleporter")
	else
		Players, Sentries, Dispensers, Teleporters = nil, nil, nil, nil
	end
end

callbacks.Register("CreateMove", "CM garlic bread background", Background)
callbacks.Register("Unload", "UNLOAD garlic bread background", function ()
	Players, Sentries, Dispensers, Teleporters = nil, nil, nil, nil
end)
end)
__bundle_register("src.convars", function(require, _LOADED, __bundle_register, __bundle_modules)
local convars = {}

local viewmodel_override = true
local viewmodel_options = {right = 0, up = 0, forward = 0}
--- x forward, y right, z up

local function CMD_ChangeSwayScale(args, num_args)
   if (not args or #args ~= num_args) then return end
   local new_scale = tostring(args[1])
   if (not new_scale) then return end --- convert to a number and then check if its nil in case the user input something that isnt a number
   client.SetConVar("cl_wpn_sway_scale", new_scale)
   SpoofConVar("cl_wpn_sway_scale", new_scale)
end

local function CMD_ChangeSwayInterp(args, num_args)
   if (not args or #args ~= num_args) then return end
   local new_interp = tostring(args[1])
   if (not new_interp) then return end
   client.SetConVar("cl_wpn_sway_interp", new_interp)
   SpoofConVar("cl_wpn_sway_interp", new_interp)
end

local function CMD_ToggleVMOverride()
   viewmodel_override = not viewmodel_override
   if not viewmodel_override then
      client.SetConVar("tf_viewmodels_offset_override", "")
   end
   printc(150, 150, 255, 255, "ViewModel override is now " .. (viewmodel_override and "enabled" or "disabled"))
end

local function CMD_ChangeVMOptions(args, num_args)
   if not args or #args ~= num_args or not viewmodel_override then return end
   local option = tostring(args[1])
   local value = tonumber(args[2])
   if option and value then
      viewmodel_options[option] = value
      local newvalue = string.format("%s %s %s", viewmodel_options.forward, viewmodel_options.right, viewmodel_options.up)
      SpoofConVar("tf_viewmodels_offset_override", "")
      client.SetConVar("tf_viewmodels_offset_override", newvalue)
   end
end

GB_GLOBALS.RegisterCommand("convars->sway->scale", "Changes weapon sway scale", 1, CMD_ChangeSwayScale)
GB_GLOBALS.RegisterCommand("convars->sway->interp", "Changes weapon sway interp", 1, CMD_ChangeSwayInterp)
GB_GLOBALS.RegisterCommand("convars->toggle->vm_override", "Toggles the viewmodel override", 0, CMD_ToggleVMOverride)
GB_GLOBALS.RegisterCommand("convars->viewmodel->set", "Changes the viewmodel offset | args: option (up, right, forward), new value (number)", 2, CMD_ChangeVMOptions)
return convars
end)
__bundle_register("src.outline", function(require, _LOADED, __bundle_register, __bundle_modules)
local m_gb = GB_GLOBALS
assert(m_gb, "outline: GB_GLOBALS is nil!")

local m_settings = GB_SETTINGS.outline
assert(m_settings, "outline: GB_SETTINGS.outline is nil!")

local m_colors = require("src.colors")
assert(m_colors, "outline: src.colors is nil!")

local get_entity_color = m_colors.get_entity_color
local unpack = table.unpack

local divided = 1 / 255

local outline = {}

local vmt =
[[
UnlitGeneric
{
    $basetexture "vgui/white_additive"
    $wireframe 1
    $envmap "skybox/sky_dustbowl_01"
    $additive 1
}
]]

local m_vmtflat =
[[
UnlitGeneric
{
    $basetexture "vgui/white_additive"
}
]]

---@type Material?
local m_material = nil

---@type Material?
local m_flatmat = nil

local STENCILOPERATION_KEEP = E_StencilOperation.STENCILOPERATION_KEEP
local STENCILCOMPARISONFUNCTION_ALWAYS = E_StencilComparisonFunction.STENCILCOMPARISONFUNCTION_ALWAYS
local STENCILCOMPARISONFUNCTION_EQUAL = E_StencilComparisonFunction.STENCILCOMPARISONFUNCTION_EQUAL
local STENCILOPERATION_REPLACE = E_StencilOperation.STENCILOPERATION_REPLACE

---@param entity Entity
---@return boolean
local function ShouldRun(entity)
    if entity:IsDormant() then return false end

    local plocal = entities.GetLocalPlayer()
    if not plocal then return false end

    if m_settings.localplayer and entity:GetIndex() == plocal:GetIndex() then
        return true
    end

    if entity:GetTeamNumber() == plocal:GetTeamNumber() and m_settings.enemy_only then
        return false
    end

    if m_settings.players and entity:IsPlayer() then
        return true
    else
        if m_settings.weapons and (entity:IsShootingWeapon() or entity:IsMeleeWeapon()) then
            return true
        end

        if m_settings.hats then
            local class = entity:GetClass()
            if string.find(class, "Wearable") then
                return true
            end
            class = nil
        end
    end

    --- free plocal as we dont need it anymore
    plocal = nil
    return false
end

---@param dme DrawModelContext
---@param entity Entity?
function outline.DrawModel(dme, entity)
    if not m_settings.enabled then return end
    if not entity then return end
    if not ShouldRun(entity) then return end

    local color = get_entity_color(entity)
    if not color then return end

    --- just in case its nil for some reason
    if m_material == nil then
        m_material = materials.Create("cooloutline", vmt)
    end

    if m_flatmat == nil then
        m_flatmat = materials.Create("coolflatmateriallolo", m_vmtflat)
    end

    local r, g, b = unpack(color)

    render.SetStencilEnable(true)
    render.OverrideDepthEnable(true, true)

    --- player stencil
    render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_ALWAYS)
    render.SetStencilPassOperation(STENCILOPERATION_REPLACE);
    render.SetStencilFailOperation(STENCILOPERATION_KEEP);
    render.SetStencilZFailOperation(STENCILOPERATION_REPLACE);
    render.SetStencilTestMask(0x0)
    render.SetStencilWriteMask(0xFF)
    render.SetStencilReferenceValue(1)

    --- draw invisible player (this is important trust me)
    dme:ForcedMaterialOverride(m_flatmat)
    dme:SetAlphaModulation(0)
    dme:Execute()

    --- outline stencil
    render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_EQUAL)
    render.SetStencilPassOperation(STENCILOPERATION_KEEP)
    render.SetStencilFailOperation(STENCILOPERATION_KEEP)
    render.SetStencilZFailOperation(STENCILOPERATION_KEEP)
    render.SetStencilTestMask(0xFF)
    render.SetStencilWriteMask(0x0)
    render.SetStencilReferenceValue(0)

    --- draw the actual outline
    dme:DepthRange(0, m_settings.visible_only and 1 or 0.2)
    dme:ForcedMaterialOverride(m_material)
    dme:SetColorModulation(r * divided, g * divided, b * divided)
    dme:SetAlphaModulation(1)
    dme:Execute()

    render.OverrideDepthEnable(false, false)
    render.SetStencilEnable(false)

    --- now we draw the original model
    dme:ForcedMaterialOverride(m_flatmat)
    --dme:SetColorModulation(1, 1, 1)
    dme:SetAlphaModulation(0.1)
    dme:DepthRange(0, 1)
end

function outline.unload()
    outline = {}

    m_flatmat = nil
    divided = nil
    vmt = nil
    m_vmtflat = nil
    get_entity_color = nil
    unpack = nil
end

--- outline->toggle hide_cloaked
local function CMD_ChangeOption(args, num_args)
    if not args or #args ~= num_args then return end
    local selected_option = tostring(args[1])
    m_settings[selected_option] = not m_settings[selected_option]
    printc(150, 255, 150, 255, string.format("Toggled option %s", selected_option))
end

local function CMD_GetOptions(args, num_args)
    if not args or #args ~= num_args then return end
    for i, v in pairs(m_settings) do
        printc(255, 255, 0, 255, string.format("%s | %s", i, v))
    end
end

GB_GLOBALS.RegisterCommand("outline->toggle", "Toggles a outline option", 1, CMD_ChangeOption)
GB_GLOBALS.RegisterCommand("outline->options", "Prints all options", 0, CMD_GetOptions)
return outline

end)
__bundle_register("src.colors", function(require, _LOADED, __bundle_register, __bundle_modules)
local COLORS = {
    RED = { 255, 0, 0, 150 },
    BLU = { 0, 255, 255, 150 },

    TARGET = { 128, 255, 0, 50 },
    FRIEND = { 66, 245, 170, 50 },
    BACKTRACK = { 50, 166, 168, 50 },
    ANTIAIM = { 168, 50, 50, 50 },
    PRIORITY = { 238, 255, 0, 50 },
    FAKELAG = { 255, 179, 0, 50 },

    LOCALPLAYER = { 156, 66, 245, 50 },
    VIEWMODEL_ARM = { 210, 210, 255, 150 },
    VIEWMODEL_WEAPON = { 255, 255, 255, 100 },

    WEAPON_PRIMARY = { 163, 64, 90, 100 },
    WEAPON_SECONDARY = { 74, 79, 125, 100 },
    WEAPON_MELEE = { 255, 255, 255, 100 },

    RED_HAT = { 255, 0, 0, 150 },
    BLU_HAT = { 0, 0, 255, 150 },

    SENTRY_RED = { 255, 0, 0, 150 },
    SENTRY_BLU = { 8, 0, 255, 150 },

    DISPENSER_RED = { 130, 0, 0, 150 },
    DISPENSER_BLU = { 3, 0, 105, 150 },

    TELEPORTER_RED = { 173, 31, 107, 150 },
    TELEPORTER_BLU = { 0, 217, 255, 150 },

    AMMOPACK = { 255, 255, 255, 150 },
    HEALTHKIT = { 200, 255, 200, 100 },

    MVM_MONEY = { 52, 235, 82, 150 },

    RAGDOLL_RED = { 255, 150, 150, 100 },
    RAGDOLL_BLU = { 150, 150, 255, 100 },

    ORIGINAL_PLAYER = { 255, 255, 255, 255 },
    ORIGINAL_VIEWMODEL = { 255, 255, 255, 255 },

    WARP_BAR_BACKGROUND = { 30, 30, 30, 255 },
    WARP_BAR_STARTPOINT = { 255, 255, 0, 255 },
    WARP_BAR_ENDPOINT = { 153, 0, 255, 255 },
    WARP_BAR_TEXT = { 255, 255, 255, 255 },
    WARP_BAR_HIGHLIGHT = { 192, 192, 192, 255 },
}

local divided = 1 / 255

--- used for string.find
local WEARABLES_CLASS = "Wearable"
local TEAM_RED = 2
local SENTRY_CLASS, DISPENSER_CLASS, TELEPORTER_CLASS =
    "CObjectSentrygun", "CObjectDispenser", "CObjectTeleporter"
local MVM_MONEY_CLASS = "CCurrencyPack"
local VIEWMODEL_ARM_CLASS = "CTFViewModel"

---@param entity Entity?
function COLORS.get_entity_color(entity)
    if (not entity) then return nil end

    if (entity:GetIndex() == client:GetLocalPlayerIndex()) then
        return COLORS.LOCALPLAYER
    end

    if (GB_GLOBALS.nAimbotTarget == entity:GetIndex()) then
        return COLORS.TARGET
    end

    if (entity:IsWeapon() and entity:IsMeleeWeapon()) then
        return COLORS.WEAPON_MELEE
    elseif (entity:IsWeapon() and not entity:IsMeleeWeapon()) then
        return entity:GetLoadoutSlot() == E_LoadoutSlot.LOADOUT_POSITION_PRIMARY and COLORS.WEAPON_PRIMARY
            or COLORS.WEAPON_SECONDARY
    end

    local team = entity:GetTeamNumber()
    do
        local class = entity:GetClass() -- not entity:GetPropInt("m_PlayerClass", "m_iClass")!!

        if (class == SENTRY_CLASS) then
            return team == TEAM_RED and COLORS.SENTRY_RED or COLORS.SENTRY_BLU
        elseif (class == DISPENSER_CLASS) then
            return team == TEAM_RED and COLORS.DISPENSER_RED or COLORS.DISPENSER_BLU
        elseif (class == TELEPORTER_CLASS) then
            return team == TEAM_RED and COLORS.TELEPORTER_RED or COLORS.TELEPORTER_BLU
        elseif (class == MVM_MONEY_CLASS) then
            return COLORS.MVM_MONEY
        elseif (class == VIEWMODEL_ARM_CLASS) then
            return COLORS.VIEWMODEL_ARM
        end

        if (class and string.find(class, WEARABLES_CLASS)) then
            return team == TEAM_RED and COLORS.RED_HAT or COLORS.BLU_HAT
        end
    end

    do
        local priority = playerlist.GetPriority(entity)
        if (priority and priority <= -1) then
            return COLORS.FRIEND
        elseif (priority and priority >= 1) then
            return COLORS.PRIORITY
        end
    end

    return COLORS[team == TEAM_RED and "RED" or "BLU"]
end

local function CMD_ChangeColor(args, num_args)
    if not args or #args ~= num_args then return end
    local r, g, b, a, selectedkey
    selectedkey = string.upper(tostring(args[1]))
    r = tonumber(args[2]) // 1
    g = tonumber(args[3]) // 1
    b = tonumber(args[4]) // 1
    a = tonumber(args[5]) // 1

    COLORS[selectedkey] = { r, g, b, a }
end

GB_GLOBALS.RegisterCommand("colors->change",
    "Changes the specified color (RGBA format) | args: r (integer), g (integer), b (integer), a (integer)", 5,
    CMD_ChangeColor)

return COLORS

end)
__bundle_register("src.custom materials", function(require, _LOADED, __bundle_register, __bundle_modules)
local custom = {}

local applied = false

local vmt =
[[
VertexLitGeneric
{
   $basetexture "dev/dev_measuregeneric01b"
   $color2 "[0.12, 0.12, 0.12]"
}
]]

local mat = materials.Create("gb_dev_texture_lolo", vmt)

local function CMD_ApplyTextures()
   applied = true
   materials.Enumerate(function (material)
      local group = material:GetTextureGroupName()
      if group == "World textures" then
         material:SetShaderParam("$basetexture", "dev/dev_measuregeneric01b")
         material:SetShaderParam("$color2", Vector3(0.12, 0.12, 0.12))
      end
   end)
end

---@param info StaticPropRenderInfo
function custom.DrawStaticProps(info)
   if not applied then return end
   --info:DrawExtraPass() --- i honestly dont know if this does anything, but its here just in case :p
   info:ForcedMaterialOverride(mat)
end

function custom.unload()
   mat = nil
   vmt = nil
   applied = nil
   custom = nil
end

GB_GLOBALS.RegisterCommand("mats->apply_custom", "Applies dev textures to materials | CANT BE REVERTED UNLESS YOU RESTART THE GAME!", 0, CMD_ApplyTextures)
return custom
end)
__bundle_register("src.binds", function(require, _LOADED, __bundle_register, __bundle_modules)
local gb = GB_GLOBALS
assert(gb, "binds: GB_GLOBALS is nil!")

local json = require("src.json")

local binds = {
   key_press = {
      --[[
      {
         key = E_ButtonCode.KEY_R,
         command = "visuals->toggle_thirdperson, chams->material textured, ...",
         id = #binds.key_press+1
      }
      ]]
   },
   class_change = {
      --[[
      {
         class = selected_class (9 engineer, eggsample),
         command = "dgfiogjdifjg"
      }
      ]]
   },

   last_id = 0
}

local last_pressed_button_tick = 0

local classes = {
   scout = 1,
   soldier = 3,
   pyro = 7,
   demo = 4,
   heavy = 6,
   engineer = 9,
   medic = 5,
   sniper = 2,
   spy = 8,
}

local function RunCommand(text)
   gb.RunCommand("gb " .. text)
end

---@param usercmd UserCmd
local function CreateMove(usercmd)
   if engine.IsChatOpen() or engine.Con_IsVisible() or engine.IsGameUIVisible() then return end
   for _, bind in pairs(binds.key_press) do
      local key = bind.key
      local command = bind.command

      local state, tick = input.IsButtonPressed(key)
      if command and state and tick > last_pressed_button_tick then
         RunCommand(command)
         last_pressed_button_tick = tick
      end
   end
end

---@param event GameEvent
local function FireGameEvent(event)
   if event:GetName() == "player_changeclass" then
      local userid = event:GetInt("userid")
      local class = event:GetInt("class")
      if userid and class then
         local playerinfo = client.GetPlayerInfo(client.GetLocalPlayerIndex())
         if not playerinfo then return end
         if not playerinfo.UserID == userid then return end

         for _, bind in pairs(binds.class_change) do
            local selected_class, command = bind.class, bind.command
            if selected_class == class then
               RunCommand(command)
            end
         end
      end
   end
end

local function MakeKPBind(words)
   local key = table.remove(words, 1)
   local selected_key = E_ButtonCode["KEY_" .. string.upper(key)]
   local command = table.concat(words, " ")
   local id = binds.last_id + 1
   local new_bind = {
      key = selected_key,
      key_str = key,
      command = command,
      id = id,
   }
   binds.key_press[#binds.key_press + 1] = new_bind
   binds.last_id = id
end

local function MakeClassBind(words)
   local class = table.remove(words, 1)
   local selected_class = classes[tostring(class)]
   local command = table.concat(words)
   local id = binds.last_id + 1
   local new_bind = {
      class = selected_class,
      class_str = class,
      command = command,
      id = id
   }
   binds.class_change[#binds.class_change + 1] = new_bind
   binds.last_id = id
end

--- gb binds->create event name what it does
--- example: gb binds->create kp R visuals->toggle_thirdperson
--- only supports 1 command per bind :(
--- TODO: improve it
local function CMD_CreateBind(args, num_args, whole_string)
   if not args then return end
   local words = {}
   for word in string.gmatch(whole_string, "%S+") do
      words[#words + 1] = word
   end

   local bindtype = table.remove(words, 1)
   if bindtype == "kp" then
      MakeKPBind(words)
   elseif bindtype == "class" then
      MakeClassBind(words)
   end
end

local function CMD_GetAllBindIDs()
   printc(150, 255, 150, 255, "Binds:")

   for _, bind in pairs(binds.key_press) do
      local unformatted_str = "id: %s | key: %s | command: %s"
      local str = string.format(unformatted_str, bind.id, bind.key_str, bind.command)
      printc(255, 255, 255, 255, str)
   end

   for _, bind in pairs(binds.class_change) do
      local unformatted_str = "Id: %s | class: %s | command: %s"
      local str = string.format(unformatted_str, bind.id, bind.class_str, bind.command)
      printc(255, 255, 255, 255, str)
   end
end

local function CMD_RemoveBind(args, num_args)
   if (not args or #args ~= num_args) then return end
   local id = tonumber(args[1])
   if id then
      for _, bindtype in pairs(binds) do

         if type(bindtype) == "table" then
            for i, bind in ipairs(bindtype) do
               if bind.id == id then
                  table.remove(bindtype, i)
                  printc(150, 255, 150, 255, "Removed bind successfully!")
                  break
               end
            end
         end

      end
   end
end

local function CMD_SaveBinds(args, num_args)
   if not args or #args ~= num_args then return end
   if not args[1] then
      printc(255, 0, 0, 255, "Invalid name!")
      return
   end
   local encoded = json.encode(binds)
   local filename = tostring(args[1])
   local str = string.format("Garlic Bread/%s.json", filename)
   filesystem.CreateDirectory("Garlic Bread")
   io.output(str)
   io.write(encoded)
   io.flush()
   io.close()
   printc(150, 255, 150, 255, "Saved binds to " .. filename)
end

local function CMD_LoadBinds(args, num_args)
   if not args or #args ~= num_args then return end
   local filename = string.format("Garlic Bread/%s.json", tostring(args[1]))
   local file = io.open(filename, "r")
   if file then
      local str = file:read("a")
      local decoded = json.decode(str)
      if decoded then
         binds = decoded
         printc(150, 150, 255, 255, "Binds loaded!")
      end
      file:close()
   end
end

local function CMD_PrintAllSavedBinds()
   filesystem.EnumerateDirectory("Garlic Bread/*.json", function(filename, attributes)
      local name = filename:gsub(".json", "")
      print(name)
   end)
end

gb.RegisterCommand("binds->create", "Creates a new bind", -1, CMD_CreateBind)
gb.RegisterCommand("binds->getall", "Prints all bind IDs and their commands", 0, CMD_GetAllBindIDs)
gb.RegisterCommand("binds->remove", "Removes a bind using a id | args: id (number)", 1, CMD_RemoveBind)
gb.RegisterCommand("binds->save", "Saves binds to a file | args: file name (string)", 1, CMD_SaveBinds)
gb.RegisterCommand("binds->load", "Loads binds from a file | args: file name (string)", 1, CMD_LoadBinds)
gb.RegisterCommand("binds->getallfiles", "Prints all the saved files", 0, CMD_PrintAllSavedBinds)

local req = {}

req.CreateMove = CreateMove
req.FireGameEvent = FireGameEvent

function req.unload()
   req = nil
   binds = nil
   last_pressed_button_tick = nil
   classes = nil
end

return req

end)
__bundle_register("src.json", function(require, _LOADED, __bundle_register, __bundle_modules)
--
-- json.lua
--
-- Copyright (c) 2020 rxi
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of
-- this software and associated documentation files (the "Software"), to deal in
-- the Software without restriction, including without limitation the rights to
-- use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
-- of the Software, and to permit persons to whom the Software is furnished to do
-- so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
--

local json = { _version = "0.1.2" }

-------------------------------------------------------------------------------
-- Encode
-------------------------------------------------------------------------------

local encode

local escape_char_map = {
  [ "\\" ] = "\\",
  [ "\"" ] = "\"",
  [ "\b" ] = "b",
  [ "\f" ] = "f",
  [ "\n" ] = "n",
  [ "\r" ] = "r",
  [ "\t" ] = "t",
}

local escape_char_map_inv = { [ "/" ] = "/" }
for k, v in pairs(escape_char_map) do
  escape_char_map_inv[v] = k
end


local function escape_char(c)
  return "\\" .. (escape_char_map[c] or string.format("u%04x", c:byte()))
end


local function encode_nil(val)
  return "null"
end


local function encode_table(val, stack)
  local res = {}
  stack = stack or {}

  -- Circular reference?
  if stack[val] then error("circular reference") end

  stack[val] = true

  if rawget(val, 1) ~= nil or next(val) == nil then
    -- Treat as array -- check keys are valid and it is not sparse
    local n = 0
    for k in pairs(val) do
      if type(k) ~= "number" then
        error("invalid table: mixed or invalid key types")
      end
      n = n + 1
    end
    if n ~= #val then
      error("invalid table: sparse array")
    end
    -- Encode
    for i, v in ipairs(val) do
      table.insert(res, encode(v, stack))
    end
    stack[val] = nil
    return "[" .. table.concat(res, ",") .. "]"

  else
    -- Treat as an object
    for k, v in pairs(val) do
      if type(k) ~= "string" then
        error("invalid table: mixed or invalid key types")
      end
      table.insert(res, encode(k, stack) .. ":" .. encode(v, stack))
    end
    stack[val] = nil
    return "{" .. table.concat(res, ",") .. "}"
  end
end


local function encode_string(val)
  return '"' .. val:gsub('[%z\1-\31\\"]', escape_char) .. '"'
end


local function encode_number(val)
  -- Check for NaN, -inf and inf
  if val ~= val or val <= -math.huge or val >= math.huge then
    error("unexpected number value '" .. tostring(val) .. "'")
  end
  return string.format("%.14g", val)
end


local type_func_map = {
  [ "nil"     ] = encode_nil,
  [ "table"   ] = encode_table,
  [ "string"  ] = encode_string,
  [ "number"  ] = encode_number,
  [ "boolean" ] = tostring,
}


encode = function(val, stack)
  local t = type(val)
  local f = type_func_map[t]
  if f then
    return f(val, stack)
  end
  error("unexpected type '" .. t .. "'")
end


function json.encode(val)
  return ( encode(val) )
end


-------------------------------------------------------------------------------
-- Decode
-------------------------------------------------------------------------------

local parse

local function create_set(...)
  local res = {}
  for i = 1, select("#", ...) do
    res[ select(i, ...) ] = true
  end
  return res
end

local space_chars   = create_set(" ", "\t", "\r", "\n")
local delim_chars   = create_set(" ", "\t", "\r", "\n", "]", "}", ",")
local escape_chars  = create_set("\\", "/", '"', "b", "f", "n", "r", "t", "u")
local literals      = create_set("true", "false", "null")

local literal_map = {
  [ "true"  ] = true,
  [ "false" ] = false,
  [ "null"  ] = nil,
}


local function next_char(str, idx, set, negate)
  for i = idx, #str do
    if set[str:sub(i, i)] ~= negate then
      return i
    end
  end
  return #str + 1
end


local function decode_error(str, idx, msg)
  local line_count = 1
  local col_count = 1
  for i = 1, idx - 1 do
    col_count = col_count + 1
    if str:sub(i, i) == "\n" then
      line_count = line_count + 1
      col_count = 1
    end
  end
  error( string.format("%s at line %d col %d", msg, line_count, col_count) )
end


local function codepoint_to_utf8(n)
  -- http://scripts.sil.org/cms/scripts/page.php?site_id=nrsi&id=iws-appendixa
  local f = math.floor
  if n <= 0x7f then
    return string.char(n)
  elseif n <= 0x7ff then
    return string.char(f(n / 64) + 192, n % 64 + 128)
  elseif n <= 0xffff then
    return string.char(f(n / 4096) + 224, f(n % 4096 / 64) + 128, n % 64 + 128)
  elseif n <= 0x10ffff then
    return string.char(f(n / 262144) + 240, f(n % 262144 / 4096) + 128,
                       f(n % 4096 / 64) + 128, n % 64 + 128)
  end
  error( string.format("invalid unicode codepoint '%x'", n) )
end


local function parse_unicode_escape(s)
  local n1 = tonumber( s:sub(1, 4),  16 )
  local n2 = tonumber( s:sub(7, 10), 16 )
   -- Surrogate pair?
  if n2 then
    return codepoint_to_utf8((n1 - 0xd800) * 0x400 + (n2 - 0xdc00) + 0x10000)
  else
    return codepoint_to_utf8(n1)
  end
end


local function parse_string(str, i)
  local res = ""
  local j = i + 1
  local k = j

  while j <= #str do
    local x = str:byte(j)

    if x < 32 then
      decode_error(str, j, "control character in string")

    elseif x == 92 then -- `\`: Escape
      res = res .. str:sub(k, j - 1)
      j = j + 1
      local c = str:sub(j, j)
      if c == "u" then
        local hex = str:match("^[dD][89aAbB]%x%x\\u%x%x%x%x", j + 1)
                 or str:match("^%x%x%x%x", j + 1)
                 or decode_error(str, j - 1, "invalid unicode escape in string")
        res = res .. parse_unicode_escape(hex)
        j = j + #hex
      else
        if not escape_chars[c] then
          decode_error(str, j - 1, "invalid escape char '" .. c .. "' in string")
        end
        res = res .. escape_char_map_inv[c]
      end
      k = j + 1

    elseif x == 34 then -- `"`: End of string
      res = res .. str:sub(k, j - 1)
      return res, j + 1
    end

    j = j + 1
  end

  decode_error(str, i, "expected closing quote for string")
end


local function parse_number(str, i)
  local x = next_char(str, i, delim_chars)
  local s = str:sub(i, x - 1)
  local n = tonumber(s)
  if not n then
    decode_error(str, i, "invalid number '" .. s .. "'")
  end
  return n, x
end


local function parse_literal(str, i)
  local x = next_char(str, i, delim_chars)
  local word = str:sub(i, x - 1)
  if not literals[word] then
    decode_error(str, i, "invalid literal '" .. word .. "'")
  end
  return literal_map[word], x
end


local function parse_array(str, i)
  local res = {}
  local n = 1
  i = i + 1
  while 1 do
    local x
    i = next_char(str, i, space_chars, true)
    -- Empty / end of array?
    if str:sub(i, i) == "]" then
      i = i + 1
      break
    end
    -- Read token
    x, i = parse(str, i)
    res[n] = x
    n = n + 1
    -- Next token
    i = next_char(str, i, space_chars, true)
    local chr = str:sub(i, i)
    i = i + 1
    if chr == "]" then break end
    if chr ~= "," then decode_error(str, i, "expected ']' or ','") end
  end
  return res, i
end


local function parse_object(str, i)
  local res = {}
  i = i + 1
  while 1 do
    local key, val
    i = next_char(str, i, space_chars, true)
    -- Empty / end of object?
    if str:sub(i, i) == "}" then
      i = i + 1
      break
    end
    -- Read key
    if str:sub(i, i) ~= '"' then
      decode_error(str, i, "expected string for key")
    end
    key, i = parse(str, i)
    -- Read ':' delimiter
    i = next_char(str, i, space_chars, true)
    if str:sub(i, i) ~= ":" then
      decode_error(str, i, "expected ':' after key")
    end
    i = next_char(str, i + 1, space_chars, true)
    -- Read value
    val, i = parse(str, i)
    -- Set
    res[key] = val
    -- Next token
    i = next_char(str, i, space_chars, true)
    local chr = str:sub(i, i)
    i = i + 1
    if chr == "}" then break end
    if chr ~= "," then decode_error(str, i, "expected '}' or ','") end
  end
  return res, i
end


local char_func_map = {
  [ '"' ] = parse_string,
  [ "0" ] = parse_number,
  [ "1" ] = parse_number,
  [ "2" ] = parse_number,
  [ "3" ] = parse_number,
  [ "4" ] = parse_number,
  [ "5" ] = parse_number,
  [ "6" ] = parse_number,
  [ "7" ] = parse_number,
  [ "8" ] = parse_number,
  [ "9" ] = parse_number,
  [ "-" ] = parse_number,
  [ "t" ] = parse_literal,
  [ "f" ] = parse_literal,
  [ "n" ] = parse_literal,
  [ "[" ] = parse_array,
  [ "{" ] = parse_object,
}


parse = function(str, idx)
  local chr = str:sub(idx, idx)
  local f = char_func_map[chr]
  if f then
    return f(str, idx)
  end
  decode_error(str, idx, "unexpected character '" .. chr .. "'")
end


function json.decode(str)
  if type(str) ~= "string" then
    error("expected argument of type string, got " .. type(str))
  end
  local res, idx = parse(str, next_char(str, 1, space_chars, true))
  idx = next_char(str, idx, space_chars, true)
  if idx <= #str then
    decode_error(str, idx, "trailing garbage")
  end
  return res
end


return json
end)
__bundle_register("src.chams", function(require, _LOADED, __bundle_register, __bundle_modules)
---@class COLOR
---@field r integer
---@field g integer
---@field b integer
---@field a integer

local settings = GB_SETTINGS.chams
assert(GB_SETTINGS and settings, "chams: GB_SETTINGS is nil!")

---@type COLOR[]
local entitylist = {}
local chams = {}
local materialmode = "flat"
local player = {
    team = 0,
    index = 0,
    viewmodel_index = 0
}

local chams_materials =
{
    flat = materials.Create(
        "garlic bread flat chams",
        [[
  "UnlitGeneric"
  {
    $basetexture "vgui/white_additive"
  }
  ]]
    ),

    textured = materials.Create(
        "garlic bread textured chams",
        [[
		"VertexLitGeneric"
  		{
    		$basetexture "vgui/white_additive"
  		}
  	]]
    )
}

local colors = require("src.colors")
local viewmodel_weapon_modelname = "models/weapons/c_models"
local entity_classes = {
    sentry = "CObjectSentrygun",
    teleporter = "CObjectTeleporter",
    dispenser = "CObjectDispenser",
    mvm_money = "CCurrencyPack",
    viewmodel_arm = "CTFViewModel",
}

local function get_color(t)
    local r, g, b, a = table.unpack(t)
    return r / 255, g / 255, b / 255, a / 255
end

local function update_entities()
    if (globals.TickCount() % settings.update_interval) > 0 then return end
    if player.alive == 0 then return end

    local new_entitylist = {}
    for _, entity in pairs(Players) do
        if not settings.filter.players then break end

        local index = entity:GetIndex()
        if entity:IsDormant() then goto continue end
        if not entity:IsAlive() then goto continue end
        if not settings.filter.localplayer and index == player.index then goto continue end
        if settings.enemy_only and player.team == entity:GetTeamNumber() then goto continue end
        if entity:InCond(E_TFCOND.TFCond_Cloaked) and settings.ignore_cloaked_spy then goto continue end
        if entity:InCond(E_TFCOND.TFCond_Disguised) and settings.ignore_disguised_spy then goto continue end

        new_entitylist[index] = colors.get_entity_color(entity)

        local child = entity:GetMoveChild()
        while child do
            new_entitylist[child:GetIndex()] = colors.get_entity_color(child)
            child = child:GetMovePeer()
        end
        ::continue::
    end

    for _, entity in pairs(Sentries) do
        if not settings.filter.sentries then break end
        if entity:IsDormant() then goto continue end
        if settings.enemy_only and player.team == entity:GetTeamNumber() then goto continue end
        if entity:GetHealth() <= 0 then goto continue end

        new_entitylist[entity:GetIndex()] = colors.get_entity_color(entity)
        ::continue::
    end

    for _, entity in pairs(Dispensers) do
        if not settings.filter.dispensers then break end
        if entity:IsDormant() then goto continue end
        if entity:GetHealth() <= 0 then goto continue end
        if settings.enemy_only and entity:GetTeamNumber() == player.team then goto continue end

        new_entitylist[entity:GetIndex()] = colors.get_entity_color(entity)
        ::continue::
    end

    for _, entity in pairs(Teleporters) do
        if not settings.filter.teleporters then break end
        if entity:IsDormant() then goto continue end
        if settings.enemy_only and entity:GetTeamNumber() == player.team then goto continue end
        if entity:GetHealth() <= 0 then goto continue end

        new_entitylist[entity:GetIndex()] = colors.get_entity_color(entity)
        ::continue::
    end

    for _, entity in pairs(entities.FindByClass("CTFRagdoll")) do
        if not settings.filter.ragdolls then break end
        if entity:IsDormant() then goto continue end
        if entity:GetHealth() <= 0 then goto continue end
        if settings.enemy_only and entity:GetTeamNumber() == player.team then goto continue end

        new_entitylist[entity:GetIndex()] = colors.get_entity_color(entity)
        ::continue::
    end

    if (settings.filter.viewmodel_arm) then
        local viewmodel = entities:GetLocalPlayer():GetPropEntity("m_hViewModel[0]")
        if (viewmodel) then
            new_entitylist[viewmodel:GetIndex()] = colors.get_entity_color(viewmodel)
        end
    end

    if (settings.filter.ammopack or settings.filter.healthpack) then
        local cbasenimating = entities.FindByClass("CBaseAnimating")
        for _, entity in pairs(cbasenimating) do
            --- medkit, ammopack
            local model = entity:GetModel()
            if model then
                local model_name = string.lower(models.GetModelName(model))
                if model_name then
                    local i = entity:GetIndex()
                    if settings.filter.ammopack and string.find(model_name, "ammo") then
                        new_entitylist[i] = colors.AMMOPACK
                    elseif settings.filter.healthpack and (string.find(model_name, "health") or string.find(model_name, "medkit")) then
                        new_entitylist[i] = colors.HEALTHKIT
                    end
                end
            end
        end
    end

    entitylist = new_entitylist
end

---@param bool boolean
local function DEPTHOVERRIDE(bool)
    render.OverrideDepthEnable(bool, bool)
end

local function ResetPlayer()
    for k, v in pairs(player) do
        player[k] = 0
    end
end

function chams.CreateMove()
    local plocal = entities:GetLocalPlayer()
    if not plocal or not plocal:IsAlive() then
        ResetPlayer()
        return
    end

    player.alive = plocal:IsAlive() and 1 or 0
    player.index = plocal:GetIndex()
    player.team = plocal:GetTeamNumber()
    player.viewmodel_index = plocal:GetPropEntity("m_hViewModel[0]"):GetIndex()

    update_entities()
end

---@param dme DrawModelContext
---@param entity Entity?
---@param modelname string
function chams.DrawModel(dme, entity, modelname)
    if not settings.enabled then return end
    if player.alive == 0 then return end

    local material = chams_materials[materialmode]

    --- viewmodel weapon
    if entity == nil and string.find(modelname, viewmodel_weapon_modelname) then
        local r, g, b, a = get_color(colors.VIEWMODEL_WEAPON)
        dme:SetColorModulation(r, g, b)
        dme:SetAlphaModulation(a)
        dme:ForcedMaterialOverride(material)

        DEPTHOVERRIDE(true)
        dme:DepthRange(0, 0.1)
        dme:Execute()
        dme:DepthRange(0, 1)
        DEPTHOVERRIDE(false)
        return
    elseif entity and entity:GetClass() == "CTFViewModel" then
        local r, g, b, a = get_color(colors.VIEWMODEL_ARM)
        dme:SetColorModulation(r, g, b)
        dme:SetAlphaModulation(a)
        dme:ForcedMaterialOverride(material)

        DEPTHOVERRIDE(true)
        dme:DepthRange(0, 0.1)
        dme:Execute()
        dme:DepthRange(0, 1)
        DEPTHOVERRIDE(false)
        return
    end

    if not entity then return end

    local index, class = entity:GetIndex(), entity:GetClass()

    if (class == "CTFPlayer" and settings.original_player_mat)
        or (class == entity_classes.viewmodel_arm and settings.original_viewmodel_mat)
    then
        dme:Execute()

        local removedtext = string.gsub(class, "CTF", "")
        local upperclass = string.upper(removedtext)
        local r, g, b, a = get_color(colors["ORIGINAL_" .. upperclass])

        dme:SetColorModulation(r, g, b)
        dme:SetAlphaModulation(a)
    end

    local color = entitylist[index]
    if not color then return end

    DEPTHOVERRIDE(true)
    local r, g, b, a = get_color(color)

    dme:SetAlphaModulation(a)
    dme:SetColorModulation(r, g, b)
    dme:ForcedMaterialOverride(material)

    if not settings.visible_only then
        dme:DepthRange(0, 0.2)
    end

    dme:Execute()
    dme:DepthRange(0, 1)
    DEPTHOVERRIDE(false)
end

function chams.unload()
    entitylist = nil
    chams = nil
    materialmode = nil
    player = nil
    chams_materials = nil
    colors = nil
    viewmodel_weapon_modelname = nil
    entity_classes = nil
end

local function CMD_ToggleChams()
    settings.enabled = not settings.enabled
end

local function CMD_ChangeMaterialMode(args)
    if (not args or #args == 0 or not args[1]) then return end

    local name = tostring(args[1])
    if (not name) then return end

    materialmode = name
end

local function CMD_ChangeColor(args, num_args)
    if (not args or #args == 0 or #args ~= num_args) then return end

    local selected_key = string.upper(table.remove(args, 1))

    local r, g, b, a = table.unpack(args)
    if (not (r or g or b or a)) then return end

    r, g, b, a = tonumber(r), tonumber(g), tonumber(b), tonumber(a)
    colors[selected_key] = { r, g, b, a }
end

local function CMD_ToggleVisibleOnly()
    settings.visible_only = not settings.visible_only
    printc(150, 255, 150, 255,
        "Chams will draw on " .. (settings.visible_only and "visible" or "invisible") .. " entities")
end

local function CMD_ToggleDrawOriginalPlayerMat()
    settings.original_player_mat = not settings.original_player_mat
    printc(150, 255, 150, 255,
        "Chams will " .. (settings.original_player_mat and "draw" or "not draw") .. " the original player material")
end

local function CMD_ToggleDrawOriginalViewmodelMat()
    settings.original_viewmodel_mat = not settings.original_viewmodel_mat
    printc(150, 255, 150, 255,
        "Chams will " .. (settings.original_viewmodel_mat and "draw" or "not draw") .. " the original viewmodel material")
end

local function CMD_ToggleDrawOnEnemyOnly()
    settings.enemy_only = not settings.enemy_only
    printc(150, 255, 150, 255,
        "Chams will " .. (settings.enemy_only and "draw only" or "not only draw") .. " the enemies")
end

local function CMD_SetUpdateInterval(args, num_args)
    if (not args or #args ~= num_args) then return end
    local new_value = tonumber(args[1])
    if (new_value <= 0) then
        printc(255, 0, 0, 255, "The new value must be at least 1!")
        return
    end

    settings.update_interval = new_value

    if (new_value < 3) then
        printc(252, 186, 3, 255, "Values below 3 are not worth it, I would recommend using 3 or more",
            "This is just a warning, the interval was still changed")
    end
end

local function CMD_TryToFixMaterials()
    chams_materials = {
        flat = materials.Create(
            "garlic bread flat chams",
            [[
	  "UnlitGeneric"
	  {
		 $basetexture "vgui/white_additive"
	  }
	  ]]
        ),

        textured = materials.Create(
            "garlic bread textured chams",
            [[
	  "VertexLitGeneric"
	  {
		 $basetexture "vgui/white_additive"
	  }
	  ]]
        ),
    }
end

GB_GLOBALS.RegisterCommand("chams->toggle", "Toggles chams", 0, CMD_ToggleChams)
GB_GLOBALS.RegisterCommand("chams->material", "Changes chams material | args: material mode (flat or textured)", 1,
    CMD_ChangeMaterialMode)
GB_GLOBALS.RegisterCommand("chams->change_color",
    "Changes the selected color on chams | args: color (string), r, g, b, a (numbers) | example: chams->change_color viewmodel_arm 150 255 150 255",
    5, CMD_ChangeColor)
GB_GLOBALS.RegisterCommand("chams->toggle->visible_only", "Makes chams only draw on visible entities", 0,
    CMD_ToggleVisibleOnly)
GB_GLOBALS.RegisterCommand("chams->toggle->original_player_mat", "Toggles chams drawing the original player material", 0,
    CMD_ToggleDrawOriginalPlayerMat)
GB_GLOBALS.RegisterCommand("chams->toggle->enemy_only", "Toggles chams drawing on only enemies or not", 0,
    CMD_ToggleDrawOnEnemyOnly)
GB_GLOBALS.RegisterCommand("chams->toggle->original_viewmodel_mat",
    "Toggles chams drawing the original viewmodel material", 0, CMD_ToggleDrawOriginalViewmodelMat)
GB_GLOBALS.RegisterCommand("chams->update_interval", "Changes the entity update interval | args new value (number)", 1,
    CMD_SetUpdateInterval)
GB_GLOBALS.RegisterCommand("chams->fix_materials", "Tries to fix materials by creating them again", 0,
    CMD_TryToFixMaterials)
return chams

end)
__bundle_register("src.movement", function(require, _LOADED, __bundle_register, __bundle_modules)
local gb_settings = GB_SETTINGS
assert(gb_settings, "movement: GB_SETTINGS is nil!")

local movement = {}

function movement.unload()
	movement = nil
end

---@param usercmd UserCmd
local function CreateMove(usercmd, player)
	local flags = player:GetPropInt("m_fFlags")
	local ground = (flags & FL_ONGROUND) ~= 0
	local class = player:GetPropInt("m_PlayerClass", "m_iClass")
	if not GB_GLOBALS.bIsStacRunning and gb_settings.misc.bhop and class ~= 1 then
		local jump = (usercmd.buttons & IN_JUMP) ~= 0
		if ground and jump then
			usercmd.buttons = usercmd.buttons | IN_JUMP
		elseif not ground and jump then
			usercmd.buttons = usercmd.buttons & ~IN_JUMP
		end
	end
end

local function cmd_ToggleBhop()
	gb_settings.misc.bhop = not gb_settings.misc.bhop
	printc(150, 255, 150, 255, "Bhop is now " .. (gb_settings.misc.bhop and "enabled" or "disabled"))
end

GB_GLOBALS.RegisterCommand("misc->toggle_bhop", "Toggles bunny hopping", 0, cmd_ToggleBhop)

movement.CreateMove = CreateMove
return movement

end)
__bundle_register("src.visuals", function(require, _LOADED, __bundle_register, __bundle_modules)
require("src.visuals.commands")

local visuals = {}
local custom_aspectratio = require("src.visuals.custom aspectratio")
local custom_fov = require("src.visuals.custom fov")
local norecoil = require("src.visuals.norecoil")
local thirdperson = require("src.visuals.thirdperson")
local dmg_visualizer = require("src.visuals.hitmarker")

---@param setup ViewSetup
function visuals.RenderView(setup)
	local player = entities:GetLocalPlayer()
	if (not player) or not player:IsAlive() then return end

	custom_aspectratio:RenderView(setup)
	custom_fov:RenderView(setup, player)
	norecoil:RenderView(setup, player)
	thirdperson:RenderView(setup)
end

function visuals.Draw()
	dmg_visualizer:Draw()
end

function visuals.FrameStageNotify(stage)
	thirdperson:FrameStageNotify(stage)
end

function visuals.FireGameEvent(event)
	dmg_visualizer:FireGameEvent(event)
end

function visuals.unload()
	visuals = nil
	custom_aspectratio = nil
	custom_fov = nil
	norecoil = nil
	thirdperson = nil
	dmg_visualizer = nil
end

return visuals

end)
__bundle_register("src.visuals.hitmarker", function(require, _LOADED, __bundle_register, __bundle_modules)
local settings = GB_SETTINGS.visuals
local shots = {}
local hooks = {}

local max_shots = 5
local max_life = 5 * 66.67

---@param event GameEvent
function hooks:FireGameEvent(event)
   if not settings.see_hits.enabled then return end
   if not (event:GetName() == "player_hurt") then return end

   local victimID, attacker, crit
   victimID = event:GetInt("userid")
   attacker = event:GetInt("attacker")
   crit = event:GetInt("crit") == 1 and true or false

   local plocalinfo = client.GetPlayerInfo(client.GetLocalPlayerIndex())
   if not (plocalinfo.UserID == attacker) then return end

   local victim = entities.GetByUserID(victimID)
   if not victim then return end

   local pos = victim:GetAbsOrigin()
   local mins, maxs = victim:GetMins(), victim:GetMaxs()
   local center = pos + ((mins + maxs) * 0.5)

   shots[#shots+1] = {pos = center, time = globals.TickCount(), crit = crit}
end

function hooks:Draw()
   if not settings.see_hits.enabled then return end

   if #shots >= max_shots then
      table.remove(shots, 1)
   end

   for i = 1, #shots do
      local shot = shots[i]
      if not shot then goto continue end
      if (globals.TickCount() - shot.time) >= max_life then
         table.remove(shots, i)
         goto continue
      else

         local center = client.WorldToScreen(shot.pos)
         if not center then goto continue end

         local color = shot.crit and settings.see_hits.crit_color or settings.see_hits.non_crit_color

         draw.Color(table.unpack(color))
         draw.OutlinedCircle(center[1], center[2], 10, 63)
      end

      --- seriously wtf why do we have to do a jump like this?
      --- why not just do like Luau or C and have a "continue"???
      ::continue::
   end
end

return hooks
end)
__bundle_register("src.visuals.thirdperson", function(require, _LOADED, __bundle_register, __bundle_modules)
local thirdperson = {}
local settings = GB_SETTINGS.visuals

function thirdperson:RenderView(setup)
	if settings.thirdperson.enabled then
		local viewangles = engine:GetViewAngles()
		local forward, right, up = viewangles:Forward(), viewangles:Right(), viewangles:Up()
		setup.origin = setup.origin + (right * settings.thirdperson.offset.right)
		setup.origin = setup.origin + (forward * settings.thirdperson.offset.forward)
		setup.origin = setup.origin + (up * settings.thirdperson.offset.up)
	end
end

function thirdperson:FrameStageNotify(stage)
	local player = entities:GetLocalPlayer()
	if (not player) then return end
	if (stage == E_ClientFrameStage.FRAME_NET_UPDATE_START) then
		player:SetPropBool(settings.thirdperson.enabled, "m_nForceTauntCam")
	end
end

return thirdperson
end)
__bundle_register("src.visuals.norecoil", function(require, _LOADED, __bundle_register, __bundle_modules)
local norecoil = {}
local settings = GB_SETTINGS.visuals

---@param setup ViewSetup
---@param player Entity
function norecoil:RenderView(setup, player)
	if settings.norecoil and player:GetPropInt("m_nForceTauntCam") == 0 and not player:InCond(E_TFCOND.TFCond_Taunting) then
		local punchangle = player:GetPropVector("m_vecPunchAngle")
		setup.angles = EulerAngles((setup.angles - punchangle):Unpack())
	end
end

return norecoil
end)
__bundle_register("src.visuals.custom fov", function(require, _LOADED, __bundle_register, __bundle_modules)
local customfov = {}
local settings = GB_SETTINGS.visuals

local function calc_fov(fov, aspect_ratio)
	local halfanglerad = fov * (0.5 * math.pi / 180)
	local t = math.tan(halfanglerad) * (aspect_ratio / (4/3))
	local ret = (180 / math.pi) * math.atan(t)
	return ret * 2
end

---@param setup ViewSetup
---@param player Entity
function customfov:RenderView(setup, player)
	local fov = player:InCond(E_TFCOND.TFCond_Zoomed) and 20 or settings.custom_fov
	if fov then
		setup.fov = calc_fov(fov, setup.aspectRatio)
	end
end

return customfov
end)
__bundle_register("src.visuals.custom aspectratio", function(require, _LOADED, __bundle_register, __bundle_modules)
local custom_aspect = {}
local gb = GB_GLOBALS
local settings = GB_SETTINGS.visuals

function custom_aspect:RenderView(setup)
	gb.nPreAspectRatio = setup.aspectRatio
	setup.aspectRatio = settings.aspect_ratio == 0 and setup.aspectRatio or settings.aspect_ratio
end

return custom_aspect
end)
__bundle_register("src.visuals.commands", function(require, _LOADED, __bundle_register, __bundle_modules)
local gb = GB_GLOBALS
assert(gb, "visuals.commands: GB_GLOBALS is nil!")

local gb_settings = GB_SETTINGS
local settings = gb_settings.visuals

local function cmd_ChangeFOV(args)
	if (not args or #args == 0 or not args[1]) then return end
	settings.custom_fov = tonumber(args[1])
end

local function cmd_ToggleThirdPerson()
	gb_settings.visuals.thirdperson.enabled = not gb_settings.visuals.thirdperson.enabled
	printc(150, 255, 150, 255, "Thirdperson is " .. (gb_settings.visuals.thirdperson.enabled and "enabled" or "disabled"))
end

local function cmd_SetThirdPersonOption(args, num_args)
	if not args or #args ~= num_args then return end
	print(args[1], args[2])
	local option = tostring(args[1])
	local value = tonumber(args[2])
	gb_settings.visuals.thirdperson.offset[option] = value
end

local function cmd_SetAspectRatio(args, num_args)
	if not args or #args ~= num_args then return end
	local newvalue = tonumber(args[1])
	if newvalue then
		settings.aspect_ratio = newvalue
		printc(150, 150, 255, 255, "Changed aspect ratio")
	end
end

local function cmd_ToggleNoRecoil()
	settings.norecoil = not settings.norecoil
	printc(150, 150, 255, 255, "No recoil is " .. (settings.norecoil and "enabled" or "disabled"))
end

local function cmd_ToggleDmgVis()
	settings.see_hits.enabled = not settings.see_hits.enabled
	printc(150, 150, 255, 255, "Dmg visualizer is " .. (settings.see_hits.enabled and "enabled" or "disabled"))
end

local function cmd_ChangeDmgVisNonCritColor(args)
	if not args then return end
	if not args[1] or not args[2] or not args[3] then return end

	local r, g, b = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
	local a = args[4] and tonumber(args[4]) or 255

	settings.see_hits.non_crit_color = {r, g, b, a}
end

local function cmd_ChangeDmgVisCritColor(args)
	if not args then return end
	if not args[1] or not args[2] or not args[3] then return end

	local r, g, b = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
	local a = args[4] and tonumber(args[4]) or 255

	settings.see_hits.crit_color = {r, g, b, a}
end

gb.RegisterCommand("visuals->fov->set", "Changes fov | args: new fov (number)", 1, cmd_ChangeFOV)
gb.RegisterCommand("visuals->thirdperson->toggle", "Toggles third person", 0, cmd_ToggleThirdPerson)
gb.RegisterCommand("visuals->thirdperson->set", "Sets the thirdperson option | args: option name (up, right, forward), new value (number)", 2, cmd_SetThirdPersonOption)
gb.RegisterCommand("visuals->aspectratio->set", "Changes the aspect ratio | args: new value (number)", 1, cmd_SetAspectRatio)
gb.RegisterCommand("visuals->norecoil->toggle", "Toggles no recoil", 0, cmd_ToggleNoRecoil)
gb.RegisterCommand("visuals->dmg->change_noncrit_color", "Changes the dmg visualizer not crit shot color", 4, cmd_ChangeDmgVisNonCritColor)
gb.RegisterCommand("visuals->dmg->change_crit_color", "Changes the dmg visualizer crit shot color", 4, cmd_ChangeDmgVisCritColor)
gb.RegisterCommand("visuals->dmg->toggle", "Toggles dmg visualizer", 0, cmd_ToggleDmgVis)
end)
__bundle_register("src.fakelag", function(require, _LOADED, __bundle_register, __bundle_modules)
local gb = GB_GLOBALS
local gb_settings = GB_SETTINGS
assert(gb, "fakelag: GB_GLOBALS is nil!")
assert(gb_settings, "fakelag: GB_SETTINGS is nil!")

local settings = gb_settings.fakelag

local fakelag = {}
local colors = require("src.colors")

local m_nChokedTicks = 0
local m_bWarping = false

local m_vecIndicatorPos = nil
local m_angIndicatorAngles = nil

---@type Entity?
local m_hIndicator = nil
local m_sModelName = "models/player/heavy.mdl"

local states = {
	choking = 1,
	recharging = 2,
}

local mat = materials.Create("garlic bread fakelag chams",
[[
"UnlitGeneric"
{
	$basetexture "vgui/white_additive"
}
]])

local m_nCurrentState = states.choking

local function GetChoked()
	return clientstate:GetChokedCommands()
end

local function DeleteIndicator()
	if m_hIndicator then
		m_hIndicator:Release()
		m_hIndicator = nil
	end
end

---@param usercmd UserCmd
function fakelag.CreateMove(usercmd)
	gb.bFakeLagEnabled = settings.enabled
	if not settings.enabled then
		DeleteIndicator()
		return
	end

	if m_nCurrentState == states.choking and not gb.bIsStacRunning then
		if GetChoked() < settings.ticks then
			usercmd.sendpacket = usercmd.buttons & IN_ATTACK ~= 0 and gb.CanWeaponShoot()
		else
			m_nCurrentState = states.recharging
		end
	elseif m_nCurrentState == states.recharging then
		if GetChoked() > 0 then
			m_bWarping = true
		else
			m_bWarping = false
			m_nCurrentState = states.choking
		end
	end

	if settings.indicator.enabled and (gb_settings.visuals.thirdperson.enabled or settings.indicator.firstperson) then
		local localplayer = entities:GetLocalPlayer()
		if not localplayer then return end

		if not m_hIndicator then
			m_hIndicator = entities.CreateEntityByName("grenade")
			if m_hIndicator then
				m_hIndicator:SetModel(m_sModelName) --- hoovy my beloved
			end
		end

		if GetChoked() == 0 then
			m_vecIndicatorPos = localplayer:GetAbsOrigin()
			m_angIndicatorAngles = localplayer:GetAbsAngles()
		end

		if not m_hIndicator then return end
		if m_vecIndicatorPos and m_angIndicatorAngles then
			m_hIndicator:SetAbsOrigin(m_vecIndicatorPos)
			m_hIndicator:SetAbsAngles(Vector3(m_angIndicatorAngles:Unpack()))
		end
	else
		DeleteIndicator()
	end
end

--- i honestly dont know if this is needed, but just in case, we warp when not choking to be able to choke more
---@param msg NetMessage
---@param returnval {ret: boolean, backupcmds: integer, newcmds: integer}
function fakelag.SendNetMsg(msg, buffer, returnval)
	if not settings.enabled then return true end
	if msg:GetType() == 9 and m_bWarping and GetChoked() > 0 and not gb.bIsAimbotShooting then

		buffer:SetCurBit(0)
		buffer:WriteInt(returnval.newcmds + returnval.backupcmds, 4)
		buffer:WriteInt(0, 3)
		buffer:SetCurBit(0)

		m_nChokedTicks = m_nChokedTicks - 1
	end
	returnval.ret = true
end

---@param context DrawModelContext
---@param entity Entity?
---@param modelname string
function fakelag.DrawModel(context, entity, modelname)
	if not settings.enabled or not settings.indicator.enabled then return end

	if entity == nil and m_hIndicator and m_hIndicator:ShouldDraw() and modelname == m_sModelName then
		local color = colors.FAKELAG
		local r, g, b, a = table.unpack(color)
		context:SetAlphaModulation(a/255)
		context:SetColorModulation(r/255, g/255, b/255)
		context:ForcedMaterialOverride(mat)
		render.OverrideDepthEnable(true, true)
		context:DepthRange(0, 0.2)
		context:Execute()
		render.OverrideDepthEnable(false, false)
		context:DepthRange(0, 1)
	end
end

local function CMD_ToggleFakeLag()
	settings.enabled = not settings.enabled
	printc(150, 150, 255, 255, "Fake lag is now " .. (settings.enabled and "enabled" or "disabled"))
end

local function CMD_ToggleFakeLagFirstPerson()
	settings.indicator.firstperson = not settings.indicator.firstperson
	printc(150, 150, 255, 255, "Fake lag indicator in 1st person is now " .. (settings.indicator.firstperson and "enabled" or "disabled"))
end

local function CMD_ToggleFakeLagIndicator()
	settings.indicator.enabled = not settings.indicator.enabled
	printc(150, 150, 255, 255, "Fake lag indicator is now " .. (settings.indicator.enabled and "enabled" or "disabled"))
end

local function CMD_SetChokeTicks(args, num_args)
	if not args or #args ~= num_args then return end
	if not args[1] then return end
	local new_value = tonumber(args[1])
	if not new_value or new_value < 0 then return end

	settings.ticks = new_value
	printc(150, 150, 255, 255, "Changed max choked ticks")
end

function fakelag.unload()
	DeleteIndicator()
	m_nChokedTicks = nil
	m_bWarping = nil
	m_hIndicator = nil
	m_vecIndicatorPos = nil
	m_angIndicatorAngles = nil
	states = nil
	m_nCurrentState = nil
	mat = nil
	m_sModelName = nil
	settings.indicator.firstperson = nil
	fakelag = nil
end

gb.RegisterCommand("fakelag->toggle", "Toggles fakelag", 0, CMD_ToggleFakeLag)
gb.RegisterCommand("fakelag->set->ticks", "Sets the amount of ticks to choke | args: new value (number)", 1, CMD_SetChokeTicks)
gb.RegisterCommand("fakelag->toggle->indicator", "Toggles the fakelag indicator", 0, CMD_ToggleFakeLagIndicator)
gb.RegisterCommand("fakelag->toggle->indicator_1st_person", "Toggles the fakelag indicator to appear in first person", 0, CMD_ToggleFakeLagFirstPerson)

return fakelag

end)
__bundle_register("src.tickshift", function(require, _LOADED, __bundle_register, __bundle_modules)
local gb = GB_GLOBALS
local gb_settings = GB_SETTINGS
assert(gb, "tickshift: GB_GLOBALS is nil!")
assert(gb_settings, "tickshift: GB_SETTINGS is nil!")

local SIGNONSTATE_TYPE = 6
local CLC_MOVE_TYPE = 9

local charged_ticks = 0

local max_ticks = 0
local last_key_tick = 0
local next_passive_tick = 0

local m_enabled = true
local warping, recharging = false, false
local doubletaping = false

local font = draw.CreateFont("TF2 BUILD", 16, 1000)

---@type number
local m_localplayer_speed

local colors = require("src.colors")

local tickshift = {}

local function CanChoke()
    return clientstate:GetChokedCommands() < max_ticks
end

local function CanShift()
    return clientstate:GetChokedCommands() == 0
end

local function GetMaxServerTicks()
    local sv_maxusrcmdprocessticks = client.GetConVar("sv_maxusrcmdprocessticks")
    if sv_maxusrcmdprocessticks then
        return sv_maxusrcmdprocessticks > 0 and sv_maxusrcmdprocessticks or 9999999
    end
    return 24
end

---@param buffer BitBuffer
function HandleWarp(buffer)
    local player = entities:GetLocalPlayer()
    if player and m_localplayer_speed <= 0 and not gb_settings.tickshift.warp.standing_still then
        return
    end

    if player and player:IsAlive() and charged_ticks > 0 and CanShift() then
        buffer:SetCurBit(0)

        buffer:WriteInt(2, 4) --- newcmd
        buffer:WriteInt(1, 3) --- backupcmd

        buffer:SetCurBit(0)

        --- make the warp only work once (if its <= 0 it wont try to warp again)
        charged_ticks = charged_ticks - 1
    end
end

---@param buffer BitBuffer
local function HandleDoubleTap(buffer, newcmds, backupcmds)
    local player = entities:GetLocalPlayer()

    if not player or not player:IsAlive() then return end
    if charged_ticks <= 1 then return end

    buffer:SetCurBit(0)

    buffer:WriteInt(newcmds + backupcmds, 4) --- new command
    buffer:WriteInt(0, 3)                    --- backup commands

    buffer:SetCurBit(0)
    charged_ticks = charged_ticks - backupcmds

    recharging = false
end

local function HandlePassiveRecharge()
    if not gb_settings.tickshift.warp.passive.enabled or charged_ticks >= max_ticks then
        return false
    end

    local player = entities:GetLocalPlayer()
    if (not player) then return false end

    if
        (globals.TickCount() >= next_passive_tick)
        or (gb_settings.tickshift.warp.passive.while_dead and not player:IsAlive())
    then
        charged_ticks = charged_ticks + 1
        local time = engine.RandomFloat(gb_settings.tickshift.warp.passive.min_time,
            gb_settings.tickshift.warp.passive.max_time)
        next_passive_tick = globals.TickCount() + (time * 66.67)
        return true
    end

    return false
end

local function clamp(value, min, max)
    return math.min(math.max(value, min), max)
end

local function HandleRecharge()
    if CanChoke() and charged_ticks < max_ticks and recharging then
        charged_ticks = charged_ticks + 1
        return true
    end

    if HandlePassiveRecharge() then
        return true
    end

    return false
end

--- Resets the variables to their default state when joining a new server
local function HandleJoinServers()
    if clientstate:GetClientSignonState() == E_SignonState.SIGNONSTATE_SPAWN then
        m_localplayer_speed = 0
        max_ticks = GetMaxServerTicks()
        charged_ticks = 0
        last_key_tick = 0
        next_passive_tick = 0
    end
end

---@param msg NetMessage
---@param returnval {ret: boolean, backupcmds: integer, newcmds: integer}
function tickshift.SendNetMsg(msg, buffer, returnval)
    --- return early if user disabled with console commands
    if not m_enabled then return true end

    if msg:GetType() == SIGNONSTATE_TYPE then
        HandleJoinServers()
    end

    --if gb.bIsStacRunning or gb.bFakeLagEnabled then return true end

    if engine.IsChatOpen() or engine.IsGameUIVisible() or engine.Con_IsVisible() then
        return true
    end

    if msg:GetType() == CLC_MOVE_TYPE then
        buffer:SetCurBit(0)

        buffer:WriteInt(returnval.newcmds, 4)
        buffer:WriteInt(returnval.backupcmds, 3)

        if doubletaping then
            HandleDoubleTap(buffer, returnval.newcmds, returnval.backupcmds)
        elseif warping and not recharging then
            HandleWarp(buffer)
        elseif HandleRecharge() then
            gb.bRecharging = true
            recharging = true
            returnval.ret = false
        end

        buffer:SetCurBit(0)
        msg:ReadFromBitBuffer(buffer)
        buffer:Delete()
    end
end

--- thanks Glitch!
---@param usercmd UserCmd
---@param player Entity
local function AntiWarp(player, usercmd)
    local vel = player:EstimateAbsVelocity()
    local flags = player:GetPropInt("m_fFlags")
    if (flags & FL_ONGROUND) == 0 or vel:Length2D() <= 15 or (usercmd.buttons & IN_JUMP) ~= 0 then return end

    local yaw = engine:GetViewAngles().y
    local dir = vel:Angles()
    dir.y = yaw - dir.y
    local forward = dir:Forward() * -vel:Length2D()
    usercmd.forwardmove, usercmd.sidemove = forward.x, forward.y
end

---@param usercmd UserCmd
function tickshift.CreateMove(usercmd, player)
    if engine.IsChatOpen() or engine.IsGameUIVisible() or engine.Con_IsVisible()
        or gb.bIsStacRunning or not m_enabled --[[or gb.bFakeLagEnabled]] then
        return
    end

    m_localplayer_speed = player:EstimateAbsVelocity():Length() or 0
    max_ticks = GetMaxServerTicks()
    charged_ticks = clamp(charged_ticks, 0, max_ticks)

    warping = input.IsButtonDown(gb_settings.tickshift.warp.send_key) and charged_ticks > 0
    gb.bWarping = warping
    recharging = input.IsButtonDown(gb_settings.tickshift.warp.recharge_key) and charged_ticks < max_ticks
    gb.bRecharging = recharging

    doubletaping = gb_settings.tickshift.doubletap.enabled
        and input.IsButtonDown(gb_settings.tickshift.doubletap.key)
        and (usercmd.buttons & IN_ATTACK ~= 0)
        and charged_ticks > 0

    gb.bDoubleTapping = doubletaping

    if recharging then
        usercmd.tick_count = 0
        usercmd.command_number = 0
        usercmd.buttons = 0
    end

    local state, tick = input.IsButtonPressed(gb_settings.tickshift.warp.passive.toggle_key)
    if state and last_key_tick < tick then
        gb_settings.tickshift.warp.passive.enabled = not gb_settings.tickshift.warp.passive.enabled
        last_key_tick = tick
        client.ChatPrintf("Passive recharge: " .. (gb_settings.tickshift.warp.passive.enabled and "ON" or "OFF"))
    end

    if doubletaping then
        AntiWarp(player, usercmd)
    end

    local netchan = clientstate.GetNetChannel()
    if netchan then
        --- the cause of the jittering when recharging is the clientsided interp
        --- this should fix it, but it does exactly 0 shit
        netchan:SetInterpolationAmount(recharging and 0 or 0.030000)
    end
end

function tickshift.Draw()
    if
        engine:Con_IsVisible()
        or engine:IsGameUIVisible()
        or (engine:IsTakingScreenshot() and gui.GetValue("clean screenshots") == 1)
        or not m_enabled or gb.bIsStacRunning --[[or gb.bFakeLagEnabled]]
    then
        return
    end

    local screenX, screenY = draw:GetScreenSize()
    local centerX, centerY = math.floor(screenX / 2), math.floor(screenY / 2)

    local formatted_text = string.format("%i / %i", charged_ticks, max_ticks)
    draw.SetFont(font)
    local textW, textH = draw.GetTextSize(formatted_text)

    local barWidth = 200
    local barHeight = 20
    local offset = 2
    local percent = charged_ticks / max_ticks
    local barX, barY = math.floor(centerX - (barWidth / 2)), math.floor(centerY + 40)
    local textX, textY = math.floor(barX + (barWidth * 0.5) - (textW / 2)),
        math.floor(barY + (barHeight * 0.5) - (textH * 0.5))

    draw.Color(table.unpack(colors.WARP_BAR_BACKGROUND))
    draw.FilledRect(
        math.floor(barX - offset),
        math.floor(barY - offset),
        math.floor(barX + barWidth + offset),
        math.floor(barY + barHeight + offset)
    )

    draw.Color(table.unpack(colors.WARP_BAR_HIGHLIGHT))
    draw.OutlinedRect(
        math.floor(barX - offset - 1),
        math.floor(barY - offset - 1),
        math.floor(barX + barWidth + offset + 1),
        math.floor(barY + barHeight + offset + 1)
    )

    pcall(function()
        --- amarelo foda
        draw.Color(table.unpack(colors.WARP_BAR_STARTPOINT))
        --draw.FilledRectFade(barX, barY, math.floor(barX + (barWidth * percent)), barY + barHeight, 255, 50, true)
        draw.FilledRectFade(barX, barY, barX + barWidth, barY + barHeight, 255, 50, true)

        --- roxo pica
        draw.Color(table.unpack(colors.WARP_BAR_ENDPOINT))
        draw.FilledRectFade(barX, barY, barX + barWidth, barY + barHeight, 50, 255, true)

        --- é a verdadeira barra que mudamos, ela vai da direita pra esquerda pra esconder o gradiente foda
        draw.Color(table.unpack(colors.WARP_BAR_BACKGROUND))
        draw.FilledRect(math.floor(barX + (barWidth * percent)), barY, barX + barWidth, barY + barHeight)
    end)

    draw.SetFont(font)
    draw.Color(table.unpack(colors.WARP_BAR_TEXT))
    draw.TextShadow(textX, textY, formatted_text)

    do --- charge bar status
        draw.SetFont(font)
        --- this is the most vile, horrendous, horrible code i have probably ever written
        --- but if it works, it works
        local color = gb_settings.fakelag.enabled and { 255, 150, 150, 255 }
            or doubletaping and { 255, 0, 0, 255 }
            or charged_ticks >= max_ticks and { 128, 255, 0, 255 }
            or warping and { 0, 225, 255, 255 }
            or recharging and { 255, 255, 0, 255 }
            or { 255, 255, 255, 255 }
        draw.Color(table.unpack(color))

        local text = gb_settings.fakelag.enabled and "FAKELAGGING"
            or doubletaping and "DOUBLETAP"
            or charged_ticks >= max_ticks and "READY"
            or warping and "WARPING"
            or recharging and "RECHARGING"
            or "IDLE"

        local textW, textH = draw.GetTextSize(text)
        local textX, textY = math.floor(barX + (barWidth * 0.5) - (textW * 0.5)), math.floor(barY - textH - 2)
        draw.TextShadow(textX, textY, text)
    end
end

local function cmd_ToggleTickShift()
    m_enabled = not m_enabled
    printc(150, 255, 150, 255, "Tick shifting is now " .. (m_enabled and "enabled" or "disabled"))
end

function tickshift.unload()
    SIGNONSTATE_TYPE = nil
    CLC_MOVE_TYPE = nil
    charged_ticks = nil
    max_ticks = nil
    last_key_tick = nil
    next_passive_tick = nil
    m_enabled = nil
    warping, recharging = nil, nil
    font = nil
    m_localplayer_speed = nil
    gb_settings.tickshift = nil
    tickshift = nil
end

local function cmd_ChangeWarpBarComponentColor(args, num_args)
    if not args or #args ~= num_args then return end

    local chosen_component = string.upper(tostring(args[1]))
    local r, g, b, a = tostring(args[2]), tostring(args[3]), tostring(args[4]), tostring(args[5])
    if not r or not g or not b or not a then return end

    colors["WARP_BAR_" .. chosen_component] = { r, g, b, a }
end

local function cmd_GetWarpBarComponents()
    printc(255, 255, 0, 255, "Components:")
    for key in pairs(colors) do
        if string.find(key, "WARP") then
            local formattedtext = string.gsub(key, "WARP_BAR_", "")
            printc(0, 255, 255, 255, string.lower(formattedtext))
        end
    end
end

gb.RegisterCommand("tickshift->toggle", "Toggles tickshifting (warp, recharge)", 0, cmd_ToggleTickShift)
gb.RegisterCommand("tickshift->warpbar->change_color", "Changes the color of the chosen component of the warp bar", 5,
    cmd_ChangeWarpBarComponentColor)
gb.RegisterCommand("tickshift->warpbar->getcomponents", "Gets the warp bar components you can change with change_color",
    0, cmd_GetWarpBarComponents)
return tickshift

end)
__bundle_register("src.esp", function(require, _LOADED, __bundle_register, __bundle_modules)
local esp = {}

local font = draw.CreateFont("TF2 BUILD", 12, 1000)

local utils = require("src.esp.utils")
local colors = require("src.colors")

local settings = GB_SETTINGS.esp

local function DrawBuildings(class, localplayer, shootpos)
    for _, entity in pairs(class) do
        if not entity:IsValid() then goto continue end
        if entity:GetTeamNumber() == localplayer:GetTeamNumber() and settings.enemy_only then goto continue end
        if entity:GetHealth() <= 0 then goto continue end
        if entity:IsDormant() then goto continue end

        local maxs = entity:GetMaxs()
        local mins = entity:GetMins()
        local center = entity:GetAbsOrigin() + ((maxs + mins) >> 1)

        if settings.visible_only then
            local trace = engine.TraceLine(shootpos, center, MASK_SHOT_HULL)
            if not trace or trace.fraction <= 0.7 then goto continue end
        end

        local top, bottom
        top = client.WorldToScreen(entity:GetAbsOrigin() + Vector3(0, 0, maxs.z))
        bottom = client.WorldToScreen(entity:GetAbsOrigin() - Vector3(0, 0, 9))
        if not top or not bottom then goto continue end

        local h = bottom[2] - top[2]
        local w = math.floor(h * 0.3)

        local left, right
        left = top[1] - w
        right = top[1] + w

        local color = colors.get_entity_color(entity) or { 255, 255, 255, 255 }
        local r, g, b, a = table.unpack(color)
        a = 255
        local actualcolor = { r, g, b, a }

        draw.Color(255, 255, 255, 255)
        utils.DrawBuildingClass(font, top, entity:GetClass())

        if settings.fade then
            draw.Color(table.unpack(actualcolor or { 255, 255, 255, 255 }))
            draw.FilledRectFastFade(left + 1, top[2] + 1, right - 1, bottom[2] - 1, top[2] + 1, bottom[2] - 1, 0, 50,
                false)
        end

        draw.Color(table.unpack(actualcolor or { 255, 255, 255, 255 }))
        draw.OutlinedRect(left, top[2], right, bottom[2])

        utils.DrawVerticalHealthBar(entity:GetHealth(), entity:GetMaxHealth(), bottom, left, right)

        if settings.outline then
            draw.Color(0, 0, 0, 255)
            draw.OutlinedRect(left - 1, top[2] - 1, right + 1, bottom[2] + 1)
            draw.OutlinedRect(left + 1, top[2] + 1, right - 1, bottom[2] - 1)
        end

        ::continue::
    end
end

local function DrawPlayers(shootpos, index, team)
    for _, entity in pairs(Players) do
        if not entity:IsAlive() then goto continue end
        if entity:IsDormant() then goto continue end
        if entity:GetTeamNumber() == team and settings.enemy_only and entity:GetIndex() ~= index then goto continue end
        if entity:GetIndex() == index and not GB_SETTINGS.visuals.thirdperson.enabled then goto continue end
        if entity:InCond(E_TFCOND.TFCond_Cloaked) and settings.hide_cloaked then goto continue end

        local maxs = entity:GetMaxs()
        if settings.visible_only then
            --- we dont need mins if we dont want to see invisible dudes
            local mins = entity:GetMins()
            local center = entity:GetAbsOrigin() + ((maxs + mins) >> 1)
            local trace = engine.TraceLine(shootpos, center, MASK_SHOT_HULL)
            if not trace or trace.fraction <= 0.7 then goto continue end
        end

        local headpos = entity:GetAbsOrigin() + Vector3(0, 0, maxs.z)

        local top, bottom
        top = client.WorldToScreen(headpos)
        bottom = client.WorldToScreen(entity:GetAbsOrigin() - Vector3(0, 0, 9))
        if not top or not bottom then goto continue end

        local h = bottom[2] - top[2]
        local w = math.floor(h * 0.3)

        local left, right
        left = top[1] - w
        right = top[1] + w

        local color = colors.get_entity_color(entity) or { 255, 255, 255, 255 }
        local r, g, b, a = table.unpack(color)
        a = 255
        local actualcolor = { r, g, b, a }

        if settings.fade then
            draw.Color(table.unpack(actualcolor or { 255, 255, 255, 255 }))
            draw.FilledRectFastFade(left + 1, top[2] + 1, right - 1, bottom[2] - 1, top[2] + 1, bottom[2] - 1, 0, 50,
                false)
        end

        draw.Color(table.unpack(actualcolor))
        draw.OutlinedRect(left, top[2], right, bottom[2])

        utils.DrawHealthBar(entity:GetHealth(), entity:GetMaxHealth(), top, bottom, left, h)

        if entity:GetHealth() > entity:GetMaxHealth() then
            --- overheal
            utils.DrawOverhealBar(entity:GetHealth(), entity:GetMaxHealth(), entity:GetMaxBuffedHealth(), top, bottom,
                left, h)
        end

        if settings.outline then
            draw.Color(0, 0, 0, 255)
            draw.OutlinedRect(left - 1, top[2] - 1, right + 1, bottom[2] + 1)
            draw.OutlinedRect(left + 1, top[2] + 1, right - 1, bottom[2] - 1)
        end

        draw.Color(255, 255, 255, 255)
        utils.DrawClass(font, top, entity:GetPropInt("m_PlayerClass", "m_iClass"))

        ::continue::
    end
end

function esp.Draw()
    if not settings.enabled then return end
    if engine:IsGameUIVisible() or engine:Con_IsVisible() then return end
    if not Players or #Players == 0 then return end

    local localplayer = entities:GetLocalPlayer()
    if not localplayer then return end

    local team = localplayer:GetTeamNumber()
    local index = localplayer:GetIndex()
    local shootpos = localplayer:GetAbsOrigin() + localplayer:GetPropVector("m_vecViewOffset[0]")

    if settings.filter.players then
        DrawPlayers(shootpos, index, team)
    end

    if settings.filter.sentries and Sentries then
        DrawBuildings(Sentries, localplayer, shootpos)
    end

    if settings.filter.other_buildings and (Dispensers or Teleporters) then
        if Dispensers then
            DrawBuildings(Dispensers, localplayer, shootpos)
        end

        if Teleporters then
            DrawBuildings(Teleporters, localplayer, shootpos)
        end
    end
end

function esp.unload()
    esp = nil
    colors = nil
end

local function CMD_ToggleESP()
    settings.enabled = not settings.enabled
    printc(150, 150, 255, 255, "ESP is now " .. (settings.enabled and "enabled" or "disabled"))
end

local function CMD_ToggleVisibleOnly()
    settings.visible_only = not settings.visible_only
    printc(150, 150, 255, 255, "ESP visible only is " .. (settings.visible_only and "enabled" or "disabled"))
end

local function CMD_ToggleEnemyOnly()
    settings.enemy_only = not settings.enemy_only
    printc(150, 150, 255, 255, "ESP enemy only is " .. (settings.enemy_only and "enabled" or "disabled"))
end

local function CMD_ToggleHideCloaked()
    settings.hide_cloaked = not settings.hide_cloaked
    printc(150, 150, 255, 255, "ESP cloaked spy is " .. (settings.hide_cloaked and "enabled" or "disabled"))
end

GB_GLOBALS.RegisterCommand("esp->toggle", "Toggles esp", 0, CMD_ToggleESP)
GB_GLOBALS.RegisterCommand("esp->toggle->enemy", "Makes esp only run on enemies or everyoe", 0, CMD_ToggleEnemyOnly)
GB_GLOBALS.RegisterCommand("esp->toggle->cloaked", "Makes esp not run on cloaked spies or not", 0, CMD_ToggleHideCloaked)
GB_GLOBALS.RegisterCommand("esp->toggle->visible", "Makes esp only run on visible players or everyone", 0,
    CMD_ToggleVisibleOnly)
return esp

end)
__bundle_register("src.esp.utils", function(require, _LOADED, __bundle_register, __bundle_modules)
local utils = {}

local mfloor = math.floor
local mmin = math.min
local mmax = math.max

local classes = {
    [1] = "scout",
    [3] = "soldier",
    [7] = "pyro",
    [4] = "demo",
    [6] = "heavy",
    [9] = "engineer",
    [5] = "medic",
    [2] = "sniper",
    [8] = "spy",
 }

function utils.DrawClass(font, top, class)
    local pos = top
    if pos then
        draw.SetFont(font)
        local str = tostring(classes[class])
        local textw, texth = draw.GetTextSize(str)
        draw.TextShadow(mfloor(pos[1] - textw / 2), mfloor(pos[2] - texth), str)
    end
end

function utils.DrawBuildingClass(font, top, class)
    local pos = top
    if pos then
        draw.SetFont(font)
        local str = tostring(class)

        str = string.gsub(str, "CObject", "")
        str = string.gsub(str, "gun", "")

        local textw, texth = draw.GetTextSize(str)
        draw.TextShadow(mfloor(pos[1] - textw / 2), mfloor(pos[2] - texth), str)
    end
end

function utils.GetHealthColor(currenthealth, maxhealth)
    local healthpercentage = currenthealth / maxhealth
    healthpercentage = mmax(0, mmin(1, healthpercentage))
    local red = 1 - healthpercentage
    local green = healthpercentage
    red = mmax(0, mmin(1, red))
    green = mmax(0, mmin(1, green))
    return mfloor(255 * red), mfloor(255 * green), 0
end

---@param health integer
---@param maxhealth integer
---@param top {[1]: number, [2]: number}
---@param bottom {[1]: number, [2]: number}
---@param left number
---@param h number
function utils.DrawHealthBar(health, maxhealth, top, bottom, left, h, color)
    draw.Color(255, 255, 255, 255)
    local thickness = 1
    local wideness = 6
    local gap = 3

    local x1, y1, x2, y2
    x1 = left - wideness
    y1 = top[2]
    x2 = left - gap
    y2 = bottom[2]

    local percent = health / maxhealth
    percent = percent > 1 and 1 or (percent < 0 and 0 or percent)

    draw.Color(0, 0, 0, 255)
    draw.FilledRect(x1 - thickness, y1 - thickness, x2 + thickness, y2 + thickness)

    local r, g, b

    if color then
        r, g, b = table.unpack(color)
    else
        r, g, b = utils.GetHealthColor(health, maxhealth)
    end

    draw.Color(r, g, b, 255)
    --draw.FilledRect(x1, math.floor(y1 + (h * (1 - percent))), x2, y2)
    draw.FilledRectFade(x1, math.floor(y1 + (h * (1 - percent))), x2, y2, 255, 50, false)
end

---@param health integer
---@param maxhealth integer
---@param top {[1]: number, [2]: number}
---@param bottom {[1]: number, [2]: number}
---@param left number
---@param h number
function utils.DrawOverhealBar(health, maxhealth, maxoverhealhealth, top, bottom, left, h)
    local wideness = 6
    local gap = 3

    local x1, y1, x2, y2
    x1 = left - wideness
    y1 = top[2]
    x2 = left - gap
    y2 = bottom[2]

    local percent = (health - maxhealth) / (maxoverhealhealth - maxhealth)
    percent = percent > 1 and 1 or (percent < 0 and 0 or percent)

    local r, g, b = 0, 255, 255

    draw.Color(r, g, b, 200)
    draw.FilledRect(x1, math.floor(y1 + (h * (1 - percent))), x2, y2)
end

function utils.DrawVerticalHealthBar(health, maxhealth, bottom, left, right)
    local thickness = 1
    local height = 6
    local gap = 3

    local x1, y1, x2, y2
    x1 = left
    y1 = bottom[2] + gap
    x2 = right
    y2 = bottom[2] + height

    local percent = health / maxhealth
    percent = percent > 1 and 1 or (percent < 0 and 0 or percent)

    draw.Color(0, 0, 0, 255)
    draw.FilledRect(x1 - thickness, y1 - thickness, x2 + thickness, y2 + thickness)

    local r, g, b = utils.GetHealthColor(health, maxhealth)
    draw.Color(r, g, b, 255)
    draw.FilledRect(x1, y1, math.floor(x1 + ((right - left) * percent)), y2)
end

return utils

end)
__bundle_register("src.triggerbot", function(require, _LOADED, __bundle_register, __bundle_modules)
local gb = GB_GLOBALS
local gb_settings = GB_SETTINGS
assert(gb, "aimbot: gb is nil!")
assert(gb_settings, "aimbot: GB_SETTINGS is nil!")

local triggerbot = {}
local settings = gb_settings.triggerbot

local DEMOMAN_CLASS = 4
local MAX_UPGRADE_LEVEL = 3

local special_classes = {
   engineer = 9,
   spy = 8
}

local player = {
   alive = false,
   team = 0,
   metal = 0,
   index = 0,
   class = 0,
   eyeangles = {0, 0, 0},

   weapon = {
      ammo = 0,
      canshoot = false,
      is_melee = false,
      is_hitscan = false,
      index = 0,
   }
}

local ResetTable

ResetTable = function(t)
   for key, value in pairs (t) do
      if type(value) == "table" then
         ResetTable(value)
      elseif type(value) == "number" then
         t[key] = 0
      elseif type(value) == "boolean" then
         t[key] = false
      end
   end
end

local function ResetPlayer()
   ResetTable(player)
end

local function IsBuilding(entity)
   local class = entity:GetClass()
   return class == "CObjectSentrygun" or class == "CObjectDispenser" or class == "CObjectTeleporter"
end

---@param usercmd UserCmd
---@param target Entity
local function AutoWrench(usercmd, target)
   if not target then return false end
   if settings.filter.autowrench and player.class == special_classes.engineer then
      if target and IsBuilding(target) and target:GetTeamNumber() == player.team then
         if player.metal > 0 and ((target:GetHealth() >= 1 and target:GetHealth() < target:GetMaxHealth())
         or (target:GetPropInt("m_iUpgradeLevel") < MAX_UPGRADE_LEVEL)) then
            gb.nAimbotTarget = target:GetIndex()
            gb.bIsAimbotShooting = true
            usercmd.buttons = usercmd.buttons | IN_ATTACK
         end
      end
   end
end

---@param usercmd UserCmd
local function AutoBackstab(usercmd)
   if settings.filter.autobackstab and player.class == special_classes.spy and player.weapon.canbackstab then
      usercmd.buttons = usercmd.buttons | IN_ATTACK
   end
end

---TODO: find a way to optimize this
---@param usercmd UserCmd
local function AutoSticky(usercmd)
   if not (player.class == DEMOMAN_CLASS) then return end

   local stickies = entities.FindByClass("CTFGrenadePipebombProjectile")
   for _, entity in pairs (Players) do
      if entity:IsDormant() or not entity:IsAlive() or not entity:IsValid() then goto skip_player end
      if entity:GetTeamNumber() == player.team then goto skip_player end
      if entity:GetIndex() == client:GetLocalPlayerIndex() then goto skip_player end
      if settings.options.sticky_ignore_cloaked_spies and entity:InCond(E_TFCOND.TFCond_Cloaked) then goto skip_player end
      if entity:InCond(E_TFCOND.TFCond_Ubercharged) then goto skip_player end

      for _, sticky in pairs (stickies) do
         if not sticky:IsValid() then goto continue end

         --- this is probably not a good idea
         --- but m_bIsLive is as useful as just shooting myself
         --- m_vecVelocity is inacurate
         --- we have no m_flSpawnTime netvar :D
         if sticky:EstimateAbsVelocity():Length() > 0 then goto continue end

         local owner = sticky:GetPropEntity("m_hThrower")
         if not owner or owner:GetIndex() ~= player.index then goto continue end

         local pos = sticky:GetAbsOrigin()
         local entitypos = entity:GetAbsOrigin()
         local vecdistance = pos - entitypos
         local distance = math.abs(vecdistance:Length())

         if distance <= settings.options.sticky_distance then
            usercmd.buttons = usercmd.buttons | IN_ATTACK2
            return
         end

         ::continue::
      end
      ::skip_player::
   end
end

---@param usercmd UserCmd
local function HitscanWeapon(usercmd)
   local viewangles = engine:GetViewAngles()
   local eyeangles = Vector3(table.unpack(player.eyeangles))
   local dest = eyeangles + (viewangles:Forward() * 8192)

   local trace = engine.TraceLine(eyeangles, dest, MASK_SHOT_HULL)
   if not trace or trace.fraction >= gb.flVisibleFraction then return false end

   local target = trace.entity
   if not target or target:GetHealth() <= 0 then return false end
   if target:GetTeamNumber() == player.team then return false end
   if target:InCond(E_TFCOND.TFCond_Cloaked) and gb_settings.aimbot.ignore.cloaked then return end

   local center = target:GetAbsOrigin() + ((target:GetMins() + target:GetMaxs()) * 0.5)

   local centerangle = gb.ToAngle(center - eyeangles) - usercmd.viewangles
   local centerfov = (math.sqrt((centerangle.x^2) + (centerangle.y^2)))
   if centerfov >= settings.fov then
      local head = center + Vector3(0, 0, target:GetMaxs().z / 2)
      local headangle, headfov
      headangle = gb.ToAngle(head - eyeangles) - usercmd.viewangles
      headfov = math.sqrt((headangle.x^2 + headangle.y^2))
      if headfov >= settings.fov then return false end
   end

   gb.nAimbotTarget = target:GetIndex()
   gb.bIsAimbotShooting = true
   usercmd.buttons = usercmd.buttons | IN_ATTACK
   return true
end

---@param usercmd UserCmd
function triggerbot.CreateMove(usercmd)
   if not settings.enabled then return end

   gb.nAimbotTarget = nil
   gb.bIsAimbotShooting = false

   if settings.key and not input.IsButtonDown(settings.key) then return end
   if not player.alive then return end
   local weapon = entities.GetByIndex(player.weapon.index)
   if not weapon then return end

   AutoSticky(usercmd)

   if player.weapon.is_hitscan and settings.filter.hitscan then
      HitscanWeapon(usercmd)
      return

   elseif player.weapon.is_melee then
      local trace = weapon:DoSwingTrace()
      if not trace then return end
      if trace.fraction < gb.flVisibleFraction or not trace.entity:IsValid() or trace.entity:GetHealth() <= 0 then return end
      local target = trace.entity

      if target:GetTeamNumber() == player.team then
         AutoWrench(usercmd, target)
      else
         AutoBackstab(usercmd)
         if not settings.filter.melee then return end
         gb.nAimbotTarget = target:GetIndex()
         gb.bIsAimbotShooting = true
         usercmd.buttons = usercmd.buttons | IN_ATTACK
      end
   end
end

function triggerbot.FrameStageNotify(stage)
   if not (stage == E_ClientFrameStage.FRAME_NET_UPDATE_END) then return end

   local localplayer = entities:GetLocalPlayer()
   if not localplayer then ResetPlayer() return end

   local weapon = localplayer:GetPropEntity("m_hActiveWeapon")
   if not weapon then ResetPlayer() return end

   player.index = localplayer:GetIndex()
   player.alive = localplayer:IsAlive()
   player.metal = localplayer:GetPropDataTableInt("m_iAmmo")[4]
   player.team = localplayer:GetTeamNumber()
   player.class = localplayer:GetPropInt("m_PlayerClass", "m_iClass")

   local eyeangles = localplayer:GetAbsOrigin() + localplayer:GetPropVector("localdata", "m_vecViewOffset[0]")
   player.eyeangles = {eyeangles:Unpack()}

   player.weapon.ammo = weapon:GetPropInt("LocalWeaponData", "m_iClip1")
   player.weapon.canshoot = gb.CanWeaponShoot()
   player.weapon.index = weapon:GetIndex()
   player.weapon.is_hitscan = weapon:GetWeaponProjectileType() == E_ProjectileType.TF_PROJECTILE_BULLET
   player.weapon.is_melee = weapon:IsMeleeWeapon()

   if weapon:GetWeaponID() == E_WeaponBaseID.TF_WEAPON_KNIFE then
      player.weapon.canbackstab = weapon:GetPropBool("m_bReadyToBackstab")
   end
end

return triggerbot
end)
__bundle_register("src.aimbot", function(require, _LOADED, __bundle_register, __bundle_modules)
local gb = GB_GLOBALS
local gb_settings = GB_SETTINGS
assert(gb, "aimbot: gb is nil!")
assert(gb_settings, "aimbot: GB_SETTINGS is nil!")

local helpers = require("src.aimbot.helpers")
local hitscan = require("src.aimbot.hitscan")
local melee = require("src.aimbot.melee")
---local projectile = require("src.aimbot.projectile") WARNING: todo :)

local aimbot = {}

function aimbot.CreateMove(usercmd, player, weapon)
	local weapontype = weapon:GetWeaponProjectileType()

	if weapontype == E_ProjectileType.TF_PROJECTILE_BULLET then
		hitscan:CreateMove(usercmd, player)
	elseif weapon:IsMeleeWeapon() then
		melee:CreateMove(usercmd, weapon, player:GetTeamNumber())
	elseif weapontype ~= E_ProjectileType.TF_PROJECTILE_BULLET then
		---projectile:CreateMove(...)
	end
end

function aimbot.Draw()
	if not gb_settings.aimbot.fov_indicator or not gb_settings.aimbot.enabled then
		return
	end

	local localplayer = entities:GetLocalPlayer()
	if not localplayer then return end

	local width, height = draw.GetScreenSize()

	if localplayer and localplayer:IsAlive() and gb_settings.aimbot.fov <= 89 then
		local viewfov = gb_settings.visuals.custom_fov
		local aspectratio = (gb_settings.visuals.aspect_ratio == 0 and gb.nPreAspectRatio or gb_settings.visuals.aspect_ratio)
		viewfov = helpers:calc_fov(viewfov, aspectratio)
		local aimfov = gb_settings.aimbot.fov * (math.tan(math.rad(viewfov / 2)) / math.tan(math.rad(45)))

		if not aimfov or not viewfov then
			return
		end

		local radius = (math.tan(math.rad(aimfov) / 2)) / (math.tan(math.rad(viewfov) / 2)) * width
		draw.Color(255, 255, 255, 255)
		draw.OutlinedCircle(math.floor(width / 2), math.floor(height / 2), math.floor(radius), 64)
	end
end

local function cmd_ChangeAimbotMode(args)
	if not args or #args == 0 then
		return
	end
	local mode = tostring(args[1])
	gb_settings.aimbot.mode = gb.aimbot_modes[mode]
end

local function cmd_ChangeAimbotKey(args)
	if not args or #args == 0 then
		return
	end

	local key = string.upper(tostring(args[1]))

	local selected_key = E_ButtonCode["KEY_" .. key]
	if not selected_key then
		print("Invalid key!")
		return
	end

	gb_settings.aimbot.key = selected_key
end

local function cmd_ChangeAimbotFov(args)
	if not args or #args == 0 or not args[1] then
		return
	end
	gb_settings.aimbot.fov = tonumber(args[1])
end

local function cmd_ChangeAimbotIgnore(args)
	if not args or #args == 0 then
		return
	end
	if not args[1] or not args[2] then
		return
	end

	local option = tostring(args[1])
	local ignoring = gb_settings.aimbot.ignore[option] and "aiming for" or "ignoring"

	gb_settings.aimbot.ignore[option] = not gb_settings.aimbot.ignore[option]

	printc(150, 255, 150, 255, "Aimbot is now " .. ignoring .. " " .. option)
end

local function cmd_ToggleAimFov()
	gb_settings.aimbot.fov_indicator = not gb_settings.aimbot.fov_indicator
end

local function cmd_ChangeAimSmoothness(args, num_args)
	if not args or #args ~= num_args then
		return
	end
	local new_value = tonumber(args[1])
	if not new_value then
		printc(255, 150, 150, 255, "Invalid value!")
		return
	end
	gb_settings.aimbot.smooth_value = new_value
end

gb.RegisterCommand(
	"aimbot->change->mode",
	"Change aimbot mode | args: mode (plain, smooth or silent)",
	1,
	cmd_ChangeAimbotMode
)
gb.RegisterCommand("aimbot->change->key", "Changes aimbot key | args: key (w, f, g, ...)", 1, cmd_ChangeAimbotKey)
gb.RegisterCommand("aimbot->change->fov", "Changes aimbot fov | args: fov (number)", 1, cmd_ChangeAimbotFov)
gb.RegisterCommand(
	"aimbot->ignore->toggle",
	"Toggles a aimbot ignore option (like ignore cloaked) | args: option name (string)",
	1,
	cmd_ChangeAimbotIgnore
)
gb.RegisterCommand(
	"aimbot->change->smoothness",
	"Changes the smoothness value | args: new value (number, 0 to 1)",
	1,
	cmd_ChangeAimSmoothness
)

gb.RegisterCommand("aimbot->toggle->fovindicator", "Toggles aim fov circle", 0, cmd_ToggleAimFov)

local function unload()
	aimbot = nil
	helpers = nil
	hitscan = nil
	melee = nil
end

aimbot.unload = unload
return aimbot

end)
__bundle_register("src.aimbot.melee", function(require, _LOADED, __bundle_register, __bundle_modules)
local gb = GB_GLOBALS
assert(gb, "melee.lua: gb_globals is nil!")

local melee = {}
local gb_settings = GB_SETTINGS
local helpers = require("src.aimbot.helpers")

---@param usercmd UserCmd
---@param weapon Entity
function melee:CreateMove(usercmd, weapon, m_team)
	if not gb_settings.aimbot.melee then return end
	if gb_settings.aimbot.key and not input.IsButtonDown(gb_settings.aimbot.key) then return end

	local swing_trace = weapon:DoSwingTrace()
	if swing_trace and swing_trace.entity and swing_trace.fraction >= gb.flVisibleFraction then
		local entity = swing_trace.entity
		local entity_team = entity:GetTeamNumber()
		local index = entity:GetIndex()
		if entity_team ~= m_team and entity:IsAlive() then
			if weapon:GetWeaponID() == E_WeaponBaseID.TF_WEAPON_KNIFE then
				return
			end
			if gb_settings.aimbot.ignore.cloaked and entity:InCond(E_TFCOND.TFCond_Cloaked) then
				return
			end
			helpers:MakeWeaponShoot(usercmd, index)
			return
		end
	end
end

return melee
end)
__bundle_register("src.aimbot.helpers", function(require, _LOADED, __bundle_register, __bundle_modules)
local helpers = {}
local gb = GB_GLOBALS

local HEADSHOT_WEAPONS_INDEXES = {
	[230] = true, --- SYDNEY SLEEPER
	[61] = true, --- AMBASSADOR
	[1006] = true, --- FESTIVE AMBASSADOR
}

---@param usercmd UserCmd
---@param targetIndex integer
function helpers:MakeWeaponShoot(usercmd, targetIndex)
	usercmd.buttons = usercmd.buttons | IN_ATTACK
	gb.nAimbotTarget = targetIndex
	gb.bIsAimbotShooting = true
end

---@param bone Matrix3x4
function helpers:GetBoneOrigin(bone)
	return Vector3(bone[1][4], bone[2][4], bone[3][4])
end

--- returns true for head and false for body
function helpers:ShouldAimAtHead(localplayer, weapon)
	if localplayer and weapon then
		local weapon_id = weapon:GetWeaponID()
		local Head, Body = true, false

		if
			weapon_id == E_WeaponBaseID.TF_WEAPON_SNIPERRIFLE
			or weapon_id == E_WeaponBaseID.TF_WEAPON_SNIPERRIFLE_DECAP
		then
			return localplayer:InCond(E_TFCOND.TFCond_Zoomed) and Head or Body
		end

		local weapon_index = weapon:GetPropInt("m_Item", "m_iItemDefinitionIndex")

		if weapon_index and HEADSHOT_WEAPONS_INDEXES[weapon_index] then
			return weapon:GetWeaponSpread() > 0 and Body or Head
		end

		return Body
	end
	return nil
end

--- some people call it eye position
---@return Vector3 
function helpers:GetShootPosition(localplayer)
	return localplayer:GetAbsOrigin() + localplayer:GetPropVector("m_vecViewOffset[0]")
end

function helpers:calc_fov(fov, aspect_ratio)
	local halfanglerad = fov * (0.5 * math.pi / 180)
	local t = math.tan(halfanglerad) * (aspect_ratio / (4 / 3))
	local ret = (180 / math.pi) * math.atan(t)
	return ret * 2
end

return helpers
end)
__bundle_register("src.aimbot.hitscan", function(require, _LOADED, __bundle_register, __bundle_modules)
---@class AimTable
---@field bestangle Vector3?
---@field bestfov number
---@field targetindex integer?

local gb = GB_GLOBALS
local gb_settings = GB_SETTINGS
assert(gb, "hitscan.lua: gb_globals is nil!")

local hitscan = {}
local settings = gb_settings.aimbot

local helpers = require("src.aimbot.helpers")
local CLASS_BONES = require("src.hitboxes")

--- precomputed stuff
local rad45 = math.rad(45)
local TraceLine = engine.TraceLine
local sqrt = math.sqrt
--- 

---@param class Entity[]
---@param shoot_pos Vector3
---@param usercmd UserCmd
---@param punchangles Vector3
---@param aimtable AimTable
local function CheckClass(class, shoot_pos, usercmd, punchangles, aimtable)
   for _, entity in pairs(class) do
      local mins, maxs = entity:GetMins(), entity:GetMaxs()
      local center = entity:GetAbsOrigin() + ((mins + maxs) * 0.5)

      local trace = TraceLine(shoot_pos, center, MASK_SHOT_HULL)
      if trace and trace.entity == entity and trace.fraction >= gb.flVisibleFraction then
         local angle = gb.ToAngle(center - shoot_pos) - (usercmd.viewangles - punchangles)
         local fov = sqrt((angle.x ^ 2) + (angle.y ^ 2))

         if fov < aimtable.bestfov then
            aimtable.bestfov = fov
            aimtable.bestangle = angle
            aimtable.targetindex = entity:GetIndex() --- not saving the whole entity here, too much memory used!
         end
      end
   end
end

---@param should_aim_at_head boolean
---@param aimtable AimTable
local function CheckPlayers(usercmd, shoot_pos, m_team, punchangles, should_aim_at_head, aimtable)
   for _, entity in pairs(Players) do
		if not entity or entity:IsDormant() or not entity:IsAlive() or entity:GetTeamNumber() == m_team then
			goto continue
		end

		--- not the best way, probably using a single if statement would be better
		--- but i think its clearer what it does like this
		if entity:InCond(E_TFCOND.TFCond_Ubercharged) then
			goto continue
		elseif entity:InCond(E_TFCOND.TFCond_Cloaked) and gb_settings.aimbot.ignore.cloaked then
			goto continue
		elseif gb_settings.aimbot.ignore.bonked and entity:InCond(E_TFCOND.TFCond_Bonked) then
			goto continue
		elseif gb_settings.aimbot.ignore.deadringer and entity:InCond(E_TFCOND.TFCond_DeadRingered) then
			goto continue
		elseif gb_settings.aimbot.ignore.disguised and entity:InCond(E_TFCOND.TFCond_Disguised) then
			goto continue
		elseif gb_settings.aimbot.ignore.friends and playerlist.GetPriority(entity) == -1 then
			goto continue
		elseif gb_settings.aimbot.ignore.taunting and entity:InCond(E_TFCOND.TFCond_Taunting) then
			goto continue
		end

		local enemy_class = entity:GetPropInt("m_PlayerClass", "m_iClass")
		local best_bone_for_weapon = nil

		if should_aim_at_head == nil then
			goto continue
		elseif should_aim_at_head == true then
			best_bone_for_weapon = CLASS_BONES[enemy_class][1]
		elseif should_aim_at_head == false then
			best_bone_for_weapon = #CLASS_BONES[enemy_class] == 6 and CLASS_BONES[enemy_class][2]
				or CLASS_BONES[enemy_class][3] --- if size is 6 then we have no HeadUpper as the first value
		end

		local bones = entity:SetupBones()
		if not bones then
			goto continue
		end

		local bone_position = helpers:GetBoneOrigin(bones[best_bone_for_weapon])
		if not bone_position then
			goto continue
		end

		local trace = TraceLine(shoot_pos, bone_position, MASK_SHOT_HULL)
		if not trace then
			goto continue
		end

		local function do_aimbot_calc()
			local angle = gb.ToAngle(bone_position - shoot_pos) - (usercmd.viewangles - punchangles)
			local fov = sqrt((angle.x ^ 2) + (angle.y ^ 2))

			if fov < aimtable.bestfov then
				aimtable.bestfov = fov
				aimtable.bestangle = angle
				aimtable.targetindex = entity:GetIndex() --- not saving the whole entity here, too much memory used!
			end
		end

		if trace and trace.entity == entity and trace.fraction >= gb.flVisibleFraction then
			do_aimbot_calc()
		else
			local BONES = CLASS_BONES[enemy_class]
			for _, bone in ipairs(BONES) do
				--- already tried the best one
				if bone ~= best_bone_for_weapon then
					bone_position = helpers:GetBoneOrigin(bones[bone])
					if not bone_position then
						goto skip_bone
					end
					trace = TraceLine(shoot_pos, bone_position, MASK_SHOT_HULL)
					if not trace then
						goto skip_bone
					end
					if trace.entity == entity and trace.fraction >= gb.flVisibleFraction then
						do_aimbot_calc()
					end
				end
				::skip_bone::
			end
		end
		::continue::
	end
end

---@param usercmd UserCmd
---@param plocal Entity
function hitscan:CreateMove(usercmd, plocal)
   gb.bIsAimbotShooting = false
   gb.nAimbotTarget = nil

   if (gb.bSpectated and not settings.ignore.spectators)
   or not settings.enabled then
      return
   end

   if settings.key and not input.IsButtonDown(settings.key) then
		return
	end

   local team = plocal:GetTeamNumber()
   local weapon = plocal:GetPropEntity("m_hActiveWeapon")

   if settings.auto_spinup and weapon:GetWeaponID() == E_WeaponBaseID.TF_WEAPON_MINIGUN then
		usercmd.buttons = usercmd.buttons | IN_ATTACK2
	end

   local canshoot = gb.CanWeaponShoot() or gb.bDoubleTapping
   local is_stac = gb.bIsStacRunning

   local aim_mode = is_stac and gb.aimbot_modes.smooth or settings.mode
   local smoothvalue = is_stac and 20 or settings.smooth_value
   local aspectratio = (gb_settings.visuals.aspect_ratio == 0
   and gb.nPreAspectRatio
   or gb_settings.visuals.aspect_ratio)

   local fov = plocal:InCond(E_TFCOND.TFCond_Zoomed) and 20 or gb_settings.visuals.custom_fov
   local viewfov = helpers:calc_fov(fov, aspectratio)
   local aimfov = settings.fov * (math.tan(math.rad(viewfov / 2)) / math.tan(rad45))
   local shootpos = helpers:GetShootPosition(plocal)
   local punchangle = weapon:GetPropVector("m_vecPunchAngle") or Vector3()
   local aim_at_head = helpers:ShouldAimAtHead(plocal, weapon) and true or false

   ---@type AimTable
   local aimtable = {bestangle = nil, bestfov = aimfov, targetindex = nil}

   CheckClass(Dispensers, shootpos, usercmd, punchangle, aimtable)
   CheckClass(Teleporters, shootpos, usercmd, punchangle, aimtable)
   CheckPlayers(usercmd, shootpos, team, punchangle, aim_at_head, aimtable)
   CheckClass(Sentries, shootpos, usercmd, punchangle, aimtable)

   if not aimtable.bestangle or not aimtable.bestfov or not aimtable.targetindex then return end

   local viewangle = usercmd.viewangles
   local smoothval = vector.Multiply(aimtable.bestangle, smoothvalue * 0.01)

   if settings.humanized_smooth then
      smoothval.x = smoothval.x * engine.RandomFloat(0.8, 6)
      smoothval.y = smoothval.y * engine.RandomFloat(0.8, 6)
   end

   local smoothed = viewangle + smoothval
   local directangle = viewangle + aimtable.bestangle
   local distance = math.sqrt(aimtable.bestangle.x^2 + aimtable.bestangle.y^2)

   if aim_mode == gb.aimbot_modes.smooth or aim_mode == gb.aimbot_modes.assistance then
      if distance <= 1 then
         helpers:MakeWeaponShoot(usercmd, aimtable.targetindex)
      end

      --- early return if its assistance mode
      if aim_mode == gb.aimbot_modes.assistance then
         if usercmd.mousedx == 0 and usercmd.mousedy == 0 then
            return
         end
      end

      engine.SetViewAngles(EulerAngles(smoothed:Unpack()))
      usercmd.viewangles = smoothed

   else --- not smooth or assistance
      if not canshoot then return end

      if settings.autoshoot then
         helpers:MakeWeaponShoot(usercmd, aimtable.targetindex)
      end

      if (usercmd.buttons & IN_ATTACK) ~= 0 then
         usercmd.viewangles = directangle

         if aim_mode == gb.aimbot_modes.plain then
            engine.SetViewAngles(EulerAngles(directangle:Unpack()))
         end
      end
   end
end

return hitscan

end)
__bundle_register("src.hitboxes", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[
Hitboxes i'll use:
Head, center, left leg, right leg, left arm, right arm
im fucked
--]]

local CLASS_HITBOXES = {
	--[[scout]]
	[1] = {
		--[[Head =]]
		6,
		--[[Body =]]
		3,
		--[[LeftLeg =]]
		15,
		--[[RightLeg =]]
		16,
		--[[LeftArm =]]
		11,
		--[[RightArm =]]
		12,
	},

	--[[soldier]]
	[3] = {
		--[[HeadUpper =]]
		6, -- 32,
		--[[Head =]]
		32, -- 6,
		--[[Body =]]
		3,
		--[[LeftLeg =]]
		15,
		--[[RightLeg =]]
		16,
		--[[LeftArm =]]
		11,
		--[[RightArm =]]
		12,
	},

	--[[[pyro]]
	[7] = {
		--[[Head =]]
		6,
		--[[Body =]]
		2,
		--[[LeftLeg =]]
		16,
		--[[RightLeg =]]
		20,
		--[[LeftArm =]]
		9,
		--[[RightArm =]]
		13,
	},

	--[[demoman]]
	[4] = {
		--[[Head =]]
		16,
		--[[Body =]]
		3,
		--[[LeftLeg =]]
		10,
		--[[RightLeg =]]
		12,
		--[[LeftArm =]]
		13,
		--[[RightArm =]]
		14,
	},

	--[[heavy]]
	[6] = {
		--[[Head =]]
		6,
		--[[Body =]]
		3,
		--[[LeftLeg =]]
		15,
		--[[RightLeg =]]
		16,
		--[[LeftArm =]]
		11,
		--[[RightArm =]]
		12,
	},

	--[[engi]]
	[9] = {
		--[[HeadUpper =]]
		8, --61,
		--[[Head =]]
		61, --8,
		--[[Body =]]
		4,
		--[[LeftLeg =]]
		10,
		--[[RightLeg =]]
		2,
		--[[LeftArm =]]
		13,
		--[[RightArm =]]
		16,
	},

	--[[medic]]
	[5] = {
		--[[HeadUpper =]]
		6, --33,
		--[[Head =]]
		33, --6,
		--[[Body =]]
		2,
		--[[LeftLeg =]]
		15,
		--[[RightLeg =]]
		16,
		--[[LeftArm =]]
		11,
		--[[RightArm =]]
		12,
	},

	--[[sniper]]
	[2] = {
		--[[HeadUpper =]]
		6, --23,
		--[[Head =]]
		23, --6,
		--[[Body =]]
		2,
		--[[LeftLeg =]]
		15,
		--[[RightLeg =]]
		16,
		--[[LeftArm =]]
		11,
		--[[RightArm =]]
		12,
	},

	--[[spy]]
	[8] = {
		--[[Head =]]
		6,
		--[[Body =]]
		2,
		--[[LeftLeg =]]
		18,
		--[[RightLeg =]]
		19,
		--[[LeftArm =]]
		12,
		--[[RightArm =]]
		13,
	},
}

callbacks.Register("Unload", "UNLOAD garlic bread hitboxes", function ()
	CLASS_HITBOXES = nil
end)

return CLASS_HITBOXES

end)
__bundle_register("src.antiaim", function(require, _LOADED, __bundle_register, __bundle_modules)
local gb = GB_GLOBALS
local gb_settings = GB_SETTINGS
assert(gb, "antiaim: GB_GLOBALS is nil!")
assert(gb_settings, "antiaim: GB_SETTINGS is nil!")

---@diagnostic disable:cast-local-type
local antiaim = {}

local m_font = draw.CreateFont("TF2 BUILD", 12, 1000)

---@param usercmd UserCmd
function antiaim.CreateMove(usercmd)
	if gb_settings.antiaim.enabled and not gb.bIsStacRunning
	and not gb.bWarping and not gb.bRecharging
	and not (usercmd.buttons & IN_ATTACK ~= 0 and gb.CanWeaponShoot()) then
		--- make sure we aren't overchoking
		if clientstate:GetChokedCommands() >= 21 then
			usercmd.sendpacket = true
			return
		end

		local view = engine:GetViewAngles()

		local realyaw = view.y + (gb_settings.antiaim.real_yaw or 0)
		local fakeyaw = view.y + (gb_settings.antiaim.fake_yaw or 0)

		local is_real_yaw_tick = usercmd.tick_count % 2 == 0
		local yaw = is_real_yaw_tick and fakeyaw or realyaw

		usercmd.viewangles = Vector3(view.x, yaw, 0)
		usercmd.sendpacket = is_real_yaw_tick
	end
end

function antiaim.unload()
	antiaim = nil
	m_font = nil
end

function antiaim.Draw()
	if not gb_settings.antiaim.enabled then
		return
	end

	local player = entities:GetLocalPlayer()
	if not player or not player:IsAlive() then
		return
	end

	local origin = player:GetAbsOrigin()
	if not origin then
		return
	end

	local origin_screen = client.WorldToScreen(origin)
	if not origin_screen then
		return
	end

	local startpos = origin
	local endpos = nil
	local line_size = 25

	local viewangle = engine:GetViewAngles().y

	local real_yaw, fake_yaw = gb_settings.antiaim.real_yaw + viewangle, gb_settings.antiaim.fake_yaw + viewangle
	local real_direction, fake_direction
	real_direction = Vector3(math.cos(math.rad(real_yaw)), math.sin(math.rad(real_yaw)))
	fake_direction = Vector3(math.cos(math.rad(fake_yaw)), math.sin(math.rad(fake_yaw)))

	endpos = origin + (fake_direction * line_size)

	local startpos_screen = client.WorldToScreen(startpos)
	if not startpos_screen then
		return
	end
	local endpos_screen = client.WorldToScreen(endpos)
	if not endpos_screen then
		return
	end

	--- fake yaw
	draw.Color(255, 150, 150, 255)
	draw.Line(startpos_screen[1], startpos_screen[2], endpos_screen[1], endpos_screen[2])
	draw.SetFont(m_font)
	draw.Color(255, 255, 255, 255)
	draw.TextShadow(endpos_screen[1], endpos_screen[2], "fake yaw")

	--- real yaw
	draw.Color(150, 255, 150, 255)
	endpos = origin + (real_direction * line_size)
	endpos_screen = client.WorldToScreen(endpos)
	if not endpos_screen then
		return
	end

	draw.Line(startpos_screen[1], startpos_screen[2], endpos_screen[1], endpos_screen[2])
	draw.Color(255, 255, 255, 255)
	draw.SetFont(m_font)
	draw.TextShadow(endpos_screen[1], endpos_screen[2], "real yaw")
end

--- SetVAngles doesn't work
function antiaim.FrameStageNotify(stage)
	if stage == E_ClientFrameStage.FRAME_NET_UPDATE_START and gb_settings.antiaim.enabled then
		local localplayer = entities:GetLocalPlayer()
		if not localplayer then
			return
		end
		local viewangles = engine:GetViewAngles()
		local angle = Vector3(viewangles.x, viewangles.y + gb_settings.antiaim.fake_yaw, 0)
		localplayer:SetVAngles(angle)
	end
end

local function cmd_toggle_aa()
	if gb.bIsStacRunning then
		printc(255, 0, 0, 255, "STAC is active! Won't change AA")
		return
	end
	gb_settings.antiaim.enabled = not gb_settings.antiaim.enabled
	printc(150, 255, 150, 255, "Anti aim is now " .. (gb_settings.antiaim.enabled and "enabled" or "disabled"))
end

local function cmd_set_options(args)
	if not args or #args == 0 then
		return
	end
	if not args[1] or not args[2] then
		return
	end

	local fake = args[1] == "fake"
	local real = args[1] == "real"
	local new_value = tonumber(args[2])
	if not new_value then
		print("Invalid value!")
		return
	end

	--local key = "m_fl%s%s"
	--local formatted = string.format(key, fake and "Fake" or "Real", wants_yaw and "Yaw" or "Pitch")
	if fake then
		gb_settings.antiaim.fake_yaw = new_value
	elseif real then
		gb_settings.antiaim.real_yaw = new_value
	end
end

gb.RegisterCommand(
	"antiaim->change",
	"Changes antiaim's yaw | args: fake or real (string), new value (number)",
	2,
	cmd_set_options
)
gb.RegisterCommand("antiaim->toggle", "Toggles antiaim", 0, cmd_toggle_aa)
return antiaim

end)
__bundle_register("src.spectatorlist", function(require, _LOADED, __bundle_register, __bundle_modules)
local gb = GB_GLOBALS
local gb_settings = GB_SETTINGS
assert(gb, "spectatorlist: GB_GLOBALS is nil!")
assert(gb_settings, "spectatorlist: GB_SETTINGS is nil!")

local feature = {}

---@type table<integer, {name: string, mode: boolean}>
local m_players = {}
local m_font = draw.CreateFont("TF2 BUILD", 16, 1000)
local m_unformattedstr = "%s is spectating you"

local OBS_MODE = {
	MODE_NONE= 0,	-- not spectating
	MODE_DEATHCAM = 2,	-- death cam animation
	MODE_FREEZECAM = 2,	-- that freeze frame when ded
	MODE_FIXED = 2,		-- viewing on a fixed cam pos
	MODE_IN_EYE = 2,	-- spectating in first person
	MODE_CHASE = 2,		-- spectating in third person
	MODE_POI = 2,		-- passtime point of interest, idk never played that
	MODE_ROAMING = 2,	-- they are free roaming some more
}

---@param stage E_ClientFrameStage
local function FrameStageNotify(stage)
   if not gb_settings.spectatorlist.enabled then return end
   if not (stage == E_ClientFrameStage.FRAME_NET_UPDATE_END) then return end

   local localplayer = entities:GetLocalPlayer()
   if not localplayer then return end
   local localindex = localplayer:GetIndex()

   local being_spectated = false
   local players_spectating = {}

   local players = entities.FindByClass("CTFPlayer")

   for _, entity in pairs (players) do
      if entity:GetIndex() ~= localindex and not entity:IsDormant() and entity and entity:IsPlayer() and entity:IsValid() and not entity:IsAlive() then
         local mode = entity:GetPropInt("m_iObserverMode")
         local target = entity:GetPropEntity("m_hObserverTarget")

         if target and target:IsValid() and target:GetIndex() == localindex then
            being_spectated = true
            local name = entity:GetName()
            local in_firstperson = mode == OBS_MODE.MODE_IN_EYE

            players_spectating[#players_spectating+1] = {name = name, mode = in_firstperson}
         end
      end
   end

   gb.bSpectated = being_spectated
   m_players = players_spectating
end

local function Draw()
   if not gb_settings.spectatorlist.enabled then return end
   if not gb.bSpectated then return end
   if not m_players then return end
   if engine:IsGameUIVisible() or engine:Con_IsVisible() then return end

   local width, height = draw.GetScreenSize()
   local centerx, centery = math.floor(width * 0.5), math.floor(height * 0.5)
   local y = math.floor(centery * gb_settings.spectatorlist.starty)
   local gap = 2 --- pixels

   for _, player in pairs (m_players) do
      local name = player.name
      local mode = player.mode
      local str = string.format(m_unformattedstr, name)

      draw.SetFont(m_font)
      local textw, texth = draw.GetTextSize(str)
      local x = math.floor( centerx - math.floor(textw * 0.5) )
      local color = not mode and {255, 255, 255, 255} or {255, 100, 100, 255}

      draw.Color(table.unpack(color))
      draw.SetFont(m_font)
      draw.TextShadow(x, y, str)

      y = y + texth + gap
   end
end

feature.FrameStageNotify = FrameStageNotify
feature.Draw = Draw

local function CMD_ToggleSpecList()
   gb_settings.spectatorlist.enabled = not gb_settings.spectatorlist.enabled
   printc(150, 255, 150, 255, "Spectator list is now " .. (gb_settings.spectatorlist.enabled and "enabled" or "disabled"))
end

local function CMD_SetStartY(args, num_args)
   if not args or not #args == num_args then return end
   local newy = tonumber(args[1])
   if newy then
      gb_settings.spectatorlist.starty = newy
      printc(150, 150, 255, 255, "Spectator list y is changed")
   end
end

gb.RegisterCommand("spectators->toggle", "Toggles the spectator list", 0, CMD_ToggleSpecList)
gb.RegisterCommand("spectators->sety", "Changes the starting Y position (percentage) of your screen, args: new y (number 0 to 1)", 1, CMD_SetStartY)

feature.unload = function()
   feature = nil
   m_players = nil
   m_font = nil
   m_unformattedstr = nil
   OBS_MODE = nil
end

return feature
end)
__bundle_register("src.spoof_convars", function(require, _LOADED, __bundle_register, __bundle_modules)
local clc_RespondCvarValue = 13
local spoofed_cvars = {}
local funcs = {}

---@param msg NetMessage
---@param returnval {ret: boolean}
function funcs.SendNetMsg(msg, returnval)
   if (msg:GetType() == clc_RespondCvarValue) then
      local bf = BitBuffer()
      bf:Reset()

      msg:WriteToBitBuffer(bf)
      local result = CLC_RespondCvarValue:ReadFromBitBuffer(bf)
      local cvar = spoofed_cvars[result.cvarName]

      if (cvar) then
         CLC_RespondCvarValue:WriteToBitBuffer(bf, result.cvarName, cvar)
         msg:ReadFromBitBuffer(bf)
         returnval.ret = true
      end

      bf:Delete()
   end
end

--- gb setsvar name value

local function CMD_SpoofConVar(args, num_args)
   if (not args or #args ~= num_args) then return end
   local cvar = tostring(args[1])
   local var = tostring(args[2])
   spoofed_cvars[cvar] = var
   client.SetConVar(cvar, var)
end

function funcs.unload()
   clc_RespondCvarValue = nil
   spoofed_cvars = nil
   funcs = nil
end

function SpoofConVar(convar, value)
   spoofed_cvars[convar] = value
end

function UnSpoofConVar(convar)
   if spoofed_cvars[convar] then
      spoofed_cvars[convar] = nil
   end
end

GB_GLOBALS.RegisterCommand("spoof->setsvar",
"Spoofs a convar to whatever you want the server to see | args: name, new value", 2, CMD_SpoofConVar)

return funcs
end)
__bundle_register("src.gui", function(require, _LOADED, __bundle_register, __bundle_modules)
local gb = GB_GLOBALS
local gb_settings = GB_SETTINGS
assert(gb, "gui: GB_GLOBALS is nil!")
assert(gb_settings, "gui: GB_SETTINGS is nil!")

---@diagnostic disable: assign-type-mismatch
local lib = require("src.gui utils")

-- Create a window instance
local window = lib.Window:new()
window.x = 1920/2
window.y = 0
window.background = {0, 0, 0, 200}

local title = lib.Text:new()
title.x = 27
title.y = 5
title.str = "Garlic Bread"
title.shadow_color = {150, 150, 255, 100}
title.shadow_voffset = 3
title.shadow_hoffset = 1
title.parent = window
window:AddChild(title)

local lasty = window.y + title.y + 16

--- toggles
for key, option in pairs (gb_settings.aimbot) do
   if type(option) == "boolean" then
      local button = lib.Checkbox:new()
      button.x = 2
      button.y = lasty
      button.background = {40, 40, 40, 255}
      button.outline = {255, 255, 255, 255}
      button.parent = window
      button.width = 180
      button.height = 26
      button.text = key
      button.text_color = {255, 255, 255, 255}
      button.checked = option
      button.events.onclick = function()
         gb_settings.aimbot[key] = not gb_settings.aimbot[key]
         button.checked = gb_settings.aimbot[key]
      end

      window:AddChild(button)
      lasty = lasty + button.height + window.children_gap
   end
end

local GUI = {}

function GUI.Draw()
   window:render()
end

function GUI.unload()
   window = nil
   title = nil
   lib = nil
end

return GUI
end)
__bundle_register("src.gui utils", function(require, _LOADED, __bundle_register, __bundle_modules)
local font = draw.CreateFont("TF2 BUILD", 14, 1000)
local GUI = {}

--- START ROOT

local last_clicked_tick = 0

---@class GUIRoot
---@field parent GUIWindow?
local GUIRoot = {
   width = 0, height = 0,
   x = 0, y = 0,
   background = {0, 0, 0, 250},
   outline = {255, 255, 255, 255},
   enabled = true,
   events = {},
   parent = nil,
}
setmetatable(GUIRoot, {__index = GUIRoot})
function GUIRoot:render()end

---@param parent GUIWindow?
---@param width integer?
---@param height integer?
function GUIRoot:CheckInput(parent, width, height)
   if not self.enabled then return end
   width = width or self.width
   height = height or self.height
   local mousePos = input:GetMousePos()
   local mx, my = mousePos[1], mousePos[2]
   local px, py = (parent and parent.x or 0), (parent and parent.y or 0)

   local mouseIsInside = mx >= self.x + px and mx <= self.x + width + px and my >= self.y + py and my <= self.y + height + py
   if not mouseIsInside then return end

   local state, tick = input.IsButtonPressed(E_ButtonCode.MOUSE_LEFT)

   -- Make sure we're checking events for THIS element, not another one
   if self.events.onhover then
      self.events.onhover(self)
   end

   if state and tick > last_clicked_tick and self.events.onclick then
      last_clicked_tick = tick
      self.events.onclick(self)
   end
end

---@param width integer?
---@param height integer?
function GUIRoot:DrawRectangle(width, height)
   width = width or self.width
   height = height or self.height
   local px, py = self.parent and self.parent.x or 0, self.parent and self.parent.y or 0
   draw.FilledRect(self.x + px, self.y + py, self.x + width + px, self.y + height + py)
end

---@param width integer?
---@param height integer?
function GUIRoot:DrawOutline(width, height)
   width = width or self.width
   height = height or self.height
   local px, py = self.parent and self.parent.x or 0, self.parent and self.parent.y or 0
   draw.Color(table.unpack(self.outline))
   draw.OutlinedRect(self.x + px, self.y + py, self.x + width + px, self.y + height + py)
end

--- END ROOT

--- START WINDOW

---@class GUIWindow: GUIRoot
---@field children (GUIRoot|GUIButton|GUIText)[]
local Window = {children = {}, vpadding = 5, hpadding = 5, children_gap = 10}
setmetatable(Window, {__index = GUIRoot})

function Window:render()
   --- find the width and height
   local width, height = 0, 0
   local num_children = #self.children

   for i = 1, num_children do
      local child = self.children[i]
      if child then
         width = math.max(width, child.width, child.x + child.width) + self.vpadding
         height = math.max(height, child.height, child.y + child.height) + self.hpadding
      end
   end
   draw.Color(table.unpack(self.background))
   draw.FilledRect(self.x, self.y, self.x + width, self.y + height)

   for i = 1, num_children do
      local child = self.children[i]
      child:render()
   end

   self:CheckInput(nil)
end

---@param child GUIRoot
function Window:AddChild(child)
   child.parent = self -- Set the parent reference
   self.children[#self.children+1] = child
end

function Window:new()
   local new = setmetatable({}, {__index = self})
   new.children = {}
   new.events = {}
   return new
end

--- END WINDOW

--- START BUTTON

---@class GUIButton: GUIRoot
local Button = {text = "", text_color = {0, 0, 0, 255}}
setmetatable(Button, {__index = GUIRoot})

function Button:render()
   draw.SetFont(font)

   local px, py = self.parent and self.parent.x or 0, self.parent and self.parent.y or 0

   local textw, texth = draw.GetTextSize(self.text)
   local middlex, middley = math.floor(self.x + (self.width * 0.5) - (textw * 0.5) + px), math.floor(self.y + (self.height * 0.5) - (texth * 0.5) + py)

   self.width = math.floor(math.max(textw, self.width)) + 10

   --- background
   draw.Color(table.unpack(self.background))
   self:DrawRectangle()

   --- outline
   self:DrawOutline()

   draw.Color(table.unpack(self.text_color))
   draw.TextShadow(middlex, middley, self.text)

   self:CheckInput(self.parent)
end

---@return GUIButton
function Button:new()
   local new = setmetatable({}, {__index = self})
   new.events = {}
   return new
end

--- END BUTTON

--- START TEXT

---@class GUIText: GUIRoot
local Text = {str = "", text_color = {255, 255, 255, 255}, shadow_color = {0, 0, 0, 220}, shadow_voffset = 0, shadow_hoffset = 0}
setmetatable(Text, {__index = GUIRoot})

---@return GUIText
function Text:new()
   local newtext = setmetatable({}, {__index = self})
   newtext.events = {}
   return newtext
end

function Text:render()
   draw.SetFont(font)

   local px, py = self.parent and self.parent.x or 0, self.parent and self.parent.y or 0

   --- shadow
   draw.Color(table.unpack(self.shadow_color))
   draw.Text(self.x + self.shadow_voffset + px, self.y + self.shadow_hoffset + py, self.str)

   draw.SetFont(font)

   --- text
   draw.Color(table.unpack(self.text_color))
   draw.Text(self.x + px, self.y + py, self.str)

   draw.SetFont(font)

   --- setting the text width & height so window can resize correctly
   local textw, texth = draw.GetTextSize(self.str)
   self.width = math.floor(textw)
   self.height = texth
end

--- END TEXT

--- START CHECKBOX

---@class GUICheckbox: GUIRoot
local Checkbox =
{
   text = "",
   text_color = {255, 255, 255, 255},
   checked = false,
   checked_color = {150, 255, 150, 255},
   unchecked_color = {255, 150, 150, 255}
}
setmetatable(Checkbox, {__index = GUIRoot})

---@return GUICheckbox
function Checkbox:new()
   local new = setmetatable({}, {__index = self})
   new.events = {}
   return new
end

function Checkbox:render()
   local px, py = self.parent and self.parent.x or 0, self.parent and self.parent.y or 0
   local gap = 5

   draw.SetFont(font)
   local textw, texth = draw.GetTextSize(self.text)
   local middley = math.floor(self.y + (self.height * 0.5) - (texth * 0.5) + py)

   local boxheight = math.floor(self.height * 0.5)
   local boxwidth = boxheight
   local fakewidth = math.floor(math.max(textw + gap, self.width + gap + boxwidth, textw))

   --- background
   draw.Color(table.unpack(self.background))
   self:DrawRectangle(fakewidth)
   self:DrawOutline(fakewidth)

   draw.Color(table.unpack(self.text_color))
   draw.SetFont(font)
   draw.TextShadow(px + self.x + gap, middley, self.text)

   do --- checkbox button
      local x = px + self.x + fakewidth - boxwidth - gap
      local y = py + math.floor(self.y + (self.height * 0.5) - (boxheight * 0.5))
      local color = self.checked and self.checked_color or self.unchecked_color
      draw.Color(table.unpack(color))
      draw.FilledRect(x, y, x + boxwidth, y + boxheight)
   end

   self:CheckInput(self.parent, fakewidth)
end

--- END CHECKBOX

GUI.Window = Window
GUI.Button = Button
GUI.Text = Text
GUI.Checkbox = Checkbox

return GUI
end)
__bundle_register("src.watermark", function(require, _LOADED, __bundle_register, __bundle_modules)
--- lol

local watermark = {}
local font = draw.CreateFont("TF2 BUILD", 24, 1000)
local smallfont -- = draw.CreateFont("TF2 BUILD", 12, 1000)
local settings = GB_SETTINGS.watermark

---@type string
local text
do
   if GB_GLOBALS.bIsPreRelease then
      text = "garlic bread - pre release"
   else
      text = "garlic bread"
   end
end

draw.SetFont(font)
local w, h = draw.GetTextSize(text)
local x, y = 10, 10
local padding = 2

w = math.floor(w) + padding
h = math.floor(h) + padding

--[[ source: https://github.com/EmmanuelOga/columns/blob/master/utils/color.lua#L113
 * Converts an HSV color value to RGB. Conversion formula
 * adapted from http://en.wikipedia.org/wiki/HSV_color_space.
 * Assumes h, s, and v are contained in the set [0, 1] and
 * returns r, g, and b in the set [0, 255].
 *
 * @param   Number  h       The hue
 * @param   Number  s       The saturation
 * @param   Number  v       The value
 * @return  Array           The RGB representation
]]
local function hsvToRgb(h, s, v, a)
   local r, g, b

   local i = math.floor(h * 6);
   local f = h * 6 - i;
   local p = v * (1 - s);
   local q = v * (1 - f * s);
   local t = v * (1 - (1 - f) * s);

   i = i % 6

   if i == 0 then
      r, g, b = v, t, p
   elseif i == 1 then
      r, g, b = q, v, p
   elseif i == 2 then
      r, g, b = p, v, t
   elseif i == 3 then
      r, g, b = p, q, v
   elseif i == 4 then
      r, g, b = t, p, v
   elseif i == 5 then
      r, g, b = v, p, q
   end

   return r * 255, g * 255, b * 255, a * 255
end

function watermark.Draw()
   if not settings.enabled then return end
   if engine:IsGameUIVisible() or engine:Con_IsVisible() then return end
   if engine:IsTakingScreenshot() then return end

   --- outline
   local hue = GB_GLOBALS.bIsStacRunning and 0 or 0.5
   draw.SetFont(font)

   do
      local r, g, b, a = hsvToRgb(hue, 0, 0.5, 1)
      r, g, b, a = math.floor(r), math.floor(g), math.floor(b), math.floor(a)
      draw.Color(r, g, b, a)
      draw.Text(x + padding, y + padding, text)
   end

   do
      local r, g, b, a = hsvToRgb(hue, 0, 1, 1)
      r, g, b, a = math.floor(r), math.floor(g), math.floor(b), math.floor(a)
      draw.Color(r, g, b, a)
      draw.Text(x, y, text)
   end

   if GB_GLOBALS.bIsStacRunning then
      if not smallfont then
         smallfont = draw.CreateFont("TF2 BUILD", 12, 1000)
      end

      draw.SetFont(smallfont)
      draw.Color(255, 0, 0, 255)
      draw.TextShadow(x, y + padding + h, "stac detected!")
   end
end

function watermark.unload()
   font = nil
   smallfont = nil
   text = nil
   w, h = nil, nil
   x, y = nil, nil
   padding = nil
   watermark = nil
end

return watermark

end)
__bundle_register("src.anticheat", function(require, _LOADED, __bundle_register, __bundle_modules)
local gb = GB_GLOBALS
assert(gb, "anticheat: GB_GLOBALS is nil!")

local clc_RespondCvarValue = 13
local SIGNONSTATE_TYPE = 6
local m_bEnabled = true

callbacks.Register("Unload", "UNLOAD garlic bread anticheat", function ()
	clc_RespondCvarValue = nil
	SIGNONSTATE_TYPE = nil
	m_bEnabled = nil
	callbacks.Unregister("SendNetMsg", "NETMSG garlic bread stac detector")
end)

---@param msg NetMessage
local function AntiCheat(msg)
	if (not m_bEnabled) then return true end
	if msg:GetType() == SIGNONSTATE_TYPE and clientstate:GetClientSignonState() == E_SignonState.SIGNONSTATE_NONE then
		gb.bIsStacRunning = false
	end

	if msg:GetType() == clc_RespondCvarValue and not gb.bIsStacRunning then
		gb.bIsStacRunning = true
		printc(255, 200, 200, 255, "STAC was detected! Some features are disabled")
		client.ChatPrintf("STAC was detected! Some features are disabled")
	end

	return true
end

callbacks.Register("SendNetMsg", "NETMSG garlic bread stac detector", AntiCheat)

local function CMD_Toggle()
	m_bEnabled = not m_bEnabled
	if (not m_bEnabled) then gb.bIsStacRunning = false end
	printc(255, 0, 0, 255, "STAC checker is " .. (m_bEnabled and "enabled" or "disabled"))
end

gb.RegisterCommand("anticheat->toggle_stac_check", "Lets go gambling!", 0,  CMD_Toggle)
end)
__bundle_register("src.bitbuf", function(require, _LOADED, __bundle_register, __bundle_modules)
---@diagnostic disable: duplicate-set-field
---@diagnostic disable: duplicate-doc-field
local MSG_SIZE = 6

CLC_RespondCvarValue = {}

---@param buffer BitBuffer
function CLC_RespondCvarValue:ReadFromBitBuffer(buffer)
	buffer:Reset()
	buffer:SetCurBit(MSG_SIZE)

	local m_iCookie = buffer:ReadInt(32)
	local m_eStatusCode = buffer:ReadInt(4) --- isnt this just a byte?
	local cvarName, cvarEndPos = buffer:ReadString(32)

	buffer:Reset()
	buffer:SetCurBit(MSG_SIZE)
	return {m_iCookie = m_iCookie, m_eStatusCode = m_eStatusCode, cvarName = cvarName, cvarEndPos = cvarEndPos}
end

---@param buffer BitBuffer
---@param cvarName string
---@param cvarValue string
function CLC_RespondCvarValue:WriteToBitBuffer(buffer, cvarName, cvarValue)
	buffer:Reset()
	buffer:SetCurBit(MSG_SIZE)

	--- skip cookie, we dont care about it :(
	buffer:ReadInt(32) --- m_iCookie
	local _, statusEndPos = buffer:ReadInt(4) --- m_eStatusCode

	local _, cvarNameEndPos = buffer:ReadString(32)

	buffer:SetCurBit(statusEndPos)
	buffer:WriteString(cvarName)

	buffer:SetCurBit(cvarNameEndPos)
	buffer:WriteString(cvarValue)

	buffer:Reset()
	buffer:SetCurBit(MSG_SIZE)
end

callbacks.Register("Unload", "UNLOAD garlic bread bitbuf", function ()
	MSG_SIZE = nil
	CLC_RespondCvarValue = nil
end)
end)
__bundle_register("src.settings", function(require, _LOADED, __bundle_register, __bundle_modules)
local aimbot_mode = { plain = "plain", smooth = "smooth", silent = "silent", assistance = "assistance" }
local json = require("src.json")
filesystem.CreateDirectory("Garlic Bread/Configs")

GB_SETTINGS = {
    privacy = {
        stop_when_taking_screenshot = true,
    },

    aimbot = {
        enabled = true,
        fov = 10,
        key = E_ButtonCode.KEY_LSHIFT,
        autoshoot = true,
        mode = aimbot_mode.silent,
        lock_aim = false,
        smooth_value = 1, --- lower value, smoother aimbot (10 = very smooth, 100 = basically plain aimbot)
        auto_spinup = true,
        fov_indicator = false,
        humanized_smooth = true,

        --- should aimbot run when using one of them?
        hitscan = true,
        projectile = true,
        melee = true,

        ignore = {
            cloaked = true,
            disguised = false,
            taunting = false,
            bonked = true,
            friends = false,
            deadringer = false,
            spectators = true,
        },

        aim = {
            players = true,
            npcs = true,
            sentries = true,
            other_buildings = true,
        },
    },

    triggerbot = {
        enabled = true,
        key = nil, --- no key means it will run in the background
        fov = 4.5,
        filter = {
            hitscan = false,
            autobackstab = true,
            autowrench = true,
            autosticky = true,
            melee = false,
        },

        options = {
            sticky_distance = 146,
            sticky_detonate_time = 0.8,
            sticky_ignore_cloaked_spies = true,
        },
    },

    esp = {
        enabled = true,
        hide_cloaked = true,
        enemy_only = false,
        visible_only = false,
        outline = true,
        fade = true,

        filter = {
            players = true,
            localplayer = true,
            sentries = true,
            other_buildings = true
        },
    },

    antiaim = {
        enabled = false,
        fake_yaw = 0,
        real_yaw = 0
    },

    hud = {
        enabled = false,
        crosshair_size = 8,
        crosshair_color = { 255, 255, 255, 255 },
    },

    chams = {
        enabled = false,
        update_interval = 5, --- ticks
        enemy_only = false,
        visible_only = false,
        original_player_mat = false,
        original_viewmodel_mat = false,
        ignore_disguised_spy = true,
        ignore_cloaked_spy = true,

        filter = {
            healthpack = true,
            ammopack = true,
            viewmodel_arm = true,
            viewmodel_weapon = true,
            players = true,
            sentries = true,
            dispensers = true,
            teleporters = true,
            money = true,
            localplayer = true,
            antiaim = true,
            backtrack = true,
            ragdolls = true,
        },
    },

    fakelag = {
        enabled = false,
        indicator = {
            enabled = true,
            firstperson = false,
        },
        ticks = 21,
    },

    visuals = {
        custom_fov = 90,
        aspect_ratio = 0,
        norecoil = false,
        thirdperson = {
            enabled = false,
            offset = { up = 0, right = 0, forward = 0 },
        },

        see_hits = {
            enabled = false,
            non_crit_color = { 255, 255, 255, 200 },
            crit_color = { 255, 0, 0, 255 },
        }
    },

    misc = {
        bhop = true,
    },

    tickshift = {
        warp = {
            send_key = E_ButtonCode.MOUSE_5,
            recharge_key = E_ButtonCode.MOUSE_4,
            while_shooting = false,
            standing_still = true,

            recharge = {
                standing_still = true,
            },

            passive = {
                enabled = false,
                while_dead = true,
                min_time = 0.5,
                max_time = 5,
                toggle_key = E_ButtonCode.KEY_R,
            },
        },

        doubletap = {
            enabled = true,
            key = E_ButtonCode.KEY_F,
            ticks = 24,
        },
    },

    spectatorlist = {
        enabled = true,
        starty = 0.3, -- (percentage from center screen height)
    },

    watermark = {
        enabled = true,
    },

    outline = {
        enabled = true,
        enemy_only = false,
        visible_only = true,
        weapons = true,
        hats = false,
        players = true,
        localplayer = true,
    },

    --[[info_panel = { planned to do later
		enabled = true,
		background = {40, 40, 40, 240},
		text_color = {255, 255, 255, 255},
		header = {
			color = {133, 237, 255, 255},
			text_color = {0, 0, 0, 255},
		},
	},]]
}

local function CMD_SaveSettings(args, num_args)
    if not args or #args ~= num_args then return end

    local filename = tostring(args[1])
    if not filename then return end

    local encoded = json.encode(GB_SETTINGS)
    io.output("Garlic Bread/Configs/" .. filename .. ".json")
    io.write(encoded)
    io.flush()
    io.close()
end

local function CMD_LoadSettings(args, num_args)
    if not args or #args ~= num_args then return end

    local filename = tostring(args[1])
    if not filename then return end

    local file = io.open("Garlic Bread/Configs/" .. filename .. ".json")
    if file then
        local content = file:read("a")
        local decoded = json.decode(content)

        for k, v in pairs(decoded) do
            GB_SETTINGS[k] = v
        end

        GB_SETTINGS = decoded
        file:close()
    end
end

local function CMD_GetAllSettingsFiles()
    filesystem.EnumerateDirectory("Garlic Bread/Configs/*.json", function(filename, attributes)
        local name = filename:gsub(".json", "")
        print(name)
    end)
end

GB_GLOBALS.RegisterCommand("settings->save", "Saves your config | args: file name (string)", 1, CMD_SaveSettings)
GB_GLOBALS.RegisterCommand("settings->load", "Loads a config | args: file name (string)", 1, CMD_LoadSettings)
GB_GLOBALS.RegisterCommand("settings->getconfigs", "Prints all configs", 0, CMD_GetAllSettingsFiles)

end)
__bundle_register("src.commands", function(require, _LOADED, __bundle_register, __bundle_modules)
local m_commands = {}
local m_prefix = "gb"

callbacks.Register("Unload", "UNLOAD garlic bread commands", function ()
	m_prefix = nil
	m_commands = nil
	callbacks.Unregister("SendStringCmd", "SSC garlic bread console commands")
end)

--- If no additional param other than cmdname, the command has no args
---@param cmdname string
---@param help string
---@param num_args integer
---@param func function?
local function RegisterCommand(cmdname, help, num_args, func)
	m_commands[cmdname] = {func = func, help = help, num_args = num_args}
end

---@param text string
local function RunCommand(text)
	local words = {}
	for word in string.gmatch(text, "%S+") do
		words[#words + 1] = word
	end

	if (words[1] ~= m_prefix) then return end
	--- remove prefix
	table.remove(words, 1)

	if (m_commands[words[1]]) then
		local command = m_commands[words[1]]
		table.remove(words, 1)

		local func = command.func
		assert(type(func) == "function", "SendStringCmd -> command.func is not a function! wtf")

		local num_args = command.num_args
		assert(type(num_args) == "number", "SendStringCmd -> command.num_args is not a number! wtf")

		local args = {}
		if num_args >= 1 then
			for i = 1, num_args do
				local arg = tostring(words[i])
				args[i] = arg
			end
		end

		local whole_string = table.concat(words, " ")
		func(args, num_args, whole_string)
	else
		printc(171, 160, 2, 255, "Invalid option! Use 'gb help' if you want to know the correct name")
		return false
	end
	return true
end

---@param cmd StringCmd
local function SendStringCmd(cmd)
	local sent_command = cmd:Get()
	if RunCommand(sent_command) then
		cmd:Set("")
	end
end

local function print_help()
	printc(255, 150, 150, 255, "Stac is " .. (GB_GLOBALS.bIsStacRunning and "detected" or "not running") .. " in this server")
	printc(255, 255, 255, 255, "The commands are:")
	for name, props in pairs (m_commands) do
		local str = "%s : %s"
		printc(200, 200, 200, 200, string.format(str, name, props.help))
	end
end

local function find_cmd(args, num_args)
	if not args or #args ~= num_args then return end
	local pattern = tostring(args[1])

	printc(255, 255, 0, 255, "commands found:")

	for name, command in pairs (m_commands) do
		if string.find(name, pattern) then
			printc(0, 255, 255, 255, tostring(name) .. " : " .. tostring(command.help))
		end
	end
end

RegisterCommand("help", "prints all command's description and usage", 0, print_help)
RegisterCommand("find", "tries to find what you're looking for | args: command name or something it has", 1, find_cmd)

GB_GLOBALS.RegisterCommand = RegisterCommand
GB_GLOBALS.RunCommand = RunCommand

callbacks.Unregister("SendStringCmd", "SSC garlic bread console commands")
callbacks.Register("SendStringCmd", "SSC garlic bread console commands", SendStringCmd)
end)
__bundle_register("src.globals", function(require, _LOADED, __bundle_register, __bundle_modules)
GB_GLOBALS = {
	bIsStacRunning = false,

	bIsAimbotShooting = false,
	nAimbotTarget = nil,

	bWarping = false,
	bRecharging = false,
	bDoubleTapping = false,

	nPreAspectRatio = 0,

	bSpectated = false,
	bFakeLagEnabled = false,

	aimbot_modes = {plain = "plain", smooth = "smooth", silent = "silent", assistance = "assistance"},

	flVisibleFraction = 0.4,

	bIsPreRelease = false,
}

local sqrt, atan = math.sqrt, math.atan
local RADPI = 180/math.pi

--[[local lastFire = 0
local nextAttack = 0
local old_weapon = nil]]

local function GetNextAttack(player)
	return player:GetPropFloat("bcc_localdata", "m_flNextAttack")
end

--[[local function GetLastFireTime(weapon)
	return weapon:GetPropFloat("LocalActiveTFWeaponData", "m_flLastFireTime")
end]]

local function GetNextPrimaryAttack(weapon)
	return weapon:GetPropFloat("LocalActiveWeaponData", "m_flNextPrimaryAttack")
end

--- https://www.unknowncheats.me/forum/team-fortress-2-a/273821-canshoot-function.html
--[[function GB_GLOBALS.CanWeaponShoot()
	local player = entities:GetLocalPlayer()
	if not player then return false end

	local weapon = player:GetPropEntity("m_hActiveWeapon")
	if not weapon or not weapon:IsValid() then return false end
	if weapon:GetPropInt("LocalWeaponData", "m_iClip1") == 0 then return false end

	local lastfiretime = GetLastFireTime(weapon)
	if lastFire ~= lastfiretime or weapon ~= old_weapon then
		lastFire = lastfiretime
		nextAttack = GetNextPrimaryAttack(weapon)
	end
	old_weapon = weapon
	return nextAttack <= globals.CurTime()
end]]

--- not sure if we should use this or the above
function GB_GLOBALS.CanWeaponShoot()
	local player = entities:GetLocalPlayer()
	if not player then return false end
	if player:InCond(E_TFCOND.TFCond_Taunting) then return false end

	local weapon = player:GetPropEntity("m_hActiveWeapon")
	if not weapon or not weapon:IsValid() then return false end
	if weapon:GetPropInt("LocalWeaponData", "m_iClip1") == 0 then return false end

	--- not a good solution but if it works it works
	if weapon:GetWeaponID() == E_WeaponBaseID.TF_WEAPON_PISTOL_SCOUT
	or weapon:GetWeaponID() == E_WeaponBaseID.TF_WEAPON_PISTOL then return true end
	if weapon:GetWeaponID() == E_WeaponBaseID.TF_WEAPON_MINIGUN then return true end

	--- globals.CurTime() is a little bit behind this one
	--- making us not able to shoot consistently and breaking the pistols
	local curtime = player:GetPropInt("m_nTickBase") * globals.TickInterval()
	return curtime >= GetNextPrimaryAttack(weapon) and curtime >= GetNextAttack(player)
end

---@param vec Vector3
function GB_GLOBALS.ToAngle(vec)
	local hyp = sqrt((vec.x * vec.x) + (vec.y * vec.y))
	return Vector3(atan(-vec.z, hyp) * RADPI, atan(vec.y, vec.x) * RADPI, 0)
end
end)
__bundle_register("src.welcome", function(require, _LOADED, __bundle_register, __bundle_modules)
local welcome_msg =
[[Welcome to Garlic Bread! :D
I hope you have fun]]

printc(150, 255, 150, 255, welcome_msg)
printc(255, 255, 255, 255, "You can use 'gb help' command to print all the console commands :)", "or use 'gb find' to find a command you want :)")
end)
return __bundle_require("__root")