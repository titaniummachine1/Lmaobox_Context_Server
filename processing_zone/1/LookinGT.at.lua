for i = 1, entities.GetHighestEntityIndex() do -- index 1 is world entity
    local entity = entities.GetByIndex( i )
    if entity then
        print( i, entity:GetClass() )
    end
end

local me = entities.GetLocalPlayer();
local source = me:GetAbsOrigin() + me:GetPropVector( "localdata", "m_vecViewOffset[0]" );
local destination = source + engine.GetViewAngles():Forward() * 1000;

local trace = engine.TraceLine( source, destination, MASK_SHOT_HULL );

if (trace.entity ~= nil) then
    print( "I am looking at " .. trace.entity:GetClass() );
    print( "Distance to entity: " .. trace.fraction * 1000 );
end