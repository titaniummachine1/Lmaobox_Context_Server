## Function/Symbol: client.RemoveConVarProtection / client.Localize

### Signatures

```lua
client.RemoveConVarProtection(name: string)          → void
client.Localize(key: string)                         → string?
```

### Curated Usage Examples

#### Remove protection before setting a protected convar

```lua
-- Some convars are write-protected on the client.
-- RemoveConVarProtection must be called once before SetConVar will work.
client.RemoveConVarProtection("sv_cheats")
client.SetConVar("sv_cheats", "1")
```

#### Localize a TF2 string

```lua
-- TF2 localization keys start with "#"
local classname = client.Localize("#TF_Class_Name_Heavy")
-- Returns "Heavy" (in the current game language)

-- Returns nil if the key is not found
local msg = client.Localize("#NonExistentKey")
if msg then
    print(msg)
end
```

### Notes

- `RemoveConVarProtection` is permanent for the session; only needs to be called once per convar
- `Localize` returns `nil` if the key is not found in the active language file — always nil-check
- Localization keys in TF2 start with `#` (e.g. `#TF_Class_Name_Scout`, `#TF_Weapon_Shotgun`)
