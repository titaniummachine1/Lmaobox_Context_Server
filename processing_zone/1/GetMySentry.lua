local sentries = entities.FindByClass("CObjectSentrygun")
local pLocal = entities.GetLocalPlayer()

-- Print all sentry data
for i, sentry in ipairs(sentries) do
    --if sentry == pLocal or sentry:GetTeamNumber() == pLocal:GetTeamNumber() then
        -- Skip local player and teammates
   --     goto continue
   -- end

    Msg("Sentry " .. i .. ":\n")
    Msg("Classname: " .. sentry:GetClassname() .. "\n")
    Msg("Health: " .. sentry:GetHealth() .. "\n")
    Msg("Owner: " .. sentry:GetOwner():GetName() .. "\n")
    -- Add more data as needed

    ::continue::
end