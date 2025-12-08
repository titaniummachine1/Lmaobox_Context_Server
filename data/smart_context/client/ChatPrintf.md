## Function/Symbol: client.ChatPrintf

> Print colored text to chat (client-side only)

### Required Context
- Color codes: \x01 white, \x02 old, \x03 name color, \x04 location, \x05 achievement, \x06 black, \x07RRGGBB custom, \x08RRGGBBAA custom with alpha

### Curated Usage Examples

```lua
client.ChatPrintf("\x07FF0000Red text \x0700FF00Green text")
```

### Notes
- Client-side only (not sent to server/other players)
- Use for debugging/notifications
