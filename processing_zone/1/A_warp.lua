callbacks.Register("CreateMove", "testingstuff_CM", function(cmd)
    local pLocal = entities.GetLocalPlayer();
    if pLocal ~= nil then
        if input.IsButtonDown(28) and warp.CanWarp() then -- 28 seems to be KEY_R
            warp.TriggerWarp();
        end
    end
end)