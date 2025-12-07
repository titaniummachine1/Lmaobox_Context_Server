## Function/Symbol: custom.normalize_vector

> Signature: function normalize_vector(vec)

### Required Context:

- Types: Vector3
- Notes: Uses engine-provided `Length()`; division by zero is handled by runtime.

### Curated Usage Examples:

#### 1. Standard

```lua
local function normalize_vector(vec)
    return vec / vec:Length()
end
```

#### 2. Guard + reuse

```lua
local function normalize_vector(vec)
    if not vec or not vec.Length then return vec end
    return vec / vec:Length()
end
```
