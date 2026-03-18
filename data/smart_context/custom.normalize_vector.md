## Function/Symbol: custom.normalize_vector

> Signature: function normalize_vector(vec)

### Required Context:

- Types: Vector3
- Notes: Uses engine-provided `Length()`; division by zero is handled by runtime.

### Curated Usage Examples:

#### 1. Standard

```lua
--fastest method
function Normalize(vec)
    return vector.Divide(vec, vec:Length())
end
```

```lua
local function normalize_vector(vec)
    return vec / vec:Length()
end
```
