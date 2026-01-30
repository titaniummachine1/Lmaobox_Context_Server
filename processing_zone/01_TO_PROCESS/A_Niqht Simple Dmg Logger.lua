--[[
    Original author: pred#2448
     Editied By Niqht
]]

local queue = {}
local floor = math.floor
local x, y = draw.GetScreenSize()
local font_calibri = draw.CreateFont("Calibri", 18, 18)

local function event_hook(ev)
    if ev:GetName() ~= "player_hurt" then return end -- only allows player_hurt event go through
    --declare variables
    --to get all structures of event: https://wiki.alliedmods.net/Team_Fortress_2_Events#player_hurt
    
    local victim_entity = entities.GetByUserID(ev:GetInt("userid"))
    local attacker = entities.GetByUserID(ev:GetInt("attacker"))
    local localplayer = entities.GetLocalPlayer()
    local damage = ev:GetInt("damageamount")
    local health = ev:GetInt("health")

    if attacker ~= localplayer then return end
    --insert table
    table.insert(queue, {
        string = string.format(" %s for %d hp (%d left)", victim_entity:GetName(), damage, health),
        delay = globals.RealTime() + 3,
        alpha = 0,
        health
    })

    printc(100, 255, 100, 255, string.format("[LMAOBOX] %s for %d hp (%d left)", victim_entity:GetName(), damage, health))
end

local function paint_logs()
    draw.SetFont(font_calibri)
    
    local totalHeight = #queue* -1
    local yOffset = 10
    for i = #queue, math.max(#queue - 2, 1), -1 do
    local v = queue[i]
    local alpha = 255
    local text = v.string
    local y_pos = floor(y / 2) + yOffset - totalHeight + ((#queue - i + (-1)) * 11)
    draw.Color(27, 185, 0, alpha)
    draw.Text(890, y_pos, text)
    end
    end    

local function anim()
    local currentTime = globals.RealTime()
    local i = 1
    
    while i <= #queue do
    local v = queue[i]
    
    if currentTime >= v.delay then
    table.remove(queue, i)
    else
    i = i + 1
    end
    end
    end

local function draw_handler()
    paint_logs()
    anim()
end

callbacks.Register("Draw", "unique_draw_hook", draw_handler)
callbacks.Register("FireGameEvent", "unique_event_hook", event_hook)
