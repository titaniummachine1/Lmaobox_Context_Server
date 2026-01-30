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
    Resolver Recode
    Author: titaniummachine1 (https://github.com/titaniummachine1)
    Credits:
    LNX (github.com/lnx00) for libries
]]

--[[ Annotations ]]
---@alias PlayerData { Angle: EulerAngles[], Position: Vector3[], SimTime: number[] }

--[[ Imports ]]
local Common = require("Resolver.Common")
local G = require("Resolver.Globals")
require("Resolver.Config")
require("Resolver.Visuals")
require("Resolver.Menu")

local function OnCreateMove(cmd)
    -- Update local player data
    G.pLocal.entity = entities.GetLocalPlayer() -- Update local player entity
    local pLocal = G.pLocal.entity
    if not pLocal or not pLocal:IsAlive() then return end -- If local player is not valid, returns

    G.Players = entities.FindByClass("CTFPlayer")
    G.pLocal.flags = pLocal:GetPropInt("m_fFlags")

    -- World properties
    G.World.Gravity = client.GetConVar("sv_gravity")
    G.World.StepHeight = pLocal:GetPropFloat("localdata", "m_flStepSize")
    G.World.Lerp = client.GetConVar("cl_interp") or 0
    G.World.latOut = clientstate.GetLatencyOut()
    G.World.latIn = clientstate.GetLatencyIn()
    G.World.Latency = Conversion.Time_to_Ticks((G.World.latOut + G.World.latIn) * (globals.TickInterval() * 66.67)) -- Converts time to ticks

    -- Player properties
    G.pLocal.Class = pLocal:GetPropInt("m_iClass") or 1
    G.pLocal.index = pLocal:GetIndex() or 1
    G.pLocal.team = pLocal:GetTeamNumber() or 1
    G.pLocal.ViewAngles = engine.GetViewAngles() or EulerAngles(0, 0, 0)
    G.pLocal.OnGround = (G.pLocal.flags & FL_ONGROUND == 1) or false

    G.pLocal.GetAbsOrigin = pLocal:GetAbsOrigin() or Vector3(0, 0, 0)
    local pLocalOrigin = G.pLocal.GetAbsOrigin
    local viewOffset = pLocal:GetPropVector("localdata", "m_vecViewOffset[0]") or Vector3(0, 0, 75)
    local adjustedHeight = pLocalOrigin + viewOffset
    local viewheight = (adjustedHeight - pLocalOrigin):Length()
    G.pLocal.Viewheight = viewheight
    G.pLocal.VisPos = G.pLocal.GetAbsOrigin + Vector3(0, 0, G.pLocal.Viewheight)

    -- Weapon properties
    G.pLocal.WpData.CurrWeapon.Weapon = pLocal:GetPropEntity("m_hActiveWeapon") or nil
    local weapon = G.pLocal.WpData.CurrWeapon.Weapon
    if not weapon then return end
    if not Common.SetupWeaponData() then return end
    if not Common.isValidWeapon(weapon) then return end
    if not Common.Helpers.CanShoot(weapon) then return end

    G.pLocal.Actions.Attacked = Common.pLocalFired(cmd, pLocal)

    G.ShouldFindTarget = G.pLocal.Actions.Attacked

    for steamID, data in pairs(G.Resolver.awaitingConfirmation) do
		Common.processConfirmation(steamID, data)
	end

    --[-----Get best target-----]
    if G.ShouldFindTarget == true then
        -- Check if need to search for target
        G.Target.entity = Common.GetBestTarget()
        local Target = G.Target.entity
        if G.Target.entity then
            G.Target.index = G.Target.entity:GetIndex()
            G.Target.AbsOrigin = G.Target.entity:GetAbsOrigin()
            G.Target.flags = pLocal:GetPropInt("m_fFlags")

            local Target_Origin = G.Target.AbsOrigin
            viewOffset = G.Target.entity:GetPropVector("localdata", "m_vecViewOffset[0]") or Vector3(0, 0, 75)
            adjustedHeight = Target_Origin + viewOffset
            viewheight = (adjustedHeight - Target_Origin):Length()
            G.Target.Viewheight = viewheight or 75
            G.Target.ViewPos = Target_Origin + Vector3(0,0,viewheight)
        end
    else
        G.ResetTarget()
        return
    end
end


local function fireGameEvent(event)
	if event:GetName() == 'player_hurt' then
		local victim = entities.GetByUserID(event:GetInt("userid"))
		local attacker = entities.GetByUserID(event:GetInt("attacker"))
		local headshot = Common.getBool(event, "crit")
        local pLocal = entities.GetLocalPlayer()

		if (attacker ~= nil and pLocal:GetName() ~= attacker:GetName()) then
			local attackerSteamID = Common.GetSteamID(attacker)
			Common.checkForFakePitch(attacker, attackerSteamID)
		end

		local steamID = Common.GetSteamID(victim)

		if G.Resolver.awaitingConfirmation[steamID] then
			G.Resolver.awaitingConfirmation[steamID].wasHit = headshot
            G.Resolver.awaitingConfirmation[steamID].Angles = victim:GetEyeAngles()
		else
			G.Resolver.lastHits[steamID] = {wasHit = headshot, time = globals.TickCount()} -- could have fired before createmove
		end
	end
end

callbacks.Unregister("CreateMove", "Resolver.CreateMove")
callbacks.Unregister("FireGameEvent", "Resolver.FireGameEvent")
--callbacks.Unregister("PostPropUpdate", "Resolver.PostPropUpdate")

callbacks.Register("CreateMove", "Resolver.CreateMove",  OnCreateMove)
callbacks.Register("FireGameEvent", "Resolver.FireGameEvent", fireGameEvent)
--callbacks.Register("PostPropUpdate", "Resolver.PostPropUpdate", propUpdate)

--[[ Play sound when loaded ]]--
client.Command('play "ui/buttonclick"', true) -- Play the "buttonclick" sound when the script is loaded
end)
__bundle_register("Resolver.Menu", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[debug commands
    client.SetConVar("cl_vWeapon_sway_interp",              0)             -- Set cl_vWeapon_sway_interp to 0
    client.SetConVar("cl_jiggle_bone_framerate_cutoff", 0)             -- Set cl_jiggle_bone_framerate_cutoff to 0
    client.SetConVar("cl_bobcycle",                     10000)         -- Set cl_bobcycle to 10000
    client.SetConVar("sv_cheats", 1)                                    -- debug fast setup
    client.SetConVar("mp_disable_respawn_times", 1)
    client.SetConVar("mp_respawnwavetime", -1)
    client.SetConVar("mp_teams_unbalance_limit", 1000)

    -- debug command: ent_fire !picker Addoutput "health 99999" --superbot
]]
local MenuModule = {}

