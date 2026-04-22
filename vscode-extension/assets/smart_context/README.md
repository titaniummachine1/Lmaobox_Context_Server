# Smart Context Layout

`data/smart_context` now uses a types-mirrored structure for additive context files:

- `data/smart_context/lmaobox_lua_api/Lua_Libraries/<library>/<Symbol>.md`
- `data/smart_context/lmaobox_lua_api/Lua_Classes/<Class>/<Member>.md`
- `data/smart_context/lmaobox_lua_api/Lua_Callbacks/<Callback>.md`
- `data/smart_context/lmaobox_lua_api/Lua_Globals/<Global>.md`
- `data/smart_context/lmaobox_lua_api/constants/<GroupOrConstant>.md`
- `data/smart_context/lmaobox_lua_api/entity_props/<EntityOrProp>.md`

## Rule

Smart context files should contain only extra guidance and curated usage notes.
Do not duplicate full type signatures from `types/` unless you are intentionally overriding wording.

The server automatically composes:

1. Base type context from `get_types(symbol)`.
2. Additional markdown from this folder when available.

If no additional markdown exists, the smart-context tool returns only the base type context.

## Backward Compatibility

Legacy files like `data/smart_context/custom.SomeHelper.md` and old folder patterns are still recognized during migration.
