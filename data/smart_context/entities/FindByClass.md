## Function/Symbol: entities.FindByClass

> Find all entities of a specific class

### Required Context

- Returns: table of Entity objects
- Types: Entity
- Common classes: "CTFPlayer", "CTFWeaponBase", "CObjectSentrygun", "obj\_\*"

### Curated Usage Examples

#### Find all players

```lua
local players = entities.FindByClass("CTFPlayer")

for _, player in pairs(players) do
    if player:IsAlive() then
        print(player:GetName() .. " - HP: " .. player:GetHealth())
    end
end
```

#### Find enemy players

```lua
local me = entities.GetLocalPlayer()
if not me then return end

local myTeam = me:GetTeamNumber()
local players = entities.FindByClass("CTFPlayer")
local enemies = {}

for _, player in pairs(players) do
    if player:IsAlive() and player:GetTeamNumber() ~= myTeam and player ~= me then
        table.insert(enemies, player)
    end
end

print("Found " .. #enemies .. " enemies")
```

#### Find sentry guns

```lua
local sentries = entities.FindByClass("CObjectSentrygun")

for _, sentry in pairs(sentries) do
    if sentry:GetTeamNumber() ~= me:GetTeamNumber() then
        local sentryPos = sentry:GetAbsOrigin()
        local dist = (sentryPos - me:GetAbsOrigin()):Length()
        print("Enemy sentry at distance: " .. math.floor(dist))
    end
end
```

#### Find health packs

```lua
-- Health packs are "item_healthkit_*"
local healthPacks = {}

-- Try all health pack variants
local classes = {
    "item_healthkit_small",
    "item_healthkit_medium",
    "item_healthkit_full"
}

for _, className in ipairs(classes) do
    local packs = entities.FindByClass(className)
    for _, pack in pairs(packs) do
        table.insert(healthPacks, pack)
    end
end

print("Found " .. #healthPacks .. " health packs")
```

#### Find projectiles

```lua
-- Find rockets, pipes, stickies
local projectiles = {}

local projClasses = {
    "CTFProjectile_Rocket",
    "CTFProjectile_Pipe",
    "CTFProjectile_Flare",
    "CTFGrenadePipebombProjectile"
}

for _, className in ipairs(projClasses) do
    local projs = entities.FindByClass(className)
    for _, proj in pairs(projs) do
        if proj:GetTeamNumber() ~= me:GetTeamNumber() then
            table.insert(projectiles, proj)
        end
    end
end

-- Track incoming projectiles
for _, proj in pairs(projectiles) do
    local projPos = proj:GetAbsOrigin()
    local dist = (projPos - me:GetAbsOrigin()):Length()
    print("Incoming projectile at " .. math.floor(dist) .. " units")
end
```

### Common TF2 Classes

- **Players**: `"CTFPlayer"`
- **Buildings**: `"CObjectSentrygun"`, `"CObjectDispenser"`, `"CObjectTeleporter"`
- **Projectiles**: `"CTFProjectile_Rocket"`, `"CTFProjectile_Pipe"`, `"CTFGrenadePipebombProjectile"`
- **Pickups**: `"item_healthkit_*"`, `"item_ammopack_*"`
- **Intel**: `"item_teamflag"`

### Notes

- Returns **empty table** if no entities found (never nil)
- Result includes **all entities** of that class (dead, dormant, etc)
- **Filter results** based on your needs (alive, team, distance)
- More specific class names are faster than generic ones
