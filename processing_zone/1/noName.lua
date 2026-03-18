local function doDraw()
    if not engine.Con_IsVisible() or not engine.IsGameUIVisible() then return end
    draw.Color(132, 162, 196, 255)
    local x, y = draw.GetScreenSize()
    draw.FilledRect(0, 0, x * 0.3, y  * 0.325)
end

callbacks.Unregister("Draw", "MCT_Draw")                        -- Unregister the "Draw" callback
callbacks.Register("Draw", "MCT_Draw", doDraw)                               -- Register the "Draw" callback