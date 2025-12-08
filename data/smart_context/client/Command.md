## Function/Symbol: client.Command

> Execute a console command

### Required Context
- Parameters: cmd (string), unrestrict (boolean)
- unrestrict: bypass some restrictions

### Curated Usage Examples

#### Simple command
```lua
client.Command("kill", true)
```

#### Voicemenu (call medic)
```lua
client.Command("voicemenu 0 0", true)
```

#### Slot switch
```lua
client.Command("slot3", true)
```

#### Bind execution
```lua
client.Command("say Hello", true)
```

### Notes
- unrestrict=true bypasses some command restrictions
- Use sparingly; commands can be logged

