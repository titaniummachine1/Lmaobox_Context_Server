## Constants Reference: E_BoneMask

> Bitfield constants for `Entity:SetupBones(boneMask, currentTime)`. Controls which subset of bones the engine computes transforms for.

### Constants

| Constant                   | Value        | Purpose                         |
| -------------------------- | ------------ | ------------------------------- |
| `BONE_USED_BY_ANYTHING`    | `0x0007FF00` | All bones used by any system    |
| `BONE_USED_BY_HITBOX`      | `0x00000100` | Only hitbox bones               |
| `BONE_USED_BY_ATTACHMENT`  | `0x00000200` | Bones driving attachment points |
| `BONE_USED_BY_VERTEX_MASK` | `0x0003FC00` | All LOD vertex bones combined   |
| `BONE_USED_BY_VERTEX_LOD0` | `0x00000400` | LOD 0 (highest detail mesh)     |
| `BONE_USED_BY_BONE_MERGE`  | `0x00040000` | Bone merge (attached models)    |

### Canonical Usage

```lua
-- Standard hitbox work — use BONE_USED_BY_ANYTHING (0x7ff00)
-- This is NOT the same as BONE_USED_BY_HITBOX alone; using only HITBOX
-- omits bones needed for some hitbox calculations.
local aBones = entity:SetupBones(0x7ff00, globals.CurTime())
```

### Notes

- **Always use `0x7ff00` (`BONE_USED_BY_ANYTHING`) for hitbox work.** Using the narrower `BONE_USED_BY_HITBOX` (`0x100`) can return incomplete bone data and cause `nil` bone lookups.
- Passing `0` as the mask may return no useful bones.
- The mask constant `BONE_USED_BY_ANYTHING` equals `0x7ff00` even though its name says "anything" — it's the union of all useful subsets for real-time work.
