# Lmaobox Lua API Type Definitions

This folder contains comprehensive type definitions for the Lmaobox Lua API to enable proper linting, autocompletion, and type checking in VS Code.

## Auto-Update

The Lua runtime version is set to **Lua 5.4** in `.luarc.json`, which will automatically use the latest 5.4.x version as the language server updates.

## File Organization

Type definitions are organized into subdirectories:

### Core API

- **`lmaobox.d.lua`** - Core Lmaobox API type definitions (client, draw, engine, entities, etc.)

### Constants (`constants/`)

All constants organized by category for easy maintenance:

- **`lmaobox_constants.d.lua`** - General constants (input keys, button codes, life states, teams, character classes)
- **`lmaobox_constants_tf2.d.lua`** - TF2 condition flags (TFCond\_\*)
- **`lmaobox_constants_weapons.d.lua`** - Weapon IDs (TF_WEAPON\_\*) and loadout slots
- **`lmaobox_constants_misc.d.lua`** - Player flags, round states, projectiles, runes, frame stages
- **`lmaobox_constants_trace.d.lua`** - Trace/contents flags and masks for collision detection
- **`lmaobox_constants_kill_effects.d.lua`** - Custom kill effects (TF_CUSTOM\_\*)
- **`lmaobox_constants_rendering.d.lua`** - Font flags, material flags, clear flags, bone masks
- **`lmaobox_constants_system.d.lua`** - File attributes, GC results, match abandon status

### Entity Properties (`entity_props/`)

All entity property definitions organized by entity type:

- **`entity_base.d.lua`** - Base entity properties (CBaseEntity)
- **`entity_player.d.lua`** - Player entity properties (CTFPlayer)
- **`entity_weapons.d.lua`** - Weapon entity properties
- **`entity_projectiles.d.lua`** - Projectile entity properties
- **`entity_buildings.d.lua`** - Building entity properties
- **`entity_items.d.lua`** - Item entity properties

## How It Works

All `.d.lua` files in this directory and subdirectories are automatically loaded by the Lua Language Server when `${workspace}/types` is included in `Lua.workspace.library`. No require statements needed!

## Auto-Update Check

Type definitions are automatically checked for updates when you:

1. Run the VS Code task: "Check Type Definitions" (Ctrl+Shift+P → "Tasks: Run Task")
2. Or manually run: `node automations/update-types.js`

The script:

- Checks the Lmaobox API sitemap for changes
- Verifies all required type definition files exist
- Warns if updates may be needed

## Manual Updating

When the Lmaobox API is updated:

1. Check the official documentation: http://lmaobox.net/lua/sitemap.xml
2. Update the relevant type definition file(s) in the appropriate subdirectory
3. Reload VS Code window (Ctrl+Shift+P → "Developer: Reload Window") for changes to take effect

## Configuration

Type definitions are automatically loaded via:

- `.vscode/.luarc.json` - Lua Language Server configuration
- `.vscode/settings.json` - VS Code workspace settings

Both reference `${workspace}/types` in the workspace library, which recursively loads all `.d.lua` files.

## Sharing

These type definitions are organized into separate files for easy sharing. You can:

- Share individual constant/entity property files with other developers
- Merge updates from different sources easily
- Maintain version control on specific categories
