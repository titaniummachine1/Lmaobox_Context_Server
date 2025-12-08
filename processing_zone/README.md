# Processing Zone

This directory organizes the analysis of Lua scripts from various Lmaobox repositories.

## Workflow

### 01_TO_PROCESS/

Lua files waiting to be analyzed for patterns and smart context improvements.

### 02_IN_PROGRESS/

Files currently being analyzed. Move files here when starting analysis.

### 03_DONE/

Completed analyses. Move files here after extracting patterns and updating smart context.

## Repositories Being Processed

1. **lbox-projectile-aimbot** - https://github.com/uosq/lbox-projectile-aimbot

   - Focus: Ballistic calculations, projectile prediction, weapon utilities
   - Key files: math.lua, weapon_utils.lua, playersim.lua, projectilesim.lua

2. **lmaobox-luas** - https://github.com/uosq/lmaobox-luas
   - Focus: Various Lmaobox scripts showing API usage patterns
   - 59 Lua files covering diverse use cases

## Pattern Extraction Goals

- API usage patterns
- Common utility functions
- Vector math operations
- Entity manipulation
- Callback structures
- Error handling approaches
- State management patterns
