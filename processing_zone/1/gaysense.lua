--[[
    
    gaysense.lua
    XJN2
    https://github.com/XJN2/LMAOBox-Luas

]]

local font = draw.CreateFont( "Consolas", 16, 200 )
local fps = 0

local cheatname = "game"
local cheatname2 = "sense"
-- made these variables so you can change the name for the watermark, just note you gotta fix text pos too since im lazy lol.

-- Goofy aaah pasted code.
local function RGBRainbow(frequency)

    local curtime = globals.CurTime() 
    local r,g,b
    r = math.floor(math.sin(curtime * frequency + 0) * 127 + 128)
    g = math.floor(math.sin(curtime * frequency + 2) * 127 + 128)
    b = math.floor(math.sin(curtime * frequency + 4) * 127 + 128)
    
    return r, g, b
end
-- End of Goofy aaah pasted code.
-- Credits: https://github.com/DemonLoverHvH/

-- Draw text: Lmaobox | FPS: x | Ping: x | Time: x
local function Gaysense()

    local inGame = clientstate.GetClientSignonState()
    local me = entities.GetLocalPlayer()  

    if inGame == 6 then
        ping = entities.GetPlayerResources():GetPropDataTableInt("m_iPing")[me:GetIndex()] 
    else
        ping = "-"
    end

    if globals.FrameCount() % 15 == 0 then
        fps = math.floor(1 / globals.FrameTime())
    end

    local r, g, b = RGBRainbow(2.5)
    draw.Color( 40, 40, 40, 150 )
    draw.FilledRect( 1500, 10, 1900, 40 )
    draw.Color( 0, 0, 0, 200 )
    draw.OutlinedRect( 1500, 10, 1900, 40 )
    draw.Color( 20, 20, 20, 255 )
    draw.FilledRect( 1505, 15, 1895, 35 )
    draw.Color( 0, 0, 0, 200 )
    draw.OutlinedRect( 1505, 15, 1895, 35 )
    draw.Color( r, g, b, 255 )
    draw.Line( 1506, 16, 1894, 16 )
    
    draw.Color( 255, 255, 255, 255 )
    draw.SetFont( font )
    draw.Text( 1515, 17, cheatname )
    draw.Color( 0, 255, 0, 255 )
    draw.Text( 1540, 17, cheatname2 )
    draw.Color( 255, 255, 255, 255 )
    draw.Text( 1585, 17, "| fps: " .. fps )
    draw.Text( 1670, 17, "| ping: " .. tostring(ping) )
    draw.Text( 1755, 17, "| time: " .. os.date("%I:%M %p") )
end

print("==========================================================")
printc(50, 255, 50, 100, "GAYSENSE")
printc(255, 255, 255, 100, "Feel the power of gay.")
print("==========================================================")
engine.PlaySound("buttons/button3.wav")

callbacks.Register( "Draw", Gaysense )
