## Callback: DispatchUserMessage

> Called for every user message received from server

### Pattern

```lua
callbacks.Register("DispatchUserMessage", "usermsg_demo", function(msg)
    local id = msg:GetID()
    local size = msg:GetSize()
    -- parse based on ID / protobuf if known
end)
```

### Notes

- Message fields depend on game; often requires protobuf/bit reading
- Use selectively; can be frequent
