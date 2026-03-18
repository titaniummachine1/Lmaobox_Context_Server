    --pLocal:GetHitboxes()
    local pLocal = entities.GetLocalPlayer()
    if pLocal then
        pLocal:AddCond(1)
    end

    client.Command("sv_cheats 1", true) -- enable cheats"sv_cheats 1"
    client.Command("AddCond 1", true)
 