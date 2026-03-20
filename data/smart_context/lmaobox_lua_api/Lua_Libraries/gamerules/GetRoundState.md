## Function/Symbol: gamerules.GetRoundState

> Returns the current round state as an integer matching the `E_RoundState` / `ROUND_*` constants.

### Signature

```lua
gamerules.GetRoundState() -> integer
```

### Round State Constants

| Constant               | Value | Meaning                    |
| ---------------------- | ----- | -------------------------- |
| `ROUND_INIT`           | 0     | Map just loaded            |
| `ROUND_PREGAME`        | 1     | Waiting for players        |
| `ROUND_STARTGAME`      | 2     | Game starting              |
| `ROUND_PREROUND`       | 3     | Setup phase (doors locked) |
| `ROUND_RUNNING`        | 4     | Round actively in progress |
| `ROUND_TEAMWIN`        | 5     | A team just won the round  |
| `ROUND_RESTART`        | 6     | Map restarting             |
| `ROUND_STALEMATE`      | 7     | Sudden death / stalemate   |
| `ROUND_GAMEOVER`       | 8     | Game over                  |
| `ROUND_BONUS`          | 9     | Humiliation / bonus time   |
| `ROUND_BETWEEN_ROUNDS` | 10    | Between rounds             |

### Curated Usage Examples

#### Gate aimbot to active round only

```lua
local function IsRoundActive()
    local state = gamerules.GetRoundState()
    return state == ROUND_RUNNING
end

callbacks.Register("CreateMove", "gated_aimbot", function(cmd)
    if not IsRoundActive() then return end
    -- aimbot logic here
end)
```

#### Detect setup phase (preround)

```lua
local function IsPreRound()
    local state = gamerules.GetRoundState()
    return state == ROUND_PREROUND or state == ROUND_STARTGAME
end

local function IsRoundOver()
    local state = gamerules.GetRoundState()
    return state == ROUND_TEAMWIN
        or state == ROUND_STALEMATE
        or state == ROUND_GAMEOVER
        or state == ROUND_BONUS
end
```

#### Full round state label (for HUD debug)

```lua
local ROUND_NAMES = {
    [ROUND_INIT]           = "Init",
    [ROUND_PREGAME]        = "Pregame",
    [ROUND_STARTGAME]      = "Starting",
    [ROUND_PREROUND]       = "Pre-round",
    [ROUND_RUNNING]        = "Running",
    [ROUND_TEAMWIN]        = "Team Won",
    [ROUND_RESTART]        = "Restart",
    [ROUND_STALEMATE]      = "Stalemate",
    [ROUND_GAMEOVER]       = "Game Over",
    [ROUND_BONUS]          = "Bonus Time",
    [ROUND_BETWEEN_ROUNDS] = "Between Rounds",
}

callbacks.Register("Draw", "round_state_hud", function()
    local state = gamerules.GetRoundState()
    local label = ROUND_NAMES[state] or ("Unknown(" .. tostring(state) .. ")")
    draw.Color(255, 255, 255, 200)
    draw.Text(10, 50, "Round: " .. label)
end)
```

#### Don't fire at humiliation / game over

```lua
local function ShouldHoldFire()
    local state = gamerules.GetRoundState()
    return state == ROUND_BONUS
        or state == ROUND_GAMEOVER
        or state == ROUND_TEAMWIN
        or state == ROUND_BETWEEN_ROUNDS
end
```

### Notes

- Constants are global integers — compare with `==`, not bitwise
- `ROUND_RUNNING` is the only state where normal gameplay is active
- During `ROUND_BONUS` players are in humiliation; shooting does nothing useful
- `gamerules` can return nil early in map load — guard with a nil check if called outside callbacks
