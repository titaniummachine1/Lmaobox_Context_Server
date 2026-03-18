warp.TriggerWarp()

local function OnCreateMove(cmd)
    if warp.GetChargedTicks() < 13 then
        cmd:SetForwardMove(0)
        cmd:SetSideMove(0)
    elseif warp.GetChargedTicks() > 13 then
        warp.TriggerWarp()
    elseif warp.GetChargedTicks() == 13 then
        local pLocal = entities.GetLocalPlayer()
        if not pLocal then return end

        local forwardMove = cmd:GetForwardMove()
        local sideMove = cmd:GetSideMove()

        if forwardMove > -1 and forwardMove < 1 then
            forwardMove = forwardMove < 0 and -1 or 1
        end

        if sideMove > -1 and sideMove < 1 then
            sideMove = sideMove < 0 and -1 or 1
        end

        cmd:SetForwardMove(forwardMove)
        cmd:SetSideMove(sideMove)
    end
end

--[[ Unregister previous callbacks ]]--
callbacks.Unregister("CreateMove", "CustomDT_CreateMove")            -- Unregister the "CreateMove" callback
--[[ Register callbacks ]]--
callbacks.Register("CreateMove", "CustomDT_CreateMove", OnCreateMove)             -- Register the "CreateMove" callback