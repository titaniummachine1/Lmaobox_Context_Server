local myfont = draw.CreateFont( "Verdana", 16, 800 )

local function doDraw()
    if engine.Con_IsVisible() or engine.IsGameUIVisible() then
        return
    end

    local players = entities.FindByClass("CTFPlayer")

    if engine.Con_IsVisible() or engine.IsGameUIVisible() then
        return
    end

    local players = entities.FindByClass("CTFPlayer")
    local pLocal = entities.GetLocalPlayer()
    if pLocal:IsAlive() then
      local screenPos = client.WorldToScreen(pLocal:GetAbsOrigin())
      if screenPos ~= nil then
        draw.SetFont(myfont)
        draw.Color(255, 255, 255, 255)
        draw.Text(screenPos[1], screenPos[2], "ignacy")
    
        local x, y = screenPos[1], screenPos[2]
        local radius = 100
        local segments = 40
        local prevx, prevy = x + radius, y
    
        for i = 1, segments do
          local angle = (i / segments) * math.pi * 2
          local newx = x + math.cos(angle) * radius
          local newy = y + math.sin(angle) * radius
          draw.Line(math.floor(prevx), math.floor(prevy), math.floor(newx), math.floor(newy))
          prevx, prevy = newx, newy
        end
        end
    end
end


callbacks.Register("Draw", "mydraw", doDraw) 