--[[ Imports ]]
local G = require("Resolver.Globals")

---@type boolean, ImMenu
local menuLoaded, ImMenu = pcall(require, "ImMenu")
assert(menuLoaded, "ImMenu not found, please install it!")
assert(ImMenu.GetVersion() >= 0.66, "ImMenu version is too old, please update it!")

local lastToggleTime = 0
local Lbox_Menu_Open = true
local toggleCooldown = 0.1  -- 200 milliseconds

function MenuModule.toggleMenu()
    local currentTime = globals.RealTime()
    if currentTime - lastToggleTime >= toggleCooldown then
        Lbox_Menu_Open = not Lbox_Menu_Open  -- Toggle the state
        G.Gui.IsVisible = Lbox_Menu_Open
        lastToggleTime = currentTime  -- Reset the last toggle time
    end
end

function MenuModule.GetPressedkey()
    local pressedKey = Input.GetPressedKey()
        if not pressedKey then
            -- Check for standard mouse buttons
            if input.IsButtonDown(MOUSE_LEFT) then return MOUSE_LEFT end
            if input.IsButtonDown(MOUSE_RIGHT) then return MOUSE_RIGHT end
            if input.IsButtonDown(MOUSE_MIDDLE) then return MOUSE_MIDDLE end

            -- Check for additional mouse buttons
            for i = 1, 10 do
                if input.IsButtonDown(MOUSE_FIRST + i - 1) then return MOUSE_FIRST + i - 1 end
            end
        end
        return pressedKey
end


local bindTimer = 0
local bindDelay = 0.25  -- Delay of 0.25 seconds

local function handleKeybind(noKeyText, keybind, keybindName)
    if KeybindName ~= "Press The Key" and ImMenu.Button(KeybindName or noKeyText) then
        bindTimer = os.clock() + bindDelay
        KeybindName = "Press The Key"
    elseif KeybindName == "Press The Key" then
        ImMenu.Text("Press the key")
    end

    if KeybindName == "Press The Key" then
        if os.clock() >= bindTimer then
            local pressedKey = MenuModule.GetPressedkey()
            if pressedKey then
                if pressedKey == KEY_ESCAPE then
                    -- Reset keybind if the Escape key is pressed
                    keybind = 0
                    KeybindName = "Always On"
                    Notify.Simple("Keybind Success", "Bound Key: " .. KeybindName, 2)
                else
                    -- Update keybind with the pressed key
                    keybind = pressedKey
                    KeybindName = Input.GetKeyName(pressedKey)
                    Notify.Simple("Keybind Success", "Bound Key: " .. KeybindName, 2)
                end
            end
        end
    end
    return keybind, keybindName
end

function OnDrawMenu()
    draw.SetFont(Fonts.Verdana)
    draw.Color(255, 255, 255, 255)
    local Menu = G.Menu
    local Main = Menu.Main

    -- Inside your OnCreateMove or similar function where you check for input
    if input.IsButtonDown(KEY_INSERT) then  -- Replace 72 with the actual key code for the button you want to use
        MenuModule.toggleMenu()
    end

    if Lbox_Menu_Open == true and ImMenu and ImMenu.Begin("Resolver", true) then
            local Tabs = Menu.Tabs
            local TabsOrder = { "Main", "Settings", "Visuals"}

            ImMenu.BeginFrame(1)
            for _, tab in ipairs(TabsOrder) do
                if ImMenu.Button(tab) then
                    for otherTab, _ in pairs(Tabs) do
                        Tabs[otherTab] = (otherTab == tab)
                    end
                end
            end
            ImMenu.EndFrame()

            if Tabs.Main then
                ImMenu.BeginFrame(1)
                    Menu.Main.minPriority = ImMenu.Slider("Min Priority", Menu.Main.minPriority, 0, 10)
                ImMenu.EndFrame()

                ImMenu.BeginFrame(1)
                    Menu.Main.cycleYawFOV = ImMenu.Slider("Roll Fov", Menu.Main.cycleYawFOV, 1, 360)
                ImMenu.EndFrame()

                --[[ImMenu.BeginFrame(1)
                    ImMenu.Text("Keybind: ")
                    Menu.Aimbot.Keybind, Menu.Aimbot.KeybindName = handleKeybind("Always On", Menu.Aimbot.Keybind,  Menu.Aimbot.KeybindName)
                ImMenu.EndFrame()]]
            end

            if Tabs.Settings then
                ImMenu.BeginFrame(1)
                    Menu.Settings.onlyHeadshots = ImMenu.Checkbox("Headshots Only", Menu.Settings.onlyHeadshots)
                ImMenu.EndFrame()

                ImMenu.BeginFrame(1)
                    Menu.Settings.maxMisses = ImMenu.Slider("Max Misses", Menu.Settings.maxMisses, 1, 10)
                ImMenu.EndFrame()
            end

            if Tabs.Visuals then
                ImMenu.BeginFrame(1)
                Menu.Visuals.Enable = ImMenu.Checkbox("Enable", Menu.Visuals.Enable)
                ImMenu.EndFrame()
            end
        ImMenu.End()
    end
end

--[[ Callbacks ]]
callbacks.Unregister("Draw", "OnDrawMenu")                                   -- unregister the "Draw" callback
callbacks.Register("Draw", "OnDrawMenu", OnDrawMenu)                              -- Register the "Draw" callback 

