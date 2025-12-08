## Function/Symbol: Entity.InCond

> Check if player has a TF2 condition active

### Required Context
- Parameters: condition (E_TFCOND constant)
- Constants: E_TFCOND (TFCond_*, e.g., TFCond_Ubercharged, TFCond_Cloaked)
- Returns: boolean

### Curated Usage Examples

#### Check ubercharge
```lua
local function IsUbered(player)
    return player:InCond(TFCond_Ubercharged) or player:InCond(TFCond_Ubercharged_Hidden)
end

local target = entities.GetByIndex(idx)
if target and IsUbered(target) then
    print(target:GetName() .. " is ubered!")
end
```

#### Check cloaked spy
```lua
if target:InCond(TFCond_Cloaked) then
    print("Spy is cloaked")
end
```

#### Check if target is stunned/vulnerable
```lua
local function IsStunned(player)
    return player:InCond(TFCond_Dazed) or player:InCond(TFCond_Stunned)
end
```

### Notes
- Use TFCond_* constants from E_TFCOND enum
- Common conditions: Ubercharged, Cloaked, Kritzkrieged, Bonked, Jarated, OnFire, Bleeding
