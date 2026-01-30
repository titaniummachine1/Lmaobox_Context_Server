-------------------------------
-- CONFIGURATION
-------------------------------
local config = {
    polygon = {
        enabled = true, -- Set to true to display impact circle
        r = 255,
        g = 200,
        b = 155,
        a = 25,
        size = 10,
        segments = 20,
    },
    line = {
        enabled = true,
        r = 255,
        g = 255,
        b = 255,
        a = 255,
    },
    flags = {
        enabled = true,
        r = 255,
        g = 0,
        b = 0,
        a = 255,
        size = 5,
    },
    outline = {
        line_and_flags = true,
        polygon = true,
        r = 0,
        g = 0,
        b = 0,
        a = 155,
    },
    measure_segment_size = 2.5, -- Range: 0.5 to 8; lower values = worse performance
}

-------------------------------
-- UTILITY FUNCTIONS
-------------------------------
local function cross(a, b, c)
    return (b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1])
end

local function clamp(val, minVal, maxVal)
    if val < minVal then return minVal end
    if val > maxVal then return maxVal end
    return val
end

-- Aliases for external functions:
local traceHull       = engine.TraceHull
local traceLine       = engine.TraceLine
local worldToScreen   = client.WorldToScreen
local texturedPolygon = draw.TexturedPolygon
local drawLine        = draw.Line
local setColor        = draw.Color

-------------------------------
-- ITEM DEFINITIONS MAPPING
-------------------------------
local ItemDefinitions = {}
do
    local defs = {
        [222] = 11,
        [812] = 12,
        [833] = 12,
        [1121] = 11,
        [18] = -1,
        [205] = -1,
        [127] = -1,
        [228] = -1,
        [237] = -1,
        [414] = -1,
        [441] = -1,
        [513] = -1,
        [658] = -1,
        [730] = -1,
        [800] = -1,
        [809] = -1,
        [889] = -1,
        [898] = -1,
        [907] = -1,
        [916] = -1,
        [965] = -1,
        [974] = -1,
        [1085] = -1,
        [1104] = -1,
        [15006] = -1,
        [15014] = -1,
        [15028] = -1,
        [15043] = -1,
        [15052] = -1,
        [15057] = -1,
        [15081] = -1,
        [15104] = -1,
        [15105] = -1,
        [15129] = -1,
        [15130] = -1,
        [15150] = -1,
        [442] = -1,
        [1178] = -1,
        [39] = 8,
        [351] = 8,
        [595] = 8,
        [740] = 8,
        [1180] = 0,
        [19] = 5,
        [206] = 5,
        [308] = 5,
        [996] = 6,
        [1007] = 5,
        [1151] = 4,
        [15077] = 5,
        [15079] = 5,
        [15091] = 5,
        [15092] = 5,
        [15116] = 5,
        [15117] = 5,
        [15142] = 5,
        [15158] = 5,
        [20] = 1,
        [207] = 1,
        [130] = 3,
        [265] = 3,
        [661] = 1,
        [797] = 1,
        [806] = 1,
        [886] = 1,
        [895] = 1,
        [904] = 1,
        [913] = 1,
        [962] = 1,
        [971] = 1,
        [1150] = 2,
        [15009] = 1,
        [15012] = 1,
        [15024] = 1,
        [15038] = 1,
        [15045] = 1,
        [15048] = 1,
        [15082] = 1,
        [15083] = 1,
        [15084] = 1,
        [15113] = 1,
        [15137] = 1,
        [15138] = 1,
        [15155] = 1,
        [588] = -1,
        [997] = 9,
        [17] = 10,
        [204] = 10,
        [36] = 10,
        [305] = 9,
        [412] = 10,
        [1079] = 9,
        [56] = 7,
        [1005] = 7,
        [1092] = 7,
        [58] = 11,
        [1083] = 11,
        [1105] = 11,
    }
    local maxIndex = 0
    for k, _ in pairs(defs) do
        if k > maxIndex then maxIndex = k end
    end
    for i = 1, maxIndex do
        ItemDefinitions[i] = defs[i] or false
    end
end

-------------------------------
-- PHYSICS ENVIRONMENT CLASS
-------------------------------
local PhysicsEnv = {}
PhysicsEnv.__index = PhysicsEnv

