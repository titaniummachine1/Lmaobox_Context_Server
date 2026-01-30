local myfont = draw.CreateFont( "Verdana", 16, 800 )

local function doDraw()
    if engine.Con_IsVisible() or engine.IsGameUIVisible() then
        return
    end

    local players = entities.FindByClass("CTFPlayer")

    for i, p in ipairs( players ) do
        if p:IsAlive() and not p:IsDormant() then

            local screenPos = client.WorldToScreen( p:GetAbsOrigin() )
            if screenPos ~= nil then
                draw.SetFont( myfont )
                draw.Color( 255, 255, 255, 255 )
                draw.Text( screenPos[1], screenPos[2], p:GetName() )
            end
        end
    end
end

callbacks.Register("Draw", "mydraw", doDraw) 