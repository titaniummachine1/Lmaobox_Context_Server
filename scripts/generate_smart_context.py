#!/usr/bin/env python
"""Generate smart context templates for all Lmaobox API functions."""
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
TYPES_DIR = REPO_ROOT / "types" / "lmaobox_lua_api"
SMART_CONTEXT_DIR = REPO_ROOT / "data" / "smart_context"

# Common custom helpers and patterns
CUSTOM_HELPERS = {
    "normalize_vector": """## Function/Symbol: custom.normalize_vector

> Normalize a vector to unit length

### Required Context
- Types: Vector3
- Notes: Safe division - engine handles zero-length vectors

### Curated Usage Examples

#### Basic normalization
```lua
local function normalize(vec)
    return vec / vec:Length()
end

-- Usage
local dir = targetPos - myPos
local unitDir = normalize(dir)
```
""",
    
    "get_eye_pos": """## Function/Symbol: custom.GetEyePos

> Get player's eye/view position (origin + view offset)

### Required Context
- Entity props: m_vecViewOffset[0]
- Types: Vector3, Entity

### Curated Usage Examples

#### Standard implementation
```lua
local function GetEyePos(player)
    if not player then return nil end
    local origin = player:GetAbsOrigin()
    local viewOffset = player:GetPropVector("localdata", "m_vecViewOffset[0]")
    return origin + viewOffset
end

-- Usage
local me = entities.GetLocalPlayer()
local eyePos = GetEyePos(me)
local viewAngles = engine.GetViewAngles()
local aimDir = viewAngles:Forward()
```
""",
    
    "distance_to": """## Function/Symbol: custom.DistanceTo

> Calculate distance between two positions

### Required Context
- Types: Vector3

### Curated Usage Examples

#### 2D and 3D distance
```lua
local function DistanceTo(pos1, pos2)
    return (pos2 - pos1):Length()
end

local function Distance2D(pos1, pos2)
    local delta = pos2 - pos1
    delta.z = 0
    return delta:Length()
end

-- Usage
local me = entities.GetLocalPlayer()
local target = entities.GetByIndex(targetIdx)
local dist = DistanceTo(me:GetAbsOrigin(), target:GetAbsOrigin())
print("Distance: " .. math.floor(dist))
```
""",
    
    "is_visible": """## Function/Symbol: custom.IsVisible

> Check if target is visible (no obstacles between positions)

### Required Context
- Functions: engine.TraceLine
- Constants: MASK_SHOT_HULL
- Types: Vector3, Entity

### Curated Usage Examples

#### Basic visibility check
```lua
local function IsVisible(from, to, skipEnt)
    local trace = engine.TraceLine(from, to, MASK_SHOT_HULL)
    return trace.fraction > 0.99 or trace.entity == skipEnt
end

-- Usage with player
local me = entities.GetLocalPlayer()
local eyePos = me:GetAbsOrigin() + me:GetPropVector("localdata", "m_vecViewOffset[0]")

for i = 1, entities.GetHighestEntityIndex() do
    local ent = entities.GetByIndex(i)
    if ent and ent:IsPlayer() and ent:IsAlive() then
        local targetPos = ent:GetAbsOrigin()
        if IsVisible(eyePos, targetPos, me) then
            print(ent:GetName() .. " is visible")
        end
    end
end
```
""",
    
    "angle_to_position": """## Function/Symbol: custom.AngleToPosition

> Calculate angles to look at a target position

### Required Context
- Functions: custom.normalize_vector
- Types: Vector3, EulerAngles

### Curated Usage Examples

#### Calculate aim angles
```lua
local function normalize(vec)
    return vec / vec:Length()
end

local function AngleToPosition(from, to)
    local dir = normalize(to - from)
    local pitch = math.asin(-dir.z) * (180 / math.pi)
    local yaw = math.atan(dir.y, dir.x) * (180 / math.pi)
    return EulerAngles(pitch, yaw, 0)
end

-- Usage for aimbot
local me = entities.GetLocalPlayer()
local eyePos = me:GetAbsOrigin() + me:GetPropVector("localdata", "m_vecViewOffset[0]")
local targetHead = target:GetHitboxPos(1) -- Head hitbox

local aimAngles = AngleToPosition(eyePos, targetHead)
engine.SetViewAngles(aimAngles)
```
"""
}