return MenuModule
end)
__bundle_register("Resolver.Globals", function(require, _LOADED, __bundle_register, __bundle_modules)
local G = {}

G.Menu = {
    Tabs = {
        Main = true,
        Visuals = false,
        Settings = false,
    },

    Main = {
        minPriority = 0,
        cycleYawFOV = 360, -- FOV to use when cycling the yaw through keybind
    },
    Settings = {
        onlyHeadshots = true,
        maxMisses = 3,
        yawCycle = {
            0,
            90, -90,
        }
    },
    Visuals = {
        Enable = true,
    }
}

G.Resolver = {
    lastHits = {},
    awaitingConfirmation = {},
    usesAntiAim = {},
    customAngleData = {},
    misses = {},
    cycleKeyState = false,
    plocal = entities.GetLocalPlayer(),
}


G.Defaults = {
    entity = nil,
    index = 1,
    team = 1,
    Class = 1,
    AbsOrigin = Vector3{0, 0, 0},
    flags = 0,
    OnGround = true,
    ViewAngles = EulerAngles{0, 0, 0},
    Viewheight = Vector3{0, 0, 75},
    VisPos = Vector3{0, 0, 75},
    PredTicks = {},
    vHitbox = {Min = Vector3(-24, -24, 0), Max = Vector3(24, 24, 82)},
}

G.pLocal = {
    entity = nil,
    index = 1,
    flags = 0,
    team = 1,
    Class = 1,
    AbsOrigin = Vector3{0, 0, 0},
    OnGround = true,
    ViewAngles = EulerAngles{0, 0, 0},
    Viewheight = Vector3{0, 0, 75},
    VisPos = Vector3{0, 0, 75},
    PredTicks = {},
    NextAttackTime = 0,
    WpData = {
        UsingMargetGarden = false,
        PWeapon = {
            Weapon = nil,
            WeaponData = nil,
            WeaponID = nil,
            WeaponDefIndex = nil,
            WeaponDef = nil,
            WeaponName = nil,
        },
        MWeapon = {
            Weapon = nil,
            WeaponData = nil,
            WeaponID = nil,
            WeaponDefIndex = nil,
            WeaponDef = nil,
            WeaponName = nil,
        },
        CurrWeapon = {
            Weapon = nil,
            WeaponData = nil,
            WeaponID = nil,
            WeaponDefIndex = nil,
            WeaponDef = nil,
            WeaponName = nil, 
        },
        SwingData = {
            SmackDelay = 13,
            SwingRange = 48,
            SwingHullSize = 35.6,
            SwingHull = {Max = Vector3(17.8,17.8,17.8), Min = Vector3(-17.8,-17.8,-17.8)},
            TotalSwingRange = 48 + (35.6 / 2),
        },
    },
    Actions = {
        Can_Attack = false,
        Attacked = false,
        NextAttackTime = 0,
        NextAttackTime2 = 0,
        LastAttackTime = 0,
        TicksBeforeHit = 0,
    },
    vHitbox = {Min = Vector3(-24, -24, 0), Max = Vector3(24, 24, 82)}
}

G.Target = {
    entity = nil,
    index = nil,
    AbsOrigin = Vector3(0,0,0),
    flags = 0,
    Viewheight = 75,
    ViewPos = Vector3(0,0,75),
    PredTicks = {},
    vHitbox = {Min = Vector3(-24, -24, 0), Max = Vector3(24, 24, 82)}
}

G.Players = {}
G.ShouldFindTarget = false

function G.ResetTarget()
    G.Target = G.Defaults
end

function G.ResetLocal()
    G.pLocal = {
        entity = nil,
        Wentity = nil,
        index = 1,
        team = 1,
        Class = 1,
        AbsOrigin = Vector3{0, 0, 0},
        OnGround = true,
        ViewAngles = EulerAngles{0, 0, 0},
        Viewheight = Vector3{0, 0, 75},
        VisPos = Vector3{0, 0, 75},
        PredTicks = {},
        BacktrackTicks = {},
        AttackTicks = {},
        NextAttackTime = 0,
        WpData = {
            UsingMargetGarden = false,
            PWeapon = {
                Weapon = nil,
                WeaponData = nil,
                WeaponID = nil,
                WeaponDefIndex = nil,
                WeaponDef = nil,
                WeaponName = nil,
            },
            MWeapon = {
                Weapon = nil,
                WeaponData = nil,
                WeaponID = nil,
                WeaponDefIndex = nil,
                WeaponDef = nil,
                WeaponName = nil,
            },
            CurrWeapon = {
                Weapon = nil,
                WeaponData = nil,
                WeaponID = nil,
                WeaponDefIndex = nil,
                WeaponDef = nil,
                WeaponName = nil, 
            },
            SwingData = {
                SmackDelay = 13,
                SwingRange = 48,
                SwingHullSize = 35.6,
                SwingHull = {Max = Vector3(17.8,17.8,17.8), Min = Vector3(-17.8,-17.8,-17.8)},
                TotalSwingRange = 48 + (35.6 / 2),
            },
        },
        Actions = {
            CanSwing = false,
            Attacked = false,
            NextAttackTime = 0,
            NextAttackTime2 = 0,
            LastAttackTime = 0,
            TicksBeforeHit = 0,
            CanCharge = false,
        },
        BlastJump = false,
        ChargeLeft = 0,
        vHitbox = {Min = Vector3(-24, -24, 0), Max = Vector3(24, 24, 82)}
    }
end

G.StrafeData = {
    Strafe = false,
    lastAngles = {}, ---@type table<number, Vector3>
    lastDeltas = {}, ---@type table<number, number>
    avgDeltas = {}, ---@type table<number, number>
    strafeAngles = {}, ---@type table<number, number>
    inaccuracy = {}, ---@type table<number, number>
    pastPositions = {}, -- Stores past positions of the local player
    maxPositions = 4, -- Number of past positions to consider
}

G.World = {
    Gravity = 800,
    StepHeight = 18,
    Lerp = 0,
    Latency = 0,
    LatIn = 0,
    Lat_out = 0,
}

G.Visuals = {
    SphereCache = {},
}

G.Gui = {
    IsVisible = false,
    FakeLatency = false,
    FakeLatencyAmount = 0,
    Backtrack = false,
    CritHackKey = gui.GetValue("Crit Hack Key")
}

return G
end)
__bundle_register("Resolver.Visuals", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[ Imports ]]
local Common = require("Resolver.Common")
local G = require("Resolver.Globals")
local Visuals = {}

local tahoma_bold = draw.CreateFont("Tahoma", 12, 800, FONTFLAG_OUTLINE)

--[[ Functions ]]
local function doDraw()
    --if true then return end
    local Menu = G.Menu
    if (engine.Con_IsVisible() or engine.IsGameUIVisible() or G.Gui.IsVisible) or not Menu.Visuals.EnableVisuals then return end
end

--[[ Callbacks ]]
callbacks.Unregister("Draw", "AMVisuals_Draw")                                   -- unregister the "Draw" callback
callbacks.Register("Draw", "AMVisuals_Draw", doDraw)                              -- Register the "Draw" callback 

