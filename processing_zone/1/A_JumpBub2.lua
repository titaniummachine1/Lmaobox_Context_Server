local indicator_settings = {
    enabled = true ,
    color = {
        indicator_main = { 255, 255, 255, 255 },
        indicator_hit = { 0, 210, 215, 255 }
    }
}
 
local indicator_font = draw.CreateFont( "Verdana Bold", 23, 800, FONTFLAG_ANTIALIAS | FONTFLAG_DROPSHADOW)  

local function isOnGround(player)
    local pFlags = player:GetPropInt("m_fFlags")
    return (pFlags & FL_ONGROUND) == 1
end

local tickAccel = 800/66.67
local crouchOffset = 100-77

callbacks.Register( "CreateMove", "jumpbug", function(cmd)

    if GlobalCheck then GlobalCheck = false end

    if input.IsButtonDown(KEY_F3) then

        cmd:SetButtons(cmd.buttons | IN_DUCK)

        local localPlayer = entities.GetLocalPlayer()
        local origin = localPlayer:GetAbsOrigin()
        local down = Vector3(origin.x, origin.y, origin.z-3000)

        local vel = localPlayer:EstimateAbsVelocity()
        local traceToGround = engine.TraceLine( origin, vector.Add(down, vel), MASK_SOLID )
        local resultV3 = traceToGround.endpos

        if (((origin.z - crouchOffset) - tickAccel) < resultV3.z) and (not isOnGround(localPlayer)) and (vel.z < 0) then
            GlobalCheck = true
            cmd:SetButtons(cmd.buttons & (~IN_DUCK))
            cmd:SetButtons(cmd.buttons | IN_JUMP)
        end      
    end
end)

--- doesn't properly center for whatever reason
local x, y = draw.GetScreenSize()
local centerX = x / 2
local centerY = y / 2 - 12 

callbacks.Register("Draw", "JBindicator", function()
    
    if not indicator_settings.enabled or engine.IsGameUIVisible() then
		return
    end

    local Offset = 100

    draw.SetFont(indicator_font)
    if jumpbug ~= 0 and input.IsButtonDown(KEY_F3)  then
        draw.Color( table.unpack( indicator_settings.color.indicator_main ) )
        draw.Text( centerX - 8, centerY + Offset, "jb")
    end

    if (not GlobalCheck) then return end
    if jumpbug ~= 0 and input.IsButtonDown(KEY_F3)  then
        draw.Color( table.unpack( indicator_settings.color.indicator_hit ) )
        draw.Text( centerX - 8, centerY + Offset, "jb")
    end
end)