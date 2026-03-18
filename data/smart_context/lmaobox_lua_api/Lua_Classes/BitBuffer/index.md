## Class: BitBuffer

> A mutable bitstream for reading and writing binary data. Preferred over deprecated `UserMessage` direct-read methods. Also used for `NetMessage` payloads.

### Constructor

```lua
local buf = BitBuffer()  -- creates an empty writable buffer
```

Or obtained from `UserMessage:GetBitBuffer()`.

### Reading Methods

| Method                  | Returns      | Description                                |
| ----------------------- | ------------ | ------------------------------------------ |
| `GetDataBitsLength()`   | `integer`    | Total bits in buffer                       |
| `GetDataBytesLength()`  | `integer`    | Total bytes in buffer                      |
| `GetCurBit()`           | `integer`    | Current read/write head position (in bits) |
| `Reset()`               | —            | Seek to start (bit 0)                      |
| `ReadByte()`            | `byte, pos`  | Read 1 byte                                |
| `ReadBit()`             | `bit, pos`   | Read 1 bit                                 |
| `ReadInt(bitLength?)`   | `int, pos`   | Read integer (default 32 bits)             |
| `ReadFloat(bitLength?)` | `float, pos` | Read float (default 32 bits)               |
| `ReadString(maxlen)`    | `str, pos`   | Read null-terminated or maxlen string      |

### Writing Methods

| Method                          | Description                                                         |
| ------------------------------- | ------------------------------------------------------------------- |
| `SetCurBit(pos)`                | Seek to bit position                                                |
| `WriteBit(bit)`                 | Write 1 bit                                                         |
| `WriteByte(byte)`               | Write 1 byte                                                        |
| `WriteInt(int, bitLength?)`     | Write integer (default 32 bits)                                     |
| `WriteFloat(float, bitLength?)` | Write float (default 32 bits)                                       |
| `WriteString(str)`              | Write string                                                        |
| `Delete()`                      | **Required:** free the buffer when done with a manually created one |

### Curated Usage Patterns

#### Read a packed UserMessage

```lua
callbacks.Register("DispatchUserMessage", "read_msg", function(msg)
    local buf = msg:GetBitBuffer()

    -- Reads advance the bit position automatically
    local flags   = buf:ReadByte()      -- 8 bits
    local health  = buf:ReadInt(16)     -- 16-bit short int
    local name    = buf:ReadString(64)  -- up to 64 chars
    print("flags:", flags, "health:", health, "name:", name)
end)
```

#### Create and write a custom buffer

```lua
local buf = BitBuffer()
buf:WriteInt(42, 8)        -- 8-bit int
buf:WriteFloat(3.14)       -- 32-bit float
buf:WriteString("hello")

-- Must delete when done with manually constructed buffers
buf:Delete()
```

#### Seek and re-read

```lua
local buf = msg:GetBitBuffer()
local pos1 = buf:GetCurBit()  -- save position

local first = buf:ReadInt(32)
buf:SetCurBit(pos1)            -- rewind
local sameFirst = buf:ReadInt(32)  -- reads the same data
```

### Notes

- `ReadInt`/`ReadFloat` default to **32 bits**. For compact message fields, pass explicit bit widths (8, 16, 64).
- All read methods return **two values**: `(value, currentBitPos)`. You can ignore the second.
- **`Delete()` is required** for buffers you create with `BitBuffer()`. Buffers from `UserMessage:GetBitBuffer()` are managed by the engine — do not call `Delete()` on them.
- Buffers obtained from `UserMessage` are **invalid after the callback returns**. Do not cache them.