return Visuals
end)
__bundle_register("Resolver.Common", function(require, _LOADED, __bundle_register, __bundle_modules)
---@class Common
local Common = {}
local G = require("Resolver.Globals")
local Menu = G.Menu

---@type boolean, LNXlib
local libLoaded, Lib = pcall(require, "LNXlib")
assert(libLoaded, "LNXlib not found, please install it!")
assert(Lib.GetVersion() >= 1.0, "LNXlib version is too old, please update it!")
Common.Lib = Lib

Common.Log = Lib.Utils.Logger.new("Resolver")

-- Import utility functions
Math = Lib.Utils.Math
Conversion = Lib.Utils.Conversion
Input = Lib.Utils.Input
Commands = Lib.Utils.Commands
Timer = Lib.Utils.Timer
Conversion = Lib.Utils.Conversion

-- Import TF2 related functions
WPlayer = Lib.TF2.WPlayer
WWeapon = Lib.TF2.WWeapon
Helpers = Lib.TF2.Helpers
Common.Helpers = Helpers
Prediction = Lib.TF2.Prediction

-- Import UI related functions
Notify = Lib.UI.Notify
Fonts = Lib.UI.Fonts
Log = Lib.Utils.Logger.new("AdvancedMelee")
Log.Level = 0

--[[Common Functions]]--

function Common.Normalize(vec)
    local length = math.sqrt(vec.x * vec.x + vec.y * vec.y + vec.z * vec.z)
    return Vector3(vec.x / length, vec.y / length, vec.z / length)
end

local LastAttackTick = 0
local AttackHappened = false

function Common.GetSteamID(player)
	local playerInfo = client.GetPlayerInfo(player:GetIndex())
	return playerInfo.SteamID
end

function Common.GetLastAttackTime(cmd, weapon)
    local TickCount = globals.TickCount()
    local NextAttackTime = G.pLocal.Actions.NextAttackTime
    --return (nextPrimaryAttack <= G.CurTime()) and (nextAttack <= G.CurTime())
    if AttackHappened == false and NextAttackTime >= TickCount then
        LastAttackTick = TickCount
        --print(LastAttackTick)
        AttackHappened = true
        return LastAttackTick, AttackHappened
    elseif NextAttackTime < TickCount and AttackHappened == true then
        AttackHappened = false
    end
    return LastAttackTick, false
end

local hasAttacked = false
local lastAmmoCount = 0

-- Check if the local player has fired their weapon
function Common.pLocalFired(cmd, plocal)
	local weapon = plocal:GetPropEntity("m_hActiveWeapon")
    G.pLocal.Actions.NextAttackTime = Conversion.Time_to_Ticks(weapon:GetPropFloat("m_flLastFireTime") or 0)
	local ammoTable = plocal:GetPropDataTableInt("localdata", "m_iAmmo")
    G.pLocal.Actions.LastAttackTime, G.pLocal.Actions.Attacked = Common.GetLastAttackTime(cmd, weapon)

	if G.pLocal.Actions.Attacked then

        hasAttacked = false

		-- Check if ammo has decreased
		local currentAmmo = ammoTable[2]
		if currentAmmo < lastAmmoCount then
			hasAttacked = true
		end
        lastAmmoCount = currentAmmo

		-- Check if attack button was pressed
		if cmd:GetButtons() & IN_ATTACK == 1 then
			hasAttacked = true
		end

		-- Check if player has attacked
		if hasAttacked then
			return true
		end
	end
end

function Common.isUsingAntiAim(pitch)
	if pitch > 89.4 or pitch < -89.4 then
		return true
	end

	return false
end

function Common.checkForFakePitch(player, steamID)
	local angles = player:GetEyeAngles()

	if Common.isUsingAntiAim(angles.pitch) then
		if not usesAntiAim[steamID] then
			usesAntiAim[steamID] = true
		end

		setupPlayerAngleData(player)
	end
end

function Common.SetupWeaponData()
    local pLocal = G.pLocal.entity

--[[Primary Weapon Data]]--
    G.pLocal.WpData.PWeapon.Weapon =  pLocal:GetEntityForLoadoutSlot( LOADOUT_POSITION_PRIMARY )
    local weapon = G.pLocal.WpData.PWeapon.Weapon

    if not weapon then print("no Primary Weapon") else
        G.pLocal.WpData.PWeapon.WeaponData = weapon:GetWeaponData()
        G.pLocal.WpData.PWeapon.WeaponID = weapon:GetWeaponID()
        G.pLocal.WpData.PWeapon.WeaponDefIndex = weapon:GetPropInt("m_iItemDefinitionIndex")
        if G.pLocal.WpData.PWeapon.WeaponDefIndex then
            G.pLocal.WpData.PWeapon.WeaponDef = itemschema.GetItemDefinitionByID(G.pLocal.WpData.PWeapon.WeaponDefIndex)
            G.pLocal.WpData.PWeapon.WeaponName = G.pLocal.WpData.PWeapon.WeaponDef:GetName()
        end
    end

--[[Melee Weapon Data]]--
    G.pLocal.WpData.MWeapon.Weapon =  pLocal:GetEntityForLoadoutSlot( LOADOUT_POSITION_MELEE )
    weapon = G.pLocal.WpData.MWeapon.Weapon

    if not weapon then print("no Melee Weapon") return false end
    G.pLocal.WpData.MWeapon.WeaponData = weapon:GetWeaponData()
    G.pLocal.WpData.MWeapon.WeaponID = weapon:GetWeaponID()
    G.pLocal.WpData.MWeapon.WeaponDefIndex = weapon:GetPropInt("m_iItemDefinitionIndex")
    G.pLocal.WpData.MWeapon.WeaponDef = itemschema.GetItemDefinitionByID(G.pLocal.WpData.MWeapon.WeaponDefIndex)
    G.pLocal.WpData.MWeapon.WeaponName = G.pLocal.WpData.MWeapon.WeaponDef:GetName()

--[[Current Weapon Data]]--
    G.pLocal.WpData.UsingMargetGarden = false
    weapon = G.pLocal.WpData.CurrWeapon.Weapon
    if not weapon then print("no Current Weapon") return false end
        local currWeapon = G.pLocal.WpData.CurrWeapon
        currWeapon.WeaponData = weapon:GetWeaponData()
        currWeapon.WeaponID = weapon:GetWeaponID()
        currWeapon.WeaponDefIndex = weapon:GetPropInt("m_iItemDefinitionIndex")
        currWeapon.WeaponDef = itemschema.GetItemDefinitionByID(currWeapon.WeaponDefIndex)
        currWeapon.WeaponName = currWeapon.WeaponDef:GetName()

    --[[if weapon:IsMeleeWeapon() then
            local swingData = G.pLocal.WpData.SwingData 
            -- Swing properties
                swingData.SmackDelay = Conversion.Time_to_Ticks(currWeapon.WeaponData.smackDelay) or 13
                G.pLocal.UsingMargetGarden = currWeapon.WeaponDefIndex == MarketGardenIndex

            local swingRange = weapon:GetSwingRange() or G.Static.DefaultSwingRange
            local isDisciplinaryAction = (currWeapon.WeaponDef:GetName() == "The Disciplinary Action")
            local swingHullSize = isDisciplinaryAction and disciplinaryActionHullSize or G.Static.defaultHullSize
            local halfHullSize = G.Static.HalfHullSize
                swingData.SwingRange = swingRange
                swingData.SwingHullSize = swingHullSize
                swingData.TotalSwingRange = swingRange + halfHullSize
                swingData.SwingHull = {
                    Max = Vector3(halfHullSize, halfHullSize, halfHullSize),
                    Min = Vector3(-halfHullSize, -halfHullSize, -halfHullSize)
                }

                if G.StrafeData.inaccuracy then -- If we got inaccuracy in strafe calculations
                    local inaccuracy = math.abs(G.StrafeData.inaccuracy[G.pLocal.index] or 0)
                    swingData.TotalSwingRange = swingData.TotalSwingRange - inaccuracy
                end
            G.pLocal.WpData.SwingData = swingData --save values
        end]]
    G.pLocal.WpData.CurrWeapon = currWeapon --save values
    return true
end

function Common.isValidWeapon(weapon)
	if not weapon then return false end
	if not weapon:IsWeapon() then return false end
	if not weapon:IsShootingWeapon() then return false end
    if weapon:IsMeleeWeapon() then return false end

	return true
end

--local fFalse = function () return false end

-- [WIP] Predict the position of a player
---@param player WPlayer
---@param t integer
---@param d number?
---@param shouldHitEntity fun(entity: WEntity, contentsMask: integer): boolean?
---@return { pos : Vector3[], vel: Vector3[], onGround: boolean[] }?
function Common.PredictPlayer(player, t, d)
        if not G.World.Gravity or not G.World.StepHeight then return nil end
        local vUp = Vector3(0, 0, 1)
        local vStep = Vector3(0, 0, G.World.StepHeight)
        local shouldHitEntity = function(entity) return entity:GetName() ~= player:GetName() end --trace ignore simulated player 
        local pFlags = player:GetPropInt("m_fFlags")
        local OnGround = pFlags & FL_ONGROUND == 1
        local vHitbox
        if G.pLocal.vHitbox and player == G.pLocal.entity then
            vHitbox = G.pLocal.vHitbox
        elseif G.Target.vHitbox then
            vHitbox = G.Target.vHitbox
        else
            vHitbox = G.Defaults.vHitbox
        end
        local pLocal = G.pLocal.entity
        local pLocalIndex = G.pLocal.index

        -- Add the current record
        local _out = {
            pos = { [0] = player:GetAbsOrigin() },
            vel = { [0] = player:EstimateAbsVelocity() },
            onGround = { [0] = OnGround }
        }

        -- Perform the prediction
        for i = 1, t do
            local lastP, lastV, lastG = _out.pos[i - 1], _out.vel[i - 1], _out.onGround[i - 1]

            local pos = lastP + lastV * globals.TickInterval()
            local vel = lastV
            local onGround1 = lastG

            -- Apply deviation
            if d then
                local ang = vel:Angles()
                ang.y = ang.y + d
                vel = ang:Forward() * vel:Length()
            end

            --[[ Forward collision ]]

            local wallTrace = engine.TraceHull(lastP + vStep, pos + vStep, vHitbox.Min, vHitbox.Max, MASK_PLAYERSOLID_BRUSHONLY, shouldHitEntity)
            --DrawLine(last.p + vStep, pos + vStep)
            if wallTrace.fraction < 1 then
                -- We'll collide
                local normal = wallTrace.plane
                local angle = math.deg(math.acos(normal:Dot(vUp)))

                -- Check the wall angle
                if angle > 55 then
                    -- The wall is too steep, we'll collide
                    local dot = vel:Dot(normal)
                    vel = vel - normal * dot
                end

                pos.x, pos.y = wallTrace.endpos.x, wallTrace.endpos.y
            end

            --[[ Ground collision ]]

            -- Don't step down if we're in-air
            local downStep = vStep
            if not onGround1 then downStep = Vector3() end

            -- Ground collision
            local groundTrace = engine.TraceHull(pos + vStep, pos - downStep, vHitbox.Min, vHitbox.Max, MASK_PLAYERSOLID_BRUSHONLY, shouldHitEntity)
            if groundTrace.fraction < 1 then
                -- We'll hit the ground
                local normal = groundTrace.plane
                local angle = math.deg(math.acos(normal:Dot(vUp)))

                -- Check the ground angle
                if angle < 45 then
                    if onGround1 and player:GetIndex() == pLocalIndex and gui.GetValue("Bunny Hop") == 1 and input.IsButtonDown(KEY_SPACE) then
                        -- Jump
                        if gui.GetValue("Duck Jump") == 1 then
                            vel.z = 277
                            onGround1 = false
                        else
                            vel.z = 271
                            onGround1 = false
                        end
                    else
                        pos = groundTrace.endpos
                        onGround1 = true
                    end
                elseif angle < 55 then
                    vel.x, vel.y, vel.z = 0, 0, 0
                    onGround1 = false
                else
                    local dot = vel:Dot(normal)
                        vel = vel - normal * dot
                        onGround1 = true
                end
            else
                -- We're in the air
                onGround1 = false
            end

            -- Gravity
            --local isSwimming, isWalking = checkPlayerState(player) -- todo: fix this
            if not onGround1 then
                vel.z = vel.z - G.World.Gravity * globals.TickInterval()
            end

            -- Add the prediction record
            _out.pos[i], _out.vel[i], _out.onGround[i] = pos, vel, onGround1
        end

        return _out
end

function Common.GetBestTarget()
	local localPlayer = entities.GetLocalPlayer()
	local players = entities.FindByClass("CTFPlayer")
	local target = nil
	local lastFov = math.huge

	for _, entity in pairs(players) do
		if not entity then goto continue end
		if not entity:IsAlive() then goto continue end
		if entity:GetTeamNumber() == localPlayer:GetTeamNumber() then goto continue end

		local player = entity
		local aimPos = getHitboxPos(player, 1)
		local angles = positionAngles(getEyePos(localPlayer), aimPos)
		local fov = angleFov(angles, engine.GetViewAngles())
		if fov > (G.Menu.Main.cycleYawFOV or gui.GetValue("aim fov")) then goto continue end

		if fov < lastFov then
			lastFov = fov
			target = { entity = entity, pos = aimPos, angles = angles, factor = fov }
		end

		::continue::
	end

	return target
end

function Common.CalcStrafe()
    local autostrafe = gui.GetValue("Auto Strafe")
    local flags = G.pLocal.entity:GetPropInt("m_fFlags")
    local OnGround = flags & FL_ONGROUND == 1

    for idx, entity in ipairs(G.Players) do
        local entityIndex = entity:GetIndex()

        if not entity or not entity:IsValid() and entity:IsDormant() or not entity:IsAlive() then
            G.StrafeData.lastAngles[entityIndex] = nil
            G.StrafeData.lastDeltas[entityIndex] = nil
            G.StrafeData.avgDeltas[entityIndex] = nil
            G.StrafeData.strafeAngles[entityIndex] = nil
            G.StrafeData.inaccuracy[entityIndex] = nil
            goto continue
        end

        local v = entity:EstimateAbsVelocity()
        if entity == G.pLocal.entity then
            table.insert(G.StrafeData.pastPositions, 1, entity:GetAbsOrigin())
            if #G.StrafeData.pastPositions > G.StrafeData.maxPositions then
                table.remove(G.StrafeData.pastPositions)
            end

            if not onGround and autostrafe == 2 and #G.StrafeData.pastPositions >= G.StrafeData.maxPositions then
                v = Vector3(0, 0, 0)
                for i = 1, #G.StrafeData.pastPositions - 1 do
                    v = v + (G.StrafeData.pastPositions[i] - G.StrafeData.pastPositions[i + 1])
                end
                v = v / (G.StrafeData.maxPositions - 1)
            else
                v = entity:EstimateAbsVelocity()
            end
        end

        local angle = v:Angles()

        if G.StrafeData.lastAngles[entityIndex] == nil then
            G.StrafeData.lastAngles[entityIndex] = angle
            goto continue
        end

        local delta = angle.y - G.StrafeData.lastAngles[entityIndex].y

        -- Calculate the average delta using exponential smoothing
        local smoothingFactor = 0.2
        local avgDelta = (G.StrafeData.lastDeltas[entityIndex] or delta) * (1 - smoothingFactor) + delta * smoothingFactor

        -- Save the average delta
        G.StrafeData.avgDeltas[entityIndex] = avgDelta

        local vector1 = Vector3(1, 0, 0)
        local vector2 = Vector3(1, 0, 0)

        -- Apply deviation
        local ang1 = vector1:Angles()
        ang1.y = ang1.y + (G.StrafeData.lastDeltas[entityIndex] or delta)
        vector1 = ang1:Forward() * vector1:Length()

        local ang2 = vector2:Angles()
        ang2.y = ang2.y + avgDelta
        vector2 = ang2:Forward() * vector2:Length()

        -- Calculate the distance between the two vectors
        local distance = (vector1 - vector2):Length()

        -- Save the strafe angle
        G.StrafeData.strafeAngles[entityIndex] = avgDelta

        -- Calculate the inaccuracy as the distance between the two vectors
        G.StrafeData.inaccuracy[entityIndex] = distance

        -- Save the last delta
        G.StrafeData.lastDeltas[entityIndex] = delta

        G.StrafeData.lastAngles[entityIndex] = angle

        ::continue::
    end
end

--[[ Sphere cache and drawn edges cache
local sphere_cache = { vertices = {}, radius = 90, center = Vector3(0, 0, 0) }
local drawnEdges = {}

local function setup_sphere(center, radius, segments)
    sphere_cache.center = center
    sphere_cache.radius = radius
    sphere_cache.segments = segments
    sphere_cache.vertices = {}  -- Clear the old vertices

    local thetaStep = math.pi / segments
    local phiStep = 2 * math.pi / segments

    for i = 0, segments - 1 do
        local theta1 = thetaStep * i
        local theta2 = thetaStep * (i + 1)

        for j = 0, segments - 1 do
            local phi1 = phiStep * j
            local phi2 = phiStep * (j + 1)

            -- Generate a square for each segment
            table.insert(sphere_cache.vertices, {
                Vector3(math.sin(theta1) * math.cos(phi1), math.sin(theta1) * math.sin(phi1), math.cos(theta1)),
                Vector3(math.sin(theta1) * math.cos(phi2), math.sin(theta1) * math.sin(phi2), math.cos(theta1)),
                Vector3(math.sin(theta2) * math.cos(phi2), math.sin(theta2) * math.sin(phi2), math.cos(theta2)),
                Vector3(math.sin(theta2) * math.cos(phi1), math.sin(theta2) * math.sin(phi1), math.cos(theta2))
            })
        end
    end
end]]

function Common.L_line(start_pos, end_pos, secondary_line_size)
    if not (start_pos and end_pos) then
        return
    end
    local direction = end_pos - start_pos
    local direction_length = direction:Length()
    if direction_length == 0 then
        return
    end
    local normalized_direction = Normalize(direction)
    local perpendicular = Vector3(normalized_direction.y, -normalized_direction.x, 0) * secondary_line_size
    local w2s_start_pos = client.WorldToScreen(start_pos)
    local w2s_end_pos = client.WorldToScreen(end_pos)
    if not (w2s_start_pos and w2s_end_pos) then
        return
    end
    local secondary_line_end_pos = start_pos + perpendicular
    local w2s_secondary_line_end_pos = client.WorldToScreen(secondary_line_end_pos)
    if w2s_secondary_line_end_pos then
        draw.Line(w2s_start_pos[1], w2s_start_pos[2], w2s_end_pos[1], w2s_end_pos[2])
        draw.Line(w2s_start_pos[1], w2s_start_pos[2], w2s_secondary_line_end_pos[1], w2s_secondary_line_end_pos[2])
    end
end

function Common.arrowPathArrow2(startPos, endPos, width)
    if not (startPos and endPos) then return nil, nil end

    local direction = endPos - startPos
    local length = direction:Length()
    if length == 0 then return nil, nil end
    direction = NormalizeVector(direction)

    local perpDir = Vector3(-direction.y, direction.x, 0)
    local leftBase = startPos + perpDir * width
    local rightBase = startPos - perpDir * width

    local screenStartPos = client.WorldToScreen(startPos)
    local screenEndPos = client.WorldToScreen(endPos)
    local screenLeftBase = client.WorldToScreen(leftBase)
    local screenRightBase = client.WorldToScreen(rightBase)

    if screenStartPos and screenEndPos and screenLeftBase and screenRightBase then
        draw.Line(screenStartPos[1], screenStartPos[2], screenEndPos[1], screenEndPos[2])
        draw.Line(screenLeftBase[1], screenLeftBase[2], screenEndPos[1], screenEndPos[2])
        draw.Line(screenRightBase[1], screenRightBase[2], screenEndPos[1], screenEndPos[2])
    end

    return leftBase, rightBase
end

function Common.arrowPathArrow(startPos, endPos, arrowWidth)
    if not startPos or not endPos then return end

    local direction = endPos - startPos
    if direction:Length() == 0 then return end

    -- Normalize the direction vector and calculate perpendicular direction
    direction = NormalizeVector(direction)
    local perpendicular = Vector3(-direction.y, direction.x, 0) * arrowWidth

    -- Calculate points for arrow fins
    local finPoint1 = startPos + perpendicular
    local finPoint2 = startPos - perpendicular

    -- Convert world positions to screen positions
    local screenStartPos = client.WorldToScreen(startPos)
    local screenEndPos = client.WorldToScreen(endPos)
    local screenFinPoint1 = client.WorldToScreen(finPoint1)
    local screenFinPoint2 = client.WorldToScreen(finPoint2)

    -- Draw the arrow
    if screenStartPos and screenEndPos then
        draw.Line(screenEndPos[1], screenEndPos[2], screenFinPoint1[1], screenFinPoint1[2])
        draw.Line(screenEndPos[1], screenEndPos[2], screenFinPoint2[1], screenFinPoint2[2])
        draw.Line(screenFinPoint1[1], screenFinPoint1[2], screenFinPoint2[1], screenFinPoint2[2])
    end
end

function Common.drawPavement(startPos, endPos, width)
    if not (startPos and endPos) then return nil end

    local direction = endPos - startPos
    local length = direction:Length()
    if length == 0 then return nil end
    direction = NormalizeVector(direction)

    -- Calculate perpendicular direction for the width
    local perpDir = Vector3(-direction.y, direction.x, 0)

    -- Calculate left and right base points of the pavement
    local leftBase = startPos + perpDir * width
    local rightBase = startPos - perpDir * width

    -- Convert positions to screen coordinates
    local screenStartPos = client.WorldToScreen(startPos)
    local screenEndPos = client.WorldToScreen(endPos)
    local screenLeftBase = client.WorldToScreen(leftBase)
    local screenRightBase = client.WorldToScreen(rightBase)

    -- Draw the pavement
    if screenStartPos and screenEndPos and screenLeftBase and screenRightBase then
        draw.Line(screenStartPos[1], screenStartPos[2], screenEndPos[1], screenEndPos[2])
        draw.Line(screenStartPos[1], screenStartPos[2], screenLeftBase[1], screenLeftBase[2])
        draw.Line(screenStartPos[1], screenStartPos[2], screenRightBase[1], screenRightBase[2])
    end

    return leftBase, rightBase
end

local function setupPlayerAngleData(player)
	local steamID = getSteamID(player)

	if customAngleData[steamID] then
		return
	end

	customAngleData[steamID] = {
		plr = player,
		yawCycleIndex = 0,
		lastYaw = 0,
	}
end

local function getMinimumLatency(trueLatency)
	local latency = clientstate.GetLatencyIn() + clientstate.GetLatencyOut()
	if trueLatency == true then return latency end
	return latency <= 0.1 and 0.1 or latency
end

function Common.announceMiss(player)
	local name, steamID = client.GetPlayerInfo(player:GetIndex()).Name, getSteamID(player)
	client.ChatPrintf(string.format("\x073475c9[Resolver] \x01Missed player \x073475c9'%s'\x01. Shots remaining: \x07f22929%s", name, 4 - (misses[steamID] or 1)))
end

function Common.announceResolve(data)
	local name, yaw = client.GetPlayerInfo(data.plr:GetIndex()).Name, getYawText(data)
	if yaw == "" or data.lastYaw == yaw then return end

	data.lastYaw = yaw
	client.ChatPrintf(string.format("\x073475c9[Resolver] \x01Adjusted player \x073475c9'%s'\x01 yaw to \x07f22929%s", name, yaw))
end

function Common.getBool(event, name)
	local bool = event:GetInt(name)
	return bool == 1
end

local function cycleYaw(data, step)
	data.yawCycleIndex = data.yawCycleIndex + (step or .5)

	if data.yawCycleIndex > #G.Menu.Settings.yawCycle then
		data.yawCycleIndex = 1
	end

	Common.announceResolve(data)
end

function Common.processConfirmation(steamID, data)
	local enemy, hitTime, wasHit = data.enemy, data.hitTime, data.wasHit

	if wasHit then
		G.Resolver.awaitingConfirmation[steamID] = nil
		goto continue
	end

	if G.Resolver.lastHits[steamID] and G.Resolver.lastHits[steamID].wasHit then
		local diff = globals.TickCount() - G.Resolver.lastHits[steamID].time
		if diff < getMinimumLatency(true) * 2 then
			G.Resolver.awaitingConfirmation[steamID] = nil -- we hit the person but the event was fired before awaitingconfirmation was updated
			goto continue
		end
	end

	if globals.TickCount() >= hitTime then
		local usingAntiAim = G.Resolver.usesAntiAim[steamID]

		if not usingAntiAim then
			if not G.Resolver.misses[steamID] then
				G.Resolver.misses[steamID] = 0
			end

			if misses[steamID] < Menu.Settings.maxMisses then
				G.Resolver.misses[steamID] = G.Resolver.misses[steamID] + 1
				G.Resolver.awaitingConfirmation[steamID] = nil
				Common.announceMiss(enemy)
				goto continue
			end
		end

		if not G.Resolver.customAngleData[steamID] then
			setupPlayerAngleData(enemy)
		end

		cycleYaw(G.Resolver.customAngleData[steamID])
		G.Resolver.awaitingConfirmation[steamID] = nil
	end

	::continue::
end


-- Call setup_sphere once at the start of your program
--setup_sphere(Vector3(0, 0, 0), 90, 7)

local white_texture = draw.CreateTextureRGBA(string.char(
	0xff, 0xff, 0xff, 25,
	0xff, 0xff, 0xff, 25,
	0xff, 0xff, 0xff, 25,
	0xff, 0xff, 0xff, 25
), 2, 2);

--[[local drawPolygon = (function()
	local v1x, v1y = 0, 0;
	local function cross(a, b)
		return (b[1] - a[1]) * (v1y - a[2]) - (b[2] - a[2]) * (v1x - a[1])
	end

	local TexturedPolygon = draw.TexturedPolygon;

	return function(vertices)
		local cords, reverse_cords = {}, {};
		local sizeof = #vertices;
		local sum = 0;

		v1x, v1y = vertices[1][1], vertices[1][2];
		for i, pos in pairs(vertices) do
			local convertedTbl = {pos[1], pos[2], 0, 0};

			cords[i], reverse_cords[sizeof - i + 1] = convertedTbl, convertedTbl;

			sum = sum + cross(pos, vertices[(i % sizeof) + 1]);
		end


		TexturedPolygon(white_texture, (sum < 0) and reverse_cords or cords, true)
	end
end)();]]

return Common
end)
__bundle_register("Resolver.Config", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[ Imports ]]
local Common = require("Resolver.Common")
Lib = Common.Lib
local G = require("Resolver.Globals")
local Menu = G.Menu

