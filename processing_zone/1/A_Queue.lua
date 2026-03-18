local mannUp = party.GetAllMatchGroups()["Mann Up"]

local reasons = party.CanQueueForMatchGroup(mannUp)

if reasons == true then
    party.QueueUp(mannUp)
else
    for k, v in pairs(reasons) do
        print(v)
    end
end