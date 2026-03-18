local isVotekickInProgress = false
local function botdetector()
  if gamerules.IsMatchTypeCasual() then
    if os.time() >= timer then
      timer = os.time() + 2
      local resources = entities.GetPlayerResources()
      local me = entities.GetLocalPlayer()
      if resources and me then
        local teams = resources:GetPropDataTableInt("m_iTeam")
        local userids = resources:GetPropDataTableInt("m_iUserID")
        local accounts = resources:GetPropDataTableInt("m_iAccountID")
        local priority = 0~10
        if playerlist.GetPriority(me) ~= -1 then
          playerlist.SetPriority(me, -1)
        end
        for i, m in pairs(teams) do
          local steamid = "[U:1:" .. accounts[i] .. "]"
          local playername = client.GetPlayerNameByUserID(userids[i])
          if me:GetTeamNumber() == m and userids[i] ~= 0 and steamid ~= "[U:1:0]" and not steam.IsFriend(steamid) and playerlist.GetPriority(userids[i]) == priority then
            if isVotekickInProgress == false then

                "callvote kick (user ID)"
              isVotekickInProgress = true
              print("Rage votekicking " .. playername .. " " .. steamid)
            end
          end
        end
      end
    end
  end
end

local function botdetector_event(event)
  if event:GetName() == 'game_newmap' then
    time = 0
    isVotekickInProgress = false
  end
end

callbacks.Unregister("Draw", "bd")
callbacks.Unregister("FireGameEvent", "bd_event")
callbacks.Unregister("DispatchUserMessage", "bd_message")
callbacks.Register("Draw", "bd", botdetector)
callbacks.Register("FireGameEvent", "bd_event", botdetector_event)