--[[
Crossbow autocombo script
author: titaniumachine1
]]

---@type boolean, lnxLib
local libLoaded, lnxLib = pcall(require, "lnxLib")
assert(libLoaded, "lnxLib not found, please install it!")
UnloadLib() --unloads all packages

local Math, Conversion = lnxLib.Utils.Math, lnxLib.Utils.Conversion
local WPlayer, WWeapon = lnxLib.TF2.WPlayer, lnxLib.TF2.WWeapon
local Helpers = lnxLib.TF2.Helpers
local Prediction = lnxLib.TF2.Prediction
local Fonts = lnxLib.UI.Fonts



local waitingForCrossbow = false  -- State variable to know if we're waiting for Crossbow
local timer = 0
local crossbowCooldownTicks = 130  -- Replace with the actual cooldown in ticks
local IsReturning = false
local CurrentTickHeal = 0
local pLocal = entities.GetLocalPlayer()

--[[local function event_hook(ev)
    if ev:GetName() ~= "player_healed" then return end -- only allows player_hurt event go through
    --declare variables
    --to get all structures of event: https://wiki.alliedmods.net/Team_Fortress_2_Events#player_hurt

    local victim_entity = entities.GetByUserID(ev:GetInt("patient"))
    local attacker = entities.GetByUserID(ev:GetInt("healer"))
    local localplayer = entities.GetLocalPlayer()
    local damage = ev:GetInt("amount")
    local health = ev:GetInt("health")
    local ping = entities.GetPlayerResources():GetPropDataTableInt("m_iPing")[victim_entity:GetIndex()]

    if attacker ~= localplayer then return end
    CurrentTickHeal = damage
    print(CurrentTickHeal)

end

callbacks.Register("FireGameEvent", "unique_event_hook", event_hook)]]
client.Command('ent_fire !picker Addoutput "health 1"', true)

---@return AimTarget? target
local function GetBestTarget()
    local players = entities.FindByClass("CTFPlayer")
    local localPlayer = entities.GetLocalPlayer()
    if not localPlayer then return end

    local localPlayerPos = localPlayer:GetAbsOrigin()
    local viewAngles = engine.GetViewAngles()

    local bestTarget = nil
    local smallestFov = 360

    -- Calculate target factors
    for _, player in ipairs(players) do
        if player ~= localPlayer and player:IsAlive() then
            local playerPos = player:GetAbsOrigin()
            local angles = Math.PositionAngles(localPlayerPos, playerPos + Vector3(0, 0, viewheight))
            local fov = Math.AngleFov(viewAngles, angles)

            if fov < smallestFov then
                smallestFov = fov
                bestTarget = { entity = player, angles = angles, fov = fov }
            end
        end
    end
    
    return bestTarget
end
local chargeLevelFloat = 0
local chargeLevelPercentage = 0
local uberTickCounter = 0  -- Counter for the number of ticks in ubercharge
local ticksBeforeUberEnds = 0  -- Global variable to count down ticks before uber ends

-- Constants for ubercharge durations in ticks
--local UBER_DURATION_TICKS = 599
local VACCINATOR_DURATION_TICKS = 198

local function CanShoot(pLocal)
    local pWeapon = pLocal:GetPropEntity("m_hActiveWeapon")
    if (not pWeapon) or (pWeapon:IsMeleeWeapon()) then return false end

    local pMedigun = pLocal:GetEntityForLoadoutSlot(LOADOUT_POSITION_SECONDARY)
    if (not pMedigun) or (not pMedigun:IsMedigun()) then return false end

    chargeLevelFloat = pMedigun:GetPropFloat("NonLocalTFWeaponMedigunData", "m_flChargeLevel")
    chargeLevelPercentage = chargeLevelFloat * 100

    local nextPrimaryAttack = pWeapon:GetPropFloat("LocalActiveWeaponData", "m_flNextPrimaryAttack")
    local nextAttack = pLocal:GetPropFloat("bcc_localdata", "m_flNextAttack")
    if (not nextPrimaryAttack) or (not nextAttack) then return false end

    -- Check if in ubercharge condition
    if pLocal:InCond(58) or pLocal:InCond(59) or pLocal:InCond(60) then
        if uberTickCounter == 0 then  -- Entering ubercharge
            ticksBeforeUberEnds = (pLocal:InCond(58) or pLocal:InCond(59) or pLocal:InCond(60)) and VACCINATOR_DURATION_TICKS
        end
        uberTickCounter = uberTickCounter + 1  -- Increment tick counter
        ticksBeforeUberEnds = ticksBeforeUberEnds - 1  -- Decrement countdown
    else
        if uberTickCounter > 0 then  -- If previously in ubercharge
            print("Total ticks in ubercharge: ", uberTickCounter)
            uberTickCounter = 0  -- Reset counter
        end
    end

    -- Print the remaining ticks before uber ends, if in ubercharge
    if ticksBeforeUberEnds > 0 then
        print("Ticks before uber ends: ", ticksBeforeUberEnds)
    end

    return nextPrimaryAttack, nextAttack
