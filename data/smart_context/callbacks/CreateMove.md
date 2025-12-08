## Callback: CreateMove

> Called every input tick with UserCmd; edit aim/move/buttons

### Pattern

```lua
callbacks.Register("CreateMove", "cm_skeleton", function(cmd)
    local me = entities.GetLocalPlayer()
    if not me or not me:IsAlive() then return end
    -- edit cmd: SetViewAngles, SetButtons, movement, sendpacket
end)
```

### Common Patterns

- Silent aim: `cmd:SetViewAngles(p, y, r)` (does not move camera)
- Button OR/AND: `cmd:SetButtons(cmd:GetButtons() | IN_JUMP)`
- Movement edits: `SetForwardMove`, `SetSideMove`
- Packet choke: `cmd:SetSendPacket(false)`

### Notes

- Use IN\_\* constants for buttons
- Combine with helpers: GetEyePos, AngleToPosition, IsVisible
