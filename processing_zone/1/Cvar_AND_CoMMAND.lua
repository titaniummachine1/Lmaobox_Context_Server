client.GetConVar("host_map") -- get map name

client.Command("sv_cheats 1", true) -- enable cheats"sv_cheats 1"

client.RemoveConVarProtection("sv_cheats") --bypass security
client.SetConVar("sv_cheats", 1, true) -- force sv_cheats 1 localy(bypass sv_cheats 0)
client.RemoveConVarProtection("cl_cmdrate") --bypass security
client.SetConVar("cl_cmdrat", 132, true) -- force sv_cheats 1 localy(bypass sv_cheats 0)
local stepSize = pLocal:GetPropFloat("localdata", "m_flStepSize") --get propint