function PhysicsEnv:new()
    local env = physics.CreateEnvironment()
    env:SetGravity(Vector3(0, 0, -800))
    env:SetAirDensity(2.0)
    env:SetSimulationTimestep(1 / 66)
    self = setmetatable({
        env = env,
        objects = {},
        activeIndex = 0,
    }, PhysicsEnv)
    return self
end

function PhysicsEnv:initializeObjects()
    if #self.objects > 0 then return end
    local function addObject(path)
        local solid, model = physics.ParseModelByName(path)
        local obj = self.env:CreatePolyObject(model, solid:GetSurfacePropName(), solid:GetObjectParameters())
        table.insert(self.objects, obj)
    end
    addObject("models/weapons/w_models/w_stickybomb.mdl")                                       -- Stickybomb
    addObject("models/workshop/weapons/c_models/c_kingmaker_sticky/w_kingmaker_stickybomb.mdl") -- QuickieBomb
    addObject("models/weapons/w_models/w_stickybomb_d.mdl")                                     -- ScottishResistance, StickyJumper
    if #self.objects > 0 then
        self.objects[1]:Wake()
        self.activeIndex = 1
    end
end

function PhysicsEnv:destroyObjects()
    self.activeIndex = 0
    for i, obj in ipairs(self.objects) do
        self.env:DestroyObject(obj)
    end
    self.objects = {}
end

function PhysicsEnv:getObject(index)
    if index ~= self.activeIndex then
        self.objects[self.activeIndex]:Sleep()
        self.objects[index]:Wake()
        self.activeIndex = index
    end
    return self.objects[self.activeIndex]
end

function PhysicsEnv:simulate(dt)
    self.env:Simulate(dt)
end

function PhysicsEnv:reset()
    self.env:ResetSimulationClock()
end

function PhysicsEnv:destroy()
    self:destroyObjects()
    physics.DestroyEnvironment(self.env)
end

-------------------------------
-- TRAJECTORY LINE CLASS
-------------------------------
local TrajectoryLine = {}
TrajectoryLine.__index = TrajectoryLine

function TrajectoryLine:new()
    self = setmetatable({}, TrajectoryLine)
    self.positions = {}
    self.flagOffset = Vector3(0, 0, 0)
    return self
end

function TrajectoryLine:clear()
    self.positions = {}
end

function TrajectoryLine:insert(pos)
    table.insert(self.positions, pos)
end

-- Draw an outlined line for better visibility.
local function drawOutlinedLine(from, to)
    setColor(config.outline.r, config.outline.g, config.outline.b, config.outline.a)
    if math.abs(from[1] - to[1]) > math.abs(from[2] - to[2]) then
        drawLine(from[1], from[2] - 1, to[1], to[2] - 1)
        drawLine(from[1], from[2] + 1, to[1], to[2] + 1)
    else
        drawLine(from[1] - 1, from[2], to[1] - 1, to[2])
        drawLine(from[1] + 1, from[2], to[1] + 1, to[2])
    end
end

function TrajectoryLine:render()
    local num = #self.positions
    if num < 2 then return end
    local lastScreen = nil
    for i = num, 1, -1 do
        local worldPos = self.positions[i]
        local screenPos = worldToScreen(worldPos)
        local flagScreenPos = worldToScreen(worldPos + self.flagOffset)
        if lastScreen and screenPos then
            if config.line.enabled then
                if config.outline.line_and_flags then
                    drawOutlinedLine(lastScreen, screenPos)
                end
                setColor(config.line.r, config.line.g, config.line.b, config.line.a)
                drawLine(lastScreen[1], lastScreen[2], screenPos[1], screenPos[2])
            end
            if config.flags.enabled and flagScreenPos then
                if config.outline.line_and_flags then
                    drawOutlinedLine(flagScreenPos, screenPos)
                end
                setColor(config.flags.r, config.flags.g, config.flags.b, config.flags.a)
                drawLine(flagScreenPos[1], flagScreenPos[2], screenPos[1], screenPos[2])
            end
        end
        lastScreen = screenPos
    end
end

-------------------------------
-- IMPACT POLYGON CLASS
-------------------------------
local ImpactPolygon = {}
ImpactPolygon.__index = ImpactPolygon

