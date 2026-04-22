## Function/Symbol: custom.GetBestTarget

> Select the best enemy target (example skeleton)

### Required Context

- Functions: entities.FindByClass, Entity:IsAlive, Entity:GetTeamNumber, IsVisible, DistanceTo, AngleToPosition
- Types: Entity, Vector3
- Constants: TEAM (2/3 in TF2), MASK_SHOT_HULL for visibility
- Treat dormant players as invalid for targeting; their props can be stale even if the entity handle still exists

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
        if ply:IsAlive() and not ply:IsDormant() and ply:GetTeamNumber() ~= myTeam then
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
        if ply:IsAlive() and not ply:IsDormant() and ply:GetTeamNumber() ~= me:GetTeamNumber() then
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
- If lnxLib is available, use `WPlayer:GetHitboxPos(E_Hitbox.Head)` for head center — it wraps the SetupBones pipeline internally and is the preferred approach over raw index probing (`GetHitboxPos(1)` is a plain-Lua fallback for non-lnxLib contexts)
- Always nil-check local player and visibility
- Common target-table shape is `entity`, `angles`, and `factor`
- Projectile-oriented target tables may additionally include `pos`
- If hitbox data is stale or the player is dormant, do not silently fall back into targeting logic as if the target were valid
