## Callback: SendNetMsg

> Called when a NetMessage is being sent to the server

### Pattern

```lua
callbacks.Register("SendNetMsg", "netmsg_demo", function(msg)
    local name = msg:GetName() -- if available
    -- inspect/modify if supported
end)
```

### Notes

- Message interfaces vary; use only if you know the net message type