end


local heallist = {}  -- Table to hold the healing data
local maxTicks = 660  -- Maximum number of ticks to store (10 seconds * 66 ticks/second)
local totalHealing = 0  -- Total healing over the last maxTicks ticks
local weaponSwitchTicks = math.floor(0.67 * 66) * 2  -- Ticks required to switch weapon twice
local latencyTolerance = 4  -- Tolerance in ticks

local function OnCreateMove(pCmd)
    -- Get the local player entity
    local pLocal = entities.GetLocalPlayer()
    if not pLocal or not pLocal:IsAlive() then
        return -- Return if the local player entity doesn't exist or is dead
    end

    -- Check if the local player is a Medic
    local pLocalClass = pLocal:GetPropInt("m_iClass")
    if pLocalClass == nil or pLocalClass ~= 5 then
        goto continue -- Skip the rest of the code if not Medic
    end

    -- Get the local player's active weapon
    local pWeapon = pLocal:GetPropEntity("m_hActiveWeapon")
    if not pWeapon then
        goto continue
    end

    local Ammo = pWeapon:GetPropInt("LocalWeaponData", "m_iClip1")
    local pWeaponDefIndex = pWeapon:GetPropInt("m_iItemDefinitionIndex")
    local nextAttack, nextPrimaryAttack = CanShoot(pLocal)
    local Best_Target = GetBestTarget(WPlayer.FromEntity(pLocal))

    -- Calculate the total tolerance in ticks
    local latOut = clientstate.GetLatencyOut()
    local latIn = clientstate.GetLatencyIn()
    local Latency = (latOut + latIn)
    Latency = math.floor(Latency * 66 + 1)  -- Convert the delay to ticks
    local totalTolerance = Latency + latencyTolerance + weaponSwitchTicks

    -- Variable for checking Ubercharge
    local shouldSwitchToCrossbow = true  -- Flag for determining whether to switch to Crossbow

    -- Check if Uber is above or equal to 25%
    if chargeLevelPercentage >= 25 then
        if ticksBeforeUberEnds <= totalTolerance then
            shouldSwitchToCrossbow = false  -- Don't switch to Crossbow to maintain Uber
        end
    end

    if Best_Target and Best_Target.entity:GetHealth() < Best_Target.entity:GetMaxHealth() then
        if shouldSwitchToCrossbow then
            if IsReturning then
                if pWeaponDefIndex == 305 and nextPrimaryAttack <= globals.CurTime() then  -- If holding Crossbow
                    client.Command("slot2", true)  -- Switch to Medigun
                    waitingForCrossbow = true  -- Set state to waiting
                    IsReturning = false
                end
            end

            if pWeaponDefIndex == 998 and nextPrimaryAttack <= globals.CurTime() then
                if waitingForCrossbow then
                    timer = timer + 1
                    if timer >= crossbowCooldownTicks then
                        client.Command("slot1", true)  -- Switch to Crossbow
                        waitingForCrossbow = false  -- Reset state
                        timer = 0  -- Reset timer
                    end
                end
            end
        end
    end

    -- We've just attacked. Let's return!
    if pWeaponDefIndex == 305 and Ammo == 0
    or pWeaponDefIndex == 305 and pCmd:GetButtons() & IN_ATTACK == 1 then
        client.Command('ent_fire !picker Addoutput "health 1"', true)
        IsReturning = true
    end

    ::continue::
end


local function OnUnload()                                -- Called when the script is unloaded
    UnloadLib() --unloading lualib
    client.Command('play "ui/buttonclickrelease"', true) -- Play the "buttonclickrelease" sound
end

--[[ Unregister previous callbacks ]]--
callbacks.Unregister("CreateMove", "MCT_CreateMove")            -- Unregister the "CreateMove" callback
callbacks.Unregister("Unload", "MCT_Unload")                    -- Unregister the "Unload" callback
--[[ Register callbacks ]]--
callbacks.Register("CreateMove", "MCT_CreateMove", OnCreateMove)             -- Register the "CreateMove" callback
callbacks.Register("Unload", "MCT_Unload", OnUnload)                         -- Register the "Unload" callback
--[[ Play sound when loaded ]]--
client.Command('play "ui/buttonclick"', true) -- Play the "buttonclick" sound when the script is loaded