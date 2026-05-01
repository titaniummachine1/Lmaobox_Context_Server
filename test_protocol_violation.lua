-- This script violates the Lmaobox Built-In Globals Protocol
-- and should be rejected by the MCP tool validation

-- ❌ FORBIDDEN: if check on builtin global
if http then
    local response = http.Get("https://example.com")
    print(response)
end

-- ❌ FORBIDDEN: nil check on builtin global
if entities ~= nil then
    local player = entities.GetLocalPlayer()
    print(player:GetHealth())
end

-- ❌ FORBIDDEN: type() check
if type(draw) == "userdata" then
    draw.Color(255, 0, 0, 255)
end
