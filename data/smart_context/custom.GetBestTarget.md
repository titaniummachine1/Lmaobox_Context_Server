## Function/Symbol: custom.GetBestTarget

> Select the best enemy target (example skeleton)

### Required Context

- Functions: entities.FindByClass, Entity:IsAlive, Entity:GetTeamNumber, IsVisible, DistanceTo, AngleToPosition
- Types: Entity, Vector3
- Constants: TEAM (2/3 in TF2), MASK_SHOT_HULL for visibility

### Curated Usage Examples

#### Simple closest-visible target

```lua
local function GetBestTarget()
    local me = entities.GetLocalPlayer()
    if not me or not me:IsAlive() then return nil end

    local myTeam = me:GetTeamNumber()
    local eye = GetEyePos(me)
    local best, bestDist = nil, math.huge

    for _, ply in pairs(entities.FindByClass("CTFPlayer")) do
        if ply:IsAlive() and ply:GetTeamNumber() ~= myTeam then
            local pos = ply:GetHitboxPos and ply:GetHitboxPos(1) or ply:GetAbsOrigin()
            if pos and IsVisible(eye, pos, me) then
                local dist = DistanceTo(eye, pos)
                if dist < bestDist then
                    best, bestDist = ply, dist
                end
            end
        end
    end

    return best
end
```

#### FOV-based scoring

```lua
local function GetBestTargetFOV(maxFov)
    local me = entities.GetLocalPlayer()
    if not me or not me:IsAlive() then return nil end

    local eye = GetEyePos(me)
    local view = engine.GetViewAngles()
    local best, bestScore = nil, math.huge

    for _, ply in pairs(entities.FindByClass("CTFPlayer")) do
        if ply:IsAlive() and ply:GetTeamNumber() ~= me:GetTeamNumber() then
            local head = ply:GetHitboxPos and ply:GetHitboxPos(1) or ply:GetAbsOrigin()
            if head and IsVisible(eye, head, me) then
                local ang = AngleToPosition(eye, head)
                local yawDiff = math.abs((ang.yaw - view.yaw + 540) % 360 - 180)
                local pitchDiff = math.abs(ang.pitch - view.pitch)
                local fov = math.max(yawDiff, pitchDiff)
                if fov < maxFov and fov < bestScore then
                    best, bestScore = ply, fov
                end
            end
        end
    end

    return best
end
```

### Notes

- Example only: plug in your own scoring (FOV, distance, health, priority)
- Use `GetHitboxPos(1)` for head when available
- Always nil-check local player and visibility
