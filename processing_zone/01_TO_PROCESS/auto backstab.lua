callbacks.Register( "CreateMove", function(cmd)
    local lPlayer = entities.GetLocalPlayer()
    local weapon = lPlayer:GetPropEntity( "m_hActiveWeapon" )
    if weapon == lPlayer:GetEntityForLoadoutSlot( 2 ) then
        if weapon:GetPropInt("m_bReadyToBackstab") == 257 and cmd.command_number % 3 then
            cmd:SetButtons( cmd.buttons | IN_ATTACK)
        end
    end
end)
