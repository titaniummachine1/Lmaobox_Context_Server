## Class: UserMessage

> Received as the sole argument in the `"DispatchUserMessage"` callback. Represents a network message from the server.

### Key Methods

- `GetID()` → `E_UserMessage` — message type ID
- `GetBitBuffer()` → `BitBuffer` — **preferred** access to the message payload (see `BitBuffer/index.md`)

### Deprecated Direct Read Methods (use BitBuffer instead)

The following methods on `UserMessage` are deprecated. Prefer calling `GetBitBuffer()` once and reading from the `BitBuffer` object — it provides the same reads plus write support and reuse.

| Deprecated Method    | Equivalent BitBuffer Call  |
| -------------------- | -------------------------- |
| `ReadBit()`          | `buf:ReadBit()`            |
| `ReadByte()`         | `buf:ReadByte()`           |
| `ReadFloat(n?)`      | `buf:ReadFloat(n?)`        |
| `ReadInt(n?)`        | `buf:ReadInt(n?)`          |
| `ReadString(maxlen)` | `buf:ReadString(maxlen)`   |
| `Reset()`            | `buf:Reset()`              |
| `SetCurBit(bit)`     | `buf:SetCurBit(bit)`       |
| `GetCurBit()`        | `buf:GetCurBit()`          |
| `GetDataBits()`      | `buf:GetDataBitsLength()`  |
| `GetDataBytes()`     | `buf:GetDataBytesLength()` |

### Curated Usage Patterns

#### Read a known message structure

```lua
callbacks.Register("DispatchUserMessage", "read_damage", function(msg)
    -- E_UserMessage constants identify the message type
    if msg:GetID() ~= E_UserMessage.Damage then return end

    local buf = msg:GetBitBuffer()
    -- Read fields in order matching the server's write order
    local damageAmount = buf:ReadInt(8)  -- 8-bit integer
    local victimID     = buf:ReadInt(16)
    print("Damage:", damageAmount, "to player index:", victimID)
end)
```

#### Re-read the same message

```lua
callbacks.Register("DispatchUserMessage", "inspect", function(msg)
    local buf = msg:GetBitBuffer()

    -- First pass
    local firstByte = buf:ReadByte()
    print("First byte:", firstByte)

    -- Reset and read again
    buf:Reset()
    local sameFirstByte = buf:ReadByte()
    print("Reread:", sameFirstByte)
end)
```

#### Write-back (modify message before dispatch)

```lua
callbacks.Register("DispatchUserMessage", "mute_voice", function(msg)
    if msg:GetID() ~= E_UserMessage.VoiceSubtitle then return end

    local buf = msg:GetBitBuffer()
    local playerIdx = buf:ReadInt(8)

    -- Seek back and overwrite to mute a specific player
    buf:SetCurBit(0)
    buf:WriteInt(0, 8)  -- replace player index with 0
end)
```

### Notes

- `GetBitBuffer()` returns the **same** buffer object every call within the same callback invocation — do not call it multiple times thinking you get a fresh copy.
- All read/write methods return `value, currentBitPos` — the second return is often ignored.
- The bit layout of messages is not documented by Valve; read order must match the server's write order. Use AlliedModders wiki for field layouts.
- After the callback returns, the `UserMessage` and its `BitBuffer` are **invalid**. Do not store references.