def extract_function_info(file_path, namespace):
    """Extract function signatures and docs from a Lua type file."""
    functions = []
    
    with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
        lines = f.readlines()
    
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        
        # Look for function definition
        match = re.match(rf"function\s+{re.escape(namespace)}\.(\w+)\s*\((.*?)\)", line)
        if match:
            func_name = match.group(1)
            params = match.group(2)
            
            # Extract doc comment above
            desc = ""
            param_docs = []
            return_docs = []
            
            j = i - 1
            while j >= 0:
                prev_line = lines[j].strip()
                if prev_line.startswith("---"):
                    content = prev_line.lstrip("-").strip()
                    if content.startswith("@param"):
                        param_docs.insert(0, content)
                    elif content.startswith("@return"):
                        return_docs.insert(0, content)
                    elif not content.startswith("@"):
                        desc = content + (" " + desc if desc else "")
                    j -= 1
                elif prev_line.startswith("--"):
                    j -= 1
                else:
                    break
            
            functions.append({
                "name": f"{namespace}.{func_name}",
                "params": params,
                "desc": desc.strip(),
                "param_docs": param_docs,
                "return_docs": return_docs
            })
        
        i += 1
    
    return functions


def generate_smart_context_template(func_info):
    """Generate a smart context markdown template for a function."""
    name = func_info["name"]
    desc = func_info["desc"] or "No description available"
    params = func_info["params"]
    
    template = f"""## Function/Symbol: {name}

> {desc}

### Required Context
- Types: {', '.join(p.split(':')[0].strip() for p in params.split(',') if p.strip())}
- Notes: TODO - Add usage notes, edge cases, common patterns

### Curated Usage Examples

#### 1. Basic usage
```lua
-- TODO: Add basic example showing minimal working code
-- {name}({params})
```

#### 2. Real-world example
```lua
-- TODO: Add practical example from actual use case
-- Show common pattern or workflow
```

### Related
- See also: TODO - Link to related functions
"""
    return template


def scan_library_file(lib_file):
    """Scan a library file and extract all functions."""
    lib_name = lib_file.stem
    print(f"Scanning {lib_name}...")
    
    functions = extract_function_info(lib_file, lib_name)
    print(f"  Found {len(functions)} functions")
    
    return lib_name, functions