local Config = {}

local Lua__fullPath = GetScriptName()
local Lua__fileName = Lua__fullPath:match("\\([^\\]-)$"):gsub("%.lua$", "")
local folder_name = string.format([[Lua %s]], Lua__fileName)

function Config.GetFilePath()
    local success, fullPath = filesystem.CreateDirectory(folder_name)
    return tostring(fullPath .. "/config.cfg")
end

function Config.CreateCFG(table)
    if not table then
        table = Menu
    end
    local filepath = Config.GetFilePath()
    local file = io.open(filepath, "w")  -- Define the file variable here
    local filePathstring = tostring(Config.GetFilePath())
    local shortFilePath = filePathstring:match(".*\\(.*\\.*)$")

    if file then
        local function serializeTable(tbl, level)
            level = level or 0
            local result = string.rep("    ", level) .. "{\n"
            for key, value in pairs(tbl) do
                result = result .. string.rep("    ", level + 1)
                if type(key) == "string" then
                    result = result .. '["' .. key .. '"] = '
                else
                    result = result .. "[" .. key .. "] = "
                end
                if type(value) == "table" then
                    result = result .. serializeTable(value, level + 1) .. ",\n"
                elseif type(value) == "string" then
                    result = result .. '"' .. value .. '",\n'
                else
                    result = result .. tostring(value) .. ",\n"
                end
            end
            result = result .. string.rep("    ", level) .. "}"
            return result
        end

        local serializedConfig = serializeTable(table)
        file:write(serializedConfig)
        file:close()

        local successMessage = shortFilePath
        printc(100, 183, 0, 255, "Succes Loading Config: Path:" .. successMessage)
        Notify.Simple("Success! Saved Config to:", successMessage, 5)
    else
        local errorMessage = "Failed to open: " .. tostring(shortFilePath)
        printc( 255, 0, 0, 255, errorMessage)
        Notify.Simple("Error", errorMessage, 5)
    end
