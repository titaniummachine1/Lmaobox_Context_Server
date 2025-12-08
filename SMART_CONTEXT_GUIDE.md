# Smart Context Guide

## What is Smart Context?

Smart context files are curated documentation that provides working examples and best practices for Lmaobox API functions and custom helper patterns. When you ask the AI about a symbol, it retrieves these files to give accurate, tested examples.

## File Structure

```
data/smart_context/
├── custom.helper_name.md          # Custom helpers you create
├── api_function.md                 # Simple API functions
└── namespace/                      # Grouped by namespace
    └── FunctionName.md            # e.g., engine/TraceLine.md
```

## Template

```markdown
## Function/Symbol: namespace.FunctionName

> Brief one-line description

### Required Context

- Constants: CONSTANT_NAME (describe what it does)
- Types: TypeName (what it represents)
- Dependencies: Other functions needed
- Notes: Any important gotchas or edge cases

### Curated Usage Examples

#### 1. Basic usage

\`\`\`lua
-- Show the simplest working example
-- Include just enough context to be runnable
\`\`\`

#### 2. Real-world pattern

\`\`\`lua
-- Show a common use case
-- Add comments explaining WHY, not WHAT
\`\`\`

#### 3. Advanced (optional)

\`\`\`lua
-- Show error handling or optimization if relevant
\`\`\`
```

## Best Practices

### DO:

- **Keep it SHORT** - 1-3 examples max, no walls of text
- **Show WORKING code** - Test before committing
- **Explain WHY** - Not "what this line does" but "why we need this"
- **List dependencies** - Constants, types, helper functions needed
- **Use real names** - Actual variable names like `me`, `player`, not `x`, `y`

### DON'T:

- **Don't duplicate API docs** - Smart context is for HOW, not WHAT
- **Don't show broken patterns** - Only proven, tested code
- **Don't over-explain** - Code should be self-documenting
- **Don't add every function** - Only complex/commonly-misused ones

## When to Add Smart Context

### YES - Add for:

- Functions with complex parameters (e.g., `engine.TraceLine` with filter callback)
- Functions requiring constants (e.g., trace masks, entity flags)
- Custom helper patterns you reuse (e.g., `GetBestTarget`, `IsVisible`)
- Functions with gotchas or edge cases
- Multi-step workflows (e.g., "How to get player view position")

### NO - Don't add for:

- Simple getters/setters (e.g., `entity.GetIndex()`)
- Self-explanatory functions (e.g., `math.floor()`)
- Functions with perfect type hints already
- Rarely-used internal functions

## Example: Good vs Bad

### ❌ BAD - Too verbose, obvious code

```markdown
## Function: draw.Color

> Sets the color for drawing

### Usage

\`\`\`lua
-- First we call draw.Color
draw.Color(255, 0, 0, 255)
-- This sets red to 255
-- This sets green to 0
-- This sets blue to 0
-- This sets alpha to 255
-- Now we can draw a rectangle
draw.FilledRect(0, 0, 100, 100)
\`\`\`
```

### ✅ GOOD - Concise, shows pattern

```markdown
## Function: draw.Color

> Sets RGBA color for subsequent draw calls

### Curated Usage Examples

#### Standard colors

\`\`\`lua
draw.Color(255, 0, 0, 255) -- Red
draw.Color(0, 255, 0, 255) -- Green
draw.Color(255, 255, 255, 128) -- White semi-transparent
\`\`\`

#### Team color helper

\`\`\`lua
local function setTeamColor(teamNum)
if teamNum == 2 then
draw.Color(255, 0, 0, 255) -- RED team
else
draw.Color(0, 0, 255, 255) -- BLU team
end
end
\`\`\`
```

## Organizing by Namespace

For API functions, mirror the API structure:

```
data/smart_context/
├── engine/
│   ├── TraceLine.md
│   └── TraceHull.md
├── entities/
│   └── FindByClass.md
└── custom.my_helper.md
```

This matches how users think: "I need engine.TraceLine docs" → `engine/TraceLine.md`

## Testing Your Smart Context

After adding a file:

1. **Test the MCP lookup:**

   ```powershell
   python scripts/query_examples.py --symbol "engine.TraceLine"
   ```

2. **Ask the AI:**

   ```
   "Show me how to use engine.TraceLine"
   ```

3. **Verify it retrieves your file** and provides accurate code

## Maintenance

- **Review quarterly** - Remove outdated patterns
- **Update when API changes** - Keep examples working
- **Delete if unused** - Check git history, remove dead files
- **Keep it DRY** - If multiple files show the same pattern, consolidate

## Priority Symbols to Document

High-value targets for smart context:

1. `engine.TraceLine`, `engine.TraceHull` - Complex filters
2. `entities.FindByClass` - Common entity queries
3. `Entity.GetPropVector`, `Entity.SetPropFloat` - Entity property access
4. Custom patterns: `GetBestTarget`, `IsVisible`, `CalculateDistance`
5. Aimbot helpers: `GetHitbox`, `GetBonePosition`
6. Drawing patterns: ESP boxes, text positioning

Focus on what YOU actually use daily, not comprehensive coverage.