def scan_class_file(class_file):
    """Scan a class file and extract all methods."""
    class_name = class_file.stem.replace(".d", "")
    print(f"Scanning class {class_name}...")
    
    # Classes use ClassName:MethodName syntax
    functions = []
    
    with open(class_file, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()
    
    # Find function definitions
    pattern = rf"function\s+{re.escape(class_name)}:(\w+)\s*\((.*?)\)"
    matches = re.finditer(pattern, content)
    
    for match in matches:
        method_name = match.group(1)
        params = match.group(2)
        
        functions.append({
            "name": f"{class_name}.{method_name}",
            "params": params,
            "desc": f"Method {method_name} on {class_name} class",
            "param_docs": [],
            "return_docs": []
        })
    
    print(f"  Found {len(functions)} methods")
    return class_name, functions


def main():
    """Main entry point."""
    print("=" * 60)
    print("Smart Context Generator")
    print("=" * 60)
    
    # Create output directory
    output_dir = REPO_ROOT / "processing_zone" / "01_TO_PROCESS" / "generated_templates"
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # First, create custom helper files
    print("\n[1/4] Creating custom helper patterns...")
    custom_dir = output_dir / "custom"
    custom_dir.mkdir(exist_ok=True)
    
    for helper_name, content in CUSTOM_HELPERS.items():
        helper_file = custom_dir / f"{helper_name}.md"
        helper_file.write_text(content, encoding="utf-8")
        print(f"  ✓ {helper_name}.md")
    
    # Scan all library files
    print("\n[2/4] Scanning Lua_Libraries...")
    lib_dir = TYPES_DIR / "Lua_Libraries"
    lib_output = output_dir / "libraries"
    lib_output.mkdir(exist_ok=True)
    
    lib_count = 0
    func_count = 0
    
    for lib_file in sorted(lib_dir.glob("*.d.lua")):
        lib_name, functions = scan_library_file(lib_file)
        lib_count += 1
        func_count += len(functions)
        
        # Create namespace directory
        lib_namespace_dir = lib_output / lib_name
        lib_namespace_dir.mkdir(exist_ok=True)
        
        # Generate template for each function
        for func in functions:
            func_file = lib_namespace_dir / f"{func['name'].split('.')[-1]}.md"
            template = generate_smart_context_template(func)
            func_file.write_text(template, encoding="utf-8")
    
    print(f"  ✓ Processed {lib_count} libraries, {func_count} functions")
    
    # Scan all class files
    print("\n[3/4] Scanning Lua_Classes...")
    class_dir = TYPES_DIR / "Lua_Classes"
    class_output = output_dir / "classes"
    class_output.mkdir(exist_ok=True)
    
    class_count = 0
    method_count = 0
    
    for class_file in sorted(class_dir.glob("*.d.lua")):
        class_name, methods = scan_class_file(class_file)
        class_count += 1
        method_count += len(methods)
        
        if methods:
            # Create class directory
            class_namespace_dir = class_output / class_name
            class_namespace_dir.mkdir(exist_ok=True)
            
            # Generate template for each method
            for method in methods:
                method_file = class_namespace_dir / f"{method['name'].split('.')[-1]}.md"
                template = generate_smart_context_template(method)
                method_file.write_text(template, encoding="utf-8")
    
    print(f"  ✓ Processed {class_count} classes, {method_count} methods")
    
    # Generate priority list
    print("\n[4/4] Creating priority list...")
    priority_file = output_dir / "PRIORITY_LIST.md"
    
    priority_content = f"""# Smart Context Priority List

Generated templates: {func_count + method_count} total

## High Priority (Complete First)

### Core Functions (25)
1. `engine/TraceLine.md` - ✅ Already done
2. `engine/TraceHull.md`
3. `engine/GetViewAngles.md`
4. `engine/SetViewAngles.md`
5. `entities/GetLocalPlayer.md`
6. `entities/GetByIndex.md`
7. `entities/FindByClass.md`
8. `entities/GetHighestEntityIndex.md`
9. `Entity/GetAbsOrigin.md`
10. `Entity/GetPropInt.md`
11. `Entity/GetPropFloat.md`
12. `Entity/GetPropVector.md`
13. `Entity/SetPropInt.md`
14. `Entity/IsAlive.md`
15. `Entity/IsPlayer.md`
16. `Entity/GetTeamNumber.md`
17. `Entity/GetClass.md`
18. `Entity/GetName.md`
19. `draw/Color.md`
20. `draw/FilledRect.md`
21. `draw/Text.md`
22. `draw/Line.md`
23. `Vector3/Length.md`
24. `callbacks/Register.md`
25. `input/IsButtonDown.md`

### Custom Helpers (6)
1. `custom/normalize_vector.md` - ✅ Already done
2. `custom/get_eye_pos.md`
3. `custom/distance_to.md`
4. `custom/is_visible.md`
5. `custom/angle_to_position.md`
6. `custom/get_best_target.md`

## Medium Priority (After Core)

### Aimbot Functions
- `aimbot/GetBestTarget.md`
- `Entity/GetHitboxPos.md`
- `Entity/GetBonePosition.md`

### Drawing/ESP
- `draw/GetTextSize.md`
- `render/*` functions for 3D rendering

### Entity Management
- `entities/GetPlayers.md`
- Entity property functions

## Low Priority (Optional)

- Rarely used library functions
- Advanced physics functions
- Network message handlers

## Workflow

1. Pick a function from High Priority
2. Open the generated template in `processing_zone/01_TO_PROCESS/generated_templates/`
3. Replace TODOs with real examples
4. Test the code in-game
5. Move to `data/smart_context/` when done
6. Delete the template

## Templates Location

```
processing_zone/01_TO_PROCESS/generated_templates/
├── custom/          # {len(CUSTOM_HELPERS)} custom helpers (DONE)
├── libraries/       # {func_count} library functions (TEMPLATES)
└── classes/         # {method_count} class methods (TEMPLATES)
```

## Quick Commands

```powershell
# Test a function
python scripts/query_examples.py --symbol "engine.TraceLine"

# Move completed file
move processing_zone/01_TO_PROCESS/generated_templates/libraries/engine/TraceLine.md data/smart_context/engine/

# Check MCP server
curl http://localhost:8765/health
```
"""
    
    priority_file.write_text(priority_content, encoding="utf-8")
    
    print("\n" + "=" * 60)
    print("GENERATION COMPLETE")
    print("=" * 60)
    print(f"✓ Custom helpers: {len(CUSTOM_HELPERS)}")
    print(f"✓ Library functions: {func_count} (from {lib_count} libraries)")
    print(f"✓ Class methods: {method_count} (from {class_count} classes)")
    print(f"✓ Total templates: {func_count + method_count + len(CUSTOM_HELPERS)}")
    print(f"\nOutput: {output_dir}")
    print("\nNext: Edit templates in 01_TO_PROCESS/generated_templates/")
    print("See PRIORITY_LIST.md for suggested order")


if __name__ == "__main__":
    main()
