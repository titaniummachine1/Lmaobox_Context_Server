-- Made by: XJ2N, Please credit me if you want to use/modify/redistribute this.
-- This script is in no way affiliated with Valve Corporation or any of its affiliates.

local function onStringCmd( stringCmd )

    if stringCmd:Get() == "customthing" then
        stringCmd:Set( "" ) -- Because the Console thinks it's a blank input, it won't print anything about a Unknown command.
        local inGame = clientstate.GetClientSignonState()

        if inGame == 6 then
            print( "You are in game!" )
        else
            print( "You are not in game!" )
        end
    end
end

callbacks.Register( "SendStringCmd", "hook", onStringCmd )
