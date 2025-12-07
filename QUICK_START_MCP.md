# Quick Start: MCP Server for Cursor

## ✅ What Was Fixed

1. **Error Handling** - Fixed database errors when tables don't exist
2. **Path Handling** - Ensured DB directories are created automatically
3. **Robustness** - Improved error handling in stdio server loop
4. **Documentation** - Added setup guides and test scripts

## 🚀 Setup (2 minutes)

### Step 1: Configure Cursor

1. Open Cursor Settings
2. Navigate to: **Features → Model Context Protocol**
3. Add this configuration (update the path!):

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

**⚠️ IMPORTANT:** Replace the path with your actual repo path!

### Step 2: Restart Cursor

Close and reopen Cursor to load the MCP server.

### Step 3: Verify It Works

In Cursor, you should now be able to ask Claude:

- "What is the Draw function in Lmaobox?"
- "Get me context for engine.TraceLine"
- "What types are available for render.text?"

Claude will automatically use the MCP tools: `get_types` and `get_smart_context`.

## 🔧 Troubleshooting

### Server Not Starting

```bash
# Test manually
cd C:\Users\Terminatort8000\Desktop\Lmaobox_Context_Server
python launch_mcp.py
```

### Check Logs

- Cursor logs: Help → Toggle Developer Tools → Console
- Look for MCP server errors

### Run Diagnostics

```bash
python diagnose_mcp.py
```

## 📝 Available Tools

The server provides two MCP tools:

1. **`get_types(symbol)`** - Get type signatures and information
2. **`get_smart_context(symbol)`** - Get curated documentation

Both tools support fuzzy matching and suggestions if the exact symbol isn't found.

## 🎯 Next Steps

- Add more smart context files in `data/smart_context/`
- Use Claude to ask about Lmaobox API - it will automatically query the server!
