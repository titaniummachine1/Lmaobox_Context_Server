--client.SetConVar("sv_cheats", 1)
--client.Command("sv_cheats", 1)
local pLocal = entities.GetLocalPlayer()     -- Immediately set "pLocal" to the local player (entities.GetLocalPlayer)

--[[local angle = EulerAngles( 0, 0, 90)
--engine.SetViewAngles(angle)

--client.Command("cyoa_pda_open", 1)
--client.SetConVar("cyoa_pda_open", 1)

client.Command("mp_autoteambalance", 0)
client.Command("mp_disable_respawn_times", 1)
client.Command("mp_friendlyfire", 0)
client.Command("mp_highlander", 0)
client.Command("mp_idledealmethod", 0)
client.Command("mp_teams_unbalance_limit", 1000) -- server operator only
client.Command("mp_timelimit", 999999) -- server operator only
client.Command("mp_waitingforplayers_cancel", 1) -- server operator only
]]
local function OnCreateMove(userCmd)
    --[[pLocal = entities.GetLocalPlayer()     -- Immediately set "pLocal" to the local player (entities.GetLocalPlayer)   
        if pLocal:InCond(1) == true and client.GetConVar("cyoa_pda_open") == 0 then
            client.Command("cyoa_pda_open", 1)
        elseif client.GetConVar("cyoa_pda_open") then
            client.Command("cyoa_pda_open", 0)
        end]]
    --client.SetConVar("cyoa_pda_open", 1)
    --client.SetConVar("host_timescale", 0.1)
    --client.SetConVar("cl_vWeapon_sway_interp",              0)             -- Set cl_vWeapon_sway_interp to 0
    --client.SetConVar("cl_jiggle_bone_framerate_cutoff", 0)             -- Set cl_jiggle_bone_framerate_cutoff to 0
    --client.SetConVar("cl_bobcycle",                     10000)         -- Set cl_bobcycle to 10000
end

--[[ Remove the menu when unloaded ]]--
local function OnUnload()                                -- Called when the script is unloaded

    local modelPath = os.getenv("LOCALAPPDATA") .. "\\fem_scout.vpk"
    pLocal:SetModel(modelPath)
    print(pLocal:SetModel(modelPath))
    --client.SetConVar("host_timescale", 1)
    --client.Command("cyoa_pda_open", 0)
    --client.SetConVar("sv_cheats", 0)
    --client.Command('play "ui/buttonclickrelease"', true) -- Play the "buttonclickrelease" sound
end

local function doDraw()

end
--sclient.Command('host_timescale', 5.0)
callbacks.Unregister("CreateMove", "MCT_CreateMove")            -- Unregister the "CreateMove" callback
callbacks.Unregister("Unload", "MCT_Unload")                    -- Unregister the "Unload" callback
callbacks.Unregister("Draw", "MCT_Draw")                        -- Unregister the "Draw" callback

callbacks.Register("Draw", "MCT_Draw", doDraw)                               -- Register the "Draw" callback
callbacks.Register("Unload", "MCT_Unload", OnUnload)                         -- Register the "Unload" callback
callbacks.Register("CreateMove", "MCT_CreateMove", OnCreateMove)             -- Register the "CreateMove" callback
--[[ Play sound when loaded ]]--
client.Command('play "ui/buttonclick"', true) -- Play the "buttonclick" sound when the script is loaded