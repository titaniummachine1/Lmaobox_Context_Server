
Custom Aimbot for Lmaobox
Author: github.com/lnx00
]]
local libLoaded, lnxLib = pcall(require, "lnxLib")
assert(libLoaded, "lnxLib not found, please install it!")
assert(lnxLib.GetVersion() >= 0.967, "LNXlib version is too old, please update it!")
local menuLoaded, MenuLib = pcall(require, "Menu")
assert(menuLoaded, "MenuLib not found, please install it!")
assert(MenuLib.Version >= 1.44, "MenuLib version is too old, please update it!")
local menu = MenuLib.Create("Projectile aimbot", MenuFlags.AutoSize)
menu.Style.TitleBg = { 205, 95, 50, 255 }
menu.Style.Outline = true
local mAimbot       = menu:AddComponent(MenuLib.Checkbox("Aimbot", true))
local mSilent       = menu:AddComponent(MenuLib.Checkbox("Silent", true))
local mAutoshoot    = menu:AddComponent(MenuLib.Checkbox("AutoShoot", true))
local mtime         = menu:AddComponent(MenuLib.Slider("time", 1 ,50, 2 ))
local mmVisuals     = menu:AddComponent(MenuLib.Checkbox("fov Circle", false))
local mFov          = menu:AddComponent(MenuLib.Slider("fov", 1 ,360, 360 ))
local mKey          = menu:AddComponent(MenuLib.Keybind("LAimbot Key", key))
local mdelay        = menu:AddComponent(MenuLib.Slider("dt delay", 1 ,24, 20 ))
local Hitbox = {
Head = 1,
Neck = 2,
Pelvis = 4,
Body = 5,
Chest = 7
}
local Hitboxes = {
1,
2,
4,
5,
7
local mhibox = menu:AddComponent(MenuLib.Combo("^Hitboxes", Hitboxes, ItemFlags.FullWidth))
local Math = lnxLib.Utils.Math
local WPlayer = lnxLib.TF2.WPlayer
local Helpers = lnxLib.TF2.Helpers
local targetFuture = nil
local options = {
AimKey      = KEY_LSHIFT,
AutoShoot   = mAutoshoot:GetValue(),
Silent      = mSilent:GetValue(),
AimFov      = mFov:GetValue()
local currentTarget = nil
function TargetPositionPrediction(targetLastPos, tickRate, time, targetEntity)
if targetLastPos == nil then
return nil
end
if not targetVelocitySamples then
targetVelocitySamples = {}
local targetKey = tostring(targetLastPos)
if not targetVelocitySamples[targetKey] then
targetVelocitySamples[targetKey] = {}
local targetVelocity = targetEntity:EstimateAbsVelocity()
if targetVelocity == nil then
targetVelocity = targetLastPos - targetEntity:GetOrigin()
table.insert(targetVelocitySamples[targetKey], 1, targetVelocity)
local samples = 2
if #targetVelocitySamples[targetKey] > samples then
table.remove(targetVelocitySamples[targetKey], samples + 1)
local totalVelocity = Vector3(0, 0, 0)
for i = 1, #targetVelocitySamples[targetKey] do
totalVelocity = totalVelocity + targetVelocitySamples[targetKey][i]
local averageVelocity = totalVelocity / #targetVelocitySamples[targetKey]
local curve = Vector3(0, 0, 0)
if #targetVelocitySamples[targetKey] >= 2 then
local previousVelocity = targetVelocitySamples[targetKey][1]
for i = 2, #targetVelocitySamples[targetKey] do
local currentVelocity = targetVelocitySamples[targetKey][i]
curve = curve + (previousVelocity - currentVelocity)
previousVelocity = currentVelocity
curve = curve / (#targetVelocitySamples[targetKey] - 1)
curve = curve * 66
targetFuture = targetLastPos + (averageVelocity) + curve
return targetFuture
local function GetBestTarget(me)
local players = entities.FindByClass("CTFPlayer")
local target = nil
local lastFov = math.huge
for _, entity in pairs(players) do
if not entity then goto continue end
if not entity:IsAlive() then goto continue end
if entity:GetTeamNumber() == entities.GetLocalPlayer():GetTeamNumber() then goto continue end
local pLocal = entities.GetLocalPlayer()
local pLocalOriginLast = me:GetAbsOrigin()
local targetOrigin = entity:GetAbsOrigin()
local pLocalOrigin = me:GetEyePos()
local tickRate = 66
local targetEntity = entity
local bulletNozzleVelocity = 1100
targetFuture = (entity:GetAbsOrigin() + entity:EstimateAbsVelocity())
if not targetFuture then goto continue end
local predictedPos = targetOrigin + targetVelocity * tickRate
local distance = (predictedPos - pLocalOrigin):Length()
local travelTime = distance / bulletNozzleVelocity
targetFuture = TargetPositionPrediction(targetOrigin, tickRate, travelTime, targetEntity)
local player = WPlayer.FromEntity(entity)
local aimPos = targetFuture
local angles = Math.PositionAngles(me:GetEyePos(), aimPos)
local fov = Math.AngleFov(angles, engine.GetViewAngles())
if fov > options.AimFov then goto continue end
if not Helpers.VisPos(entity, me:GetEyePos(), aimPos) then goto continue end
if fov < lastFov then
lastFov = fov
target = { entity = entity, pos = aimPos, angles = angles, factor = fov }
::continue::
return target
lasttarget = Vector3(0, 0, 0)
local function OnCreateMove(userCmd)
options = {
AimPos      = Hitbox.Head,
local me = WPlayer.GetLocal()
if not me then return end
currentTarget = GetBestTarget(me)
if not currentTarget then return end
if not input.IsButtonDown(options.AimKey) then return end
userCmd:SetViewAngles(currentTarget.angles:Unpack())
if not options.Silent then
engine.SetViewAngles(currentTarget.angles)
local pWeapon = me:GetPropEntity("m_hActiveWeapon")
if options.AutoShoot then
userCmd.buttons = userCmd.buttons | IN_ATTACK
lasttarget = currentTarget
local myfont = draw.CreateFont( "Verdana", 16, 800 )
local function OnDraw()
if engine.Con_IsVisible() or engine.IsGameUIVisible() then
return
draw.SetFont( myfont )
draw.Color( 255, 255, 255, 255 )
local w, h = draw.GetScreenSize()
local screenPos = { w / 2 - 15, h / 2 + 35}
screenPos = client.WorldToScreen(targetFuture)
if screenPos ~= nil then
draw.Line( screenPos[1] + 10, screenPos[2], screenPos[1] - 10, screenPos[2])
draw.Line( screenPos[1], screenPos[2] - 10, screenPos[1], screenPos[2] + 10)
local function OnUnload()
MenuLib.RemoveMenu(menu)
client.Command('play "ui/buttonclickrelease"', true)
callbacks.Unregister("CreateMove", "LNX.Aimbot.CreateMove")
callbacks.Unregister("Unload", "MCT_Unload")
callbacks.Unregister("Draw", "LNX.Aimbot.Draw")
callbacks.Register("CreateMove", "LNX.Aimbot.CreateMove", OnCreateMove)
callbacks.Register("Unload", "MCT_Unload", OnUnload)
callbacks.Register("Draw", "LNX.Aimbot.Draw", OnDraw)
local menu = MenuLib.Create("Anti Aim lua for Lmaobox", MenuFlags.AutoSize)
menu.Style.TitleBg = { 125, 155, 255, 255 }
local RandomToggle  = menu:AddComponent(MenuLib.Checkbox("Random Yaw", true))
local Antioverlap   = menu:AddComponent(MenuLib.Checkbox("anti overlap", true))
local FakeLagToggle = menu:AddComponent(MenuLib.Checkbox("Random Fake Lag", false))
local MinFakeLag    = menu:AddComponent(MenuLib.Slider("Fake Lag Min Value", 1 ,22 , 14 ))
local MaxFakeLag    = menu:AddComponent(MenuLib.Slider("Fake Lag Max Value", 1 ,22 , 22 ))
local JitterToggle  = menu:AddComponent(MenuLib.Checkbox("(Yaw) Jitter", false))
local JitterReal    = menu:AddComponent(MenuLib.Slider("Real Angle Jitter", -180 ,180 , 140 ))
local JitterFake    = menu:AddComponent(MenuLib.Slider("Fake Angle Jitter", -180 ,180 , 170 ))
local OffsetSpinToggle  = menu:AddComponent(MenuLib.Checkbox("(Yaw) Offset Spin", false))
local RealOffset    = menu:AddComponent(MenuLib.Slider("Real Angle Offset", 0 ,180 , 65 ))
local SemiSpinToggle  = menu:AddComponent(MenuLib.Checkbox("(Yaw) Semi Spin (broken)", false))
local SemiSpinOffset    = menu:AddComponent(MenuLib.Slider("Spin Angle", -179 ,180 , 50 ))
local SemiSpinRealOffset    = menu:AddComponent(MenuLib.Slider("Real Angle Offset", -180 ,180 , 50 ))
local function script()
if RandomToggle:GetValue() == true then
gui.SetValue("Anti Aim - Custom Yaw (Real)", math.random(-180, 180 ))
gui.SetValue("Anti Aim - Custom Yaw (Fake)", math.random(-180, 180 ))
gui.SetValue("Anti Aim - Pitch", "Custom")
if FakeAngle == RealAngle then
RealAngle = somethingElse
local number = math.random(1,3)
if number == 1 then
gui.SetValue("Anti Aim - Pitch", 2)
elseif number == 2 then
gui.SetValue("Anti Aim - Pitch", 4)
else
local pitch = math.random(40, 80)
pitch = -pitch
gui.SetValue("Anti Aim - Custom Pitch (Real)", pitch)
if FakeLagToggle:GetValue() == true then
ticks = math.random(MinFakeLag.Value, MaxFakeLag.Value) * 15
if JitterToggle:GetValue() == true then
if gui.GetValue( "Anti Aim - Custom Yaw (Real)" ) == JitterReal.Value then
gui.SetValue( "Anti Aim - Custom Yaw (Real)", JitterFake.Value)
gui.SetValue( "Anti Aim - Custom Yaw (Fake)", JitterReal.Value)
gui.SetValue( "Anti Aim - Custom Yaw (Real)", JitterReal.Value)
gui.SetValue( "Anti Aim - Custom Yaw (Fake)", JitterFake.Value)
gui.SetValue( "Anti Aim - Custom Yaw (Real)", -JitterReal.Value)
gui.SetValue( "Anti Aim - Custom Yaw (Fake)", -JitterFake.Value)
if OffsetSpinToggle:GetValue() == true then
gui.SetValue( "Anti Aim - Custom Yaw (fake)", gui.GetValue( "Anti Aim - Custom Yaw (fake)" ) + 1)
if (gui.GetValue( "Anti Aim - Custom Yaw (fake)") == 180) then
gui.SetValue( "Anti Aim - Custom Yaw (fake)", -180)
gui.SetValue( "Anti Aim - Custom Yaw (real)", gui.GetValue( "Anti Aim - Custom Yaw (fake)") - RealOffset.Value)
if SemiSpinToggle:GetValue() == true then
if (gui.GetValue("Anti Aim - Custom Yaw (fake)") == SemiSpinOffset.Value) then
gui.SetValue( "Anti Aim - Custom Yaw (fake)", (SemiSpinOffset.Value - 100))
gui.SetValue( "Anti Aim - Custom Yaw (real)", gui.GetValue( "Anti Aim - Custom Yaw (fake)") - SemiSpinRealOffset.Value)
callbacks.Unregister("CreateMove", "MCT_CreateMove")
callbacks.Register( "Draw", "MCT_Script", script )
Auto Peek for Lmaobox
Author: LNX (github.com/lnx00)
assert(MenuLib.Version >= 1.43, "MenuLib version is too old, please update it!")
Font = draw.CreateFont("Roboto", 20, 400)
local menu = MenuLib.Create("Auto Peek", MenuFlags.AutoSize)
menu.Style.TitleBg = { 0, 100, 100, 255 }
local mEnabled = menu:AddComponent(MenuLib.Checkbox("Enable", true))
local mKey = menu:AddComponent(MenuLib.Keybind("Peek Key", KEY_LSHIFT, ItemFlags.FullWidth))
menu:AddComponent(MenuLib.Label("_"))
local mFreeMove = menu:AddComponent(MenuLib.Checkbox("Free Move", false))
local mDistance = menu:AddComponent(MenuLib.Slider("Distance", 20, 400, 100))
local mSegments = menu:AddComponent(MenuLib.Slider("Segments", 2, 15, 5))
local PosPlaced = false
local IsReturning = false
local HasDirection = false
local PeekStartVec = Vector3(0, 0, 0)
local PeekDirectionVec = Vector3(0, 0, 0)
local PeekReturnVec = Vector3(0, 0, 0)
local LineDrawList = {}
HEAD = 1,
NECK = 2,
PELVIS = 4,
BODY = 5,
CHEST = 7
local function OnGround(player)
local pFlags = player:GetPropInt("m_fFlags")
return (pFlags & FL_ONGROUND) == 1
local function VisPos(target, vFrom, vTo)
local trace = engine.TraceLine(vFrom, vTo, MASK_SHOT | CONTENTS_GRATE)
return ((trace.entity and trace.entity == target) or (trace.fraction > 0.99))
local function CanShoot(pLocal)
local pWeapon = pLocal:GetPropEntity("m_hActiveWeapon")
if (not pWeapon) or (pWeapon:IsMeleeWeapon()) then return false end
local nextPrimaryAttack = pWeapon:GetPropFloat("LocalActiveWeaponData", "m_flNextPrimaryAttack")
local nextAttack = pLocal:GetPropFloat("bcc_localdata", "m_flNextAttack")
if (not nextPrimaryAttack) or (not nextAttack) then return false end
return (nextPrimaryAttack <= globals.CurTime()) and (nextAttack <= globals.CurTime())
local function GetHitboxPos(entity, hitbox)
local hitbox = entity:GetHitboxes()[hitbox]
if not hitbox then return end
return (hitbox[1] + hitbox[2]) * 0.5
local function CanAttackFromPos(pLocal, pPos)
if CanShoot(pLocal) == false then return false end
local ignoreFriends = gui.GetValue("ignore steam friends")
for k, vPlayer in pairs(players) do
if vPlayer:IsValid() == false then goto continue end
if vPlayer:IsAlive() == false then goto continue end
if vPlayer:GetTeamNumber() == pLocal:GetTeamNumber() then goto continue end
local playerInfo = client.GetPlayerInfo(vPlayer:GetIndex())
if steam.IsFriend(playerInfo.SteamID) and ignoreFriends == 1 then goto continue end
if VisPos(vPlayer, pPos, GetHitboxPos(vPlayer, Hitboxes.HEAD)) then
return true
return false
local function ComputeMove(pCmd, a, b)
local diff = (b - a)
if diff:Length() == 0 then return Vector3(0, 0, 0) end
local x = diff.x
local y = diff.y
local vSilent = Vector3(x, y, 0)
local ang = vSilent:Angles()
local cPitch, cYaw, cRoll = pCmd:GetViewAngles()
local yaw = math.rad(ang.y - cYaw)
local pitch = math.rad(ang.x - cPitch)
local move = Vector3(math.cos(yaw) * 450, -math.sin(yaw) * 450, -math.cos(pitch) * 450)
return move
local function WalkTo(pCmd, pLocal, pDestination)
local localPos = pLocal:GetAbsOrigin()
local result = ComputeMove(pCmd, localPos, pDestination)
pCmd:SetForwardMove(result.x)
pCmd:SetSideMove(result.y)
local function DrawLine(startPos, endPos)
table.insert(LineDrawList, {
start = startPos,
endPos = endPos
})
local function OnCreateMove(pCmd)
if not pLocal or mEnabled:GetValue() == false then return end
if pLocal:IsAlive() and input.IsButtonDown(mKey:GetValue()) or pLocal:IsAlive() and (pLocal:InCond(13)) then
if PosPlaced == false then
if OnGround(pLocal) then
PeekReturnVec = localPos
PosPlaced = true
if mFreeMove:GetValue() == false and HasDirection == false and OnGround(pLocal) then
local viewAngles = engine.GetViewAngles()
local vDirection = Vector3(0, 0, 0)
if input.IsButtonDown(KEY_A) or input.IsButtonDown(KEY_W) or input.IsButtonDown(KEY_D) or input.IsButtonDown(KEY_S) then
local eyePos = localPos + pLocal:GetPropVector("localdata", "m_vecViewOffset[0]")
if input.IsButtonDown(KEY_A) or input.IsButtonDown(KEY_W) then
vDirection = vDirection - (viewAngles:Right() * mDistance:GetValue())
elseif input.IsButtonDown(KEY_D) or input.IsButtonDown(KEY_S) then
vDirection = vDirection + (viewAngles:Right() * mDistance:GetValue())
local traceDest = eyePos + vDirection
local trace = engine.TraceLine(eyePos, traceDest, MASK_SOLID)
if trace then
PeekStartVec = trace.startpos
PeekDirectionVec = trace.endpos - trace.startpos
HasDirection = true
if mFreeMove:GetValue() == false and HasDirection == true then
local targetFound = false
local segmentSize = math.floor(100 / mSegments:GetValue())
LineDrawList = {}
for i = 1, mSegments:GetValue() do
local step = (i * segmentSize) / 100
local currentPos = PeekStartVec + (PeekDirectionVec * step)
if CanAttackFromPos(pLocal, currentPos) then
WalkTo(pCmd, pLocal, currentPos)
targetFound = true
DrawLine(PeekReturnVec, currentPos)
if targetFound then
break
if targetFound == false then IsReturning = true end
if pCmd:GetButtons() & IN_ATTACK == 1 then
IsReturning = true
if IsReturning == true then
local distVector = PeekReturnVec - localPos
local dist = distVector:Length()
if dist < 7 then
IsReturning = false
WalkTo(pCmd, pLocal, PeekReturnVec)
PosPlaced = false
HasDirection = false
PeekReturnVec = Vector3(0, 0, 0)
if PosPlaced == false then return end
draw.SetFont(options.Font)
draw.Color(255, 255, 255, 255)
if HasDirection == true then
draw.Color(200, 200, 200, 230)
for k, v in pairs(LineDrawList) do
local start = client.WorldToScreen(v.start)
local endPos = client.WorldToScreen(v.endPos)
if start ~= nil and endPos ~= nil then
draw.Line(start[1], start[2], endPos[1], endPos[2])
if mFreeMove:GetValue() == true then
if pLocal then
local startPos = client.WorldToScreen(pLocal:GetAbsOrigin())
local endPos = client.WorldToScreen(PeekReturnVec)
if startPos ~= nil and endPos ~= nil then
draw.Line(startPos[1], startPos[2], endPos[1], endPos[2])
callbacks.Unregister("CreateMove", "AP_CreateMove")
callbacks.Unregister("Draw", "AP_Draw")
callbacks.Unregister("Unload", "AP_Unload")
callbacks.Register("CreateMove", "AP_CreateMove", OnCreateMove)
callbacks.Register("Draw", "AP_Draw", OnDraw)
callbacks.Register("Unload", "AP_Unload", OnUnload)
client.Command('play "ui/buttonclick"', true)
client.RemoveConVarProtection("cyoa_pda_open")
client.Command("cyoa_pda_open 0", true)
local commandExecuted = false
if not pLocal then return end
local wtunzoom = false
if input.IsButtonReleased(MOUSE_RIGHT) and not pLocal:InCond(1) then
wtunzoom = true
if wtunzoom and not commandExecuted then
client.Command("cyoa_pda_open 1", true)
commandExecuted = true
elseif not wtunzoom and commandExecuted then
commandExecuted = false
callbacks.Register("CreateMove", "MCT_CreateMove", OnCreateMove)
local time = 0
local sec = 2
local bwplist = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 20, 22, 23, 24, 25, 58, 61, 65, 72, 73, 78, 80, 81, 91}
local function damage(event)
if (event:GetName() == 'player_hurt' ) then
local localPlayer = entities.GetLocalPlayer();
victim = entities.GetByUserID(event:GetInt("userid"))
local health = event:GetInt("health")
local attacker = entities.GetByUserID(event:GetInt("attacker"))
local damage = event:GetInt("damageamount")
local weaponid = event:GetInt("weaponid")
if (attacker == nil or localPlayer:GetIndex() ~= attacker:GetIndex()) or victim:GetIndex() == localPlayer:GetIndex() then
for i = 1, #bwplist do
if bwplist[i] == weaponid then
pbox = 1
hitboxv = victim:HitboxSurroundingBox()
time = globals.RealTime()
hitboxv = victim:GetHitboxes()
pbox = 0
callbacks.Register("FireGameEvent", "damageDraw", damage)
local function HitboxDraw()
if sec + time >= globals.RealTime() then
local poof = math.floor( 255 / sec)
local ac = math.floor(255 + ((time - globals.RealTime()) * poof))
for i = 1, 1 do
if pbox == 1 then
min = hitboxv[1]
max = hitboxv[2]
if pbox == 0 then
hitboxq = hitboxv[i]
min = hitboxq[1]
max = hitboxq[2]
local xa, ya, za = min:Unpack()
local xb, yb, zb = max:Unpack()
mool = Vector3(xb, ya, za)
moal = Vector3(xb, yb, za)
moul = Vector3(xa, yb, za)
moql = Vector3(xb, ya, zb)
morl = Vector3(xa, yb, zb)
mozl = Vector3(xa, ya, zb)
mool = client.WorldToScreen( mool )
moal = client.WorldToScreen( moal )
moul = client.WorldToScreen( moul )
moql = client.WorldToScreen( moql )
mozl = client.WorldToScreen( mozl )
morl = client.WorldToScreen( morl )
min = client.WorldToScreen( min )
max = client.WorldToScreen( max )
if (min ~= nil and max ~= nil and mozl ~= nil and morl ~= nil and moql ~= nil and mool ~= nil and moul ~= nil and moal ~= nil) then
draw.Color(255, 255, 255, ac)
draw.Line(mozl[1], mozl[2], morl[1], morl[2])
draw.Line(mozl[1], mozl[2], moql[1], moql[2])
draw.Line(morl[1], morl[2], max[1], max[2])
draw.Line(moql[1], moql[2], max[1], max[2])
draw.Line(min[1], min[2], mool[1], mool[2])
draw.Line(min[1], min[2], moul[1], moul[2])
draw.Line(mool[1], mool[2], moal[1], moal[2])
draw.Line(moul[1], moul[2], moal[1], moal[2])
draw.Line(min[1], min[2], mozl[1], mozl[2])
draw.Line(moal[1], moal[2], max[1], max[2])
draw.Line(moul[1], moul[2], morl[1], morl[2])
draw.Line(mool[1], mool[2], moql[1], moql[2])
callbacks.Register( "Draw", HitboxDraw )
local victim = pLocal
client.Command("cyoa_pda_open " .. ('0'), true)
if wtunzoom then
client.Command("cyoa_pda_open " .. ('1'), true)
client.ChatPrintf("works")
elseif not pLocal:InCond(1) then
if userCmd.command_number % 8 == 0 then
local menu = MenuLib.Create("Swing Prediction", MenuFlags.AutoSize)
client.SetConVar("cl_vWeapon_sway_interp",              0)
client.SetConVar("cl_jiggle_bone_framerate_cutoff", 0)
client.SetConVar("cl_bobcycle",                     10000)
client.SetConVar("sv_cheats", 1)
client.SetConVar("mp_disable_respawn_times", 1)
client.SetConVar("mp_respawnwavetime", -1)
client.SetConVar("mp_teams_unbalance_limit", 1000)
end, ItemFlags.FullWidth))]]
local Swingpred     = menu:AddComponent(MenuLib.Checkbox("Enable", true, ItemFlags.FullWidth))
local rangepred     = menu:AddComponent(MenuLib.Checkbox("range prediction", true))
local mtime         = menu:AddComponent(MenuLib.Slider("attack distance", 200 ,275 , 240 ))
local mAutoRefill   = menu:AddComponent(MenuLib.Checkbox("Crit Refill", true))
local mAutoGarden   = menu:AddComponent(MenuLib.Checkbox("Troldier assist", false))
local mmVisuals     = menu:AddComponent(MenuLib.Checkbox("Enable Visuals", false))
local Visuals = {
["Range Circle"] = true,
["Draw Trail"] = true
local mVisuals = menu:AddComponent(MenuLib.MultiCombo("^Visuals", Visuals, ItemFlags.FullWidth))
local mcolor_close  = menu:AddComponent(MenuLib.Colorpicker("Color", color))
if GetViewHeight ~= nil then
local mTHeightt = GetViewHeight()
local mTHeightt = 85
local msamples = 66
local pastPredictions = {}
local hitbox_min = Vector3(14, 14, 0)
local hitbox_max = Vector3(-14, -14, 85)
local vPlayerOrigin = nil
local pLocalOrigin
local closestPlayer
local closestDistance = 2000
local tick = 0
local pLocalClass
local swingrange = 1
local mresolution = 128
local viewheight
local tick_count = 0
function UpdateLocals()
local viewOffset = vector3(0, 0, 75)
local adjustedHeight = pLocal:GetAbsOrigin() + viewOffset
viewheight = (adjustedHeight - pLocal:GetAbsOrigin()):Length()
local Vheight = Vector3(0, 0, viewheight)
pLocalOrigin = (pLocal:GetAbsOrigin() + Vheight)
return viewheight
function GetClosestEnemy(pLocal, pLocalOrigin)
closestDistance = 2000
local maxDistance = 2000
closestPlayer = nil
for _, vPlayer in ipairs(players) do
if vPlayer ~= nil and vPlayer:IsAlive() and vPlayer:GetTeamNumber() ~= pLocal:GetTeamNumber() then
local vPlayerOrigin = vPlayer:GetAbsOrigin()
local distanceX = math.abs(vPlayerOrigin.x - pLocalOrigin.x)
local distanceY = math.abs(vPlayerOrigin.y - pLocalOrigin.y)
local distanceZ = math.abs(vPlayerOrigin.z - pLocalOrigin.z)
local distance = math.sqrt(distanceX * distanceX + distanceY * distanceY + distanceZ * distanceZ)
if distance < closestDistance and distance <= maxDistance then
closestPlayer = vPlayer
closestDistance = distance
if closestDistance < 2000 then
return closestPlayer
curve = curve * tickRate * time
local targetFuture = targetLastPos + (averageVelocity * time) + curve
local vhitbox_Height = 85
local vhitbox_width = 18
function GetTriggerboxMin(swingrange, vPlayerFuture)
if vPlayerFuture ~= nil and isMelee then
vhitbox_Height_trigger_bottom = swingrange
vhitbox_width_trigger = (vhitbox_width + swingrange)
local vhitbox_min = Vector3(-vhitbox_width_trigger, -vhitbox_width_trigger, -vhitbox_Height_trigger_bottom)
local hitbox_min_trigger = (vPlayerFuture + vhitbox_min)
return hitbox_min_trigger
function GetTriggerboxMax(swingrange, vPlayerFuture)
vhitbox_Height_trigger = (vhitbox_Height + swingrange)
local vhitbox_max = Vector3(vhitbox_width_trigger, vhitbox_width_trigger, vhitbox_Height_trigger)
local hitbox_max_trigger = (vPlayerFuture + vhitbox_max)
return hitbox_max_trigger
function isWithinHitbox(hitboxMinTrigger, hitboxMaxTrigger, pLocalFuture, vPlayerFuture)
if not pLocalFuture or not hitboxMinTrigger or not hitboxMaxTrigger then
local minX, minY, minZ = hitboxMinTrigger:Unpack()
local maxX, maxY, maxZ = hitboxMaxTrigger:Unpack()
return pLocalFuture.x >= minX and pLocalFuture.x <= maxX and
pLocalFuture.y >= minY and pLocalFuture.y <= maxY and
pLocalFuture.z >= minZ and pLocalFuture.z <= maxZ
pLocal = entities.GetLocalPlayer()
if not Swingpred:GetValue() then goto continue end
if not pLocal then goto continue end
pLocalClass = pLocal:GetPropInt("m_iClass")
if pLocalClass == nil then goto continue end
if pLocalClass == 8 then goto continue end
swingrange = pWeapon:GetSwingRange()
local flags = pLocal:GetPropInt( "m_fFlags" )
local time = mtime:GetValue() * 0.001
if mAutoGarden:GetValue() == true then
local bhopping = false
local state = ""
local downheight = Vector3(0, 0, -250)
if input.IsButtonDown( KEY_SPACE ) then
bhopping = true
if flags & FL_ONGROUND == 0 or bhopping then
state = "slot3"
state = "slot1"
if state then
client.Command(state, true)
flags = player:GetPropInt( "m_fFlags" )
if flags & FL_ONGROUND == 0 and not bhopping then
pCmd:SetButtons(pCmd.buttons | IN_DUCK)
pCmd:SetButtons(pCmd.buttons & (~IN_DUCK))
tick_count = tick_count + 1
if tick_count % 132 == 0 then
isMelee = pWeapon:IsMeleeWeapon()
if pLocalClass ~= pLocalClasslast then
if pLocal == nil then pLocalOrigin = pLocal:GetAbsOrigin() return pLocalOrigin end
local viewOffset = Vector3(0, 0, 70)
closestPlayer = GetClosestEnemy(pLocal, pLocalOrigin, players)
if closestPlayer == nil then goto continue end
vPlayerOrigin = closestPlayer:GetAbsOrigin()
vdistance = (vPlayerOrigin - pLocalOrigin):Length()
vPlayerFuture = TargetPositionPrediction(vPlayerOrigin, tickRate, time, closestPlayer)
pLocalFuture =  TargetPositionPrediction(pLocalOrigin, tickRate, time, pLocal)
fDistance = (vPlayerFuture - pLocalFuture):Length()
if not isMelee then goto continue end
local stop = false
if (pLocal:InCond(17)) and pLocalClass == 4 or pLocalClass == 8 then
stop = true
local dynamicstop = swingrange + 10
if (pCmd.forwardmove == 0) then dynamicstop = swingrange - 10 end
if isMelee and pLocalClass == 4 and vdistance <= dynamicstop then
pCmd:SetButtons(pCmd:GetButtons() | IN_ATTACK)
local can_attack = false
local trace = engine.TraceLine(pLocalFuture, vPlayerFuture, MASK_SHOT_HULL)
if (trace.entity:GetClass() == "CTFPlayer") and (trace.entity:GetTeamNumber() ~= pLocal:GetTeamNumber()) then
can_attack = isWithinHitbox(GetTriggerboxMin(swingrange, vPlayerFuture), GetTriggerboxMax(swingrange, vPlayerFuture), pLocalFuture, vPlayerFuture)
swingrange = swingrange + 40
if fDistance <= (swingrange + 20) then
can_attack = true
if isMelee and not stop and can_attack then
warp.TriggerWarp()
end]]
elseif isMelee and not stop and pWeapon:GetCritTokenBucket() <= 27 and mAutoRefill:GetValue() == true then
if vdistance > 400 and can_attack then
elseif vdistance > 500 then
vPlayerOriginLast = vPlayerOrigin
pLocalOriginLast = pLocalOrigin
local function doDraw()
if vPlayerOrigin == nil then return end
if vPlayerFuture == nil and pLocalFuture == nil then return end
if not mmVisuals:GetValue() then return end
if pLocalFuture == nil then return end
local vPlayerTargetPos = vPlayerFuture
screenPos = client.WorldToScreen(pLocalFuture)
screenPos = client.WorldToScreen(vPlayerTargetPos)
local screenPos1 = client.WorldToScreen(vPlayerOrigin)
if screenPos1 ~= nil then
draw.Line( screenPos1[1], screenPos1[2], screenPos[1], screenPos[2])
if vhitbox_Height_trigger == nil then return end
local vertices = {
client.WorldToScreen(vPlayerTargetPos + Vector3(vhitbox_width_trigger, vhitbox_width_trigger, -vhitbox_Height_trigger_bottom)),
client.WorldToScreen(vPlayerTargetPos + Vector3(-vhitbox_width_trigger, vhitbox_width_trigger, -vhitbox_Height_trigger_bottom)),
client.WorldToScreen(vPlayerTargetPos + Vector3(-vhitbox_width_trigger, -vhitbox_width_trigger, -vhitbox_Height_trigger_bottom)),
client.WorldToScreen(vPlayerTargetPos + Vector3(vhitbox_width_trigger, -vhitbox_width_trigger, -vhitbox_Height_trigger_bottom)),
client.WorldToScreen(vPlayerTargetPos + Vector3(vhitbox_width_trigger, vhitbox_width_trigger, vhitbox_Height_trigger)),
client.WorldToScreen(vPlayerTargetPos + Vector3(-vhitbox_width_trigger, vhitbox_width_trigger, vhitbox_Height_trigger)),
client.WorldToScreen(vPlayerTargetPos + Vector3(-vhitbox_width_trigger, -vhitbox_width_trigger, vhitbox_Height_trigger)),
client.WorldToScreen(vPlayerTargetPos + Vector3(vhitbox_width_trigger, -vhitbox_width_trigger, vhitbox_Height_trigger))
if vertices[1] and vertices[2] and vertices[3] and vertices[4] and vertices[5] and vertices[6] and vertices[7] and vertices[8] then
draw.Line(vertices[1][1], vertices[1][2], vertices[2][1], vertices[2][2])
draw.Line(vertices[2][1], vertices[2][2], vertices[3][1], vertices[3][2])
draw.Line(vertices[3][1], vertices[3][2], vertices[4][1], vertices[4][2])
draw.Line(vertices[4][1], vertices[4][2], vertices[1][1], vertices[1][2])
draw.Line(vertices[5][1], vertices[5][2], vertices[6][1], vertices[6][2])
draw.Line(vertices[6][1], vertices[6][2], vertices[7][1], vertices[7][2])
draw.Line(vertices[7][1], vertices[7][2], vertices[8][1], vertices[8][2])
draw.Line(vertices[8][1], vertices[8][2], vertices[5][1], vertices[5][2])
if vertices[1] and vertices[5] then draw.Line(vertices[1][1], vertices[1][2], vertices[5][1], vertices[5][2]) end
if vertices[2] and vertices[6] then draw.Line(vertices[2][1], vertices[2][2], vertices[6][1], vertices[6][2]) end
if vertices[3] and vertices[7] then draw.Line(vertices[3][1], vertices[3][2], vertices[7][1], vertices[7][2]) end
if vertices[4] and vertices[8] then draw.Line(vertices[4][1], vertices[4][2], vertices[8][1], vertices[8][2])
if mVisuals:IsSelected("Draw Trail") then
local maxPositions = 20
if predictedPositions == nil then
predictedPositions = {}
table.insert(predictedPositions, 1, pLocalFuture)
if #predictedPositions > maxPositions then
table.remove(predictedPositions, maxPositions + 1)
for i = 1, math.min(#predictedPositions - 1, maxPositions - 1) do
local pos1 = predictedPositions[i]
local pos2 = predictedPositions[i + 1]
local screenPos1 = client.WorldToScreen(pos1)
local screenPos2 = client.WorldToScreen(pos2)
if screenPos1 ~= nil and screenPos2 ~= nil then
draw.Line(screenPos1[1], screenPos1[2], screenPos2[1], screenPos2[2])
if mVisuals:IsSelected("Range Circle") == false then return end
if vPlayerFuture == nil then return end
if not isMelee then return end
local color_close = {r = 255, g = 0, b = 0, a = 255}
local color_far = {r = 0, g = 0, b = 255, a = 255}
local selected_color = mcolor_close:GetColor()
color_close = {r = selected_color[1], g = selected_color[2], b = selected_color[3], a = selected_color[4]}
local selected_color1 = mcolor_close:GetColor()
color_far = {r = selected_color1[1], g = selected_color1[2], b = selected_color1[3], a = selected_color1[4]}
local target_distance = (swingrange)
local center = vPlayerFuture
local radius = swingrange
local segments = mresolution
vertices = {}
local colors = {}
for i = 1, segments do
local angle = math.rad(i * (360 / segments))
local direction = Vector3(math.cos(angle), math.sin(angle), 0)
local trace = engine.TraceLine(vPlayerFuture, center + direction * radius, MASK_SHOT_BRUSHONLY)
local distance = radius
local x = center.x + math.cos(angle) * distance
local y = center.y + math.sin(angle) * distance
local z = center.z + 1
if trace == nil then return end
local distance_to_hit = trace.fraction * radius
if  distance_to_hit == nil then return end
if distance_to_hit > 0 then
local max_height_adjustment = mTHeightt
local height_adjustment = (1 - distance_to_hit / radius) * max_height_adjustment
z = z + height_adjustment
vertices[i] = client.WorldToScreen(Vector3(x, y, z))
local t = (z - center.z - target_distance) / (mTHeightt - target_distance)
if t < 0 then
t = 0
elseif t > 1 then
t = 1
local color = {}
for key, value in pairs(color_close) do
color[key] = math.floor((1 - t) * value + t * color_far[key])
colors[i] = color
local top_height = mTHeightt
local top_vertex = client.WorldToScreen(Vector3(center.x, center.y, center.z + top_height))
local j = i + 1
if j > segments then j = 1 end
if vertices[i] ~= nil and vertices[j] ~= nil then
draw.Color(colors[i].r, colors[i].g, colors[i].b, colors[i].a)
draw.Line(vertices[i][1], vertices[i][2], vertices[j][1], vertices[j][2])
callbacks.Unregister("Draw", "MCT_Draw")
callbacks.Register("Draw", "MCT_Draw", doDraw)
client.Command("cyoa_pda_open", 1)
client.SetConVar("cyoa_pda_open", 1)
if pLocal:InCond(1) == true and client.GetConVar("cyoa_pda_open") == 0 then
elseif client.GetConVar("cyoa_pda_open") then
client.Command("cyoa_pda_open", 0)
client.SetConVar("sv_cheats", 0)
circle = {
color       = Color(1,1,1),
opacity     = 1.0,
radius      = 1,
show        = true,
steps       = 32,
thickness   = 0.2,
vert_offset = 0.05,
function toggleCircle()
circle.show = not circle.show
if circle.show then drawCircle() else clearCircle() end
function drawCircle()
circle.show = true
self.setVectorLines({
{
points    = getCircleVectorPoints(circle.radius, circle.steps, circle.vert_offset),
color     = circle.color,
thickness = circle.thickness,
rotation  = {0,-90,0},
function clearCircle()
circle.show = false
self.setVectorLines({})
function getCircleVectorPoints(radius, steps, y)
local t = {}
local d,s,c,r = 360/steps, math.sin, math.cos, math.rad
for i = 0,steps do
table.insert(t, {
c(r(d*i))*radius,
y,
s(r(d*i))*radius
return t
local function ShouldThink(localPlayer)
local playerResources = entities.GetPlayerResources();
local allPlayerClasses = playerResources:GetPropDataTableInt("m_iPlayerClass");
local currentPlayerClass = allPlayerClasses[localPlayer:GetIndex() + 1];
local playingSpy = currentPlayerClass == TF2_Spy;
return playingSpy;
local shouldThink = false;
local function CreateMoveHook(cmd)
if not localPlayer:IsAlive() then
if cmd.tick_count % 33 == 0 then
shouldThink = ShouldThink(localPlayer);
if not shouldThink then
return;
local isDisguised = localPlayer:InCond(TFCond_Cloaked);
if not isDisguised then
local cloakMeter = localPlayer:GetPropFloat("m_flCloakMeter");
if cloakMeter > 15.0 then
local moveModifier;
if cloakMeter > 1 and cloakMeter < 10 then
moveModifier = 0.2;
if cloakMeter < 1 then
moveModifier = 0;
cmd:SetForwardMove(cmd:GetForwardMove() * moveModifier);
cmd:SetSideMove(cmd:GetSideMove() * moveModifier);
cmd:SetUpMove(cmd:GetUpMove() * moveModifier);
cmd:SetButtons(cmd:GetButtons() & ~IN_JUMP);
callbacks.Register("CreateMove", "createmove_cloak_stop", CreateMoveHook);
local menu         = MenuLib.Create("Trajectories", MenuFlags.AutoSize)
menu:AddComponent(MenuLib.Label("                   [ Draw ]", ItemFlags.FullWidth))
local mEnagle        = menu:AddComponent(MenuLib.Checkbox("Enable", true))
local GRAVITY = 800
local FIXED_VELOCITY = 1300
function CalculateProjectilePath(startPos, endPos, velocity)
local distance = (endPos - startPos):Length()
local direction = (endPos - startPos)
if not velocity then
velocity = FIXED_VELOCITY
assert(startPos ~= nil and type(startPos) == "userdata", "Invalid start position")
assert(endPos ~= nil and type(endPos) == "userdata", "Invalid end position")
assert(velocity ~= nil and type(velocity) == "number", "Invalid velocity")
local angle = math.deg(math.asin((GRAVITY * distance) / (velocity * velocity)) / 2)
local timeToTarget = velocity * math.sin(math.rad(angle))
local height = velocity * math.sin(math.rad(angle)) * timeToTarget - 0.5 * GRAVITY * timeToTarget * timeToTarget
local path = {}
local interval = 0.04
local currentTime = 0
while currentTime <= timeToTarget do
local x = velocity * math.cos(math.rad(angle)) * currentTime
local y = velocity * math.sin(math.rad(angle)) * currentTime - 0.5 * GRAVITY * currentTime * currentTime + height
local z = velocity * math.cos(math.rad(angle)) * currentTime
local point = startPos + direction * x + Vector3(0, 0, z)
table.insert(path, point)
currentTime = currentTime + interval
return path
local myfont = draw.CreateFont("Verdana", 16, 800)
local me = entities.GetLocalPlayer()
me = entities.GetLocalPlayer();
local source = me:GetAbsOrigin() + me:GetPropVector( "localdata", "m_vecViewOffset[0]" );
local destination = source + engine.GetViewAngles():Forward() * 1000;
source = source + engine.GetViewAngles():Forward() * 10;
local trace = engine.TraceLine( source, destination, MASK_SHOT_HULL );
if (trace.entity == nil) then return end
local startPos = source + Vector3(-20, -20, -20)
local endPos = trace.endpos
local path = CalculateProjectilePath(source, endPos, FIXED_VELOCITY)
if path == nil then return end
for i, point in ipairs(path) do
local startScreenPos = client.WorldToScreen(path[i])
local endScreenPos = client.WorldToScreen(path[i+1])
if startScreenPos ~= nil and endScreenPos ~= nil then
draw.Line(startScreenPos[1], startScreenPos[2], endScreenPos[1], endScreenPos[2])
Cheater Detection for Lmaobox
StrikeLimit = 3,
MaxAngleDelta = 50
local playerStrikes = {}
local oldSimTimes = {}
local oldEyeAngles = {}
local function StrikePlayer(index, reason)
if playerStrikes[index] == nil then
playerStrikes[index] = 1
elseif playerStrikes[index] >= 0 then
playerStrikes[index] = playerStrikes[index] + 1
client.ChatPrintf("\x04[CD] \x02Player\x05 " .. index .. " \x02striked for:\x05 " .. reason)
local function CheckChoke(player)
local simTime = player:GetPropFloat("m_flSimulationTime")
if not simTime then return end
if not oldSimTimes[player:GetIndex()] then
oldSimTimes[player:GetIndex()] = simTime
local delta = simTime - oldSimTimes[player:GetIndex()]
if delta > 1 then
StrikePlayer(player:GetIndex(), "Packet was choked")
local function CheckPitch(player)
local eyeAnglesX = player:GetPropFloat("tfnonlocaldata", "m_angEyeAngles[0]")
if not eyeAnglesX then return end
if (eyeAnglesX ~= 0) and (eyeAnglesX >= 90 and eyeAnglesX <= -90) then
StrikePlayer(player:GetIndex(), "Invalid Pitch")
local function CheckAngleDelta(player)
local eyeAngles = player:GetPropVector("tfnonlocaldata", "m_angEyeAngles")
if not eyeAngles then return end
if not oldEyeAngles[player:GetIndex()] then
oldEyeAngles[player:GetIndex()] = eyeAngles
local delta = eyeAngles - oldEyeAngles[player:GetIndex()]
if delta:Length() > options.MaxAngleDelta then
StrikePlayer(player:GetIndex(), "Invalid Angle Delta")
if vPlayer:IsValid() == false or vPlayer:IsAlive() == false then
oldEyeAngles[vPlayer:GetIndex()] = nil
goto continue
CheckChoke(vPlayer)
CheckPitch(vPlayer)
CheckAngleDelta(vPlayer)
for kIndex, vStrikes in pairs(playerStrikes) do
if vStrikes == options.StrikeLimit then
client.ChatPrintf("\x04[CD] \x02Cheater detected:\x05 " .. entities.GetByIndex(kIndex):GetName())
playerStrikes[kIndex] = -1
callbacks.Unregister("CreateMove", "CD_CreateMove")
callbacks.Register("CreateMove", "CD_CreateMove", OnCreateMove)
Doubletap Bar for Lmaobox
X = 0.5,
Y = 0.6,
Size = 5,
Colors = {
Background = { 45, 50, 55, 100 },
Recharge = { 75, 120, 235, 255 },
Ready = { 70, 190, 50, 255 },
Outline = { 15, 15, 15, 255 }
local MAX_TICKS = 23
local function DT_Enabled()
local dtMode = gui.GetValue("double tap (beta)")
local dashKey = gui.GetValue("dash move key")
return dtMode ~= "off" or dashKey ~= 0
if not DT_Enabled() then return end
if not pLocal or engine.IsGameUIVisible() then return end
if not pWeapon then return end
local ratio = warp.GetChargedTicks() / MAX_TICKS
local boxWidth = 24 * options.Size
local boxHeight = math.floor(4 * options.Size)
local barWidth = math.floor(boxWidth * ratio)
local sWidth, sHeight = draw.GetScreenSize()
local xPos = math.floor(sWidth * options.X - boxWidth * 0.5)
local yPos = math.floor(sHeight * options.Y - boxHeight * 0.5)
draw.Color(table.unpack(options.Colors.Background))
draw.FilledRect(xPos, yPos, xPos + boxWidth, yPos + boxHeight)
if warp.IsWarping() or warp.GetChargedTicks() < MAX_TICKS then
draw.Color(table.unpack(options.Colors.Recharge))
elseif warp.CanDoubleTap(pWeapon) then
draw.Color(table.unpack(options.Colors.Ready))
draw.Color(205, 95, 50, 255)
draw.FilledRect(xPos, yPos, xPos + barWidth, yPos + boxHeight)
draw.Color(table.unpack(options.Colors.Outline))
draw.OutlinedRect(xPos, yPos, xPos + boxWidth, yPos + boxHeight)
callbacks.Unregister("Draw", "lnx_DT-Bar_Draw")
callbacks.Register("Draw", "lnx_DT-Bar_Draw", OnDraw)
File browser for ImMenu
ImMenu Styles:
- FileBrowser_ListSize: number
local ImMenu = require("ImMenu")
local currentPath = "./"
local currentOffset = 1
local function GetFileList(path)
local files = {}
pcall(function()
filesystem.EnumerateDirectory(path .. "*", function (filename, attributes)
if filename == "." or filename == ".." then return end
table.insert(files, { name = filename, attributes = attributes })
end)
return files
function ImMenu.FileBrowser()
local selectedFile = nil
local listSize = ImMenu.GetStyle()["FileBrowser_ListSize"] or 10
if ImMenu.Begin("File Browser", true) then
local fileList = GetFileList(currentPath)
local fileCount = #fileList
ImMenu.BeginFrame(ImAlign.Horizontal)
ImMenu.Text("Path: " .. currentPath)
ImMenu.EndFrame()
ImMenu.PushStyle("ItemSize", { 25, 75 })
ImMenu.BeginFrame(ImAlign.Vertical)
if ImMenu.Button("^") then
currentOffset = math.max(currentOffset - 1, 1)
if ImMenu.Button("<") then
currentPath = currentPath:match("(.*/).*/") or "./"
if ImMenu.Button("v") then
currentOffset = math.clamp(currentOffset + 1, 1, fileCount - listSize)
ImMenu.PopStyle()
ImMenu.PushStyle("ItemSize", { 300, 25 })
if fileCount == 0 then
ImMenu.Text("No files found")
for i = currentOffset, currentOffset + listSize - 1 do
local file = fileList[i]
if file then
local isFolder = file.attributes == FILE_ATTRIBUTE_DIRECTORY
if isFolder then
if ImMenu.Button(file.name .. "/") then
currentPath = currentPath .. file.name .. "/"
currentOffset = 1
if ImMenu.Button(file.name) then
selectedFile = currentPath .. file.name
ImMenu.End()
return selectedFile
animated hitlog recoded
remade animation
author: pred#2448
local queue = {}
local floor = math.floor
local x, y = draw.GetScreenSize()
local font_calibri = draw.CreateFont("Calibri", 18, 18)
local function event_hook(ev)
if ev:GetName() ~= "player_healed" then return end
local victim_entity = entities.GetByUserID(ev:GetInt("patient"))
local attacker = entities.GetByUserID(ev:GetInt("healer"))
local localplayer = entities.GetLocalPlayer()
local damage = ev:GetInt("amount")
local health = ev:GetInt("health")
local ping = entities.GetPlayerResources():GetPropDataTableInt("m_iPing")[victim_entity:GetIndex()]
if attacker ~= localplayer then return end
table.insert(queue, {
string = string.format("Healed %s for %d health (%d health remaining)", victim_entity:GetName(), damage, health, ping),
delay = globals.RealTime() + 5.5,
alpha = 0,
printc(100, 255, 100, 255, string.format("Healed %s for %d health (%d health remaining)", victim_entity:GetName(), damage, health, ping))
local function paint_logs()
draw.SetFont(font_calibri)
for i, v in pairs(queue) do
local alpha = floor(v.alpha)
local text = v.string
local y_pos = floor(y / 2) + (i * 20)
draw.Color(255, 255, 255, alpha)
draw.Text(7, y_pos, text)
local function anim()
if globals.RealTime() < v.delay then
v.alpha = math.min(v.alpha + 1, 255)
v.string = string.sub(v.string, 1, string.len(v.string) - 1)
if 0 >= string.len(v.string) then
table.remove(queue, i)
local function draw_handler()
paint_logs()
anim()
callbacks.Register("Draw", "unique_draw_hook", draw_handler)
callbacks.Register("FireGameEvent", "unique_event_hook", event_hook)
if ev:GetName() ~= "player_hurt" then return end
local victim_entity = entities.GetByUserID(ev:GetInt("userid"))
local attacker = entities.GetByUserID(ev:GetInt("attacker"))
local damage = ev:GetInt("damageamount")
local iscrit = ev:GetString("crit") == 1 and true or false
string = string.format("Hit %s for %d damage (%d health remaining)", victim_entity:GetName(), damage, health, iscrit, ping),
printc(100, 255, 100, 255, string.format("[LMAOBOX] Hit %s for %d damage (%d health remaining)", victim_entity:GetName(), damage, health, iscrit, ping))
HVh_Tools.lua for lmaobox
Author: github.com/titaniummachine1
credits:
Muqa for aa help
lmaobox for fixing cheat
Vodeninja.ru for config help
others... who inspired me
local menu         = MenuLib.Create("Hvh_tools", MenuFlags.AutoSize)
menu:AddComponent(MenuLib.Label("                   [ Misc ]", ItemFlags.FullWidth))
local mslowwalk            = menu:AddComponent(MenuLib.Slider("Walk Speed", 1, 200, 17))
local mSKey            = menu:AddComponent(MenuLib.Keybind("Key", KEY_LSHIFT, ItemFlags.FullWidth))
menu:AddComponent(MenuLib.Seperator())
local MinFakeLag        = menu:AddComponent(MenuLib.Slider("Fake Lag Min", 1, 329, 3))
local MaxFakeLag        = menu:AddComponent(MenuLib.Slider("Fake Lag Max", 2, 330, 2))
local mLegJitter        = menu:AddComponent(MenuLib.Checkbox("Leg Jitter", true))
local mlgstrengh        = menu:AddComponent(MenuLib.Slider("Leg Jitter Strengh", 9, 47, 33))
local mmVisuals         = menu:AddComponent(MenuLib.Checkbox("indicators", true))
local mmIndicator       = menu:AddComponent(MenuLib.Slider("Indicator Size", 10, 100, 50))
local mAutoPriority     = menu:AddComponent(MenuLib.Checkbox("Auto Priority", true))
menu:AddComponent(MenuLib.Label("                  [ Safety ]", ItemFlags.FullWidth))
local msafe_angles      = menu:AddComponent(MenuLib.Checkbox("Safe Angles", true))
local downPitch         = menu:AddComponent(MenuLib.Checkbox("Safe pitch", true))
local mAntiTaunt        = menu:AddComponent(MenuLib.Checkbox("Anti Holiday Punch", true))
local mHandShield        = menu:AddComponent(MenuLib.Checkbox("Hand Shield(BETA)", false))
menu:AddComponent(MenuLib.Label("                [ Anty Aim ]", ItemFlags.FullWidth))
local RandomPitchtype   = menu:AddComponent(MenuLib.Checkbox("Jitter Pitch type", true))
local RandomToggle      = menu:AddComponent(MenuLib.Checkbox("Jitter Yaw", true))
local mDelay            = menu:AddComponent(MenuLib.Slider("jitter Speed", 1, 66, 1))
local atenemy           = menu:AddComponent(MenuLib.Checkbox("At enemy", true))
local mHeadSize          = menu:AddComponent(MenuLib.Slider("Angle Distance", 1, 60, 44))
local Jitter_Range_Real  = menu:AddComponent(MenuLib.Slider("Jitter Range", 30, 180, 55))
local tick_count                = 0
local pitch                     = 0
local targetAngle
local yaw_real = nil
local yaw_Fake = nil
local offset = 0
local jitter_Real = 0
local jitter_Fake = 0
local number = 0
local Got_Hit = false
local pitchType
local BEST = 1
local BEST_UP = 2
local BEST_DOWN = 3
local UNSAFE = 4
local pitchtype1 = gui.GetValue("Anti Aim - Pitch")
local TargetAngle
local Jitter_Range_Real1 = Jitter_Range_Real:GetValue() / 2
local function GetBestTarget(me, pLocalOrigin, pLocal)
players = entities.FindByClass("CTFPlayer")
local closestPlayer = nil
local closestDistance = math.huge
AimPos = 1,
AimFov = 360
if entity == pLocal then goto continue end
local ValidTarget = entity and entity:IsAlive() and entity:GetTeamNumber() ~= me:GetTeamNumber()
if ValidTarget and (entity:GetPropInt("m_iClass") == 2 or entity:GetPropInt("m_iClass") == 8) then
local distance = (entity:GetAbsOrigin() - me:GetAbsOrigin()):Length()
if distance < closestDistance and distance < 2000 then
closestPlayer = entity
local targetPos = entity:GetAbsOrigin()
local playerPos = me:GetAbsOrigin()
local forwardVec = engine.GetViewAngles():Forward()
local targetAngle1 = math.deg(math.atan(targetPos.y - playerPos.y, targetPos.x - playerPos.x))
local viewAngle = math.deg(math.atan(forwardVec.y, forwardVec.x))
local finalAngle = targetAngle1 - viewAngle
local aimPos = player:GetHitboxPos(options.AimPos)
local angles = Math.PositionAngles(engine.GetViewAngles():Forward(), aimPos)
local entityOrigin = entity:GetAbsOrigin()
local function bestFov()
if not Helpers.VisPos(entityOrigin, me:GetEyePos(), aimPos) then
bestFov()
elseif closestDistance <= 250 then
target = closestPlayer
if target == nil then return nil end
local function damageLogger(event)
local victim = entities.GetByUserID(event:GetInt("attacker"))
local attacker = entities.GetByUserID(event:GetInt("userid"))
if (attacker == nil or localPlayer:GetIndex() ~= attacker:GetIndex()) then
Got_Hit = true
callbacks.Register("FireGameEvent", "exampledamageLogger", damageLogger)
local angleTable = {}
local evaluationTable = {}
function createAngleTable(Jitter_Min_Real, Jitter_Max_Real, dist)
local numPoints = math.floor((Jitter_Max_Real - Jitter_Min_Real) / dist) + 1
local stepSize = (Jitter_Max_Real - Jitter_Min_Real) / (numPoints - 1)
for i = 1, numPoints do
local angle = Jitter_Min_Real + (i - 1) * stepSize
local evaluation = 1
if msafe_angles:GetValue() then
if angle ~= 90 and angle ~= -90 and angle ~= 0 and angle ~= 180 then
table.insert(angleTable, angle)
table.insert(evaluationTable, evaluation)
evaluation = 0
function randomizeValue(Jitter_Min_Real, Jitter_Max_Real, dist)
if #angleTable == 0 then
createAngleTable(Jitter_Min_Real, Jitter_Max_Real, dist)
Got_Hit = false
if Got_Hit == true then
for i = 1, #evaluationTable do
if evaluationTable[i] > 1 then
evaluationTable[i] = evaluationTable[i] - 0.1
elseif evaluationTable[i] < 1 then
evaluationTable[i] = evaluationTable[i] + 0.1
local sortedTable = {}
for i = 1, #angleTable do
sortedTable[i] = {angle = angleTable[i], evaluation = evaluationTable[i]}
table.sort(sortedTable, function(a, b) return a.evaluation > b.evaluation end)
local highestRated = {}
local highestRating = sortedTable[1].evaluation
for i = 1, #sortedTable do
if sortedTable[i].evaluation == highestRating then
table.insert(highestRated, sortedTable[i].angle)
local randomIndex = math.random(1, #highestRated)
local randomValue = highestRated[randomIndex]
if Got_Hit then
if angleTable[i] == randomValue then
evaluationTable[i] = 1
table.remove(angleTable, i)
table.remove(evaluationTable, i)
return randomValue
function randomizeValue(jitterMin, jitterMax, dist, gotHit)
createAngleTable(jitterMin, jitterMax, dist)
if gotHit then
if evaluationTable[i] < 1 then
elseif evaluationTable[i] > 1 then
if i == #evaluationTable then
sortedTable[i] = { angle = angleTable[i], evaluation = evaluationTable[i] }
evaluationTable[i] = 2.0
local function updateYaw(Jitter_Real, Jitter_Fake)
if currentTarget then
local targetPos = currentTarget
if targetPos == nil then goto continue end
local playerPos = entities.GetLocalPlayer():GetAbsOrigin()
targetAngle = math.deg(math.atan(targetPos.y - playerPos.y, targetPos.x - playerPos.x))
TargetAngle = math.floor(targetAngle - viewAngle)
local yaw
if not atenemy:GetValue() then
yaw = Jitter_Fake
yaw = TargetAngle + Jitter_Fake
if yaw > 180 then
yaw = yaw - 360
elseif yaw < -180 then
yaw = yaw + 360
Jitter_Fake1 = yaw - TargetAngle
yaw = math.floor(yaw)
gui.SetValue("Anti Aim - Custom Yaw (Fake)", yaw)
yaw = jitter_Real
if pitchDowned then
yaw = TargetAngle - jitter_Real + 180
yaw = TargetAngle - jitter_Real
Jitter_Real1 = yaw - TargetAngle
gui.SetValue("Anti Aim - Custom Yaw (Real)", yaw)
if not pLocal:IsAlive() then return end
pitchtype1 = gui.GetValue("Anti Aim - Pitch")
local pLocalOrigin = pLocal:GetAbsOrigin() + Vector3(0, 0, 75)
if pitchType == 3 or pitchtype1 == "fake up" or pitchtype1 == "down" then
pitchDowned = true
pitchDowned = false
local Jitter_Min_Real = -Jitter_Range_Real1
local Jitter_Max_Real = Jitter_Range_Real1
if mAutoPriority:GetValue() then
for _, vPlayer in pairs(players) do
if vPlayer ~= nil and vPlayer:GetTeamNumber() ~= pLocal:GetTeamNumber() then
if playerlist.GetPriority(vPlayer) == 0 then
playerlist.SetPriority(vPlayer, 10)
if playerlist.GetPriority(vPlayer) == 10 then
playerlist.SetPriority(vPlayer, 0)
if mslowwalk:GetValue() ~= 100 and input.IsButtonDown(mSKey:GetValue()) then
local slowwalk = mslowwalk:GetValue() * 0.01
userCmd:SetForwardMove(userCmd:GetForwardMove()*slowwalk)
userCmd:SetSideMove(userCmd:GetSideMove()*slowwalk)
userCmd:SetUpMove(userCmd:GetUpMove()*slowwalk)
if userCmd.command_number % mDelay:GetValue() == 0 then
updateYaw(jitter_Real, jitter_Fake)
if mLegJitter:GetValue() == true then
local vVelocity  = pLocal:EstimateAbsVelocity()
if (userCmd.sidemove == 0) then
if userCmd.command_number % 2 == 0 then
userCmd:SetSideMove(mlgstrengh:GetValue())
userCmd:SetSideMove(-mlgstrengh:GetValue())
elseif (userCmd.forwardmove == 0) then
userCmd:SetForwardMove(mlgstrengh:GetValue())
userCmd:SetForwardMove(-mlgstrengh:GetValue())
Jitter_Range_Real1 = Jitter_Range_Real:GetValue() / 2
local currentTarget1 = GetBestTarget(me, pLocalOrigin)
if #players > 0 and currentTarget1 then
currentTarget = currentTarget1.entity:GetAbsOrigin()
currentTarget = pLocal:GetAbsOrigin()
local class = pLocal:GetPropInt("m_iClass")
local AimbotTarget = GetBestTarget(me)
if MinFakeLag:GetValue() < MaxFakeLag:GetValue() then
gui.SetValue("Fake Lag Value (MS)", math.random(MinFakeLag:GetValue(), MaxFakeLag:GetValue()))
local Head_size = mHeadSize:GetValue()
Jitter_Min_Real = -Jitter_Range_Real1
Jitter_Max_Real = Jitter_Range_Real1
if atenemy:GetValue() then
if mHandShield:GetValue() then
if (userCmd:GetButtons() & IN_ATTACK) == 1 then
jitter_Real = randomizeValue(Jitter_Min_Real, Jitter_Max_Real, Head_size)
jitter_Real = 30
if pLocal:InCond(1) == true then
jitter_real1 = jitter_Real
local Number1 = math.random(1, 3)
jitter_Fake = 180
jitter_Fake = jitter_Fake + Number1 * 90
jitter_Real = randomizeValue(Jitter_Min_Real * 2, Jitter_Max_Real * 2, Head_size)
local Number1 = math.random(1, 4)
jitter_Real_Last = jitter_Real
local YawFake = math.random(-180, 180)
while math.abs(YawFake - gui.GetValue("Anti Aim - Custom Yaw (Real)")) <= 37 do
YawFake = math.random(-180, 180)
gui.SetValue("Anti Aim - Custom Yaw (Fake)", YawFake)
if RandomPitchtype:GetValue() then
local function setMinMax(pitchType)
if pitchType == UNSAFE then
return 1, 4
elseif pitchType == BEST_UP then
return 1, 2
elseif pitchType == BEST_DOWN then
return 3, 4
local min, max = setMinMax(BEST)
min, max = setMinMax(UNSAFE)
if not downPitch:GetValue() then
pitchType = UNSAFE
elseif class == 1 then
pitchType = BEST_DOWN
elseif class == 2 then
pitchType = BEST_UP
elseif class == 3 then
elseif class == 4 then
elseif class == 5 then
elseif class == 6 then
elseif class == 7 then
elseif class == 8 then
elseif class == 9 then
min, max = setMinMax(pitchType)
number = math.random(min, max)
gui.SetValue("Anti Aim - Pitch", 1)
elseif number == 3 then
gui.SetValue("Anti Aim - Pitch", 3)
if userCmd:GetButtons(userCmd.buttons | IN_ZOOM) then
offset1 = offset:GetValue() - 25
elseif userCmd:GetButtons(userCmd.buttons | ~IN_ZOOM) then
offset1 = offset:GetValue() - 7
local direction = Vector3(0, 0, 0)
if targetAngle ~= nil then
if not atenemy then
yaw = Jitter_Real1
yaw = targetAngle + Jitter_Real1
if targetAngle then
direction = Vector3(math.cos(math.rad(yaw)), math.sin(math.rad(yaw)), 0)
yaw = gui.GetValue("Anti Aim - Custom Yaw (Real)")
local center = pLocal:GetAbsOrigin()
local range = mmIndicator:GetValue()
draw.Color( 81, 255, 54, 255 )
screenPos = client.WorldToScreen(center)
local endPoint = center + direction * range
local screenPos1 = client.WorldToScreen(endPoint)
draw.Line(screenPos[1], screenPos[2], screenPos1[1], screenPos1[2])
yaw = Jitter_Fake1
yaw = targetAngle + Jitter_Fake1
direction = Vector3(math.cos(math.rad(yaw)), math.sin(math.rad(yaw)), 0) + yaw_public_real
draw.Color( 255, 0, 0, 255 )
gui.SetValue("Anti Aim - Custom Pitch (Real)", math.random(-90, 90 ))
Immediate mode menu library for Lmaobox
if UnloadLib ~= nil then UnloadLib() end
local libLoaded, lnxLib = pcall(require, "LNXlib")
assert(libLoaded, "LNXlib not found, please install it!")
assert(lnxLib.GetVersion() >= 0.94, "LNXlib version is too old, please update it!")
local Fonts, Notify = lnxLib.UI.Fonts, lnxLib.UI.Notify
local KeyHelper, Input = lnxLib.Utils.KeyHelper, lnxLib.Utils.Input
ImAlign = { Vertical = 0, Horizontal = 1 }
local ImMenu = {
Cursor = { X = 0, Y = 0 },
ActiveItem = nil
local ScreenWidth, ScreenHeight = draw.GetScreenSize()
local DragPos = { X = 0, Y = 0 }
local MouseHelper = KeyHelper.new(MOUSE_LEFT)
local EnterHelper = KeyHelper.new(KEY_ENTER)
local LeftArrow = KeyHelper.new(KEY_LEFT)
local RightArrow = KeyHelper.new(KEY_RIGHT)
local Windows = {}
local Colors = {
Title = { 55, 100, 215, 255 },
Text = { 255, 255, 255, 255 },
Window = { 30, 30, 30, 255 },
Item = { 50, 50, 50, 255 },
ItemHover = { 60, 60, 60, 255 },
ItemActive = { 70, 70, 70, 255 },
Highlight = { 180, 180, 180, 100 },
HighlightActive = { 240, 240, 240, 140 },
WindowBorder = { 55, 100, 215, 255 },
FrameBorder = { 0, 0, 0, 200 },
Border = { 0, 0, 0, 200 }
local Style = {
Font = Fonts.Verdana,
Spacing = 5,
FramePadding = 7,
ItemSize = nil,
WindowBorder = true,
FrameBorder = false,
ButtonBorder = false,
CheckboxBorder = false,
SliderBorder = false,
Border = false
local WindowStack = Stack.new()
local FrameStack = Stack.new()
local ColorStack = Stack.new()
local StyleStack = Stack.new()
local function UnpackColor(color)
return color[1], color[2], color[3], color[4] or 255
function ImMenu.GetVersion() return 0.61 end
function ImMenu.GetStyle() return table.readOnly(Style) end
function ImMenu.GetColors() return table.readOnly(Colors) end
function ImMenu.GetCurrentWindow() return WindowStack:peek() end
function ImMenu.GetCurrentFrame() return FrameStack:peek() end
function ImMenu.PushColor(key, color)
ColorStack:push({ Key = key, Value = Colors[key] })
Colors[key] = color
function ImMenu.PopColor(amount)
amount = amount or 1
for _ = 1, amount do
local color = ColorStack:pop()
Colors[color.Key] = color.Value
function ImMenu.PushStyle(key, style)
StyleStack:push({ Key = key, Value = Style[key] })
Style[key] = style
function ImMenu.PopStyle(amount)
local style = StyleStack:pop()
Style[style.Key] = style.Value
function ImMenu.AddColor(key, value)
Colors[key] = value
function ImMenu.AddStyle(key, value)
Style[key] = value
function ImMenu.UpdateCursor(w, h)
local frame = ImMenu.GetCurrentFrame()
if frame then
if frame.A == 0 then
ImMenu.Cursor.Y = ImMenu.Cursor.Y + h + Style.Spacing
frame.W = math.max(frame.W, w)
frame.H = math.max(frame.H, ImMenu.Cursor.Y - frame.Y)
elseif frame.A == 1 then
ImMenu.Cursor.X = ImMenu.Cursor.X + w + Style.Spacing
frame.W = math.max(frame.W, ImMenu.Cursor.X - frame.X)
frame.H = math.max(frame.H, h)
function ImMenu.InteractionColor(hovered, active)
if active then
draw.Color(UnpackColor(Colors.ItemActive))
elseif hovered then
draw.Color(UnpackColor(Colors.ItemHover))
draw.Color(UnpackColor(Colors.Item))
function ImMenu.GetSize(width, height)
if Style.ItemSize ~= nil then
width = Style.ItemSize[1] == -1 and frame.W or Style.ItemSize[1]
height = Style.ItemSize[2] == -1 and frame.H or Style.ItemSize[2]
return width, height
function ImMenu.GetInteraction(x, y, width, height, id)
if ImMenu.ActiveItem ~= nil and ImMenu.ActiveItem ~= id then
return false, false, false
local hovered = Input.MouseInBounds(x, y, x + width, y + height) or id == ImMenu.ActiveItem
local clicked = hovered and (MouseHelper:Pressed() or EnterHelper:Pressed())
local active = hovered and (MouseHelper:Down() or EnterHelper:Down())
if active and ImMenu.ActiveItem == nil then
ImMenu.ActiveItem = id
if ImMenu.ActiveItem == id and not active then
ImMenu.ActiveItem = nil
return hovered, clicked, active
function ImMenu.GetLabel(text)
for label in text:gmatch("(.+)###(.+)") do
return label
return text
function ImMenu.Space(size)
size = size or Style.Spacing
ImMenu.UpdateCursor(size, size)
function ImMenu.Separator()
local x, y = ImMenu.Cursor.X, ImMenu.Cursor.Y
local width, height = ImMenu.GetSize(250, Style.Spacing * 2)
draw.Color(UnpackColor(Colors.WindowBorder))
draw.Line(x, y + height // 2, x + width, y + height // 2)
ImMenu.UpdateCursor(width, height)
function ImMenu.BeginFrame(align)
align = align or 0
FrameStack:push({ X = ImMenu.Cursor.X, Y = ImMenu.Cursor.Y, W = 0, H = 0, A = align })
ImMenu.Cursor.X = ImMenu.Cursor.X + Style.FramePadding
ImMenu.Cursor.Y = ImMenu.Cursor.Y + Style.FramePadding
function ImMenu.EndFrame()
local frame = FrameStack:pop()
ImMenu.Cursor.X = frame.X
ImMenu.Cursor.Y = frame.Y
frame.W = frame.W + Style.FramePadding * 2
frame.H = frame.H + Style.FramePadding - Style.Spacing
frame.H = frame.H + Style.FramePadding * 2
frame.W = frame.W + Style.FramePadding - Style.Spacing
if Style.FrameBorder then
draw.Color(UnpackColor(Colors.FrameBorder))
draw.OutlinedRect(frame.X, frame.Y, frame.X + frame.W, frame.Y + frame.H)
ImMenu.UpdateCursor(frame.W, frame.H)
return frame
function ImMenu.Begin(title, visible)
local isVisible = (visible == nil) or visible
if not isVisible then return false end
if not Windows[title] then
Windows[title] = {
X = 50,
Y = 150,
W = 100,
H = 100
draw.SetFont(Style.Font)
local window = Windows[title]
local titleText = ImMenu.GetLabel(title)
local txtWidth, txtHeight = draw.GetTextSize(titleText)
local titleHeight = txtHeight + Style.Spacing
local hovered, clicked, active = ImMenu.GetInteraction(window.X, window.Y, window.W, titleHeight, title)
draw.Color(table.unpack(Colors.Title))
draw.OutlinedRect(window.X, window.Y, window.X + window.W, window.Y + window.H)
draw.FilledRect(window.X, window.Y, window.X + window.W, window.Y + titleHeight)
draw.Color(table.unpack(Colors.Text))
draw.Text(window.X + (window.W // 2) - (txtWidth // 2), window.Y + (20 // 2) - (txtHeight // 2), titleText)
draw.Color(table.unpack(Colors.Window))
draw.FilledRect(window.X, window.Y + titleHeight, window.X + window.W, window.Y + window.H + titleHeight)
if Style.WindowBorder then
draw.OutlinedRect(window.X, window.Y, window.X + window.W, window.Y + window.H + titleHeight)
draw.Line(window.X, window.Y + titleHeight, window.X + window.W, window.Y + titleHeight)
local mX, mY = table.unpack(input.GetMousePos())
if clicked then
DragPos = { X = mX - window.X, Y = mY - window.Y }
window.X = math.clamp(mX - DragPos.X, 0, ScreenWidth - window.W)
window.Y = math.clamp(mY - DragPos.Y, 0, ScreenHeight - window.H - titleHeight)
ImMenu.Cursor.X = window.X
ImMenu.Cursor.Y = window.Y + titleHeight
ImMenu.BeginFrame()
Windows[title] = window
WindowStack:push(window)
function ImMenu.End()
local frame = ImMenu.EndFrame()
local window = WindowStack:pop()
window.W = frame.W
window.H = frame.H
function ImMenu.Text(text)
local label = ImMenu.GetLabel(text)
local txtWidth, txtHeight = draw.GetTextSize(label)
local width, height = ImMenu.GetSize(txtWidth, txtHeight)
draw.Text(x + (width // 2) - (txtWidth // 2), y + (height // 2) - (txtHeight // 2), label)
function ImMenu.Checkbox(text, state)
local boxSize = txtHeight + Style.Spacing * 2
local width, height = ImMenu.GetSize(boxSize + Style.Spacing + txtWidth, boxSize)
local hovered, clicked, active = ImMenu.GetInteraction(x, y, width, height, text)
ImMenu.InteractionColor(hovered, active)
draw.FilledRect(x, y, x + boxSize, y + boxSize)
if Style.CheckboxBorder then
draw.Color(UnpackColor(Colors.Border))
draw.OutlinedRect(x, y, x + boxSize, y + boxSize)
draw.Color(UnpackColor(Colors.Highlight))
draw.FilledRect(x + Style.Spacing, y + Style.Spacing, x + (boxSize - Style.Spacing), y + (boxSize - Style.Spacing))
draw.Color(UnpackColor(Colors.Text))
draw.Text(x + boxSize + Style.Spacing, y + (height // 2) - (txtHeight // 2), label)
state = not state
return state, clicked
function ImMenu.Button(text)
local width, height = ImMenu.GetSize(txtWidth + Style.Spacing * 2, txtHeight + Style.Spacing * 2)
draw.FilledRect(x, y, x + width, y + height)
if Style.ButtonBorder then
draw.OutlinedRect(x, y, x + width, y + height)
return clicked, active
function ImMenu.Texture(id)
local width, height = ImMenu.GetSize(draw.GetTextureSize(id))
draw.TexturedRect(id, x, y, x + width, y + height)
if Style.Border then
function ImMenu.Slider(text, value, min, max, step)
step = step or 1
local label = string.format("%s: %s", ImMenu.GetLabel(text), value)
local width, height = ImMenu.GetSize(250, txtHeight + Style.Spacing * 2)
local sliderWidth = math.floor(width * (value - min) / (max - min))
draw.FilledRect(x, y, x + sliderWidth, y + height)
if Style.SliderBorder then
local percent = math.clamp((mX - x) / width, 0, 1)
value = math.round((min + (max - min) * percent) / step) * step
if LeftArrow:Pressed() then
value = math.max(value - step, min)
elseif RightArrow:Pressed() then
value = math.min(value + step, max)
return value, clicked
function ImMenu.Progress(value, min, max)
local width, height = ImMenu.GetSize(250, 15)
local progressWidth = math.floor(width * (value - min) / (max - min))
draw.FilledRect(x, y, x + progressWidth, y + height)
function ImMenu.Option(selected, options)
local txtWidth, txtHeight = draw.GetTextSize("#")
local btnSize = txtHeight + 2 * Style.Spacing
local width, height = ImMenu.GetSize(250, txtHeight)
ImMenu.PushStyle("ItemSize", { btnSize, btnSize })
ImMenu.PushStyle("FramePadding", 0)
ImMenu.BeginFrame(1)
if ImMenu.Button("<###" .. tostring(options)) then
selected = ((selected - 2) % #options) + 1
ImMenu.PushStyle("ItemSize", { width - (2 * btnSize) - (2 * Style.Spacing), height })
ImMenu.Text(tostring(options[selected]))
if ImMenu.Button(">###" .. tostring(options)) then
selected = (selected % #options) + 1
ImMenu.PopStyle(2)
return selected
function ImMenu.List(text, items)
local txtWidth, txtHeight = draw.GetTextSize(text)
ImMenu.PushStyle("ItemSize", { width, height })
ImMenu.Text(text)
for _, item in ipairs(items) do
ImMenu.Button(tostring(item))
function ImMenu.TabControl(tabs, currentTab)
ImMenu.PushStyle("ItemSize", { 100, 25 })
ImMenu.PushStyle("Spacing", 0)
for i, item in ipairs(tabs) do
if ImMenu.Button(tostring(item)) then
currentTab = i
ImMenu.PopStyle(3)
return currentTab
lnxLib.UI.Notify.Simple("ImMenu loaded", string.format("Version: %.2f", ImMenu.GetVersion()))
return ImMenu
Infinite Food automation
Credits: Baan
Dependencies: LNXlib (github.com/lnx00/Lmaobox-Library)
local libLoaded, Lib = pcall(require, "LNXlib")
assert(Lib.GetVersion() >= 0.89, "LNXlib version is too old, please update it!")
local KeyHelper, Timer, WPlayer = Lib.Utils.KeyHelper, Lib.Utils.Timer, Lib.TF2.WPlayer
local key = KeyHelper.new(KEY_J)
local tauntTimer = Timer.new()
local function OnUserCmd(userCmd)
local localPlayer = WPlayer.GetLocal()
if not localPlayer:IsAlive()
or not key:Down()
or engine.IsGameUIVisible()
then return end
local weapon = localPlayer:GetActiveWeapon()
if weapon:IsShootingWeapon() or weapon:IsMeleeWeapon() then return end
userCmd:SetButtons(userCmd:GetButtons() | IN_ATTACK)
if tauntTimer:Run(0.5) then
client.Command("taunt", true)
callbacks.Unregister("CreateMove", "LNX_IF_UserCmd")
callbacks.Register("CreateMove", "LNX_IF_UserCmd", OnUserCmd)
local __bundle_require, __bundle_loaded, __bundle_register, __bundle_modules = (function(superRequire)
local loadingPlaceholder = {[{}] = true}
local register
local modules = {}
local require
local loaded = {}
register = function(name, body)
if not modules[name] then
modules[name] = body
require = function(name)
local loadedModule = loaded[name]
if loadedModule then
if loadedModule == loadingPlaceholder then
if not superRequire then
local identifier = type(name) == 'string' and '\"' .. name .. '\"' or tostring(name)
error('Tried to require ' .. identifier .. ', but no such module has been registered')
return superRequire(name)
loaded[name] = loadingPlaceholder
loadedModule = modules[name](require, loaded, register, modules)
loaded[name] = loadedModule
return loadedModule
return require, loaded, register, modules
end)(require)
__bundle_register("__root", function(require, _LOADED, __bundle_register, __bundle_modules)
lnxLib - An utility library for Lmaobox
require("lnxLib/Global/Global")
local lnxLib = {
TF2 = require("lnxLib/TF2/TF2"),
UI = require("lnxLib/UI/UI"),
Utils = require("lnxLib/Utils/Utils"),
function lnxLib.GetVersion()
return 0.969
function UnloadLib()
lnxLib.Utils.UnloadPackages("lnxLib")
lnxLib.Utils.UnloadPackages("LNXlib")
printc(75, 210, 55, 255, string.format("lnxLib Loaded (v%.3f)", lnxLib.GetVersion()))
lnxLib.UI.Notify.Simple("lnxLib loaded", string.format("Version: %.3f", lnxLib.GetVersion()))
Internal.Cleanup()
return lnxLib
__bundle_register("lnxLib/Utils/Utils", function(require, _LOADED, __bundle_register, __bundle_modules)
local Utils = {
Conversion = require("lnxLib/Utils/Conversion"),
FileSystem = require("lnxLib/Utils/FileSystem"),
Web = require("lnxLib/Utils/Web"),
Input = require("lnxLib/Utils/Input"),
KeyHelper = require("lnxLib/Utils/KeyHelper"),
KeyValues = require("lnxLib/Utils/KeyValues"),
Logger = require("lnxLib/Utils/Logger"),
Math = require("lnxLib/Utils/Math"),
Timer = require("lnxLib/Utils/Timer"),
Config = require("lnxLib/Utils/Config"),
Commands = require("lnxLib/Utils/Commands")
function Utils.Sanitize(str)
str = string.gsub(str, "[%p%c]", "")
str = string.gsub(str, '"', "'")
return str
function Utils.Rainbow(offset)
local r = math.floor(math.sin(offset + 0) * 127 + 128)
local g = math.floor(math.sin(offset + 2) * 127 + 128)
local b = math.floor(math.sin(offset + 4) * 127 + 128)
return r, g, b
function Utils.UnloadPackages(libName)
local unloadCount = 0
for name, _ in pairs(package.loaded) do
if string.find(name, libName) then
print(string.format("Unloading package '%s'...", name))
package.loaded[name] = nil
unloadCount = unloadCount + 1
warn(string.format("All packages of '%s' have been unloaded!", libName))
return unloadCount
return Utils
__bundle_register("lnxLib/Utils/Commands", function(require, _LOADED, __bundle_register, __bundle_modules)
Custom Console Commands
local Commands = {
_Commands = {}
function Commands.Register(name, callback)
if Commands._Commands[name] ~= nil then
warn(string.format("Command '%s' already exists and will be overwritten!", name))
Commands._Commands[name] = callback
function Commands.Unregister(name)
Commands._Commands[name] = nil
local function OnStringCmd(stringCmd)
local args = Deque.new(string.split(stringCmd:Get(), " "))
local cmd = args:popFront()
if Commands._Commands[cmd] then
stringCmd:Set("")
Commands._Commands[cmd](args)
Internal.RegisterCallback("SendStringCmd", OnStringCmd, "Utils", "Commands")
return Commands
__bundle_register("lnxLib/Utils/Config", function(require, _LOADED, __bundle_register, __bundle_modules)
local FileSystem = require("lnxLib/Utils/FileSystem")
local Json = require("lnxLib/Libs/dkjson")
local Config = {
_Name = "",
_Content = {},
AutoSave = true,
AutoLoad = false
Config.__index = Config
setmetatable(Config, Config)
local ConfigExtension = ".cfg"
local ConfigFolder = FileSystem.GetWorkDir() .. "/Configs/"
function Config.new(name)
local self = setmetatable({}, Config)
self._Name = name
self._Content = {}
self.AutoSave = true
self.AutoLoad = false
self:Load()
return self
function Config:GetPath()
if not FileSystem.Exists(ConfigFolder) then
filesystem.CreateDirectory(ConfigFolder)
return ConfigFolder .. self._Name .. ConfigExtension
function Config:Load()
local configPath = self:GetPath()
if not FileSystem.Exists(configPath) then return false end
local content = FileSystem.Read(self:GetPath())
self._Content = Json.decode(content, 1, nil)
return self._Content ~= nil
function Config:Delete()
return FileSystem.Delete(configPath)
function Config:Save()
local content = Json.encode(self._Content, { indent = true })
return FileSystem.Write(self:GetPath(), content)
function Config:SetValue(key, value)
if self.AutoLoad then self:Load() end
self._Content[key] = value
if self.AutoSave then self:Save() end
function Config:GetValue(key, default)
local value = self._Content[key]
if value == nil then return default end
return value
return Config
__bundle_register("lnxLib/Libs/dkjson", function(require, _LOADED, __bundle_register, __bundle_modules)
local register_global_module_table = false
local global_module_name = 'json'
David Kolf's JSON module for Lua 5.1 - 5.4
Version 2.6
For the documentation see the corresponding readme.txt or visit
<http://dkolf.de/src/dkjson-lua.fsl/>.
You can contact the author by sending an e-mail to 'david' at the
domain 'dkolf.de'.
Copyright (C) 2010-2021 David Heiko Kolf
Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:
The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
local pairs, type, tostring, tonumber, getmetatable, setmetatable, rawset =
pairs, type, tostring, tonumber, getmetatable, setmetatable, rawset
local error, require, pcall, select = error, require, pcall, select
local floor, huge = math.floor, math.huge
local strrep, gsub, strsub, strbyte, strchar, strfind, strlen, strformat =
string.rep, string.gsub, string.sub, string.byte, string.char,
string.find, string.len, string.format
local strmatch = string.match
local concat = table.concat
local json = { version = "dkjson 2.6" }
local jsonlpeg = {}
if register_global_module_table then
_G[global_module_name] = json
local _ENV = nil
pcall (function()
json.null = setmetatable ({}, {
__tojson = function () return "null" end
local function isarray (tbl)
local max, n, arraylen = 0, 0, 0
for k,v in pairs (tbl) do
if k == 'n' and type(v) == 'number' then
arraylen = v
if v > max then
max = v
if type(k) ~= 'number' or k < 1 or floor(k) ~= k then
if k > max then
max = k
n = n + 1
if max > 10 and max > arraylen and max > n * 2 then
return true, max
local escapecodes = {
["\""] = "\\\"", ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f",
["\n"] = "\\n",  ["\r"] = "\\r",  ["\t"] = "\\t"
local function escapeutf8 (uchar)
local value = escapecodes[uchar]
if value then
local a, b, c, d = strbyte (uchar, 1, 4)
a, b, c, d = a or 0, b or 0, c or 0, d or 0
if a <= 0x7f then
value = a
elseif 0xc0 <= a and a <= 0xdf and b >= 0x80 then
value = (a - 0xc0) * 0x40 + b - 0x80
elseif 0xe0 <= a and a <= 0xef and b >= 0x80 and c >= 0x80 then
value = ((a - 0xe0) * 0x40 + b - 0x80) * 0x40 + c - 0x80
elseif 0xf0 <= a and a <= 0xf7 and b >= 0x80 and c >= 0x80 and d >= 0x80 then
value = (((a - 0xf0) * 0x40 + b - 0x80) * 0x40 + c - 0x80) * 0x40 + d - 0x80
return ""
if value <= 0xffff then
return strformat ("\\u%.4x", value)
elseif value <= 0x10ffff then
value = value - 0x10000
local highsur, lowsur = 0xD800 + floor (value/0x400), 0xDC00 + (value % 0x400)
return strformat ("\\u%.4x\\u%.4x", highsur, lowsur)
local function fsub (str, pattern, repl)
if strfind (str, pattern) then
return gsub (str, pattern, repl)
local function quotestring (value)
value = fsub (value, "[%z\1-\31\"\\\127]", escapeutf8)
if strfind (value, "[\194\216\220\225\226\239]") then
value = fsub (value, "\194[\128-\159\173]", escapeutf8)
value = fsub (value, "\216[\128-\132]", escapeutf8)
value = fsub (value, "\220\143", escapeutf8)
value = fsub (value, "\225\158[\180\181]", escapeutf8)
value = fsub (value, "\226\128[\140-\143\168-\175]", escapeutf8)
value = fsub (value, "\226\129[\160-\175]", escapeutf8)
value = fsub (value, "\239\187\191", escapeutf8)
value = fsub (value, "\239\191[\176-\191]", escapeutf8)
return "\"" .. value .. "\""
json.quotestring = quotestring
local function replace(str, o, n)
local i, j = strfind (str, o, 1, true)
if i then
return strsub(str, 1, i-1) .. n .. strsub(str, j+1, -1)
local decpoint, numfilter
local function updatedecpoint ()
decpoint = strmatch(tostring(0.5), "([^05+])")
numfilter = "[^0-9%-%+eE" .. gsub(decpoint, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0") .. "]+"
updatedecpoint()
local function num2str (num)
return replace(fsub(tostring(num), numfilter, ""), decpoint, ".")
local function str2num (str)
local num = tonumber(replace(str, ".", decpoint))
if not num then
num = tonumber(replace(str, ".", decpoint))
return num
local function addnewline2 (level, buffer, buflen)
buffer[buflen+1] = "\n"
buffer[buflen+2] = strrep ("  ", level)
buflen = buflen + 2
return buflen
function json.addnewline (state)
if state.indent then
state.bufferlen = addnewline2 (state.level or 0,
state.buffer, state.bufferlen or #(state.buffer))
local encode2
local function addpair (key, value, prev, indent, level, buffer, buflen, tables, globalorder, state)
local kt = type (key)
if kt ~= 'string' and kt ~= 'number' then
return nil, "type '" .. kt .. "' is not supported as a key by JSON."
if prev then
buflen = buflen + 1
buffer[buflen] = ","
if indent then
buflen = addnewline2 (level, buffer, buflen)
buffer[buflen+1] = quotestring (key)
buffer[buflen+2] = ":"
return encode2 (value, indent, level, buffer, buflen + 2, tables, globalorder, state)
local function appendcustom(res, buffer, state)
local buflen = state.bufferlen
if type (res) == 'string' then
buffer[buflen] = res
local function exception(reason, value, state, buffer, buflen, defaultmessage)
defaultmessage = defaultmessage or reason
local handler = state.exception
if not handler then
return nil, defaultmessage
state.bufferlen = buflen
local ret, msg = handler (reason, value, state, defaultmessage)
if not ret then return nil, msg or defaultmessage end
return appendcustom(ret, buffer, state)
function json.encodeexception(reason, value, state, defaultmessage)
return quotestring("<" .. defaultmessage .. ">")
encode2 = function (value, indent, level, buffer, buflen, tables, globalorder, state)
local valtype = type (value)
local valmeta = getmetatable (value)
valmeta = type (valmeta) == 'table' and valmeta
local valtojson = valmeta and valmeta.__tojson
if valtojson then
if tables[value] then
return exception('reference cycle', value, state, buffer, buflen)
tables[value] = true
local ret, msg = valtojson (value, state)
if not ret then return exception('custom encoder failed', value, state, buffer, buflen, msg) end
tables[value] = nil
buflen = appendcustom(ret, buffer, state)
elseif value == nil then
buffer[buflen] = "null"
elseif valtype == 'number' then
local s
if value ~= value or value >= huge or -value >= huge then
s = "null"
s = num2str (value)
buffer[buflen] = s
elseif valtype == 'boolean' then
buffer[buflen] = value and "true" or "false"
elseif valtype == 'string' then
buffer[buflen] = quotestring (value)
elseif valtype == 'table' then
level = level + 1
local isa, n = isarray (value)
if n == 0 and valmeta and valmeta.__jsontype == 'object' then
isa = false
local msg
if isa then
buffer[buflen] = "["
for i = 1, n do
buflen, msg = encode2 (value[i], indent, level, buffer, buflen, tables, globalorder, state)
if not buflen then return nil, msg end
if i < n then
buffer[buflen] = "]"
local prev = false
buffer[buflen] = "{"
local order = valmeta and valmeta.__jsonorder or globalorder
if order then
local used = {}
n = #order
local k = order[i]
local v = value[k]
if v ~= nil then
used[k] = true
buflen, msg = addpair (k, v, prev, indent, level, buffer, buflen, tables, globalorder, state)
prev = true
for k,v in pairs (value) do
if not used[k] then
buflen = addnewline2 (level - 1, buffer, buflen)
buffer[buflen] = "}"
return exception ('unsupported type', value, state, buffer, buflen,
"type '" .. valtype .. "' is not supported by JSON.")
function json.encode (value, state)
state = state or {}
local oldbuffer = state.buffer
local buffer = oldbuffer or {}
state.buffer = buffer
local ret, msg = encode2 (value, state.indent, state.level or 0,
buffer, state.bufferlen or 0, state.tables or {}, state.keyorder, state)
if not ret then
error (msg, 2)
elseif oldbuffer == buffer then
state.bufferlen = ret
state.bufferlen = nil
state.buffer = nil
return concat (buffer)
local function loc (str, where)
local line, pos, linepos = 1, 1, 0
while true do
pos = strfind (str, "\n", pos, true)
if pos and pos < where then
line = line + 1
linepos = pos
pos = pos + 1
return "line " .. line .. ", column " .. (where - linepos)
local function unterminated (str, what, where)
return nil, strlen (str) + 1, "unterminated " .. what .. " at " .. loc (str, where)
local function scanwhite (str, pos)
pos = strfind (str, "%S", pos)
if not pos then return nil end
local sub2 = strsub (str, pos, pos + 1)
if sub2 == "\239\187" and strsub (str, pos + 2, pos + 2) == "\191" then
pos = pos + 3
elseif sub2 == "//" then
pos = strfind (str, "[\n\r]", pos + 2)
elseif sub2 == "/*" then
pos = strfind (str, "*/", pos + 2)
pos = pos + 2
return pos
local escapechars = {
["\""] = "\"", ["\\"] = "\\", ["/"] = "/", ["b"] = "\b", ["f"] = "\f",
["n"] = "\n", ["r"] = "\r", ["t"] = "\t"
local function unichar (value)
if value < 0 then
elseif value <= 0x007f then
return strchar (value)
elseif value <= 0x07ff then
return strchar (0xc0 + floor(value/0x40),
0x80 + (floor(value) % 0x40))
elseif value <= 0xffff then
return strchar (0xe0 + floor(value/0x1000),
0x80 + (floor(value/0x40) % 0x40),
return strchar (0xf0 + floor(value/0x40000),
0x80 + (floor(value/0x1000) % 0x40),
local function scanstring (str, pos)
local lastpos = pos + 1
local buffer, n = {}, 0
local nextpos = strfind (str, "[\"\\]", lastpos)
if not nextpos then
return unterminated (str, "string", pos)
if nextpos > lastpos then
buffer[n] = strsub (str, lastpos, nextpos - 1)
if strsub (str, nextpos, nextpos) == "\"" then
lastpos = nextpos + 1
local escchar = strsub (str, nextpos + 1, nextpos + 1)
local value
if escchar == "u" then
value = tonumber (strsub (str, nextpos + 2, nextpos + 5), 16)
local value2
if 0xD800 <= value and value <= 0xDBff then
if strsub (str, nextpos + 6, nextpos + 7) == "\\u" then
value2 = tonumber (strsub (str, nextpos + 8, nextpos + 11), 16)
if value2 and 0xDC00 <= value2 and value2 <= 0xDFFF then
value = (value - 0xD800)  * 0x400 + (value2 - 0xDC00) + 0x10000
value2 = nil
value = value and unichar (value)
if value2 then
lastpos = nextpos + 12
lastpos = nextpos + 6
if not value then
value = escapechars[escchar] or escchar
lastpos = nextpos + 2
buffer[n] = value
if n == 1 then
return buffer[1], lastpos
elseif n > 1 then
return concat (buffer), lastpos
return "", lastpos
local scanvalue
local function scantable (what, closechar, str, startpos, nullval, objectmeta, arraymeta)
local len = strlen (str)
local tbl, n = {}, 0
local pos = startpos + 1
if what == 'object' then
setmetatable (tbl, objectmeta)
setmetatable (tbl, arraymeta)
pos = scanwhite (str, pos)
if not pos then return unterminated (str, what, startpos) end
local char = strsub (str, pos, pos)
if char == closechar then
return tbl, pos + 1
local val1, err
val1, pos, err = scanvalue (str, pos, nullval, objectmeta, arraymeta)
if err then return nil, pos, err end
char = strsub (str, pos, pos)
if char == ":" then
if val1 == nil then
return nil, pos, "cannot use nil as table index (at " .. loc (str, pos) .. ")"
pos = scanwhite (str, pos + 1)
local val2
val2, pos, err = scanvalue (str, pos, nullval, objectmeta, arraymeta)
tbl[val1] = val2
tbl[n] = val1
if char == "," then
scanvalue = function (str, pos, nullval, objectmeta, arraymeta)
pos = pos or 1
if not pos then
return nil, strlen (str) + 1, "no valid JSON value (reached the end)"
if char == "{" then
return scantable ('object', "}", str, pos, nullval, objectmeta, arraymeta)
elseif char == "[" then
return scantable ('array', "]", str, pos, nullval, objectmeta, arraymeta)
elseif char == "\"" then
return scanstring (str, pos)
local pstart, pend = strfind (str, "^%-?[%d%.]+[eE]?[%+%-]?%d*", pos)
if pstart then
local number = str2num (strsub (str, pstart, pend))
if number then
return number, pend + 1
pstart, pend = strfind (str, "^%a%w*", pos)
local name = strsub (str, pstart, pend)
if name == "true" then
return true, pend + 1
elseif name == "false" then
return false, pend + 1
elseif name == "null" then
return nullval, pend + 1
return nil, pos, "no valid JSON value at " .. loc (str, pos)
local function optionalmetatables(...)
if select("#", ...) > 0 then
return ...
return {__jsontype = 'object'}, {__jsontype = 'array'}
function json.decode (str, pos, nullval, ...)
local objectmeta, arraymeta = optionalmetatables(...)
return scanvalue (str, pos, nullval, objectmeta, arraymeta)
return json
__bundle_register("lnxLib/Utils/FileSystem", function(require, _LOADED, __bundle_register, __bundle_modules)
Filesystem Utils
local FileSystem = {}
local WorkDir = engine.GetGameDir() .. "/../lnxLib/"
function FileSystem.Read(path)
local file = io.open(path, "rb")
if not file then return nil end
local content = file:read "*a"
file:close()
return content
function FileSystem.Write(path, content)
local file = io.open(path, "wb")
if not file then return false end
file:write(content)
function FileSystem.Delete(path)
return os.remove(path)
function FileSystem.Exists(path)
if file then file:close() end
return file ~= nil
function FileSystem.GetWorkDir()
if not FileSystem.Exists(WorkDir) then
filesystem.CreateDirectory(WorkDir)
return WorkDir
return FileSystem
__bundle_register("lnxLib/Utils/Timer", function(require, _LOADED, __bundle_register, __bundle_modules)
local Timer = {
_LastTime = 0
Timer.__index = Timer
setmetatable(Timer, Timer)
function Timer.new()
local self = setmetatable({}, Timer)
self._LastTime = 0
function Timer:_Check(delta)
return globals.CurTime() - self._LastTime >= delta
function Timer:Run(interval)
if (self:_Check(interval)) then
self._LastTime = globals.CurTime()
return Timer
__bundle_register("lnxLib/Utils/Math", function(require, _LOADED, __bundle_register, __bundle_modules)
Math Functions
local Math = {}
local M_RADPI = 180 / math.pi
local function isNaN(x) return x ~= x end
function Math.NormalizeAngle(angle)
if angle > 180 then
angle = angle - 360
elseif angle < -180 then
angle = angle + 360
return angle
function Math.RemapValClamped(val, A, B, C, D)
if A == B then
return val >= B and D or C
local cVal = (val - A) / (B - A)
cVal = math.clamp(cVal, 0, 1)
return C + (D - C) * cVal
function Math.PositionAngles(source, dest)
local delta = source - dest
local pitch = math.atan(delta.z / delta:Length2D()) * M_RADPI
local yaw = math.atan(delta.y / delta.x) * M_RADPI
if delta.x >= 0 then
yaw = yaw + 180
if isNaN(pitch) then pitch = 0 end
if isNaN(yaw) then yaw = 0 end
return EulerAngles(pitch, yaw, 0)
function Math.AngleFov(vFrom, vTo)
local vSrc = vFrom:Forward()
local vDst = vTo:Forward()
local fov = math.deg(math.acos(vDst:Dot(vSrc) / vDst:LengthSqr()))
if isNaN(fov) then fov = 0 end
return fov
return Math
__bundle_register("lnxLib/Utils/Logger", function(require, _LOADED, __bundle_register, __bundle_modules)
Logging utility
local Logger = {
Name = "",
Level = 1
Logger.__index = Logger
setmetatable(Logger, Logger)
function Logger.new(name)
local self = setmetatable({}, Logger)
self.Name = name
self.Level = 1
local logModes = {
["Debug"] = { Color = { 165, 175, 190 }, Level = 0 },
["Info"] = { Color = { 15, 185, 180 }, Level = 1 },
["Warn"] = { Color = { 225, 175, 45 }, Level = 2 },
["Error"] = { Color = { 230, 65, 25 }, Level = 3 }
for mode, data in pairs(logModes) do
rawset(Logger, mode, function(self, ...)
if data.Level < self.Level then return end
local msg = string.format(...)
local r, g, b = table.unpack(data.Color)
local name = self.Name
local time = os.date("%H:%M:%S")
local logMsg = string.format("[%-6s%s] %s: %s", mode, time, name, msg)
printc(r, g, b, 255, logMsg)
return Logger
__bundle_register("lnxLib/Utils/KeyValues", function(require, _LOADED, __bundle_register, __bundle_modules)
KeyValues utils
local KeyValues = {}
local function SerializeKV(name, data, indent)
local bodyData = {}
for key, value in pairs(data) do
if type(value) == "table" then
table.insert(bodyData, SerializeKV(key, value, indent .. "\t"))
table.insert(bodyData, string.format("\t%s\"%s\"\t\"%s\"", indent, key, value))
local body = table.concat(bodyData, "\n")
return string.format("%s\"%s\"\n%s{\n%s\n%s}", indent, name, indent, body, indent)
function KeyValues.Serialize(name, data)
data = data or {}
return SerializeKV(name, data, "")
return KeyValues
__bundle_register("lnxLib/Utils/KeyHelper", function(require, _LOADED, __bundle_register, __bundle_modules)
local KeyHelper = {
Key = 0,
_LastState = false
KeyHelper.__index = KeyHelper
setmetatable(KeyHelper, KeyHelper)
function KeyHelper.new(key)
local self = setmetatable({}, KeyHelper)
self.Key = key
self._LastState = false
function KeyHelper:Down()
local isDown = input.IsButtonDown(self.Key)
return isDown
function KeyHelper:Pressed()
local shouldCheck = self._LastState == false
self._LastState = self:Down()
return self._LastState and shouldCheck
function KeyHelper:Released()
local shouldCheck = self._LastState == true
return self._LastState == false and shouldCheck
return KeyHelper
__bundle_register("lnxLib/Utils/Input", function(require, _LOADED, __bundle_register, __bundle_modules)
Input Utils
local Input = {}
local KeyNames = {
[KEY_SEMICOLON] = "SEMICOLON",
[KEY_APOSTROPHE] = "APOSTROPHE",
[KEY_BACKQUOTE] = "BACKQUOTE",
[KEY_COMMA] = "COMMA",
[KEY_PERIOD] = "PERIOD",
[KEY_SLASH] = "SLASH",
[KEY_BACKSLASH] = "BACKSLASH",
[KEY_MINUS] = "MINUS",
[KEY_EQUAL] = "EQUAL",
[KEY_ENTER] = "ENTER",
[KEY_SPACE] = "SPACE",
[KEY_BACKSPACE] = "BACKSPACE",
[KEY_TAB] = "TAB",
[KEY_CAPSLOCK] = "CAPSLOCK",
[KEY_NUMLOCK] = "NUMLOCK",
[KEY_ESCAPE] = "ESCAPE",
[KEY_SCROLLLOCK] = "SCROLLLOCK",
[KEY_INSERT] = "INSERT",
[KEY_DELETE] = "DELETE",
[KEY_HOME] = "HOME",
[KEY_END] = "END",
[KEY_PAGEUP] = "PAGEUP",
[KEY_PAGEDOWN] = "PAGEDOWN",
[KEY_BREAK] = "BREAK",
[KEY_LSHIFT] = "LSHIFT",
[KEY_RSHIFT] = "RSHIFT",
[KEY_LALT] = "LALT",
[KEY_RALT] = "RALT",
[KEY_LCONTROL] = "LCONTROL",
[KEY_RCONTROL] = "RCONTROL",
[KEY_UP] = "UP",
[KEY_LEFT] = "LEFT",
[KEY_DOWN] = "DOWN",
[KEY_RIGHT] = "RIGHT",
local KeyValues = {
[KEY_LBRACKET] = "[",
[KEY_RBRACKET] = "]",
[KEY_SEMICOLON] = ";",
[KEY_APOSTROPHE] = "'",
[KEY_BACKQUOTE] = "`",
[KEY_COMMA] = ",",
[KEY_PERIOD] = ".",
[KEY_SLASH] = "/",
[KEY_BACKSLASH] = "\\",
[KEY_MINUS] = "-",
[KEY_EQUAL] = "=",
[KEY_SPACE] = " ",
local function D(x) return x, x end
for i = 1, 10 do KeyNames[i], KeyValues[i] = D(tostring(i - 1)) end
for i = 11, 36 do KeyNames[i], KeyValues[i] = D(string.char(i + 54)) end
for i = 37, 46 do KeyNames[i], KeyValues[i] = "KP_" .. (i - 37), tostring(i - 37) end
for i = 92, 103 do KeyNames[i] = "F" .. (i - 91) end
function Input.GetKeyName(key)
return KeyNames[key]
function Input.KeyToChar(key)
return KeyValues[key]
function Input.CharToKey(char)
return table.find(KeyValues, string.upper(char))
function Input.GetPressedKey()
for i = KEY_FIRST, KEY_LAST do
if input.IsButtonDown(i) then return i end
function Input.GetPressedKeys()
local keys = {}
if input.IsButtonDown(i) then table.insert(keys, i) end
return keys
function Input.MouseInBounds(x, y, x2, y2)
local mx, my = table.unpack(input.GetMousePos())
return mx >= x and mx <= x2 and my >= y and my <= y2
return Input
__bundle_register("lnxLib/Utils/Web", function(require, _LOADED, __bundle_register, __bundle_modules)
Simple Web library using curl
local function S(str)
return "\"" .. str:gsub("\"", "'") .. "\""
local Web = {}
function Web.Download(url, path)
os.execute("curl -o " .. S(path) .. "
function Web.Get(url)
local handle = io.popen("curl -s -L " .. S(url) .. "")
if not handle then return nil end
local content = handle:read("*a")
handle:close()
function Web.Post(url, data)
local handle = io.popen("curl -s -L -d " .. S(data) .. " " .. S(url))
return Web
__bundle_register("lnxLib/Utils/Conversion", function(require, _LOADED, __bundle_register, __bundle_modules)
Conversion Utils
local Conversion = {}
function Conversion.ID3_to_ID64(steamID3)
if tonumber(steamID3) then
return tostring(tonumber(steamID3) + 0x110000100000000)
elseif steamID3:match("(%[U:1:%d+%])") then
return tostring(tonumber(steamID3:match("%[U:1:(%d+)%]")) + 0x110000100000000)
return false, "Invalid SteamID"
function Conversion.ID64_to_ID3(steamID64)
if not tonumber(steamID64) then
local steamID = tonumber(steamID64)
if (steamID - 0x110000100000000) < 0 then
return false, "Not a SteamID64"
return ("[U:1:%d]"):format(steamID - 0x110000100000000)
function Conversion.Hex_to_RGB(pHex)
local r = tonumber(string.sub(pHex, 1, 2), 16)
local g = tonumber(string.sub(pHex, 3, 4), 16)
local b = tonumber(string.sub(pHex, 5, 6), 16)
function Conversion.RGB_to_Hex(r, g, b)
return string.format("%02x%02x%02x", r, g, b)
function Conversion.HSV_to_RGB(h, s, v)
local r, g, b
local i = math.floor(h * 6);
local f = h * 6 - i;
local p = v * (1 - s);
local q = v * (1 - f * s);
local t = v * (1 - (1 - f) * s);
i = i % 6
if i == 0 then
r, g, b = v, t, p
elseif i == 1 then
r, g, b = q, v, p
elseif i == 2 then
r, g, b = p, v, t
elseif i == 3 then
r, g, b = p, q, v
elseif i == 4 then
r, g, b = t, p, v
elseif i == 5 then
r, g, b = v, p, q
return math.floor(r * 255), math.floor(g * 255), math.floor(b * 255)
function Conversion.RGB_to_HSV(r, g, b)
r, g, b = r / 255, g / 255, b / 255
local max, min = math.max(r, g, b), math.min(r, g, b)
local h, s, v
v = max
local d = max - min
if max == 0 then
s = 0
s = d / max
if max == min then
h = 0
if max == r then
h = (g - b) / d
if g < b then
h = h + 6
elseif max == g then
h = (b - r) / d + 2
elseif max == b then
h = (r - g) / d + 4
h = h / 6
return h, s, v
function Conversion.Time_to_Ticks(time)
return math.floor(0.5 + time / globals.TickInterval())
function Conversion.Ticks_to_Time(ticks)
return ticks * globals.TickInterval()
return Conversion
__bundle_register("lnxLib/UI/UI", function(require, _LOADED, __bundle_register, __bundle_modules)
local UI = {
Fonts = require("lnxLib/UI/Fonts"),
Textures = require("lnxLib/UI/Textures"),
Notify = require("lnxLib/UI/Notify")
return UI
__bundle_register("lnxLib/UI/Notify", function(require, _LOADED, __bundle_register, __bundle_modules)
UI Notifications
A notification can have the following attributes:
Title, Content, Duration
local Fonts = require("lnxLib/UI/Fonts")
local Size = { W = 300, H = 50 }
local Offset = { X = 10, Y = 10 }
local Padding = { X = 10, Y = 10 }
local FadeTime = 0.3
local Notify = {}
local notifications = {}
local currentID = 0
function Notify.Push(data)
assert(type(data) == "table", "Notify.Push: data must be a table")
data.ID = currentID
data.Duration = data.Duration or 3
data.StartTime = globals.RealTime()
notifications[data.ID] = data
currentID = (currentID + 1) % 1000
return data.ID
function Notify.Alert(title, duration)
return Notify.Push({
Title = title,
Duration = duration
function Notify.Simple(title, msg, duration)
Content = msg,
function Notify.Pop(id)
local notification = notifications[id]
if notification then
notification.Duration = 0
local currentY = Offset.Y
for id, note in pairs(notifications) do
local deltaTime = globals.RealTime() - note.StartTime
if deltaTime > note.Duration then
notifications[id] = nil
local fadeStep = 1.0
if deltaTime < FadeTime then
fadeStep = deltaTime / FadeTime
elseif deltaTime > note.Duration - FadeTime then
fadeStep = (note.Duration - deltaTime) / FadeTime
local fadeAlpha = math.floor(fadeStep * 255)
currentY = currentY - math.floor((1 - fadeStep) * Size.H)
draw.Color(35, 50, 60, fadeAlpha)
draw.FilledRect(Offset.X, currentY, Offset.X + Size.W, currentY + Size.H)
local barWidth = math.floor(Size.W * (deltaTime / note.Duration))
draw.Color(255, 255, 255, 150)
draw.FilledRect(Offset.X, currentY, Offset.X + barWidth, currentY + 5)
draw.Color(245, 245, 245, fadeAlpha)
draw.SetFont(Fonts.SegoeTitle)
if note.Title then
draw.Text(Offset.X + Padding.X, currentY + Padding.Y, note.Title)
draw.SetFont(Fonts.Segoe)
if note.Content then
draw.Text(Offset.X + Padding.X, currentY + Padding.Y + 20, note.Content)
currentY = currentY + Size.H + Offset.Y
Internal.RegisterCallback("Draw", OnDraw, "UI", "Notify")
return Notify
__bundle_register("lnxLib/UI/Fonts", function(require, _LOADED, __bundle_register, __bundle_modules)
local Fonts = table.readOnly {
Verdana = draw.CreateFont("Verdana", 14, 510),
Segoe = draw.CreateFont("Segoe UI", 14, 510),
SegoeTitle = draw.CreateFont("Segoe UI", 24, 700),
return Fonts
__bundle_register("lnxLib/UI/Textures", function(require, _LOADED, __bundle_register, __bundle_modules)
local Textures = {}
local byteMap = {}
for i = 0, 255 do byteMap[i] = string.char(i) end
local textureCache = {}
local r, g, b, a = table.unpack(color)
a = a or 255
return r, g, b, a
local function UnpackSize(size)
local w, h = table.unpack(size)
w, h = w or 256, h or 256
return w, h
local function GetTextureID(name, ...)
return table.concat({name, ...})
local function CreateTexture(id, width, height, data)
local binaryData = table.concat(data)
local texture = draw.CreateTextureRGBA(binaryData, width, height)
textureCache[id] = texture
return texture
function Textures.LinearGradient(startColor, endColor, size)
local sR, sG, sB, sA = UnpackColor(startColor)
local eR, eG, eB, eA = UnpackColor(endColor)
local w, h = UnpackSize(size)
local id = GetTextureID("LG", sR, sG, sB, sA, eR, eG, eB, eA, w, h)
local cache = textureCache[id]
if cache then return cache end
local dataSize = w * h * 4
local data, bm = {}, byteMap
local i = 1
while i < dataSize do
local idx = (i / 4)
local x, y = idx % w, idx // w
data[i] = bm[sR + (eR - sR) * x // w]
data[i + 1] = bm[sG + (eG - sG) * y // h]
data[i + 2] = bm[sB + (eB - sB) * x // w]
data[i + 3] = bm[sA + (eA - sA) * y // h]
i = i + 4
return CreateTexture(id, w, h, data)
function Textures.Circle(radius, color)
local r, g, b, a = UnpackColor(color)
local id = GetTextureID("C", r, g, b, a, radius)
local diameter = radius * 2
local dataSize = diameter * diameter * 4
local x, y = idx % diameter, idx // diameter
local dx, dy = x - radius, y - radius
local dist = math.sqrt(dx * dx + dy * dy)
if dist <= radius then
data[i] = bm[r]
data[i + 1] = bm[g]
data[i + 2] = bm[b]
data[i + 3] = bm[a]
data[i] = bm[0]
data[i + 1] = bm[0]
data[i + 2] = bm[0]
data[i + 3] = bm[0]
return CreateTexture(id, diameter, diameter, data)
return Textures
__bundle_register("lnxLib/TF2/TF2", function(require, _LOADED, __bundle_register, __bundle_modules)
local TF2 = {
Helpers = require("lnxLib/TF2/Helpers"),
Globals = require("lnxLib/TF2/Globals"),
WPlayer = require("lnxLib/TF2/Wrappers/WPlayer"),
WEntity = require("lnxLib/TF2/Wrappers/WEntity"),
WWeapon = require("lnxLib/TF2/Wrappers/WWeapon"),
WPlayerResource = require("lnxLib/TF2/Wrappers/WPlayerResource")
function TF2.Exit()
os.exit()
return TF2
__bundle_register("lnxLib/TF2/Wrappers/WPlayerResource", function(require, _LOADED, __bundle_register, __bundle_modules)
Wrapper Class for Wepaon Entities
local WEntity = require("lnxLib/TF2/Wrappers/WEntity")
local WPlayerResource = {}
WPlayerResource.__index = WPlayerResource
setmetatable(WPlayerResource, WEntity)
function WPlayerResource.FromEntity(entity)
assert(entity, "WPlayerResource.FromEntity: entity is nil")
local self = setmetatable({}, WPlayerResource)
self:SetEntity(entity)
function WPlayerResource.Get()
local pr = entities.GetPlayerResources()
return pr ~= nil and WPlayerResource.FromEntity(pr) or nil
function WPlayerResource:GetPing(index)
return self:GetPropDataTableInt("m_iPing")[index + 1]
function WPlayerResource:GetScore(index)
return self:GetPropDataTableInt("m_iScore")[index + 1]
function WPlayerResource:GetDeaths(index)
return self:GetPropDataTableInt("m_iDeaths")[index + 1]
function WPlayerResource:GetConnected(index)
return self:GetPropDataTableBool("m_bConnected")[index + 1]
function WPlayerResource:GetTeam(index)
return self:GetPropDataTableInt("m_iTeam")[index + 1]
function WPlayerResource:GetAlive(index)
return self:GetPropDataTableBool("m_bAlive")[index + 1]
function WPlayerResource:GetHealth(index)
return self:GetPropDataTableInt("m_iHealth")[index + 1]
function WPlayerResource:GetAccountID(index)
return self:GetPropDataTableInt("m_iAccountID")[index + 1]
function WPlayerResource:GetValid(index)
return self:GetPropDataTableBool("m_bValid")[index + 1]
function WPlayerResource:GetUserID(index)
return self:GetPropDataTableInt("m_iUserID")[index + 1]
function WPlayerResource:GetTotalScore(index)
return self:GetPropDataTableInt("m_iTotalScore")[index + 1]
function WPlayerResource:GetMaxHealth(index)
return self:GetPropDataTableInt("m_iMaxHealth")[index + 1]
function WPlayerResource:GetMaxBuffedHealth(index)
return self:GetPropDataTableInt("m_iMaxBuffedHealth")[index + 1]
function WPlayerResource:GetPlayerClass(index)
return self:GetPropDataTableInt("m_iPlayerClass")[index + 1]
function WPlayerResource:GetArenaSpectator(index)
return self:GetPropDataTableBool("m_bArenaSpectator")[index + 1]
function WPlayerResource:GetActiveDominations(index)
return self:GetPropDataTableInt("m_iActiveDominations")[index + 1]
function WPlayerResource:GetNextRespawnTime(index)
return self:GetPropDataTableFloat("m_flNextRespawnTime")[index + 1]
function WPlayerResource:GetChargeLevel(index)
return self:GetPropDataTableInt("m_iChargeLevel")[index + 1]
function WPlayerResource:GetDamage(index)
return self:GetPropDataTableInt("m_iDamage")[index + 1]
function WPlayerResource:GetDamageAssist(index)
return self:GetPropDataTableInt("m_iDamageAssist")[index + 1]
function WPlayerResource:GetDamageBoss(index)
return self:GetPropDataTableInt("m_iDamageBoss")[index + 1]
function WPlayerResource:GetHealing(index)
return self:GetPropDataTableInt("m_iHealing")[index + 1]
function WPlayerResource:GetHealingAssist(index)
return self:GetPropDataTableInt("m_iHealingAssist")[index + 1]
function WPlayerResource:GetDamageBlocked(index)
return self:GetPropDataTableInt("m_iDamageBlocked")[index + 1]
function WPlayerResource:GetCurrencyCollected(index)
return self:GetPropDataTableInt("m_iCurrencyCollected")[index + 1]
function WPlayerResource:GetBonusPoints(index)
return self:GetPropDataTableInt("m_iBonusPoints")[index + 1]
function WPlayerResource:GetPlayerLevel(index)
return self:GetPropDataTableInt("m_iPlayerLevel")[index + 1]
function WPlayerResource:GetStreaks(index)
return self:GetPropDataTableInt("m_iStreaks")[index + 1]
function WPlayerResource:GetUpgradeRefundCredits(index)
return self:GetPropDataTableInt("m_iUpgradeRefundCredits")[index + 1]
function WPlayerResource:GetBuybackCredits(index)
return self:GetPropDataTableInt("m_iBuybackCredits")[index + 1]
function WPlayerResource:GetPartyLeaderRedTeamIndex(index)
return self:GetPropDataTableInt("m_iPartyLeaderRedTeamIndex")[index + 1]
function WPlayerResource:GetPartyLeaderBlueTeamIndex(index)
return self:GetPropDataTableInt("m_iPartyLeaderBlueTeamIndex")[index + 1]
function WPlayerResource:GetEventTeamStatus(index)
return self:GetPropDataTableInt("m_iEventTeamStatus")[index + 1]
function WPlayerResource:GetPlayerClassWhenKilled(index)
return self:GetPropDataTableInt("m_iPlayerClassWhenKilled")[index + 1]
function WPlayerResource:GetConnectionState(index)
return self:GetPropDataTableInt("m_iConnectionState")[index + 1]
function WPlayerResource:GetConnectTime(index)
return self:GetPropDataTableFloat("m_flConnectTime")[index + 1]
return WPlayerResource
__bundle_register("lnxLib/TF2/Wrappers/WEntity", function(require, _LOADED, __bundle_register, __bundle_modules)
Wrapper Class for Entities
local Helpers = require("lnxLib/TF2/Helpers")
local WEntity = {
Entity = nil
WEntity.__index = WEntity
setmetatable(WEntity, {
__index = function(self, key, ...)
return function(t, ...)
local entity = rawget(t, "Entity")
return entity[key](entity, ...)
function WEntity.FromEntity(entity)
assert(entity, "WEntity.FromEntity: entity is nil")
local self = setmetatable({}, WEntity)
function WEntity:SetEntity(entity)
self.Entity = entity
function WEntity:Unwrap()
return self.Entity
function WEntity:Equals(other)
return self:GetIndex() == other:GetIndex()
function WEntity:GetSimulationTime()
return self:GetPropFloat("m_flSimulationTime")
function WEntity:Extrapolate(t)
return self:GetAbsOrigin() + self:EstimateAbsVelocity() * t
function WEntity:IsVisible(fromEntity)
return Helpers.VisPos(self, fromEntity:GetAbsOrigin(), self:GetAbsOrigin())
return WEntity
__bundle_register("lnxLib/TF2/Helpers", function(require, _LOADED, __bundle_register, __bundle_modules)
Helpers
local Helpers = {}
local function ComputeMove(userCmd, a, b)
local cPitch, cYaw, cRoll = userCmd:GetViewAngles()
function Helpers.WalkTo(userCmd, localPlayer, destination)
local localPos = localPlayer:GetAbsOrigin()
local result = ComputeMove(userCmd, localPos, destination)
userCmd:SetForwardMove(result.x)
userCmd:SetSideMove(result.y)
function Helpers.CanShoot(weapon)
local lPlayer = entities.GetLocalPlayer()
if weapon:IsMeleeWeapon() then return false end
local nextPrimaryAttack = weapon:GetPropFloat("LocalActiveWeaponData", "m_flNextPrimaryAttack")
local nextAttack = lPlayer:GetPropFloat("bcc_localdata", "m_flNextAttack")
function Helpers.VisPos(target, from, to)
local trace = engine.TraceLine(from, to, MASK_SHOT | CONTENTS_GRATE)
return (trace.entity == target) or (trace.fraction > 0.99)
function Helpers.GetBBox(player)
local padding = Vector3(0, 0, 10)
local headPos = player:GetEyePos() + padding
local feetPos = player:GetAbsOrigin() - padding
local headScreenPos = client.WorldToScreen(headPos)
local feetScreenPos = client.WorldToScreen(feetPos)
if (not headScreenPos) or (not feetScreenPos) then return nil end
local height = math.abs(headScreenPos[2] - feetScreenPos[2])
local width = height * 0.6
return {
x = math.floor(headScreenPos[1] - width * 0.5),
y = math.floor(headScreenPos[2]),
w = math.floor(width),
h = math.floor(height)
return Helpers
__bundle_register("lnxLib/TF2/Wrappers/WWeapon", function(require, _LOADED, __bundle_register, __bundle_modules)
local WWeapon = {}
WWeapon.__index = WWeapon
setmetatable(WWeapon, WEntity)
function WWeapon.FromEntity(entity)
assert(entity, "WWeapon.FromEntity: entity is nil")
assert(entity:IsWeapon(), "WWeapon.FromEntity: entity is not a weapon")
local self = setmetatable({}, WWeapon)
function WWeapon:GetOwner()
return self:GetPropEntity("m_hOwner")
function WWeapon:GetDefIndex()
return self:GetPropInt("m_iItemDefinitionIndex")
return WWeapon
__bundle_register("lnxLib/TF2/Wrappers/WPlayer", function(require, _LOADED, __bundle_register, __bundle_modules)
Wrapper Class for Player Entities
local WWeapon = require("lnxLib/TF2/Wrappers/WWeapon")
local WPlayer = {}
WPlayer.__index = WPlayer
setmetatable(WPlayer, WEntity)
function WPlayer.FromEntity(entity)
assert(entity, "WPlayer.FromEntity: entity is nil")
assert(entity:IsPlayer(), "WPlayer.FromEntity: entity is not a player")
local self = setmetatable({}, WPlayer)
function WPlayer.GetLocal()
local lp = entities.GetLocalPlayer()
return lp ~= nil and WPlayer.FromEntity(lp) or nil
function WPlayer:IsOnGround()
local pFlags = self:GetPropInt("m_fFlags")
function WPlayer:GetActiveWeapon()
return WWeapon.FromEntity(self:GetPropEntity("m_hActiveWeapon"))
function WPlayer:GetObserverMode()
return self:GetPropInt("m_iObserverMode")
function WPlayer:GetObserverTarget()
return WPlayer.FromEntity(self:GetPropEntity("m_hObserverTarget"))
function WPlayer:GetHitboxPos(hitboxID)
local hitbox = self:GetHitboxes()[hitboxID]
if not hitbox then return Vector3(0, 0, 0) end
function WPlayer:GetViewOffset()
return self:GetPropVector("localdata", "m_vecViewOffset[0]")
function WPlayer:GetEyePos()
return self:GetAbsOrigin() + self:GetViewOffset()
function WPlayer:GetEyeAngles()
local angles = self:GetPropVector("tfnonlocaldata", "m_angEyeAngles[0]")
return EulerAngles(angles.x, angles.y, angles.z)
function WPlayer:GetViewPos()
local eyePos = self:GetEyePos()
local targetPos = eyePos + self:GetEyeAngles():Forward() * 8192
local trace = engine.TraceLine(eyePos, targetPos, MASK_SHOT)
return trace.endpos
return WPlayer
__bundle_register("lnxLib/TF2/Globals", function(require, _LOADED, __bundle_register, __bundle_modules)
Global variables for TF2
local Globals = {
LastCommandNumber = 0,
CommandNumber = 0
Globals.LastCommandNumber = Globals.CommandNumber
Globals.CommandNumber = userCmd.command_number
Internal.RegisterCallback("CreateMove", OnCreateMove, "TF2", "Globals")
return Globals
__bundle_register("lnxLib/Global/Global", function(require, _LOADED, __bundle_register, __bundle_modules)
require("lnxLib/Global/Extensions")
require("lnxLib/Global/Internal")
require("lnxLib/Global/Stack")
require("lnxLib/Global/Deque")
require("lnxLib/Global/DelayedCall")
__bundle_register("lnxLib/Global/DelayedCall", function(require, _LOADED, __bundle_register, __bundle_modules)
Delayed Calls
local delayedCalls = {}
function _G.DelayedCall(delay, func)
table.insert(delayedCalls, {
time = globals.RealTime() + delay,
func = func
local curTime = globals.RealTime()
for i, call in ipairs(delayedCalls) do
if curTime > call.time then
table.remove(delayedCalls, i)
call.func()
Internal.RegisterCallback("Draw", OnDraw, "DelayedCall")
__bundle_register("lnxLib/Global/Deque", function(require, _LOADED, __bundle_register, __bundle_modules)
Double ended queue data structure
Deque = {
_items = {},
_size = 0
Deque.__index = Deque
setmetatable(Deque, Deque)
function Deque.new(items)
local self = setmetatable({}, Deque)
self._items = items or {}
self._size = #self._items
function Deque:pushFront(item)
table.insert(self._items, 1, item)
self._size = self._size + 1
function Deque:pushBack(item)
self._items[self._size] = item
function Deque:popFront()
self._size = self._size - 1
return table.remove(self._items, 1)
function Deque:popBack()
return table.remove(self._items)
function Deque:peekFront()
return self._items[1]
function Deque:peekBack()
return self._items[self._size]
function Deque:empty()
return self._size == 0
function Deque:clear()
self._items = {}
self._size = 0
function Deque:size()
return self._size
function Deque:items()
return table.readOnly(self._items)
__bundle_register("lnxLib/Global/Stack", function(require, _LOADED, __bundle_register, __bundle_modules)
Stack data structure
Stack = {
Stack.__index = Stack
setmetatable(Stack, Stack)
function Stack.new(items)
local self = setmetatable({}, Stack)
function Stack:push(item)
function Stack:pop()
function Stack:peek()
function Stack:empty()
function Stack:clear()
function Stack:size()
function Stack:items()
__bundle_register("lnxLib/Global/Internal", function(require, _LOADED, __bundle_register, __bundle_modules)
Internal functions for the library.
local oldInternal = rawget(_G, "Internal")
_G.Internal = {}
function Internal.RegisterCallback(id, callback, ...)
local name = table.concat({"lnxLib", ..., id}, ".")
callbacks.Unregister(id, name)
callbacks.Register(id, name, callback)
function Internal.Cleanup()
_G.Internal = oldInternal
__bundle_register("lnxLib/Global/Extensions", function(require, _LOADED, __bundle_register, __bundle_modules)
Extensions for Lua
function math.clamp(n, low, high)
return math.min(math.max(n, low), high)
function math.round(n)
return math.floor(n + 0.5)
function math.lerp(a, b, t)
return a + (b - a) * t
function table.readOnly(t)
local proxy = {}
setmetatable(proxy, {
__index = t,
__newindex = function(u, k, v)
error("Attempt to modify read-only table", 2)
return proxy
function table.find(t, value)
for k, v in pairs(t) do
if v == value then return k end
function table.contains(t, value)
return table.find(t, value) ~= nil
function string.split(str, delimiter)
local result = {}
local from = 1
local delim_from, delim_to = string.find(str, delimiter, from)
while delim_from do
table.insert(result, string.sub(str, from, delim_from - 1))
from = delim_to + 1
delim_from, delim_to = string.find(str, delimiter, from)
table.insert(result, string.sub(str, from))
return result
return __bundle_require("__root")
local   ObserverMode    = {
None            = 0,
Deathcam        = 1,
FreezeCam       = 2,
Fixed           = 3,
FirstPerson     = 4,
ThirdPerson     = 5,
PointOfInterest = 6,
FreeRoaming     = 7
local Removals = {
["RTD Effects"] = false,
["HUD Texts"] = false
local Callouts = {
["Battle Cry Melee"] = false,
local autoswitch_options = {
["safe-mode"] = true,
["Self Defence"] = true,
["Auto-crit-refill"] = true,
["force Change"] = true,
local LastExtenFreeze = 0
local prTimer = 0
local flTimer = 0
local c2Timer = 0
local c2Timer2 = 0
local mfTimer = 0
local menu = MenuLib.Create("Misc Tools", MenuFlags.AutoSize)
local mAutoweapon       = menu:AddComponent(MenuLib.Checkbox("low health esp",      true))
local mWswitchoptions   = menu:AddComponent(MenuLib.MultiCombo("^Settings",             autoswitch_options, ItemFlags.FullWidth))
local mcrossbowhealth   = menu:AddComponent(MenuLib.Slider("crossbow min health",    1, 100, 92))
local mAutoWeaponDist   = menu:AddComponent(MenuLib.Slider("melee Switch Distance",    0, 400, 77))
menu:AddComponent(MenuLib.Button("Disable Weapon Sway", function()
end, ItemFlags.FullWidth))
local mRetryStunned     = menu:AddComponent(MenuLib.Checkbox("suicide when stunned",     true))
local WFlip             = menu:AddComponent(MenuLib.Checkbox("Auto Weapon Flip",       true))
local mMedicFinder      = menu:AddComponent(MenuLib.Checkbox("Medic Finder",           true))
local mLegitSpec        = menu:AddComponent(MenuLib.Checkbox("Legit when Spectated",   false))
local mLegitSpecFP      = menu:AddComponent(MenuLib.Checkbox("^Firstperson Only",      false))
local mLegJitter        = menu:AddComponent(MenuLib.Checkbox("Leg Jitter",             false))
local mRocketLines      = menu:AddComponent(MenuLib.Checkbox("Rocket Lines",           false))
local mExtendFreeze     = menu:AddComponent(MenuLib.Checkbox("inffinite spectator time", false))
local msandwitchex      = menu:AddComponent(MenuLib.Checkbox("inffinite sandwich exploid", false))
local mRetryLowHP       = menu:AddComponent(MenuLib.Checkbox("Retry When Low HP",      false))
local mRetryLowHPValue  = menu:AddComponent(MenuLib.Slider("Retry HP",                 1, 299, 30))
local mAutoFL           = menu:AddComponent(MenuLib.Checkbox("Auto Fake Latency",      false))
local mAutoFLDist       = menu:AddComponent(MenuLib.Slider("AFL Activation Distance",    100, 700, 530))
local mAutoFLFar        = menu:AddComponent(MenuLib.Slider("AFL Far Value",         0, 1000, 777))
local mAutoFLNear       = menu:AddComponent(MenuLib.Slider("AFL Close Value",        0, 1000, 477))
local mRandPingValue    = menu:AddComponent(MenuLib.Slider("Ping Randomness",          0, 15, 0))
local mRandLag          = menu:AddComponent(MenuLib.Checkbox("Random Fakelag",         false))
local mRandLagValue     = menu:AddComponent(MenuLib.Slider("Fakelag Randomness",       1, 200, 77))
local mRandLagMin       = menu:AddComponent(MenuLib.Slider("Fakelag Min",              1, 314, 247))
local mRandLagMax       = menu:AddComponent(MenuLib.Slider("Fakelag Max",              2, 315, 315))
local TempOptions = {}
local function ResetTempOptions()
for k, v in pairs(TempOptions) do
TempOptions[k].WasUsed = false
local function SetOptionTemp(option, value)
local guiValue = gui.GetValue(option)
if guiValue ~= value then
gui.SetValue(option, value)
TempOptions[option] = {
Value   = guiValue,
WasUsed = true    }
if TempOptions[option] ~= nil then
TempOptions[option].WasUsed = true
local function CheckTempOptions()
if not v.WasUsed then
gui.SetValue(k, v.Value)
TempOptions[k] = nil
ResetTempOptions()
local cmdButtons = pCmd:GetButtons()
if (pCmd.forwardmove == 0) and (pCmd.sidemove == 0)
and (vVelocity:Length2D() < 10) then
if pCmd.command_number % 2 == 0 then
pCmd:SetSideMove(9)
pCmd:SetSideMove(-9)
if mFastStop:GetValue() == true then
if (pLocal:IsAlive()) and (pCmd.forwardmove == 0)
and (pCmd.sidemove == 0)
and (vVelocity:Length2D() > 10) then
local fsx, fsy, fsz = vVelocity:Unpack()
print(fsx, fsy, fsz)
if (fsz < 0.01) then
pCmd:SetForwardMove(fsx)
pCmd:SetSideMove(fsy)
print("Success! X:" .. fsx .. " Y:" .. fsy .. " Z:" .. fsz)
if mRetryLowHP:GetValue() == true then
if (pLocal:IsAlive()) and (pLocal:GetHealth() > 0
and (pLocal:GetHealth()) <= mRetryLowHPValue:GetValue()) then
client.Command("retry", true)
if mExtendFreeze:GetValue() == true then
if (pLocal:IsAlive() == false) and (globals.RealTime() > (LastExtenFreeze + 2)) then
client.Command("extendfreeze", true)
LastExtenFreeze = globals.RealTime()
if mRandLag:GetValue() == true then
flTimer = flTimer +1
if (flTimer >= mRandLagValue:GetValue()) then
flTimer = 0
local randValue = math.random(mRandLagMin:GetValue(), mRandLagMax:GetValue())
gui.SetValue("fake lag value", randValue)
if mRandPingValue:GetValue() >= 1 then
prTimer = prTimer +1
if (prTimer >= mRandPingValue:GetValue() * 66) then
prTimer = 0
local prActive = gui.GetValue("ping reducer")
if (prActive == 0) then
gui.SetValue("ping reducer", 1)
elseif (prActive == 1) then
gui.SetValue("ping reducer", 0)
if mRemovals:IsSelected("RTD Effects") then
if CurrentRTD == "Cursed" then
pCmd:SetForwardMove(pCmd:GetForwardMove() * (-1))
pCmd:SetSideMove(pCmd:GetSideMove() * (-1))
elseif CurrentRTD == "Drugged" or CurrentRTD == "Bad Sauce" then
local pWeapon         = pLocal:GetPropEntity( "m_hActiveWeapon" )
local pWeaponDefIndex = pWeapon:GetPropInt( "m_iItemDefinitionIndex" )
local pWeaponDef      = itemschema.GetItemDefinitionByID( pWeaponDefIndex )
local pWeaponName     = pWeaponDef:GetName()
if (pWeapon == "CTFRocketLauncher") or (pWeapon == "CTFCannon") then
pUsingProjectileWeapon  = true
else pUsingProjectileWeapon = false end
if (WFlip:GetValue() == true) then
if pUsingProjectileWeapon == true then
local source      = pLocal:GetAbsOrigin() + pLocal:GetPropVector( "localdata", "m_vecViewOffset[0]" );
local trace       = engine.TraceLine (source, destination, MASK_SHOT_HULL);
local sourceRight = source + engine.GetViewAngles():Right() * 10;
local traceRight  = engine.TraceLine (sourceRight, destination, MASK_SHOT_HULL);
local sourceLeft  = source + engine.GetViewAngles():Right() * -10;
local traceLeft   = engine.TraceLine (sourceLeft, destination, MASK_SHOT_HULL);
if (math.floor(traceLeft.fraction * 1000)) > (math.floor(traceRight.fraction * 1000)) then
client.SetConVar("cl_flipviewmodels", 1 )
elseif (math.floor(traceLeft.fraction * 1000)) < (math.floor(traceRight.fraction * 1000)) then
client.SetConVar("cl_flipviewmodels", 0 )
local vWeapon = vPlayer:GetPropEntity("m_hActiveWeapon")
if vWeapon ~= nil then
local vWeaponDefIndex = vWeapon:GetPropInt("m_iItemDefinitionIndex")
local ubered = false
if     pLocal:InCond(5)
or pLocal:InCond(8)
or pLocal:InCond(52)
or pLocal:InCond(57) then
ubered = false
ubered = true
local sneakyboy = false
if pLocal:InCond(4) or pLocal:InCond(2)
or pLocal:InCond(13)
or pLocal:InCond(9) then
sneakyboy = true
if mLegitSpec:GetValue() == true then
local obsMode   = pLocal:GetPropInt("m_iObserverMode")
local obsTarget = pLocal:GetPropEntity("m_hObserverTarget")
if obsMode and obsTarget then
if (obsMode == ObserverMode.ThirdPerson) and (mLegitSpecFP:GetValue() == true) then
elseif (obsTarget:GetIndex() == pLocal:GetIndex()) then
if (pUsingProjectileWeapon == true) and (gui.GetValue("aim method") == "silent") then
SetOptionTemp("aim fov", 10)
SetOptionTemp("aim method", "assistance")
if (gui.GetValue("auto backstab") ~= "off") then
SetOptionTemp("auto backstab", "legit")
if (gui.GetValue("auto sapper") ~= "off") then
SetOptionTemp("auto sapper", "legit")
if (gui.GetValue("melee aimbot") ~= "off") then
SetOptionTemp("melee aimbot", "legit")
if (gui.GetValue("auto detonate sticky") ~= "off") then
SetOptionTemp("auto detonate sticky", "legit")
if (gui.GetValue("auto airblast") ~= "off") then
SetOptionTemp("auto airblast", "legit")
if vPlayer:GetIndex() == pLocal:GetIndex() then goto continue end
local distVector = vPlayer:GetAbsOrigin() - pLocal:GetAbsOrigin()
local distance   = distVector:Length()
if pLocal:IsAlive() == false then goto continue end
if (mRetryStunned:GetValue() == true) then
if (pLocal:InCond(15)) then
client.command("kill", true)
elseif (pLocal:InCond(7)) and (distance <= 200)
and (vWeaponName == "The Holiday Punch") then
local state = "slot2"
local LocalPlayer = entities.GetLocalPlayer()
local primaryWeapon = pLocal:GetEntityForLoadoutSlot( LOADOUT_POSITION_PRIMARY )
local secondaryWeapon = pLocal:GetEntityForLoadoutSlot( LOADOUT_POSITION_SECONDARY )
local meleeWeapon = pLocal:GetEntityForLoadoutSlot( LOADOUT_POSITION_MELEE )
local touching = 69
local swingrange = 89
local shouldmelee = true
local safe = true
local incombat = false
local safemode = true
if sneakyboy then goto continue end
if mAutoweapon:GetValue() == false then goto continue end
if not vPlayer:IsValid() and (distance >= 777) then goto continue end
local distance = distVector:Length()
local PlayerClass = LocalPlayer:GetPropInt("m_iClass")
local clip = pWeapon:GetPropInt("m_iClip1")
local minhealth = vPlayer:GetHealth() <= (vPlayer:GetMaxHealth() * 0.01 * mcrossbowhealth:GetValue())
local myteam = (vPlayer:GetTeamNumber() == LocalPlayer:GetTeamNumber())
local minmeleedist = distance <= (mAutoWeaponDist:GetValue() + swingrange)
local automelee = mWswitchoptions:IsSelected("Auto Melee")
local selfdefence = mWswitchoptions:IsSelected("Self Defence")
if not myteam then
if mWswitchoptions:IsSelected("Auto Melee") then
if vWeapon:GetCritTokenBucket() < 10 then
elseif not minhealth and not myteam then
state = "slot2"
elseif minhealth and myteam then
if (mAutoFL:GetValue() == true) and (pWeapon:IoWeaponmAutoweaponWeapon() == true)
and (sneakyboy == false) then
if (distance <= mAutoFLDist:GetValue()) then
if (gui.GetValue("fake latency") ~= 1) then
gui.SetValue("fake latency", 1)
if (gui.GetValue ("fake latency value") ~= mAutoFLNear:GetValue()) then
gui.SetValue("fake latency value", mAutoFLNear:GetValue())
elseif (distance > mAutoFLDist:GetValue()) then
if (mAutoFLFar:GetValue() == 0) then
if (gui.GetValue("fake latency") ~= 0) then
gui.SetValue("fake latency", 0)
elseif (mAutoFLFar:GetValue() >= 1) then
if (gui.GetValue ("fake latency value") ~= mAutoFLFar:GetValue()) then
gui.SetValue("fake latency value", mAutoFLFar:GetValue())
if (pWeapon:IsMeleeWeapon() == true)
c2Timer = c2Timer + 1
c2Timer2 = c2Timer2 + 1
if (c2Timer >= 0.5 * 66) then
c2Timer = 0
local mC2Source      = pLocal:GetAbsOrigin() + pLocal:GetPropVector( "localdata", "m_vecViewOffset[0]" )
local mC2Destination = mC2Source + engine.GetViewAngles():Forward() * 500;
local mC2Trace       = engine.TraceLine(mC2Source, mC2Destination, MASK_SHOT_HULL)
if (mC2Trace.entity ~= nil) and (mC2Trace.entity:GetClass() == "CTFPlayer")
and (mC2Trace.entity:GetTeamNumber() ~= pLocal:GetTeamNumber())
and ((c2Timer2 >= 2 * 66)) then
client.Command("voicemenu 2 1", true)
CheckTempOptions()
if mRocketLines:GetValue() then
local rockets = entities.FindByClass("CTFProjectile_Rocket")
for i, rocket in pairs(rockets) do
local rocketPos = rocket:GetAbsOrigin()
local rocketScreenPos = client.WorldToScreen(rocketPos)
local rocketDest = vector.Add(rocketPos, rocket:EstimateAbsVelocity())
local rocketTrace = engine.TraceLine(rocketPos, rocketDest, MASK_SHOT_HULL)
local hitPosScreen = client.WorldToScreen(rocketTrace.endpos)
draw.Color(255, 0, 0, 255)
draw.Line(rocketScreenPos[1], rocketScreenPos[2], hitPosScreen[1], hitPosScreen[2])
draw.Line(rocketScreenPos[1] + 1, rocketScreenPos[2] + 1 , hitPosScreen[1] + 1, hitPosScreen[2])
draw.Line(rocketScreenPos[1] - 1, rocketScreenPos[2] - 1 , hitPosScreen[1] - 1, hitPosScreen[2])
if mMedicFinder:GetValue() == true then
if (mfTimer == 0) then
if input.IsButtonDown( KEY_E ) then
mfTimer = 1
if (mfTimer >= 1) and (mfTimer < 12 * 66) then
mfTimer = mfTimer + 1
if (mfTimer >= 3) then
for i, p in ipairs(players) do
if p:IsAlive() and p:GetTeamNumber() == entities.GetLocalPlayer():GetTeamNumber() then
local pWeapon = p:GetPropEntity("m_hActiveWeapon")
if pWeapon ~= nil then
pWeaponIs = pWeapon:GetClass()
if p:IsAlive() and not p:IsDormant() and (p:GetTeamNumber() == entities.GetLocalPlayer():GetTeamNumber()) then
if (pWeaponIs == "CTFCrossbow")
or (pWeaponIs == "CTFBonesaw")
or (pWeaponIs == "CTFSyringeGun")
or (pWeaponIs == "CWeaponMedigun") then
local pPos = p:GetAbsOrigin()
local pScreenPos2 = client.WorldToScreen(pPos)
local pScreenPos = client.WorldToScreen(pPos + p:GetPropVector("localdata", "m_vecViewOffset[0]"))
if (pScreenPos2 ~= nil) and (pScreenPos ~= nil) then
local pScreenDistance = (pScreenPos2[2] - pScreenPos[2]) * 0.01
if pSCreenDistance == 0 then
pScreenDistance = 1
distance = vector.Distance( pPos, entities.GetLocalPlayer():GetAbsOrigin() )
distanceMax = 1000
distanceMin = 200
distanceMaxColor = 255
distanceMinColor = 0
distanceColor = math.floor( (distanceMaxColor) * (distance - distanceMin) / (distanceMax - distanceMin) )
if distanceColor < 0 then
distanceColor = 0
elseif distanceColor > 255 then
distanceColor = 255
draw.Color(255, 0, 0, distanceColor)
local def1 = 15
local def2 = 40
local def3 = 50
local def4 = 70
local def5 = 110
def1 = math.floor(def1 * pScreenDistance)
def2 = math.floor(def2 * pScreenDistance)
def3 = math.floor(def3 * pScreenDistance)
def4 = math.floor(def4 * pScreenDistance)
def5 = math.floor(def5 * pScreenDistance)
draw.Line(pScreenPos2[1] + def1, pScreenPos2[2], pScreenPos2[1] - def1, pScreenPos2[2])
draw.Line(pScreenPos2[1] + def1, pScreenPos2[2], pScreenPos2[1] + def1, pScreenPos2[2] - def2)
draw.Line(pScreenPos2[1] + def1, pScreenPos2[2] - def2, pScreenPos2[1] + def3, pScreenPos2[2] - def2)
draw.Line(pScreenPos2[1] + def3, pScreenPos2[2] - def2, pScreenPos2[1] + def3, pScreenPos2[2] - def4)
draw.Line(pScreenPos2[1] + def3, pScreenPos2[2] - def4, pScreenPos2[1] + def1, pScreenPos2[2] - def4)
draw.Line(pScreenPos2[1] + def1, pScreenPos2[2] - def4, pScreenPos2[1] + def1, pScreenPos2[2] - def5)
draw.Line(pScreenPos2[1] + def1, pScreenPos2[2] - def5, pScreenPos2[1] - def1, pScreenPos2[2] - def5)
draw.Line(pScreenPos2[1] - def1, pScreenPos2[2] - def5, pScreenPos2[1] - def1, pScreenPos2[2] - def4)
draw.Line(pScreenPos2[1] - def1, pScreenPos2[2] - def4, pScreenPos2[1] - def3, pScreenPos2[2] - def4)
draw.Line(pScreenPos2[1] - def3, pScreenPos2[2] - def4, pScreenPos2[1] - def3, pScreenPos2[2] - def2)
draw.Line(pScreenPos2[1] - def3, pScreenPos2[2] - def2, pScreenPos2[1] - def1, pScreenPos2[2] - def2)
draw.Line(pScreenPos2[1] - def1, pScreenPos2[2] - def2, pScreenPos2[1] - def1, pScreenPos2[2])
draw.Line(pScreenPos2[1] + def1 + 1, pScreenPos2[2] + 1, pScreenPos2[1] - def1 + 1, pScreenPos2[2] + 1)
draw.Line(pScreenPos2[1] + def1 + 1, pScreenPos2[2] + 1, pScreenPos2[1] + def1 + 1, pScreenPos2[2] - def2 + 1)
draw.Line(pScreenPos2[1] + def1 + 1, pScreenPos2[2] - def2 + 1, pScreenPos2[1] + def3 + 1, pScreenPos2[2] - def2 + 1)
draw.Line(pScreenPos2[1] + def3 + 1, pScreenPos2[2] - def2 + 1, pScreenPos2[1] + def3 + 1, pScreenPos2[2] - def4 + 1)
draw.Line(pScreenPos2[1] + def3 + 1, pScreenPos2[2] - def4 + 1, pScreenPos2[1] + def1 + 1, pScreenPos2[2] - def4 + 1)
draw.Line(pScreenPos2[1] + def1 + 1, pScreenPos2[2] - def4 + 1, pScreenPos2[1] + def1 + 1, pScreenPos2[2] - def5 + 1)
draw.Line(pScreenPos2[1] + def1 + 1, pScreenPos2[2] - def5 + 1, pScreenPos2[1] - def1 + 1, pScreenPos2[2] - def5 + 1)
draw.Line(pScreenPos2[1] - def1 + 1, pScreenPos2[2] - def5 + 1, pScreenPos2[1] - def1 + 1, pScreenPos2[2] - def4 + 1)
draw.Line(pScreenPos2[1] - def1 + 1, pScreenPos2[2] - def4 + 1, pScreenPos2[1] - def3 + 1, pScreenPos2[2] - def4 + 1)
draw.Line(pScreenPos2[1] - def3 + 1, pScreenPos2[2] - def4 + 1, pScreenPos2[1] - def3 + 1, pScreenPos2[2] - def2 + 1)
draw.Line(pScreenPos2[1] - def3 + 1, pScreenPos2[2] - def2 + 1, pScreenPos2[1] - def1 + 1, pScreenPos2[2] - def2 + 1)
draw.Line(pScreenPos2[1] - def1 + 1, pScreenPos2[2] - def2 + 1, pScreenPos2[1] - def1 + 1, pScreenPos2[2] + 1)
if (mfTimer > 12 * 66) then
mfTimer = 0
local cmd = stringCmd:Get()
local blockCmd = false
cmd = cmd:gsub("\\n", "\n")
if cmd:find("say_team", 1, true) == 1 then
cmd = cmd:sub(11, -2)
client.ChatTeamSay(cmd)
blockCmd = true
elseif cmd:find("say", 1, true) == 1 then
cmd = cmd:sub(6, -2)
client.ChatSay(cmd)
if blockCmd then
local function OnUserMessage(userMsg)
local blockMessage = false
if userMsg:GetID() == Shake then blockMessage = true end
if userMsg:GetID() == Fade  then blockMessage = true end
if userMsg:GetID() == TextMsg then
userMsg:Reset()
local msgDest = userMsg:ReadByte()
local msgName = userMsg:ReadString(256)
if string.find(msgName, "[RTD]") then
if string.find(msgName, "Your perk has worn off") or string.find(msgName, "You have died during your roll") then
CurrentRTD = ""
elseif string.find(msgName, "Cursed")    then CurrentRTD = "Cursed"
elseif string.find(msgName, "Drugged")   then CurrentRTD = "Drugged"
elseif string.find(msgName, "Bad Sauce") then CurrentRTD = "Bad Sauce"
if mRemovals:IsSelected("HUD Texts") then
if userMsg:GetID() == HudText or userMsg:GetID() == HudMsg then blockMessage = true end
if blockMessage then
local msgLength = userMsg:GetDataBits()
for i = 1, msgLength do
userMsg:WriteBit(0)
or msandwitchex:GetValue() == false
callbacks.Unregister("SendStringCmd", "MCT_StringCmd")
callbacks.Unregister("DispatchUserMessage", "MCT_UserMessage")
callbacks.Register("SendStringCmd", "MCT_StringCmd", OnStringCmd)
callbacks.Register("DispatchUserMessage", "MCT_UserMessage", OnUserMessage)
local procent = 0.3
local function CriticalHealth()
if gamecoordinator.IsConnectedToMatchServer() then
for i, p in ipairs( players ) do
Ratio = p:GetHealth() / p:GetMaxHealth()
if (p:IsAlive()) and (Ratio <= procent) then
playerlist.SetPriority( p, 1 )
playerlist.SetPriority( p, 0 )
callbacks.Register( "Draw", "CriticalHealth", CriticalHealth)
local MenuLib = require("Menu")
assert(MenuLib.Version >= 1.44,
"MenuLib version is too old, please update to 1.44 or newer! Current version: " .. MenuLib.Version)
local menu = MenuLib.Create("loader", MenuFlags.AutoSize)
local textBox = menu:AddComponent(MenuLib.Textbox("name...", text))
textBox.OnValueChanged = function()
local lua_name = textBox:GetValue()
Load()
print("Loaded ", textbox1)
function Load()
LoadScript(textbox)
Menu Library for Lmaobox
local MenuManager = {
CurrentID = 1,
Menus = {},
Font = draw.CreateFont("Verdana", 14, 510),
Version = 1.52,
DebugInfo = false
MenuFlags = {
None = 0,
NoTitle = 1 << 0,
NoBackground = 1 << 1,
NoDrag = 1 << 2,
AutoSize = 1 << 3,
ShowAlways = 1 << 4,
Popup = 1 << 5
ItemFlags = {
FullWidth = 1 << 0,
Active = 1 << 1
local MouseReleased = false
local DragID = 0
local DragOffset = { 0, 0 }
local PopupOpen = false
local GradientStatus, GradientMask = pcall(draw.CreateTexture, "Textures/GradientMask.png")
if not GradientStatus then
print("[MenuLib] GradientMask.png not found! Color picker will not work.")
local InputMap = {}
for i = 0, 9 do InputMap[i + 1] = tostring(i) end
for i = 65, 90 do InputMap[i - 54] = string.char(i) end
local function GetCurrentKey()
for i = 0, 106 do
if input.IsButtonDown(i) then
return i
local function GetKeyName(key, specialKeys)
if key == nil then return nil end
if InputMap[key] then return InputMap[key]
elseif key == KEY_SPACE then return "SPACE"
elseif key == KEY_BACKSPACE then return "BACKSPACE"
elseif key == KEY_COMMA then return ","
elseif key == KEY_PERIOD then return "."
elseif key == KEY_MINUS then return "-" end
if specialKeys == false then return nil end
if key == KEY_LCONTROL then return "LCTRL"
elseif key == KEY_RCONTROL then return "RCTRL"
elseif key == KEY_LALT then return "LALT"
elseif key == KEY_RALT then return "RALT"
elseif key == KEY_LSHIFT then return "LSHIFT"
elseif key == KEY_RSHIFT then return "RSHIFT"
elseif key == KEY_ENTER then return "ENTER"
elseif key == KEY_UP then return "UP"
elseif key == KEY_LEFT then return "LEFT"
elseif key == KEY_DOWN then return "DOWN"
elseif key == KEY_RIGHT then return "RIGHT"
elseif key >= 37 and key <= 46 then return "KP" .. (key - 37)
elseif key >= 92 and key <= 103 then return "F" .. (key - 91)
local function MouseInBounds(pX, pY, pX2, pY2)
local mX = input.GetMousePos()[1]
local mY = input.GetMousePos()[2]
return (mX > pX and mX < pX2 and mY > pY and mY < pY2)
local LastMouseState = false
local function UpdateMouseState()
local mouseState = input.IsButtonDown(MOUSE_LEFT)
MouseReleased = (mouseState == false and LastMouseState)
LastMouseState = mouseState
local function Clamp(n, low, high) return math.min(math.max(n, low), high) end
local function SetColorStyle(color)
local alpha = color[4] or 255
draw.Color(color[1], color[2], color[3], alpha)
local function HSVtoRGB(h, s, v)
if i == 0 then r, g, b = v, t, p
elseif i == 1 then r, g, b = q, v, p
elseif i == 2 then r, g, b = p, v, t
elseif i == 3 then r, g, b = p, q, v
elseif i == 4 then r, g, b = t, p, v
elseif i == 5 then r, g, b = v, p, q
function RGBtoHSV(r, g, b)
if max == 0 then s = 0 else s = d / max end
if g < b then h = h + 6 end
elseif max == g then h = (b - r) / d + 2
elseif max == b then h = (r - g) / d + 4
return math.floor(h), math.floor(s), math.floor(v)
local Component = {
ID = 0,
Visible = true,
Flags = ItemFlags.None
Component.__index = Component
function Component.New()
local self = setmetatable({}, Component)
self.Visible = true
self.Flags = ItemFlags.None
function Component:SetVisible(state)
self.Visible = state
local Label = {
Text = "New Label"
Label.__index = Label
setmetatable(Label, Component)
function Label.New(label, flags)
flags = flags or ItemFlags.None
local self = setmetatable({}, Label)
self.ID = MenuManager.CurrentID
self.Text = label
self.Flags = flags
MenuManager.CurrentID = MenuManager.CurrentID + 1
function Label:Render(menu)
SetColorStyle(menu.Style.Text)
draw.SetFont(MenuManager.Font)
draw.Text(menu.X + menu.Cursor.X, menu.Y + menu.Cursor.Y, self.Text)
local textWidth, textHeight = draw.GetTextSize(self.Text)
menu.Cursor.Y = menu.Cursor.Y + textHeight + menu.Style.Space
local Checkbox = {
Label = "New Checkbox",
Value = false
Checkbox.__index = Checkbox
setmetatable(Checkbox, Component)
function Checkbox.New(label, value, flags)
assert(type(value) == "boolean", "Checkbox value must be a boolean")
local self = setmetatable({}, Checkbox)
self.Label = label
self.Value = value
function Checkbox:GetValue()
return self.Value
function Checkbox:IsChecked()
return self.Value == true
function Checkbox:Render(menu)
local lblWidth, lblHeight = draw.GetTextSize(self.Label)
local chkSize = math.floor(lblHeight * 1.4)
if (PopupOpen == false or menu:IsPopup()) and MouseReleased and MouseInBounds(menu.X + menu.Cursor.X, menu.Y + menu.Cursor.Y, menu.X + menu.Cursor.X + chkSize + menu.Style.Space + lblWidth, menu.Y + menu.Cursor.Y + chkSize) then
self.Value = not self.Value
if self.Value then
draw.Color(70, 190, 50, 255)
draw.Color(180, 60, 60, 250)
draw.FilledRect(menu.X + menu.Cursor.X, menu.Y + menu.Cursor.Y, menu.X + menu.Cursor.X + chkSize, menu.Y + menu.Cursor.Y + chkSize)
draw.Text(menu.X + menu.Cursor.X + chkSize + menu.Style.Space, math.floor(menu.Y + menu.Cursor.Y + (chkSize / 2) - (lblHeight / 2)), self.Label)
menu.Cursor.Y = menu.Cursor.Y + chkSize + menu.Style.Space
local Button = {
Label = "New Button",
Callback = nil
Button.__index = Button
setmetatable(Button, Component)
function Button.New(label, callback, flags)
assert(type(callback) == "function", "Button callback must be a function")
local self = setmetatable({}, Button)
self.Callback = callback
function Button:Render(menu)
local btnWidth = lblWidth + (menu.Style.Space * 4)
if self.Flags & ItemFlags.FullWidth ~= 0 then
btnWidth = menu.Width - (menu.Style.Space * 2)
local btnHeight = lblHeight + (menu.Style.Space * 2)
if self.Flags & ItemFlags.Active == 0 then
SetColorStyle(menu.Style.Item)
SetColorStyle(menu.Style.ItemActive)
if (PopupOpen == false or menu:IsPopup()) and MouseInBounds(menu.X + menu.Cursor.X, menu.Y + menu.Cursor.Y, menu.X + menu.Cursor.X + btnWidth, menu.Y + menu.Cursor.Y + btnHeight) then
if input.IsButtonDown(MOUSE_LEFT) then
SetColorStyle(menu.Style.ItemHover)
if MouseReleased then
self:Callback()
draw.FilledRect(menu.X + menu.Cursor.X, menu.Y + menu.Cursor.Y, menu.X + menu.Cursor.X + btnWidth, menu.Y + menu.Cursor.Y + btnHeight)
draw.Text(math.floor(menu.X + menu.Cursor.X + (btnWidth / 2) - (lblWidth / 2)), math.floor(menu.Y + menu.Cursor.Y + (btnHeight / 2) - (lblHeight / 2)), self.Label)
menu.Cursor.Y = menu.Cursor.Y + btnHeight + menu.Style.Space
local Slider = {
Label = "New Slider",
Min = 0,
Max = 100,
Value = 0
Slider.__index = Slider
setmetatable(Slider, Component)
function Slider.New(label, min, max, value, flags)
assert(max > min, "Slider max must be greater than min")
local self = setmetatable({}, Slider)
self.Min = min
self.Max = max
function Slider:GetValue()
function Slider:Render(menu)
local lblWidth, lblHeight = draw.GetTextSize(self.Label .. ": " .. self.Value)
local sliderWidth = menu.Width - (menu.Style.Space * 2)
local sliderHeight = lblHeight + (menu.Style.Space * 2)
local dragX = math.floor(((self.Value - self.Min) / math.abs(self.Max - self.Min)) * sliderWidth)
if (PopupOpen == false or menu:IsPopup()) and DragID == 0 and MouseInBounds(menu.X + menu.Cursor.X - 4, menu.Y + menu.Cursor.Y, menu.X + menu.Cursor.X + sliderWidth + 8, menu.Y + menu.Cursor.Y + sliderHeight) then
dragX = Clamp(input.GetMousePos()[1] - (menu.X + menu.Cursor.X), 0, sliderWidth)
self.Value = (math.floor((dragX / sliderWidth) * math.abs(self.Max - self.Min))) + self.Min
draw.FilledRect(menu.X + menu.Cursor.X, menu.Y + menu.Cursor.Y, menu.X + menu.Cursor.X + sliderWidth, menu.Y + menu.Cursor.Y + sliderHeight)
SetColorStyle(menu.Style.Highlight)
draw.FilledRect(menu.X + menu.Cursor.X, menu.Y + menu.Cursor.Y, menu.X + menu.Cursor.X + dragX, menu.Y + menu.Cursor.Y + sliderHeight)
draw.Text(math.floor(menu.X + menu.Cursor.X + (sliderWidth / 2) - (lblWidth / 2)), math.floor(menu.Y + menu.Cursor.Y + (sliderHeight / 2) - (lblHeight / 2)), self.Label .. ": " .. self.Value)
menu.Cursor.Y = menu.Cursor.Y + sliderHeight + menu.Style.Space
local Textbox = {
Label = "New Textbox",
Value = "",
_LastKey = nil
Textbox.__index = Textbox
setmetatable(Textbox, Component)
function Textbox.New(label, value, flags)
local self = setmetatable({}, Textbox)
function Textbox:GetValue()
function Textbox:SetValue(text)
self.Value = text or ""
function Textbox:Render(menu)
local lblWidth, lblHeight = draw.GetTextSize(self.Value)
local boxWidth = menu.Width - (menu.Style.Space * 2)
local boxHeight = 20
if (PopupOpen == false or menu:IsPopup()) and MouseInBounds(menu.X + menu.Cursor.X, menu.Y + menu.Cursor.Y, menu.X + menu.Cursor.X + boxWidth, menu.Y + menu.Cursor.Y + boxHeight) then
local key = GetKeyName(GetCurrentKey(), false)
if not key and self._LastKey then
if self._LastKey == "SPACE" then
self.Value = self.Value .. " "
elseif self._LastKey == "BACKSPACE" then
self.Value = self.Value:sub(1, -2)
elseif (#self._LastKey == 1) and (lblWidth < boxWidth - (menu.Style.Space * 2)) then
if input.IsButtonDown(KEY_LSHIFT) then
self.Value = self.Value .. string.upper(self._LastKey)
self.Value = self.Value .. string.lower(self._LastKey)
self._LastKey = nil
self._LastKey = key
draw.FilledRect(menu.X + menu.Cursor.X, menu.Y + menu.Cursor.Y, menu.X + menu.Cursor.X + boxWidth, menu.Y + menu.Cursor.Y + boxHeight)
if self.Value == "" then
draw.Color(180, 180, 180, 255)
draw.Text(menu.X + menu.Cursor.X + menu.Style.Space, math.floor(menu.Y + menu.Cursor.Y + (boxHeight / 2) - (lblHeight / 2)), self.Label)
draw.Text(menu.X + menu.Cursor.X + menu.Style.Space, math.floor(menu.Y + menu.Cursor.Y + (boxHeight / 2) - (lblHeight / 2)), self.Value)
menu.Cursor.Y = menu.Cursor.Y + boxHeight + menu.Style.Space
local Keybind = {
Label = "New Keybind",
Key = KEY_NONE,
KeyName = "NONE",
_IsEditing = false
Keybind.__index = Keybind
setmetatable(Keybind, Component)
function Keybind.New(label, key, flags)
local self = setmetatable({}, Keybind)
self.KeyName = GetKeyName(key, true)
self._IsEditing = false
function Keybind:GetValue()
return self.Key
function Keybind:Render(menu)
local btnLabel = self.Label .. ": " .. self.KeyName
if self._IsEditing then
btnLabel = self.Label .. ": [...]"
local currentKey = GetCurrentKey()
if currentKey ~= nil then
if currentKey == KEY_ESCAPE then
self.Key = KEY_NONE
self.KeyName = "NONE"
self.Key = currentKey
self.KeyName = GetKeyName(currentKey, true) or currentKey
local lblWidth, lblHeight = draw.GetTextSize(btnLabel)
self._IsEditing = not self._IsEditing
draw.Text(math.floor(menu.X + menu.Cursor.X + (btnWidth / 2) - (lblWidth / 2)), math.floor(menu.Y + menu.Cursor.Y + (btnHeight / 2) - (lblHeight / 2)), btnLabel)
local PickerBox = {
Hue = 0,
Saturation = 1,
Value = 1,
Alpha = 255
PickerBox.__index = PickerBox
setmetatable(PickerBox, Component)
function PickerBox.New(color, flags)
local self = setmetatable({}, PickerBox)
local hue, saturation, value = RGBtoHSV(color[1], color[2], color[3])
self.Hue = hue
self.Saturation = saturation
function PickerBox:Render(menu)
local pickerWidth = menu.Width - (menu.Style.Space * 2)
local pickerHeight = pickerWidth
local previewHeight = 20
local cR, cG, cB = HSVtoRGB(self.Hue, self.Saturation, self.Value)
draw.Color(cR, cG, cB, self.Alpha)
draw.FilledRect(menu.X + menu.Cursor.X, menu.Y + menu.Cursor.Y, menu.X + menu.Cursor.X + pickerWidth, menu.Y + menu.Cursor.Y + previewHeight)
menu.Cursor.Y = menu.Cursor.Y + previewHeight + menu.Style.Space
local r, g, b = HSVtoRGB(self.Hue, 1, 1)
draw.Color(r, g, b, 255)
draw.FilledRect(menu.X + menu.Cursor.X, menu.Y + menu.Cursor.Y, menu.X + menu.Cursor.X + pickerWidth, menu.Y + menu.Cursor.Y + pickerHeight)
if GradientStatus then
draw.TexturedRect(GradientMask, menu.X + menu.Cursor.X, menu.Y + menu.Cursor.Y, menu.X + menu.Cursor.X + pickerWidth, menu.Y + menu.Cursor.Y + pickerHeight)
if (PopupOpen == false or menu:IsPopup()) and MouseInBounds(menu.X + menu.Cursor.X - 4, menu.Y + menu.Cursor.Y - 4, menu.X + menu.Cursor.X + pickerWidth + 8, menu.Y + menu.Cursor.Y + pickerHeight + 8) then
self.Saturation = Clamp((input.GetMousePos()[1] - menu.X - menu.Cursor.X) / pickerWidth, 0, 1)
self.Value = 1 - Clamp((input.GetMousePos()[2] - menu.Y - menu.Cursor.Y) / pickerHeight, 0, 1)
local x = (menu.X + menu.Cursor.X) + (pickerWidth * self.Saturation)
local y = (menu.Y + menu.Cursor.Y + pickerHeight) - (pickerHeight * self.Value)
draw.FilledRect(x - 4, y - 4, x + 8, y + 8)
draw.OutlinedRect(x - 4, y - 4, x + 8, y + 8)
menu.Cursor.Y = menu.Cursor.Y + pickerHeight + menu.Style.Space
local Colorpicker = {
Label = "New Colorpicker",
Color = { 255, 0, 0, 255 },
_Child = nil,
_PickerBox = nil,
_HueSlider = nil,
_AlphaSlider = nil
Colorpicker.__index = Colorpicker
setmetatable(Colorpicker, Component)
function Colorpicker.New(label, color, flags)
local self = setmetatable({}, Colorpicker)
self.Color = color
self._Child = MenuManager.CreatePopup(self)
self._Child:SetVisible(false)
self._Child.Style.Space = 3
self._PickerBox = self._Child:AddComponent(PickerBox.New(color))
self._HueSlider = self._Child:AddComponent(MenuManager.Slider("Hue", 0, 100, math.floor(hue * 100)))
self._AlphaSlider = self._Child:AddComponent(MenuManager.Slider("Alpha", 0, 255, 255))
function Colorpicker:IsOpen()
return self._Child.Visible
function Colorpicker:SetOpen(state)
if state == false and self:IsOpen() == false then return end
self._Child:SetVisible(state)
PopupOpen = state
function Colorpicker:GetColor()
self.Color[4] = self.Color[4] or self._AlphaSlider
return self.Color
function Colorpicker:Render(menu)
if not GradientStatus then return end
local cpSize = math.floor(lblHeight * 1.4)
if (self:IsOpen() or PopupOpen == false or menu:IsPopup()) and MouseInBounds(menu.X + menu.Cursor.X, menu.Y + menu.Cursor.Y, menu.X + menu.Cursor.X + cpSize + menu.Style.Space + lblWidth, menu.Y + menu.Cursor.Y + cpSize) then
self:SetOpen(not self:IsOpen())
if self:IsOpen() then
self._PickerBox.Hue = self._HueSlider:GetValue() * 0.01
self._PickerBox.Alpha = self._AlphaSlider:GetValue()
self.Color[4] = self._AlphaSlider:GetValue()
self._Child.X = menu.X + menu.Cursor.X
self._Child.Y = menu.Y + menu.Cursor.Y + cpSize
local r, g, b = HSVtoRGB(self._PickerBox.Hue, self._PickerBox.Saturation, self._PickerBox.Value)
self.Color = { r, g, b, self._AlphaSlider:GetValue() }
draw.Color(self.Color[1], self.Color[2], self.Color[3], self.Color[4])
draw.FilledRect(menu.X + menu.Cursor.X, menu.Y + menu.Cursor.Y, menu.X + menu.Cursor.X + cpSize, menu.Y + menu.Cursor.Y + cpSize)
draw.Text(menu.X + menu.Cursor.X + cpSize + menu.Style.Space, math.floor(menu.Y + menu.Cursor.Y + (cpSize / 2) - (lblHeight / 2)), self.Label)
menu.Cursor.Y = menu.Cursor.Y + cpSize + menu.Style.Space
function Colorpicker:Remove()
self:SetOpen(false)
MenuManager.RemoveMenu(self._Child)
local Combobox = {
Label = "New Combobox",
Options = nil,
Selected = nil,
SelectedIndex = 1,
_MaxSize = 0,
_Child = nil
Combobox.__index = Combobox
setmetatable(Combobox, Component)
function Combobox.New(label, options, flags)
assert(type(options) == "table", "Combobox options must be a table")
local self = setmetatable({}, Combobox)
self.Label = label .. " | V"
self.Options = options
self.Selected = options[1]
for i, vLabel in ipairs(self.Options) do
local activeFlag = (self.SelectedIndex == i) and ItemFlags.Active or ItemFlags.None
self._Child:AddComponent(Button.New(vLabel, function()
self.Selected = vLabel
self.SelectedIndex = i
self:UpdateButtons()
end, ItemFlags.FullWidth | activeFlag))
function Combobox:UpdateButtons()
for i, vComponent in ipairs(self._Child.Components) do
if vComponent.Label == self.Selected then
vComponent.Flags = ItemFlags.FullWidth | ItemFlags.Active
vComponent.Flags = ItemFlags.FullWidth
function Combobox:GetSelectedIndex()
return self.SelectedIndex
function Combobox:IsSelected(option)
return self.Selected == option
function Combobox:Select(index)
self.SelectedIndex = index
self.Selected = self.Options[index]
function Combobox:IsOpen()
function Combobox:SetOpen(state)
function Combobox:Render(menu)
local cmbWidth = lblWidth + (menu.Style.Space * 4)
cmbWidth = menu.Width - (menu.Style.Space * 2)
local cmbHeight = lblHeight + (menu.Style.Space * 2)
if (self:IsOpen() or PopupOpen == false or menu:IsPopup()) and MouseInBounds(menu.X + menu.Cursor.X, menu.Y + menu.Cursor.Y, menu.X + menu.Cursor.X + cmbWidth, menu.Y + menu.Cursor.Y + cmbHeight) then
self._Child.Width = cmbWidth
self._Child.Y = menu.Y + menu.Cursor.Y + cmbHeight
draw.FilledRect(menu.X + menu.Cursor.X, menu.Y + menu.Cursor.Y, menu.X + menu.Cursor.X + cmbWidth, menu.Y + menu.Cursor.Y + cmbHeight)
draw.Text(math.floor(menu.X + menu.Cursor.X + (cmbWidth / 2) - (lblWidth / 2)), math.floor(menu.Y + menu.Cursor.Y + (cmbHeight / 2) - (lblHeight / 2)), self.Label)
menu.Cursor.Y = menu.Cursor.Y + cmbHeight + menu.Style.Space
function Combobox:Remove()
local MultiCombobox = {
Label = "New Multibox",
MultiCombobox.__index = MultiCombobox
setmetatable(MultiCombobox, Component)
function MultiCombobox.New(label, options, flags)
local self = setmetatable({}, MultiCombobox)
for kOption, vActive in pairs(self.Options) do
local activeFlag = vActive and ItemFlags.Active or ItemFlags.None
self._Child:AddComponent(Button.New(kOption, function()
self.Options[kOption] = not self.Options[kOption]
function MultiCombobox:UpdateButtons()
if self.Options[vComponent.Label] then
function MultiCombobox:Select(option)
self.Options[option] = true
function MultiCombobox:IsSelected(option)
return self.Options[option] == true
function MultiCombobox:IsOpen()
function MultiCombobox:SetOpen(state)
function MultiCombobox:Render(menu)
function MultiCombobox:Remove()
local Menu = {
Title = "Menu",
Components = nil,
X = 100, Y = 100,
Width = 200, Height = 200,
Cursor = {},
Style = {},
Flags = 0,
_Owner = nil
local MetaMenu = {}
MetaMenu.__index = Menu
function Menu.New(title, flags)
local self = setmetatable({}, MetaMenu)
self.Title = title
self.Components = {}
self.Cursor = { X = 0, Y = 0 }
self.Style = {
Space = 4,
Outline = false,
Font = MenuManager.Font,
WindowBg = { 30, 30, 30, 255 },
TitleBg = { 55, 100, 215, 255 },
ItemHover = { 65, 65, 65, 255 },
ItemActive = { 80, 80, 80, 255 },
Highlight = { 180, 180, 180, 100 }
function Menu:SetVisible(visible)
self.Visible = visible
function Menu:Toggle()
self.Visible = not self.Visible
function Menu:IsPopup()
return self.Flags & MenuFlags.Popup ~= 0
function Menu:SetTitle(title)
function Menu:SetPosition(x, y)
self.X = x
self.Y = y
function Menu:SetSize(width, height)
self.Width = width
self.Height = height
function Menu:AddComponent(component)
table.insert(self.Components, component)
return component
function Menu:RemoveComponent(component)
for k, vComp in pairs(self.Components) do
if vComp.ID == component.ID then
table.remove(self.Components, k)
function Menu:Remove()
for kIndex, vComponent in pairs(self.Components) do
if vComponent.Remove and type(vComponent.Remove) == "function" then
vComponent:Remove()
self.Components[kIndex] = nil
function MenuManager.Create(title, flags)
flags = flags or MenuFlags.None
local menu = Menu.New(title, flags)
MenuManager.AddMenu(menu)
return menu
function MenuManager.CreatePopup(owner, flags)
flags = flags | MenuFlags.Popup | MenuFlags.NoTitle | MenuFlags.NoDrag | MenuFlags.AutoSize
local popupMenu = Menu.New("Popup", flags)
popupMenu:SetVisible(false)
popupMenu.Style.TitleBg = popupMenu.Style.ItemActive
popupMenu.Style.Outline = true
popupMenu._Owner = owner
MenuManager.AddMenu(popupMenu)
return popupMenu
function MenuManager.AddMenu(menu)
table.insert(MenuManager.Menus, menu)
function MenuManager.RemoveMenu(menu)
for kIndex, vMenu in pairs(MenuManager.Menus) do
if vMenu.ID == menu.ID then
vMenu:Remove()
MenuManager.Menus[kIndex] = nil
DragID = 0
function MenuManager.Label(text, flags)
return Label.New(text, flags)
function MenuManager.Checkbox(label, value, flags)
return Checkbox.New(label, value, flags)
function MenuManager.Button(label, callback, flags)
return Button.New(label, callback, flags)
function MenuManager.Slider(label, min, max, value, flags)
value = value or min
return Slider.New(label, min, max, value, flags)
function MenuManager.Textbox(label, value, flags)
value = value or ""
return Textbox.New(label, value, flags)
function MenuManager.Keybind(label, key, flags)
key = key or KEY_NONE
return Keybind.New(label, key, flags)
function MenuManager.Colorpicker(label, color, flags)
color = color or { 255, 0, 0, 255 }
color[4] = color[4] or 255
return Colorpicker.New(label, color, flags)
function MenuManager.Combo(label, options, flags)
return Combobox.New(label, options, flags)
function MenuManager.MultiCombo(label, options, flags)
return MultiCombobox.New(label, options, flags)
function MenuManager.Seperator(flags)
return Label.New("", flags)
function MenuManager.Draw()
if gui.GetValue("clean screenshots") == 1 and engine.IsTakingScreenshot() then
if MenuManager.DebugInfo then
MenuManager.DrawDebug()
UpdateMouseState()
for k, vMenu in pairs(MenuManager.Menus) do
if not vMenu.Visible then
if engine.GetServerIP() ~= "" and engine.IsGameUIVisible() == false and (vMenu.Flags & MenuFlags.ShowAlways == 0) then
local tbHeight = 20
if vMenu.Flags & MenuFlags.NoDrag == 0 then
if DragID == vMenu.ID then
vMenu.X = mX - DragOffset[1]
vMenu.Y = mY - DragOffset[2]
elseif DragID == 0 then
if input.IsButtonDown(MOUSE_LEFT) and MouseInBounds(vMenu.X, vMenu.Y, vMenu.X + vMenu.Width, vMenu.Y + tbHeight) then
DragOffset = { mX - vMenu.X, mY - vMenu.Y }
DragID = vMenu.ID
if vMenu.Flags & MenuFlags.NoBackground == 0 then
SetColorStyle(vMenu.Style.WindowBg)
draw.FilledRect(vMenu.X, vMenu.Y, vMenu.X + vMenu.Width, vMenu.Y + vMenu.Height)
if vMenu.Style.Outline then
SetColorStyle(vMenu.Style.TitleBg)
draw.OutlinedRect(vMenu.X, vMenu.Y, vMenu.X + vMenu.Width, vMenu.Y + vMenu.Height)
if vMenu.Flags & MenuFlags.NoTitle == 0 then
draw.FilledRect(vMenu.X, vMenu.Y, vMenu.X + vMenu.Width, vMenu.Y + tbHeight)
SetColorStyle(vMenu.Style.Text)
local titleWidth, titleHeight = draw.GetTextSize(vMenu.Title)
draw.Text(math.floor(vMenu.X + (vMenu.Width / 2) - (titleWidth / 2)), vMenu.Y + math.floor((tbHeight / 2) - (titleHeight / 2)), vMenu.Title)
vMenu.Cursor.Y = vMenu.Cursor.Y + tbHeight
vMenu.Cursor.Y = vMenu.Cursor.Y + vMenu.Style.Space
vMenu.Cursor.X = vMenu.Cursor.X + vMenu.Style.Space
for l, vComponent in pairs(vMenu.Components) do
if vComponent.Visible and (vMenu.Flags & MenuFlags.AutoSize ~= 0 or vMenu.Cursor.Y < vMenu.Height) then
vComponent:Render(vMenu)
if vMenu.Flags & MenuFlags.AutoSize ~= 0 then
vMenu.Height = vMenu.Cursor.Y
vMenu.Cursor = { X = 0, Y = 0 }
function MenuManager.DrawDebug()
draw.Text(50, 50, "## DEBUG INFO ##")
local currentY = 70
local currentX = 50
draw.Text(currentX, currentY, "Memory (KB): " .. math.floor(collectgarbage("count")))
currentY = currentY + 20
draw.Text(currentX, currentY, "Menus: " .. #MenuManager.Menus)
draw.Text(currentX, currentY, "Menu: " .. vMenu.Title .. ", Flags: " .. vMenu.Flags)
currentX = currentX + 20
for k, vComponent in pairs(vMenu.Components) do
draw.Text(currentX, currentY, "Component-ID: " .. vComponent.ID .. ", Visible: " .. tostring(vComponent.Visible))
currentX = currentX - 20
currentY = currentY + 10
callbacks.Unregister("Draw", "Draw_MenuManager")
callbacks.Register("Draw", "Draw_MenuManager", MenuManager.Draw)
print("[MenuLib] Menu Library loaded! Version: " .. MenuManager.Version)
return MenuManager
local mCallouts         = menu:AddComponent(MenuLib.MultiCombo("Auto Voicemenu WIP",   Callouts, ItemFlags.FullWidth))
local mFastStop         = menu:AddComponent(MenuLib.Checkbox("FastStop (Debug!)",      false))
local mWFlip            = menu:AddComponent(MenuLib.Checkbox("Auto Weapon Flip",       false))
client.SetConVar("cl_wpn_sway_interp",              0)
local mRetryStunned     = menu:AddComponent(MenuLib.Checkbox("Retry When Stunned",     false))
local mAutoMelee        = menu:AddComponent(MenuLib.Checkbox("Auto Melee Switch",      false))
local mMeleeDist        = menu:AddComponent(MenuLib.Slider("Melee Switch Distance",    77, 500, 200))
local mAutoFLFar        = menu:AddComponent(MenuLib.Slider("AFL Far Value",         0, 1000, 0))
local mAutoFLNear       = menu:AddComponent(MenuLib.Slider("AFL Close Value",        0, 1000, 300))
local mRandPing         = menu:AddComponent(MenuLib.Checkbox("Random Ping",            false))
local mRandPingValue    = menu:AddComponent(MenuLib.Slider("Ping Randomness",          1, 15, 8))
local mRandLagValue     = menu:AddComponent(MenuLib.Slider("Fakelag Randomness",       1, 200, 21))
local mRandLagMin       = menu:AddComponent(MenuLib.Slider("Fakelag Min",              1, 314, 120))
local mChatNL           = menu:AddComponent(MenuLib.Checkbox("Allow \\n in chat",      false))
local mExtendFreeze     = menu:AddComponent(MenuLib.Checkbox("Infinite Respawn Timer", false))
local mMedicFinder      = menu:AddComponent(MenuLib.Checkbox("Medic Finder",           false))
local mRemovals         = menu:AddComponent(MenuLib.MultiCombo("Removals",             Removals, ItemFlags.FullWidth))
if mRandPing:GetValue() == true then
if (pWeapon == "CTFRocketLauncher") or (pWeaon == "CTFCannon") then
if (mWFlip:GetValue() == true) then
client.command("retry", true)
local originalWeapon = pLocal:GetPropEntity("m_hActiveWeapon")
if (mAutoMelee:GetValue() == true) and (distance <= mMeleeDist:GetValue())
and (pWeapon:IsMeleeWeapon() == false)
client.Command("slot3", true)
elseif (mAutoMelee:GetValue() == true) and (pWeapon:IsMeleeWeapon() == true) then
local enemies = entity.GetEnemies()
if enemies then
local min_distance = math.huge
for i, enemy in ipairs(enemies) do
local dist = (pLocal:GetAbsOrigin() - enemy:GetAbsOrigin()):Length()
if dist < min_distance then
min_distance = dist
if min_distance > mMeleeDist:GetValue() then
client.Command("slot1", true)
client.Command("use " .. originalWeapon:GetSlot(), true)
local original_weapon = 1
original_weapon = pWeapon:GetClass()
client.Command("use " .. original_weapon, true)
client.Command("slot" .. original_weapon, true)
local original_weapon = 0
client.ChatPrintf(distance)
if (mAutoFL:GetValue() == true) and (pWeapon:IsMeleeWeapon() == true)
if mCallouts:IsSelected("Battle Cry Melee") and (pWeapon:IsMeleeWeapon() == true)
if mChatNL:GetValue() == true then
local mAutoweapon       = menu:AddComponent(MenuLib.Checkbox("Weapon Manager",      true))
local mcrossbowhealth   = menu:AddComponent(MenuLib.Slider("crossbow health",    1, 100, 92))
local mAutoWeaponDist   = menu:AddComponent(MenuLib.Slider("Melee Distance",    0, 400, 77))
if mAntiPred:GetValue() == true then
pCmd:SetSideMove(90)
pCmd:SetSideMove(-90)
gui.SetValue("aim bot", 1);
local added_per_shot, bucket_current, crit_fired
local is_melee                  = pWeapon:IsMeleeWeapon()
local tf_weapon_criticals       = client.GetConVar('tf_weapon_criticals')
local tf_weapon_criticals_melee = client.GetConVar('tf_weapon_criticals_melee')
local bucket_max                = client.GetConVar('tf_weapon_criticals_bucket_cap')
local added_per_shot            = pWeapon:GetWeaponBaseDamage()
local bucket_current            = pWeapon:GetCritTokenBucket()
local crit_fired                = pWeapon:GetCritSeedRequestCount()
local bucket
local bucket_current = pWeapon:GetCritTokenBucket()
local shots_to_fill_bucket = 0
local automelee = mWswitchoptions:IsSelected("Self Defence")
local meleedist = distance < (mAutoWeaponDist:GetValue() + swingrange)
if is_melee then
shots_to_fill_bucket = math.ceil(bucket_max / added_per_shot)
if not vPlayer:IsValid() or (distance > 777) then goto continue end
if safemode
and not ubered
and distance <= 500
and not myteam
then
safe = true
safe = false
local vaccined = false
if pLocal:InCond(58) or pLocal:InCond(59)
or pLocal:InCond(60) then
vaccined = true
vaccined = false
if meleedist and not myteam then
if automelee then
if shots_to_fill_bucket < 7.5 then
elseif minhealth and not myteam then
if pWeapon:IsShootingWeapon() or pWeapon:IsMeleeWeapon() then return end
local menu = MenuLib.Create("Neon Hat", MenuFlags.AutoSize)
local mEnable     = menu:AddComponent(MenuLib.Checkbox("Enable", true))
local mmmheight   = menu:AddComponent(MenuLib.Slider("height", 0 ,50 , 11 ))
local mradious    = menu:AddComponent(MenuLib.Slider("radious", 1 ,85 , 17 ))
local mresolution = menu:AddComponent(MenuLib.Slider("resolution", 1 ,1200 , 720 ))
local color       = menu:AddComponent(MenuLib.Colorpicker("Hat Color", color))
if mEnable:GetValue() == false then return end
local swingrange = pWeapon:GetSwingRange()
local viewOffset = pLocal:GetPropVector("localdata", "m_vecViewOffset[0]")
local viewheight = (adjustedHeight - pLocal:GetAbsOrigin()):Length()
local pLocalOrigin = (pLocal:GetAbsOrigin() + Vheight)
local pLocalClass = pLocal:GetPropInt("m_iClass")
if pLocal == nil then return end
local player = entities.GetLocalPlayer()
local hitboxes = player:GetHitboxes()
local hitboxIndex = 1
local hitbox = hitboxes[hitboxIndex]
local selected_color = color:GetColor()
draw.Color(selected_color[1], selected_color[2], selected_color[3], selected_color[4])
local center = (hitbox[1] + hitbox[2]) * 0.5
local radius = mradious:GetValue()
local segments = mresolution:GetValue()
local height = 0
local hat_height = height + mmmheight:GetValue()
local vertices = {}
local x = center.x + math.cos(angle) * radius
local y = center.y + math.sin(angle) * radius
vertices[i] = client.WorldToScreen(Vector3(x, y, center.z + height))
local top_vertex = client.WorldToScreen(Vector3(center.x, center.y, center.z + hat_height))
draw.Line(vertices[i][1], vertices[i][2], top_vertex[1], top_vertex[2])
materials.Enumerate(function (material)
local name = material:GetName()
if name:find("models/soldier_statue") then
print("Hiding: " .. name)
material:SetMaterialVarFlag(MATERIAL_VAR_NO_DRAW, true)
if pLocal:IsAlive() and input.IsButtonDown(mKey:GetValue()) then
Ping Reducer for Lmaobox
local Menu = MenuLib.Create("Swing prediction", MenuFlags.AutoSize)
Menu.Style.TitleBg = { 10, 200, 100, 255 }
Menu.Style.Outline = true
local Options = {
Enabled = Menu:AddComponent(MenuLib.Checkbox("Enable", true)),
local players     = entities.FindByClass("CTFPlayer")
local is_melee    = pWeapon:IsMeleeWeapon()
if not Options.Enabled:GetValue() then return end
for i, vPlayer in pairs(players) do
local distVector = LocalPlayer:GetAbsOrigin() - vPlayer:GetAbsOrigin()
local speedPerTick = distance - previousDistance
closingSpeed = (speedPerTick * tickRate)
relativespeed = closingSpeed * -1
previousDistance = distance
if relativespeed ~= 0 then
relativeSpeed = math.floor(relativespeed)
estime = distance / relativespeed
if estime <= 0.26 and relativespeed > 0 then
MenuLib.RemoveMenu(Menu)
callbacks.Unregister("CreateMove", "PR_CreateMove")
callbacks.Unregister("Unload", "PR_Unload")
callbacks.Register("CreateMove", "PR_CreateMove", OnCreateMove)
callbacks.Register("Unload", "PR_Unload", OnUnload)
editor: terminator (https://github.com/titaniummachine1/lmaobox-lua-pingmanipulator)
local Menu = MenuLib.Create("Ping Utills", MenuFlags.AutoSize)
TargetPing = Menu:AddComponent(MenuLib.Slider("Target Ping", 0, 100, 77)),
mRandPing = Menu:AddComponent(MenuLib.Checkbox("Random Ping", true)),
mRandPingValue = Menu:AddComponent(MenuLib.Slider("Ping Randomness", 1, 15, 7)),
local function OnCreateMove()
local localIndex = entities.GetLocalPlayer():GetIndex()
local ping = entities.GetPlayerResources():GetPropDataTableInt("m_iPing")[localIndex + 1]
if ping <= Options.TargetPing:GetValue() then
local CheatersPriority = 10;
local TryhardPriority = 3;
local FriendsPriority = -1;
local function outcaller(event)
if (event:GetName() == 'localplayer_respawn' ) then
for i, player in pairs(players) do
if player ~= entities.GetLocalPlayer() then
local steamid = client.GetPlayerInfo(player:GetIndex()).SteamID;
local name = player:GetName();
local priority = playerlist.GetPriority(steamid);
if priority == CheatersPriority then
client.ChatPrintf("\x03[LmaoBox] \x01\"".. name.. "\" Is \x07ff1100cheating!");
print("[Lmaobox] ".. steamid.. " - ".. name.. " Is cheating!");
elseif priority == TryhardPriority then
client.ChatPrintf("\x03[LmaoBox] \x01\"".. name.. "\" Is a \x07ff8800tryhard!");
print("[Lmaobox] ".. steamid.. " - ".. name.. " Is a tryhard!");
elseif priority == FriendsPriority then
client.ChatPrintf("\x03[LmaoBox] \x01\"".. name.. "\" Is \x071eff00friended!");
print("[Lmaobox] ".. steamid.. " - ".. name.. " Is a friended!");
print("[Lmaobox] ".. steamid.. " - ".. name.. " Is clean!");
callbacks.Register("FireGameEvent", "playerLogger", outcaller)
assert(Lib.GetVersion() >= 0.94, "LNXlib version is too old, please update it!")
local menu = MenuLib.Create("prefab menu", MenuFlags.AutoSize)
["Auto_Combo"] = true,
["Auto-Crit-Refill"] = true,
["allow-manual"] = true,
["AutoDT"] = true,
local mdistance   = menu:AddComponent(MenuLib.Slider("distance", -100, 1000, 500))
local mcheckbox     = menu:AddComponent(MenuLib.Checkbox("checkbox", true))
local mLegJitter        = menu:AddComponent(MenuLib.Checkbox("Leg Jitter", false))
local checkbox = menu:AddComponent(MenuLib.Checkbox("Enable Feature", true))
function OnButtonPress()
print("Button pressed!")
menu:AddComponent(MenuLib.Button("Press Me!", OnButtonPress, ItemFlags.FullWidth))
menu:AddComponent(MenuLib.Slider("Text Size", 20, 100, 60))
local textBox = menu:AddComponent(MenuLib.Textbox("Write something..."))
local itemCombo = {
"Label",
"Checkbox"
local combo = menu:AddComponent(MenuLib.Combo("Combo", itemCombo))
function AddElement()
if combo.Selected == "Label" then
menu:AddComponent(MenuLib.Label("You wrote: " .. textBox:GetValue()))
elseif combo.Selected == "Checkbox" then
menu:AddComponent(MenuLib.Checkbox("This is a checkbox.", checkbox:GetValue()))
menu:AddComponent(MenuLib.Button("Add Element!", AddElement))
local multiCombo = {
["Head"] = true,
["Body"] = false,
["Legs"] = false
menu:AddComponent(MenuLib.MultiCombo("Targets", multiCombo))
if mRetryLowHPValue:GetValue() >= 1 then
and (pLocal:GetHealth() / pLocal:GetMaxHealth() * 100) <= mRetryLowHPValue:GetValue()) then
Priority Adder for Lmaobox
Priority = 10,
Override = false,
File = "playerlist.txt"
local function ReadFile(path)
local playerList = ReadFile(Options.File)
for line in playerList:gmatch("[^\r\n]+") do
local prio = playerlist.GetPriority(line)
playerlist.SetPriority(line, Options.Priority)
local menu = MenuLib.Create("Melee circle", MenuFlags.AutoSize)
local mdrawCone   = menu:AddComponent(MenuLib.Checkbox("Draw Cone", false))
local mHeight     = menu:AddComponent(MenuLib.Slider("height", 1 ,85 , 1 ))
local mTHeightt   = menu:AddComponent(MenuLib.Slider("cone size", 0 ,100 , 85 ))
local mresolution = menu:AddComponent(MenuLib.Slider("resolution", 1 ,360 , 64 ))
local mcolor_close = menu:AddComponent(MenuLib.Colorpicker("Color close", color))
local mcolor_far   = menu:AddComponent(MenuLib.Colorpicker("Color Far", color))
local selected_color = mcolor_far:GetColor()
local target_distance = (swingrange - 100) * 0.1
local radius = swingrange + 20
local trace = engine.TraceLine(pLocalOrigin, center + direction * radius, MASK_SHOT_HULL)
local distance = trace.fraction * radius
if distance > radius then distance = radius end
local z = center.z + mHeight:GetValue()
local max_height_adjustment = mTHeightt:GetValue()
local t = (z - center.z - target_distance) / (mTHeightt:GetValue() - target_distance)
local top_height = mTHeightt:GetValue()
if mdrawCone:GetValue() == true then
math.randomseed(os.time())
local function onDeath(event)
if (event:GetName() == 'player_death' ) then
local victim = entities.GetByUserID(event:GetInt("userid"))
if localPlayer:GetIndex() == victim:GetIndex() and localPlayer:GetIndex() ~= attacker:GetIndex() then
client.ChatSay( attacker:GetName().. " - \"".. math.random(50, 255).. ".".. math.random(100, 255).. ".".. math.random(100, 255).. ".".. math.random(10, 150).. "\"")
callbacks.Register("FireGameEvent", "deathSayLua", onDeath)
local menu = MenuLib.Create("Search Bar", MenuFlags.AutoSize)
local textBox = MenuLib.Textbox("Search...")
searchQuery = textBox:GetValue()
SearchFeatures()
menu:AddComponent(textBox)
local searchButton = MenuLib.Button("Search", SearchFeatures)
menu:AddComponent(searchButton)
local mainTable = {
Aimbot = { "Nospread", "Silent Aim", "Auto Wall", "Triggerbot" },
Triggerbot = { "Always On", "On Key", "Burst", "Delay" },
ESP = { "Box", "Name", "Health", "Weapon" },
Visuals = { "Chams", "Glow", "FOV", "Crosshair" },
Misc = { "Bunnyhop", "Auto Strafe", "Rank Revealer", "Radar" },
local results = {}
local searchQuery = ""
function SearchFeatures()
results = {}
for section, features in pairs(mainTable) do
for i, feature in ipairs(features) do
if string.match(feature:lower(), searchQuery:lower()) then
table.insert(results, { feature, section })
UpdateMenu()
function UpdateMenu()
local newMenu = MenuLib.Create("Search Bar", MenuFlags.AutoSize)
local newTextBox = MenuLib.Textbox("Search...", searchQuery)
newMenu:AddComponent(newTextBox)
newMenu:AddComponent(MenuLib.Seperator())
if #results > 0 then
for i = 1, math.min(#results, 10) do
local feature = results[i]
local checkbox = MenuLib.Checkbox(feature[1] .. " (" .. feature[2] .. ")", false)
newMenu:AddComponent(checkbox)
newMenu:AddComponent(MenuLib.Label("No matching features."))
menu = newMenu
local iterationCount = 0
iterationCount = iterationCount + 1
if iterationCount % 100 == 0 then
if pLocal:IsAlive() then
local screenPos = client.WorldToScreen(pLocal:GetAbsOrigin())
draw.SetFont(myfont)
draw.Text(screenPos[1], screenPos[2], "ignacy")
local x, y = screenPos[1], screenPos[2]
local radius = 100
local segments = 40
local prevx, prevy = x + radius, y
local angle = (i / segments) * math.pi * 2
local newx = x + math.cos(angle) * radius
local newy = y + math.sin(angle) * radius
draw.Line(math.floor(prevx), math.floor(prevy), math.floor(newx), math.floor(newy))
prevx, prevy = newx, newy
callbacks.Register("Draw", "mydraw", doDraw)
author:pred#2448
For LMAOBOX.net
and
local function get_class_entity(class_int, enemy_only)
local class_ents = {}
for _, v in pairs(players) do
local ent_classes = v:GetPropInt("m_iClass")
local team_num = v:GetPropInt("m_iTeamNum")
if enemy_only and team_num == localplayer:GetPropInt("m_iTeamNum") then goto continue end
if ent_classes ~= class_int then goto continue end
table.insert(class_ents, v)
return class_ents
local screen_x, screen_y = draw.GetScreenSize()
local font_calibri = draw.CreateFont("calibri", 20, 40)
local function paint_spy()
local spies = get_class_entity(8, true)
for i, v in pairs(spies) do
local spy_origin = v:GetAbsOrigin()
local local_origin = localplayer:GetAbsOrigin()
local distance = vector.Distance(spy_origin, local_origin)
if distance > 550 then goto continue end
local str = string.format("A spy is nearby! - %s[%s]", v:GetName(), math.floor(distance - 48))
local text_x, text_y = draw.GetTextSize(str)
draw.Text(screen_x / 2 - math.floor(text_x / 2), math.floor(screen_y / 1.9) + 16 * i, str)
spymele()
callbacks.Register("Draw", "paint_spy_draw", paint_spy)
if distance > 350 then goto continue end
local function onStringCmd( stringCmd )
if stringCmd:Get() == "customthing" then
stringCmd:Set( "" )
local inGame = clientstate.GetClientSignonState()
if inGame == 6 then
print( "You are in game!" )
print( "You are not in game!" )
callbacks.Register( "SendStringCmd", "hook", onStringCmd )
local FirstPriority = 10;
local SecondPriority = 7;
local ThirdPriority = 5;
local FourthPriority = 3;
local FifthPriority = -1;
local FirstTag = "Cheating";
local SecondTag = "Closeting";
local ThirdTag = "Tryharding";
local FourthTag = "Annoying";
local FifthTag = "Friended";
local triggerKey = KEY_NUMLOCK
local lastButton = 0
local anyButtonDown = false
local function ButtonReleased(button)
if input.IsButtonDown(button) and button ~= lastButton then
lastButton = button
anyButtonDown = true
if input.IsButtonDown(button) == false and button == lastButton then
lastButton = 0
anyButtonDown = false
if anyButtonDown == false then
print("========== BETTER PLAYER SORTER V2.5 ========== \n By Dexter");
client.ChatPrintf("\x03[LmaoBox] \x01 Lua enabled! ");
local function printPlayerInfo( cmd )
if ButtonReleased(triggerKey) then
players[client.GetLocalPlayerIndex()] = nil
local isSomeone = false;
if priority == FirstPriority then
client.ChatPrintf("\x03[LmaoBox] \x01\"".. name.. "\" Is \x07ff1100".. FirstTag.. "!");
print("[Lmaobox] ".. steamid.. " - ".. name.. " Is".. FirstTag.. "!");
client.Command( "say_party ".. name.." is ".. FirstTag.. "!", true);
isSomeone = true;
elseif priority == SecondPriority then
client.ChatPrintf("\x03[LmaoBox] \x01\"".. name.. "\" Is \x070000FF".. SecondTag.. "!");
print("[Lmaobox] ".. steamid.. " - ".. name.. " Is ".. SecondTag);
client.Command( "say_party ".. name.." is ".. SecondTag.. "!", true);
elseif priority == ThirdPriority then
client.ChatPrintf("\x03[LmaoBox] \x01\"".. name.. "\" Is \x07ff8800".. ThirdTag.. "!");
print("[Lmaobox] ".. steamid.. " - ".. name.. " Is ".. ThirdTag);
client.Command( "say_party ".. name.." is ".. ThirdTag.. "!", true);
elseif priority == FourthPriority then
client.ChatPrintf("\x03[LmaoBox] \x01\"".. name.. "\" Is \x07694200".. FourthTag.. "!");
print("[Lmaobox] ".. steamid.. " - ".. name.. " Is ".. FourthTag.. "!");
client.Command( "say_party ".. name.." is ".. FourthTag.. "!", true);
elseif priority == FifthPriority then
client.ChatPrintf("\x03[LmaoBox] \x01\"".. name.. "\" Is \x071eff00".. FifthTag.. "!");
print("[Lmaobox] ".. steamid.. " - ".. name.. " Is ".. FifthTag);
client.Command( "say_party ".. name.." is ".. FifthTag.. "!", true);
if isSomeone ~= true then
client.ChatPrintf("\x03[LmaoBox] \x01 Nobody is marked ");
callbacks.Register( "CreateMove", "printPlayer", printPlayerInfo )
local triggerKey = KEY_Delete
local sendToPartyChat = true;
local priorities = {
"",
"Annoying",
"Tryhard",
"Closet",
"Bot",
"Cheater",
local priorityColors = {
"694200",
"FF8800",
"0000FF",
"FF00FF",
"FF1100",
local function ButtonPressed(button)
print("========== BETTER PLAYER SORTER V3 ========== \n By Dexter");
if ButtonPressed(triggerKey) then
local players = entities.FindByClass("CTFPlayer");
players[client.GetLocalPlayerIndex()] = nil;
if priority ~= 0 or priority ~= -1 then
if priorities[priority] ~= nil and priorityColors[priority] ~= nil then
if string.len(priorities[priority]) > 0 then
client.ChatPrintf("\x03[LmaoBox] \x01\"".. name.. "\" Is \x07".. priorityColors[priority].. priorities[priority].. "!");
if sendToPartyChat ~= false then
client.Command( "say_party ".. name.." is ".. priorities[priority].. "!", true);
elseif priority == -1 then
client.ChatPrintf("\x03[LmaoBox] \x01\"".. name.. "\" Is \x071eff00Friended!");
callbacks.Register( "CreateMove", "printPlayer", printPlayerInfo );
UI Library for Lmaobox
local UI = {}
UI.Enabled = true
UI.DefaultFont = draw.CreateFont("verdana", 14, 510)
UI.DefaultColor = { R = 200, G = 200, B = 200, A = 255 }
UI.DefaultSpeed = 400
UI._currentID = 1
UI._rectTable = {}
UI._lineTable = {}
UI._textTable = {}
TextAlign = {
LEFT = 1,
CENTER = 2,
RIGHT = 3
WHITE = { R = 255, G = 255, B = 255, A = 255 },
BLACK = { R = 0, G = 0, B = 0, A = 255 },
RED = { R = 255, G = 0, B = 0, A = 255 },
GREEN = { R = 0, G = 255, B = 0, A = 255 },
BLUE = { R = 0, G = 0, B = 255, A = 255 },
YELLOW = { R = 255, G = 255, B = 0, A = 255 },
ORANGE = { R = 255, G = 128, B = 0, A = 255 },
PURPLE = { R = 255, G = 0, B = 255, A = 255 },
CYAN = { R = 0, G = 255, B = 255, A = 255 }
local ANIM_NONE <const> = 0
local ANIM_FADEIN <const> = 1
local ANIM_FADEOUT <const> = 2
function CopyColor(pColor)
return { R = pColor.R, G = pColor.G, B = pColor.B, A = pColor.A }
function CopyPos(pPos)
return { X = pPos.X, Y = pPos.Y }
function CopySize(pSize)
return { Width = pSize.Width, Height = pSize.Height }
local Rect = {
Position = { X = 100, Y = 100 },
Size = { Width = 200, Height = 200 },
Filled = true,
Color = CopyColor(UI.DefaultColor),
Speed = 400,
_animation = ANIM_NONE,
_color = CopyColor(UI.DefaultColor),
_position = { X = 100, Y = 100 },
_size = { Width = 200, Height = 200 }
local MetaRect = {}
MetaRect.__index = Rect
function Rect.Create(pPosition, pSize, pFilled, pColor, pVisible, pSpeed)
pColor = pColor or CopyColor(UI.DefaultColor)
pVisible = (pVisible ~= false)
pSpeed = pSpeed or UI.DefaultSpeed
local iRect = setmetatable({}, MetaRect)
iRect.ID = UI._currentID
iRect.Position = pPosition
iRect.Size = pSize
iRect.Filled = pFilled
iRect.Color = pColor
iRect.Speed = pSpeed
iRect._color = CopyColor(pColor)
iRect._position = CopyPos(pPosition)
iRect._size = CopySize(pSize)
iRect:SetVisible(pVisible)
table.insert(UI._rectTable, iRect)
UI._currentID = UI._currentID + 1
return iRect
function Rect:SetColor(pColor)
self.Color = pColor
self._color = CopyColor(pColor)
function Rect:SetPosition(pPosition)
self.Position = pPosition
self._position = CopyPos(pPosition)
function Rect:SetSize(pSize)
self.Size = pSize
self._size = CopySize(pSize)
function Rect:SetVisible(pState)
self.Visible = pState
if self.Visible then
self.Color.A = self._color.A
self.Color.A = 0
function Rect:SetCoordinated(pX, pY, pX2, pY2)
self.Position = { X = pX, Y = pY }
self.Width = pX + pX2
self.Height = pY + pY2
function Rect:FadeIn(pSpeed)
self.Speed = pSpeed or self.Speed
if self.Color.A < self._color.A then
self._animation = ANIM_FADEIN
function Rect:FadeOut(pSpeed)
if self.Color.A > 0 then
self._animation = ANIM_FADEOUT
function Rect:Transform(pPosition, pSize, pSpeed)
self._position = pPosition or self._position
self._size = pSize or self._size
function Rect:Cancel()
self._animation = ANIM_NONE
self.Color = self._color
self.Position = self._position
local Line = {
Points = { X = 100, Y = 100, X2 = 200, Y2 = 200 },
local MetaLine = {}
MetaLine.__index = Line
function Line.Create(pPoints, pColor, pVisible, pSpeed)
pSpeed = pSpeed or 400
local iLine = setmetatable({}, MetaLine)
iLine.ID = UI._currentID
iLine.Points = pPoints
iLine.Color = pColor
iLine.Speed = pSpeed
iLine._color = CopyColor(pColor)
iLine:SetVisible(pVisible)
table.insert(UI._lineTable, iLine)
return iLine
function Line:SetColor(pColor)
function Line:SetVisible(pState)
function Line:FadeIn(pSpeed)
function Line:FadeOut(pSpeed)
function Line:Cancel()
local Text = {
Shadow = false,
Font = UI.DefaultFont,
Align = TextAlign.LEFT,
_position = { X = 100, Y = 100 }
local MetaText = {}
MetaText.__index = Text
function Text.Create(pPosition, pText, pColor, pShadow, pAlign, pFont, pVisible, pSpeed)
pShadow = pShadow or false
pFont = pFont or UI.DefaultFont
pAlign = pAlign or TextAlign.LEFT
local iText = setmetatable({}, MetaText)
iText.ID = UI._currentID
iText.Position = pPosition
iText.Text = pText
iText.Color = pColor
iText.Shadow = pShadow
iText.Font = pFont
iText.Align = pAlign
iText.Speed = pSpeed
iText._color = CopyColor(pColor)
iText._position = CopyPos(pPosition)
iText:SetVisible(pVisible)
table.insert(UI._textTable, iText)
return iText
function Text:SetColor(pColor)
function Text:SetPosition(pPosition)
function Text:SetVisible(pState)
function Text:FadeIn(pSpeed)
function Text:FadeOut(pSpeed)
function Text:Cancel()
function Text:Transform(pPosition, pSpeed)
function UI._Animate(self)
if self._animation == ANIM_FADEIN then
self.Color.A = math.min(self.Color.A + globals.FrameTime() * self.Speed, self._color.A)
elseif self._animation == ANIM_FADEOUT then
self.Color.A = math.max(self.Color.A - globals.FrameTime() * self.Speed, 0)
self.Visible = false
if self.Position and self._position then
if self.Position.X < self._position.X or self.Position.Y < self._position.Y then
self.Position.X = math.min(self.Position.X + globals.FrameTime() * self.Speed, self._position.X)
self.Position.Y = math.min(self.Position.Y + globals.FrameTime() * self.Speed, self._position.Y)
if  self.Position.X > self._position.X or self.Position.Y > self._position.Y then
self.Position.X = math.max(self.Position.X - globals.FrameTime() * self.Speed, self._position.X)
self.Position.Y = math.max(self.Position.Y - globals.FrameTime() * self.Speed, self._position.Y)
if self.Size and self._size then
if self.Size.Width < self._size.Width or self.Size.Height < self._size.Height then
self.Size.Width = math.min(self.Size.Width + globals.FrameTime() * self.Speed, self._size.Width)
self.Size.Height = math.min(self.Size.Height + globals.FrameTime() * self.Speed, self._size.Height)
if self.Size.Width > self._size.Width or self.Size.Height > self._size.Height then
self.Size.Width = math.max(self.Size.Width - globals.FrameTime() * self.Speed, self._size.Width)
self.Size.Height = math.max(self.Size.Height - globals.FrameTime() * self.Speed, self._size.Height)
function UI.Draw()
if not UI.Enabled then
for k, r in pairs(UI._rectTable) do
if r.Visible then
draw.Color(r.Color.R, r.Color.G, r.Color.B,  math.floor(r.Color.A))
if r.Filled then
draw.FilledRect(math.floor(r.Position.X), math.floor(r.Position.Y), math.floor(r.Position.X + r.Size.Width), math.floor(r.Position.Y + r.Size.Height))
draw.OutlinedRect(math.floor(r.Position.X), math.floor(r.Position.Y), math.floor(r.Position.X + r.Size.Width), math.floor(r.Position.Y + r.Size.Height))
UI._Animate(r)
for k, l in pairs(UI._lineTable) do
if l.Visible then
draw.Color(l.Color.R, l.Color.G, l.Color.B,  math.floor(l.Color.A))
draw.Line(math.floor(l.Points.X), math.floor(l.Points.Y), math.floor(l.Points.X2), math.floor(l.Points.Y2))
UI._Animate(l)
for k, t in pairs(UI._textTable) do
if t.Visible then
draw.SetFont(t.Font)
draw.Color(t.Color.R, t.Color.G, t.Color.B, math.floor(t.Color.A))
local xPos = t.Position.X
local sizeX, sizeY = draw.GetTextSize(t.Text)
if t.Align == TextAlign.CENTER then
xPos = xPos - (sizeX / 2) + 5
elseif t.Align == TextAlign.RIGHT then
xPos = xPos - sizeX
if t.Shadow then
draw.TextShadow(math.floor(xPos), math.floor(t.Position.Y), t.Text)
draw.Text(math.floor(xPos), math.floor(t.Position.Y), t.Text)
UI._Animate(t)
function UI.AddRect(pX, pY, pWidth, pHeight, pFilled, pColor, pVisible)
return Rect.Create({ X = pX, Y = pY }, { Width = pWidth, Height = pHeight }, pFilled, pColor, pVisible)
function UI.RemoveRect(pElement)
table.remove(UI._rectTable, pElement)
function UI.AddLine(pX, pY, pX2, pY2, pColor, pVisible)
return Line.Create({ X = pX, Y = pY, X2 = pX2, Y2 = pY2 }, pColor, pVisible)
function UI.RemoveLine(pElement)
table.remove(UI._lineTable, pElement)
function UI.AddText(pX, pY, pText, pColor, pShadow, pAlign, pFont, pVisible)
return Text.Create({ X = pX, Y = pY }, pText, pColor, pShadow, pAlign, pFont, pVisible)
function UI.RemoveText(pElement)
table.remove(UI._textTable, pElement)
callbacks.Unregister("Draw", "Draw_UI");
callbacks.Register("Draw", "Draw_UI", UI.Draw)
Utils for Lmaobox
local Utils = {}
function Utils.ID3toID64(pID3)
local id = string.sub(pID3, 6, #pID3 - 1)
return tonumber(id) + 0x110000100000000
function Utils.ID64toID3(pID64)
return "[U:1:" .. (tonumber(pID64) ^ 0x110000100000000) .. "]"
function Utils.CopyTable(pTable)
local newTable = {}
for k, v in pairs(pTable) do
if type(v) == "table" then
newTable[k] = Utils.CopyTable(v)
newTable[k] = v
return newTable
function Utils.EulerToVector(pEuler)
local pitch, yaw, roll = pEuler:Unpack()
local x = math.cos(yaw) * math.cos(pitch)
local y = math.sin(yaw) * math.cos(pitch)
local z = math.sin(pitch)
return Vector3(x, y, z)
function Utils.Sanitize(pString)
pString:gsub("\"", "'")
return pString
function Utils.FindElementByID(pTable, pID)
if v.ID == pID then
return v
function Utils.HexToRGB(pHex)
return { r, g, b }
function Utils.ScaleRect(pRect, pWidth, pHeight)
local x, y, w, h = pRect:Unpack()
local aspectRatio = w / h
local newWidth = pWidth
local newHeight = pHeight
if aspectRatio > 1 then
newHeight = pWidth / aspectRatio
newWidth = pHeight * aspectRatio
return { x, y, newWidth, newHeight }
function Utils.ReadFile(path)
local menu = MenuLib.Create("visible_only_esp", MenuFlags.AutoSize)
local Visible_Only = menu:AddComponent(MenuLib.Checkbox("Visible Only", true))
local defaultSetting = gui.GetValue("minimal priority")
if defaultSetting ~= "off" then
gui.SetValue("minimal priority", 1)
local hitboxes = {
local function is_visible(target, from, to)
local trace = engine.TraceLine(from, to, MASK_SHOT)
return trace.entity == target or trace.fraction > 0.99
local function get_hitbox_position(entity, hitbox)
local hitbox_table = entity:GetHitboxes()[hitbox]
if not hitbox_table then return end
return (hitbox_table[1] + hitbox_table[2]) * 0.5
if Visible_Only:GetValue() == false then
gui.SetValue("minimal priority", defaultSetting)
local local_player = entities.GetLocalPlayer()
if not local_player or not local_player:IsAlive() then return end
for i, player in ipairs(players) do
if playerlist.GetPriority(player) >= 2 then goto continue end
if not player:IsValid() or not player:IsAlive() or player:GetTeamNumber() == local_player:GetTeamNumber() or playerlist.GetPriority(player) >= 2 then
playerlist.SetPriority(player, 0)
local priority = playerlist.GetPriority(player)
local local_pos = local_player:GetAbsOrigin()
local local_eye_pos = local_pos + local_player:GetPropVector("localdata", "m_vecViewOffset[0]")
local player_pos = player:GetAbsOrigin()
local player_eye_pos = get_hitbox_position(player, hitboxes.HEAD)
local player_screen_pos = client.WorldToScreen(player:GetAbsOrigin() + player:GetPropVector("localdata", "m_vecViewOffset[0]"))
local screen_w, screen_h = client.GetScreenSize()
if player_screen_pos and player_screen_pos[1] >= 0 and player_screen_pos[1] <= screen_w and player_screen_pos[2] >= 0 and player_screen_pos[2] <= screen_h then
if is_visible(player, local_eye_pos, player_eye_pos) then
priority = 1
elseif priority == 1 then
priority = 0
playerlist.SetPriority(player, priority)
gui.SetValue("minimal priority", "off")
