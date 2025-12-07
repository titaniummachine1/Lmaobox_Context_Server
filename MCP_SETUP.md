# MCP Server Setup for Cursor/Claude Desktop

This guide explains how to configure the Lmaobox Context MCP server for use with Cursor IDE or Claude Desktop.

## Quick Setup

### Option 1: Cursor IDE

1. **Find your Cursor MCP config file:**

   - Windows: `%APPDATA%\Cursor\User\globalStorage\saoudrizwan.claude-dev\settings\cline_mcp_settings.json`
   - Or: Check Cursor Settings → Features → Model Context Protocol

2. **Add the server configuration:**

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

3. **Update the paths** in the config to match your system:

   - Replace `C:\\Users\\Terminatort8000\\Desktop\\Lmaobox_Context_Server` with your actual repo path

4. **Restart Cursor** to load the MCP server

### Option 2: Claude Desktop

1. **Find your Claude Desktop config:**

   - Windows: `%APPDATA%\Claude\claude_desktop_config.json`

2. **Add the server configuration** (same format as above)

3. **Restart Claude Desktop**

## Testing the Server

After configuration, the server should automatically start when Cursor/Claude needs it. To test manually:

```bash
# Test stdio server directly
python launch_mcp.py

# The server will wait for JSON-RPC messages on stdin
# You can test it by sending an initialize request:
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' | python launch_mcp.py
```

## Available Tools

Once configured, Claude/Cursor can use these MCP tools:

1. **`get_types`** - Get type information for a Lmaobox Lua API symbol

   - Example: `get_types("Draw")` or `get_types("render.text")`

2. **`get_smart_context`** - Get curated smart context for a symbol
   - Example: `get_smart_context("engine.TraceLine")`

## Troubleshooting

### Server not starting

- Check that Python is in your PATH
- Verify the paths in the config file are correct
- Check Cursor/Claude logs for error messages

### Import errors

- Ensure you're in the repo directory when running
- Check that all dependencies are installed

### Database errors

- The server will create the database automatically if it doesn't exist
- If you see DB errors, check that the `.cache` directory is writable

## Manual Server Test

Run the diagnostic script:

```bash
python diagnose_mcp.py
```

This will test all components and report any issues.
