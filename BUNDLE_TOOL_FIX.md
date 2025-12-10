# Bundle Tool Fix

## Problem

The MCP `bundle` tool was **hardcoded to only work within the Lmaobox_Context_Server repository**. It assumed:

1. The script was always in `src/mcp_server/mcp_stdio.py`
2. The automations folder was at `../../automations/` relative to the script
3. All project paths were relative to the MCP server repo root
4. The CWD was always the MCP server repo

This completely broke the tool for any workspace that wasn't this specific repo.

## Solution

### Changes Made to `src/mcp_server/mcp_stdio.py`

1. **Absolute Path Support**: `projectDir` now accepts both absolute and relative paths
   - Absolute: `C:/Users/You/my_project` 
   - Relative: `my_project` (resolved from Cursor workspace CWD)

2. **Path Resolution Logic**:
   ```python
   # Resolve project_dir: if absolute, use as-is; if relative, resolve from CWD
   project_path = Path(project_dir).expanduser()
   if not project_path.is_absolute():
       # Try relative to current working directory (Cursor workspace)
       project_path = Path.cwd() / project_path
   
   project_path = project_path.resolve()
   ```

3. **Better Error Messages**: Shows exactly what path was provided and what CWD is when project not found

4. **Bundler Location**: Still uses the MCP server's `automations/bundle-and-deploy.js` (which is correct - that's where the bundler lives), but projects can be anywhere

5. **Output Paths**: `bundleOutputDir` and `deployDir` can also be absolute or relative (relative to `projectDir`)

## How It Works Now

### Example 1: Project in any workspace

```python
# User has project at C:/Users/You/my_lua_project/
# Cursor workspace is C:/Users/You/my_lua_project/

bundle(projectDir=".")  # CWD is workspace root
# OR
bundle(projectDir="C:/Users/You/my_lua_project")  # Absolute
```

### Example 2: Project in subdirectory

```python
# User has project at C:/Users/You/workspace/prototypes/
# Cursor workspace is C:/Users/You/workspace/

bundle(projectDir="prototypes")  # Relative to workspace
```

### Example 3: Completely different location

```python
# User has project at D:/TF2/Scripts/aimbot/
# Cursor workspace is anywhere

bundle(projectDir="D:/TF2/Scripts/aimbot")  # Absolute path
```

## What Was Wrong Before

```python
# OLD CODE (BROKEN):
repo_root = Path(__file__).resolve().parents[2]  # Always MCP server repo!
env["PROJECT_DIR"] = str(Path(project_dir).expanduser())  # Treated as relative to repo_root
process.run(["node", str(script_path)], cwd=str(repo_root), ...)
```

This would fail for ANY workspace other than Lmaobox_Context_Server because:
- It resolved relative paths from the MCP server repo, not the user's workspace
- It didn't handle absolute paths properly
- Error messages didn't show what went wrong

## What's Correct Now

```python
# NEW CODE (WORKS):
# 1. Resolve project path from user's workspace CWD
project_path = Path(project_dir).expanduser()
if not project_path.is_absolute():
    project_path = Path.cwd() / project_path  # Use Cursor workspace CWD!

# 2. Find MCP server's bundler script (this is fine - bundler lives here)
mcp_server_root = Path(__file__).resolve().parents[2]
script_path = mcp_server_root / "automations" / "bundle-and-deploy.js"

# 3. Pass absolute project path to bundler
env["PROJECT_DIR"] = str(project_path)

# 4. Run bundler from MCP server location (needs node_modules there)
process.run(["node", str(script_path)], cwd=str(mcp_server_root), ...)
```

## Testing

To test, try bundling a project in a completely different workspace:

```bash
# In ANY workspace with a Lua project:
mcp_tool bundle projectDir="path/to/project"
```

The tool should now:
1. ✅ Find the project regardless of workspace
2. ✅ Resolve paths correctly
3. ✅ Run the bundler from the MCP server location (where node_modules exist)
4. ✅ Deploy to %LOCALAPPDATA%/lua by default

