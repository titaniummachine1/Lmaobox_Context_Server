local timer = 0
local delay = 33
local timer2 = 0

local function OnCreateMove(cmd)
    if timer < delay then
        timer = timer + 1
    else
        timer = 0
        client.Command("build 1", true) -- enable cheats"sv_cheats 1"
        if timer < 20 then
            timer2 = timer2 + 1
        else
            timer2 = 0
            cmd:SetButtons(cmd.buttons | IN_ATTACK)  -- Perform backstab
        end
    end
end

callbacks.Unregister("CreateMove", "OnCreateMove123313")
callbacks.Register("CreateMove", "OnCreateMove12313", OnCreateMove)