end

-- Function to check if all expected functions exist in the loaded config
local function checkAllFunctionsExist(expectedMenu, loadedMenu)
    for key, value in pairs(expectedMenu) do
        if type(value) == 'function' then
            -- Check if the function exists in the loaded menu and has the correct type
            if not loadedMenu[key] or type(loadedMenu[key]) ~= 'function' then
                return false
            end
        end
    end
    for key, value in pairs(expectedMenu) do
        if not loadedMenu[key] or type(loadedMenu[key]) ~= type(value) then
            return false
        end
    end
    return true
end

function Config.LoadCFG()
    local filepath = Config.GetFilePath()
    local file = io.open(filepath, "r")
    local filePathstring = tostring(Config.GetFilePath())
    local shortFilePath = filePathstring:match(".*\\(.*\\.*)$")
    Menu = G.Menu

    if file then
        local content = file:read("*a")
        file:close()
        local chunk, err = load("return " .. content)
        if chunk then
            local loadedMenu = chunk()
            if checkAllFunctionsExist(Menu, loadedMenu) and not input.IsButtonDown(KEY_LSHIFT) then
                local successMessage = shortFilePath
                printc(100, 183, 0, 255, "Succes Loading Config: Path:" .. successMessage)
                Notify.Simple("Success! Loaded Config from", successMessage, 5)
                Menu = loadedMenu
                G.Menu = Menu
                return loadedMenu
            elseif input.IsButtonDown(KEY_LSHIFT) then
                local warningMessage = "Creating a new config."
                printc( 255, 0, 0, 255, warningMessage)
                Notify.Simple("Warning", warningMessage, 5)
                Config.CreateCFG(Menu) -- Save the config
                return Menu
            else
                local warningMessage = "Config is outdated or invalid. Creating a new config."
                printc( 255, 0, 0, 255, warningMessage)
                Notify.Simple("Warning", warningMessage, 5)
                Config.CreateCFG(Menu) -- Save the config
                return Menu
            end
        else
            local errorMessage = "Error executing configuration file: " .. tostring(err)
            printc( 255, 0, 0, 255, errorMessage)
            Notify.Simple("Error", errorMessage, 5)
            Config.CreateCFG(Menu) -- Save the config
            return Menu
        end
    else
        local warningMessage = "Config file not found. Creating a new config."
        printc( 255, 0, 0, 255, warningMessage)
        Notify.Simple("Warning", warningMessage, 5)
        Config.CreateCFG(Menu) -- Save the config
        return Menu
    end
end

Config.LoadCFG() -- Load the config on load

--[[ Callbacks ]]
local function OnUnload() -- Called when the script is unloaded
    Config.CreateCFG(Menu) -- Save the configurations to a file
    UnloadLib() --unloading lualib
    -- Unload package for debugging
    Lib.Utils.UnloadPackages("Resolver")
    client.Command('play "ui/buttonclickrelease"', true) -- Play the "buttonclickrelease" sound
end

callbacks.Unregister("Unload", "AM_Unload")                                -- unregister the "Unload" callback
callbacks.Register("Unload", "AM_Unload", OnUnload)                         -- Register the "Unload" callback

return Config

end)
return __bundle_require("__root")