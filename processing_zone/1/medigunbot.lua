local function medigunbot(cmd)


  local player = entities.GetLocalPlayer( );

    if (player == nil or not player:IsAlive()) then
    return end

 local medigun = player:GetPropEntity( "m_hActiveWeapon" )
local itemDefinitionIndex = medigun:GetPropInt( "m_iItemDefinitionIndex" )
local itemDefinition = itemschema.GetItemDefinitionByID( itemDefinitionIndex )
local weapontype = itemDefinition:GetTypeName()
local weaponname = itemDefinition:GetName()
local eye_pos = player:GetAbsOrigin() + player:GetPropVector( "localdata", "m_vecViewOffset[0]" );

local loadout_pos = medigun:GetLoadoutSlot()
local player_class = player:GetPropInt( "m_iClass" )




if (medigun:IsMedigun()) then

local chargetype = medigun:GetPropInt( "m_nChargeResistType")
local chargerelease = medigun:GetPropBool("m_bChargeRelease")
local healtarget = medigun:GetPropEntity("m_hHealingTarget")
local healing = medigun:GetPropBool("m_bHealing")
local partymembers = party.GetMembers()
local people = entities.FindByClass("CTFPlayer")
local friendclose = false;
local friendhealing = false;
local medigunaim = gui.GetValue("medigun aim")
local injuredclose = false;
local friendinjuredclose = false;
local ubertrigger = false;



for i, v in pairs(people) do

local playerinfo = client.GetPlayerInfo(v:GetIndex())
local steamid = playerinfo.SteamID;
local userid = playerinfo.UserID;

local target_origin = v:GetAbsOrigin()
local local_origin = player:GetAbsOrigin()
local distance = vector.Distance(target_origin, local_origin)


if(player:GetTeamNumber() ~= v:GetTeamNumber()
and v:IsAlive()
and not v:IsDormant()
) then
if (v:InCond( TFCond_Zoomed)) then
local distance2me = vector.Distance(v:GetAbsOrigin() + v:GetPropVector( "localdata", "m_vecViewOffset[0]" ), local_origin + Vector3( 0, 0, 45 ))
local dest2me = v:GetAbsOrigin() + v:GetPropVector( "localdata", "m_vecViewOffset[0]" ) + v:GetPropVector("tfnonlocaldata", "m_angEyeAngles[0]"):Forward() * distance2me;
local distance2dest2me = vector.Distance(local_origin + Vector3( 0, 0, 45 ), dest2me)

local distance2healtarget;
local dest2healtarget;
local distance2dest2healtarget = 1000;


if(healing and healtarget ~= nil) then
distance2healtarget = vector.Distance(v:GetAbsOrigin() + v:GetPropVector( "localdata", "m_vecViewOffset[0]" ), healtarget:GetAbsOrigin() + Vector3( 0, 0, 45 ))
dest2healtarget = v:GetAbsOrigin() + v:GetPropVector( "localdata", "m_vecViewOffset[0]" ) + v:GetPropVector("tfnonlocaldata", "m_angEyeAngles[0]"):Forward() * distance2healtarget;
distance2dest2healtarget = vector.Distance(healtarget:GetAbsOrigin() + Vector3( 0, 0, 45 ), dest2healtarget)
end


if (not player:InCond( TFCond_UberBulletResist ) and ((chargetype == 0 and weapontype == "#TF_Weapon_Medigun_Resist") or weapontype ~= "#TF_Weapon_Medigun_Resist") and distance2dest2me < 60 and not ubertrigger) then
local trace = engine.TraceLine(eye_pos, target_origin + v:GetPropVector( "localdata", "m_vecViewOffset[0]" ), MASK_SHOT_HULL);
if ((trace.fraction == 1 or trace.entity == v) and not trace.startsolid) then ubertrigger = true end
end

if (((chargetype == 0 and weapontype == "#TF_Weapon_Medigun_Resist") or weapontype ~= "#TF_Weapon_Medigun_Resist") and distance2dest2healtarget < 60 and healing and healtarget ~= nil and not healtarget:InCond( TFCond_UberBulletResist ) and not ubertrigger) then
local trace = engine.TraceLine(healtarget:GetAbsOrigin() + Vector3( 0, 0, 75 ), target_origin + v:GetPropVector( "localdata", "m_vecViewOffset[0]" ), MASK_SHOT_HULL);
if ((trace.fraction == 1 or trace.entity == v) and not trace.startsolid) then ubertrigger = true end
end
end

end

if (
player:GetTeamNumber() == v:GetTeamNumber()
and v:IsAlive()
and not v:InCond(TFCond_Cloaked)
and not v:IsDormant()
and steamid ~= "[U:1:0]"
and steamid ~= steam.GetSteamID()
and distance <= 500
) then

local trace = engine.TraceLine(eye_pos, target_origin + Vector3( 0, 0, 45 ), MASK_SOLID_BRUSHONLY);

if(steamid == partymembers[1]
or steamid == partymembers[2]
or steamid == partymembers[3]
or steamid == partymembers[4]
or steamid == partymembers[5]
or steamid == partymembers[6]
or steam.IsFriend(steamid)) then
if(v:GetHealth() < v:GetMaxHealth() and trace.fraction == 1 and not trace.startsolid) then
friendinjuredclose = true;
end

if (trace.fraction == 1 and not trace.startsolid) then friendclose = true; end
if (healing) then
local healtargetinfo = client.GetPlayerInfo(healtarget:GetIndex())
if (steamid == healtargetinfo.SteamID) then
friendhealing = true;
end
end
end


if(v:GetHealth() < v:GetMaxHealth() and trace.fraction == 1 and not trace.startsolid) then
injuredclose = true;
end





end

end



if (ubertrigger) then
cmd:SetButtons(cmd.buttons | IN_ATTACK2)
end






if (chargerelease) then
if (not friendhealing) then
if (friendclose) then
if (medigunaim ~= "friends only") then gui.SetValue("medigun aim", 2) end
end
if (not friendclose and not healing) then
if (medigunaim ~= "all players") then gui.SetValue("medigun aim", 1) end
else
if (medigunaim ~= "off") then gui.SetValue("medigun aim", 0) end
end
else
if (medigunaim ~= "off") then gui.SetValue("medigun aim", 0) end
end
else



if((friendclose and not friendhealing and not injuredclose) or friendinjuredclose) then
if (medigunaim ~= "friends only") then gui.SetValue("medigun aim", 2) end
end


if((not friendclose and not healing) or (injuredclose and not friendinjuredclose)) then
if (medigunaim ~= "all players") then gui.SetValue("medigun aim", 1) end
end

if((not friendclose and not injuredclose and healing) or (friendclose and friendhealing and not injuredclose)) then
if (medigunaim ~= "off") then gui.SetValue("medigun aim", 0) end
end

end








end
end


callbacks.Unregister("CreateMove", "medigunbot")
callbacks.Register("CreateMove", "medigunbot", medigunbot)
