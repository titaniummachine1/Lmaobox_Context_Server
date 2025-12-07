# 🚀 Cursor MCP Configuration for Lmaobox Context Server

## ✅ Server Status: READY

The MCP server is working and ready to use!

## 📋 Step-by-Step Setup

### Step 1: Open Cursor MCP Settings

1. Open Cursor
2. Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on Mac)
3. Type: `Preferences: Open User Settings (JSON)`
4. OR go to: **Settings → Features → Model Context Protocol → Edit Config**

### Step 2: Add Server Configuration

Add this JSON to your Cursor settings (update the paths to match your system):

```json
{
  "mcpServers": {
    "lmaobox-context": {
      "command": "python",
      "args": [
        "C:\\Users\\Terminatort8000\\Desktop\\Lmaobox_Context_Server\\launch_mcp.py"
      ],
      "cwd": "C:\\Users\\Terminatort8000\\Desktop\\Lmaobox_Context_Server"
    }
  }
}
```

**IMPORTANT:**

- Use double backslashes (`\\`) in Windows paths
- OR use forward slashes: `C:/Users/Terminatort8000/Desktop/Lmaobox_Context_Server/launch_mcp.py`
- Make sure Python is in your PATH

### Step 3: Restart Cursor

Close and reopen Cursor completely to load the MCP server.

### Step 4: Test It!

Ask Claude in Cursor:

- "Use the get_types tool to tell me about the Draw function"
- "Get smart context for engine.TraceLine"
- "What Lmaobox API functions are available?"

Claude will automatically use the MCP server to fetch real Lmaobox API documentation!

## 🔧 Troubleshooting

### Server Not Showing Up

1. Check Python is in PATH:

   ```cmd
   python --version
   ```

2. Test server manually:

   ```cmd
   cd C:\Users\Terminatort8000\Desktop\Lmaobox_Context_Server
   echo {"jsonrpc":"2.0","id":1,"method":"initialize","params":{}} | python launch_mcp.py
   ```

   Should return JSON with "lmaobox-context"

3. Check Cursor logs:
   - Help → Toggle Developer Tools → Console
   - Look for MCP errors

### Wrong Path

If you moved the repo, update both:

- `args`: Full path to `launch_mcp.py`
- `cwd`: Full path to repo root directory

### Python Not Found

Cursor might not find Python. Try full Python path:

```json
"command": "C:\\Users\\Terminatort8000\\AppData\\Local\\Programs\\Python\\Python311\\python.exe"
```

## 🎯 Available MCP Tools

Once configured, Claude can use these tools:

1. **`get_types(symbol)`**

   - Get type information, signatures, parameters for any Lmaobox Lua API symbol
   - Example: `get_types("Draw")`, `get_types("render.text")`

2. **`get_smart_context(symbol)`**
   - Get curated documentation and examples
   - Example: `get_smart_context("engine.TraceLine")`

## ✨ Usage Examples

After setup, try asking Claude:

```
"Use get_types to show me the signature of engine.TraceLine"

"Get smart context for custom.normalize_vector and explain how to use it"

"What parameters does Draw.Color take? Use the MCP tools"
```

Claude will automatically query the server and give you accurate Lmaobox API information!

## 🔍 Verify It's Working

In Cursor chat, type `@` and you should see your MCP tools listed. Or just ask Claude to use them - if configured correctly, Claude will have access to query your local Lmaobox documentation!