function ImpactPolygon.new()
    local tex = draw.CreateTextureRGBA(string.char(
        0xff, 0xff, 0xff, config.polygon.a,
        0xff, 0xff, 0xff, config.polygon.a,
        0xff, 0xff, 0xff, config.polygon.a,
        0xff, 0xff, 0xff, config.polygon.a
    ), 2, 2)
    local instance = setmetatable({
        texture = tex,
        segments = config.polygon.segments,
        segAngleOffset = math.pi / config.polygon.segments,
        segAngle = (math.pi / config.polygon.segments) * 2,
    }, ImpactPolygon)
    return instance
end

function ImpactPolygon:draw(plane, origin)
    if not config.polygon.enabled then return end
    local positions = {}
    local radius = config.polygon.size
    if math.abs(plane.z) >= 0.99 then
        for i = 1, self.segments do
            local ang = i * self.segAngle + self.segAngleOffset
            local pos = worldToScreen(origin + Vector3(radius * math.cos(ang), radius * math.sin(ang), 0))
            if not pos then return end
            positions[i] = pos
        end
    else
        local right = Vector3(-plane.y, plane.x, 0)
        local up = Vector3(plane.z * right.y, -plane.z * right.x, (plane.y * right.x) - (plane.x * right.y))
        radius = radius / math.cos(math.asin(plane.z))
        for i = 1, self.segments do
            local ang = i * self.segAngle + self.segAngleOffset
            local pos = worldToScreen(origin + (right * (radius * math.cos(ang))) + (up * (radius * math.sin(ang))))
            if not pos then return end
            positions[i] = pos
        end
    end

    -- Draw outline if enabled.
    if config.outline.polygon then
        setColor(config.outline.r, config.outline.g, config.outline.b, config.outline.a)
        local last = positions[#positions]
        for i = 1, #positions do
            local cur = positions[i]
            drawLine(last[1], last[2], cur[1], cur[2])
            last = cur
        end
    end

    -- Draw filled polygon.
    setColor(config.polygon.r, config.polygon.g, config.polygon.b, 255)
    local pts, ptsReversed = {}, {}
    local sum = 0
    for i, pos in ipairs(positions) do
        local pt = { pos[1], pos[2], 0, 0 }
        pts[i] = pt
        ptsReversed[#positions - i + 1] = pt
        local nextPos = positions[(i % #positions) + 1]
        sum = sum + cross(pos, nextPos, positions[1])
    end
    local polyPts = (sum < 0) and ptsReversed or pts
    texturedPolygon(self.texture, polyPts, true)

    -- Draw final outline.
    local last = positions[#positions]
    for i = 1, #positions do
        local cur = positions[i]
        drawLine(last[1], last[2], cur[1], cur[2])
        last = cur
    end
end

function ImpactPolygon:destroy()
    if self.texture then
        draw.DeleteTexture(self.texture)
        self.texture = nil
    end
end

----------------------------------------
-- PROJECTILE INFORMATION FUNCTION
----------------------------------------
-- Returns (offset, forward velocity, upward velocity, collision hull, gravity, drag)
local function GetProjectileInformation(pWeapon, bDucking, iCase, iDefIndex, iWepID, pLocal)
    local chargeTime = pWeapon:GetPropFloat("m_flChargeBeginTime") or 0
    if chargeTime ~= 0 then
        chargeTime = globals.CurTime() - chargeTime
    end

    -- Predefined offsets and collision sizes:
    local offsets = {
        Vector3(16, 8, -6),    -- Index 1: Sticky Bomb, Iron Bomber, etc.
        Vector3(23.5, -8, -3), -- Index 2: Huntsman, Crossbow, etc.
        Vector3(23.5, 12, -3), -- Index 3: Flare Gun, Guillotine, etc.
        Vector3(16, 6, -8)     -- Index 4: Syringe Gun, etc.
    }
    local collisionMaxs = {
        Vector3(0, 0, 0), -- For projectiles that use TRACE_LINE (e.g. rockets)
        Vector3(1, 1, 1),
        Vector3(2, 2, 2),
        Vector3(3, 3, 3)
    }

    if iCase == -1 then
        -- Rocket Launcher types: force a zero collision hull so that TRACE_LINE is used.
        local vOffset = Vector3(23.5, -8, bDucking and 8 or -3)
        local vCollisionMax = collisionMaxs[1] -- Zero hitbox
        local fForwardVelocity = 1200
        if iWepID == 22 or iWepID == 65 then
            vOffset.y = (iDefIndex == 513) and 0 or 12
            fForwardVelocity = (iWepID == 65) and 2000 or ((iDefIndex == 414) and 1550 or 1100)
        elseif iWepID == 109 then
            vOffset.y, vOffset.z = 6, -3
        else
            fForwardVelocity = 1200
        end
        return vOffset, fForwardVelocity, 0, vCollisionMax, 0, nil
    elseif iCase == 1 then
        return offsets[1], 900 + clamp(chargeTime / 4, 0, 1) * 1500, 200, collisionMaxs[3], 0, nil
    elseif iCase == 2 then
        return offsets[1], 900 + clamp(chargeTime / 1.2, 0, 1) * 1500, 200, collisionMaxs[3], 0, nil
    elseif iCase == 3 then
        return offsets[1], 900 + clamp(chargeTime / 4, 0, 1) * 1500, 200, collisionMaxs[3], 0, nil
    elseif iCase == 4 then
        return offsets[1], 1200, 200, collisionMaxs[4], 400, 0.45
    elseif iCase == 5 then
        local vel = (iDefIndex == 308) and 1500 or 1200
        local drag = (iDefIndex == 308) and 0.225 or 0.45
        return offsets[1], vel, 200, collisionMaxs[4], 400, drag
    elseif iCase == 6 then
        return offsets[1], 1440, 200, collisionMaxs[3], 560, 0.5
    elseif iCase == 7 then
        return offsets[2], 1800 + clamp(chargeTime, 0, 1) * 800, 0, collisionMaxs[2], 200 - clamp(chargeTime, 0, 1) * 160,
            nil
    elseif iCase == 8 then
        -- Flare Gun: Use a small nonzero collision hull and a higher drag value to make drag noticeable.
        return Vector3(23.5, 12, bDucking and 8 or -3), 2000, 0, Vector3(0.1, 0.1, 0.1), 120, 0.5
    elseif iCase == 9 then
        local idx = (iDefIndex == 997) and 2 or 4
        return offsets[2], 2400, 0, collisionMaxs[idx], 80, nil
    elseif iCase == 10 then
        return offsets[4], 1000, 0, collisionMaxs[2], 120, nil
    elseif iCase == 11 then
        return Vector3(23.5, 8, -3), 1000, 200, collisionMaxs[4], 450, nil
    elseif iCase == 12 then
        return Vector3(23.5, 8, -3), 3000, 300, collisionMaxs[3], 900, 1.3
    end
end


-------------------------------
-- GLOBALS & INITIALIZATION
-------------------------------
local physicsEnv = PhysicsEnv:new()
local trajectoryLine = TrajectoryLine:new()
local impactPolygon = ImpactPolygon:new()

local g_fTraceInterval = clamp(config.measure_segment_size, 0.5, 8) / 66
local g_fFlagInterval = g_fTraceInterval * 1320

-------------------------------
-- MAIN SIMULATION CALLBACK
-------------------------------
callbacks.Register("CreateMove", "LoadPhysicsObjects", function()
    callbacks.Unregister("CreateMove", "LoadPhysicsObjects")
    physicsEnv:initializeObjects()

    callbacks.Register("Draw", function()
        trajectoryLine:clear()
        if engine.Con_IsVisible() or engine.IsGameUIVisible() then return end

        local pLocal = entities.GetLocalPlayer()
        if not pLocal or pLocal:InCond(7) or not pLocal:IsAlive() then return end

        local pWeapon = pLocal:GetPropEntity("m_hActiveWeapon")
        if not pWeapon or (pWeapon:GetWeaponProjectileType() or 0) < 2 then return end

        local iItemDefinitionIndex = pWeapon:GetPropInt("m_iItemDefinitionIndex")
        local iItemDefinitionType = ItemDefinitions[iItemDefinitionIndex] or 0
        if iItemDefinitionType == 0 then return end

        local vOffset, fForwardVelocity, fUpwardVelocity, vCollisionMax, fGravity, fDrag =
            GetProjectileInformation(pWeapon, (pLocal:GetPropInt("m_fFlags") & FL_DUCKING) == 2,
                iItemDefinitionType, iItemDefinitionIndex, pWeapon:GetWeaponID(), pLocal)
        local vCollisionMin = -vCollisionMax

        local vStartPosition = pLocal:GetAbsOrigin() + pLocal:GetPropVector("localdata", "m_vecViewOffset[0]")
        local vStartAngle = engine.GetViewAngles()

        local results = traceHull(
            vStartPosition,
            vStartPosition +
            (vStartAngle:Forward() * vOffset.x) +
            (vStartAngle:Right() * (vOffset.y * (pWeapon:IsViewModelFlipped() and -1 or 1))) +
            (vStartAngle:Up() * vOffset.z),
            vCollisionMin, vCollisionMax, 100679691
        )
        if results.fraction ~= 1 then return end
        vStartPosition = results.endpos

        -- Adjust view angle for rockets and for some projectiles if needed.
        if iItemDefinitionType == -1 or ((iItemDefinitionType >= 7 and iItemDefinitionType < 11) and fForwardVelocity ~= 0) then
            local res = traceLine(results.startpos, results.startpos + (vStartAngle:Forward() * 2000), 100679691)
            vStartAngle = (((res.fraction <= 0.1) and (results.startpos + (vStartAngle:Forward() * 2000)) or res.endpos)
                - vStartPosition):Angles()
        end

        local vVelocity = (vStartAngle:Forward() * fForwardVelocity) + (vStartAngle:Up() * fUpwardVelocity)
        trajectoryLine.flagOffset = vStartAngle:Right() * -config.flags.size
        trajectoryLine:insert(vStartPosition)

        if iItemDefinitionType == -1 then
            results = traceHull(vStartPosition, vStartPosition + (vStartAngle:Forward() * 10000),
                vCollisionMin, vCollisionMax, 100679691)
            if results.startsolid then return end
            local segCount = math.floor((results.endpos - results.startpos):Length() / g_fFlagInterval)
            local vForward = vStartAngle:Forward()
            for i = 1, segCount do
                trajectoryLine:insert(vForward * (i * g_fFlagInterval) + vStartPosition)
            end
            trajectoryLine:insert(results.endpos)
        elseif iItemDefinitionType > 3 then
            local vPos = Vector3(0, 0, 0)
            for i = 0.01515, 5, g_fTraceInterval do
                local scalar = (fDrag == nil) and i or ((1 - math.exp(-fDrag * i)) / fDrag)
                vPos.x = vVelocity.x * scalar + vStartPosition.x
                vPos.y = vVelocity.y * scalar + vStartPosition.y
                vPos.z = (vVelocity.z - fGravity * i) * scalar + vStartPosition.z

                -- Use hull trace if collision hull is nonzero.
                if vCollisionMax.x ~= 0 then
                    results = traceHull(results.endpos, vPos, vCollisionMin, vCollisionMax, 100679691)
                else
                    results = traceLine(vStartPosition, vStartPosition + (vStartAngle:Forward() * 10000), 100679691)
                end
                trajectoryLine:insert(results.endpos)
                if results.fraction ~= 1 then break end
            end
        else
            local obj = physicsEnv:getObject(iItemDefinitionType)
            obj:SetPosition(vStartPosition, vStartAngle, true)
            obj:SetVelocity(vVelocity, Vector3(0, 0, 0))
            for i = 2, 330 do
                results = traceHull(results.endpos, obj:GetPosition(), vCollisionMin, vCollisionMax, 100679691)
                trajectoryLine:insert(results.endpos)
                if results.fraction ~= 1 then break end
                physicsEnv:simulate(g_fTraceInterval)
            end
            physicsEnv:reset()
        end

        if #trajectoryLine.positions == 0 then return end
        if results and results.plane then
            impactPolygon:draw(results.plane, results.endpos)
        end
        if #trajectoryLine.positions > 1 then
            trajectoryLine:render()
        end
    end)
end)

-------------------------------
-- UNLOAD CALLBACK
-------------------------------
callbacks.Register("Unload", function()
    physicsEnv:destroy()
    impactPolygon:destroy()
end)
