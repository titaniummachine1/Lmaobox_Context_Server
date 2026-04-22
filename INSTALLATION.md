# Installation & Setup Guide

## Prerequisites

- **Go 1.18+** (to build the server)
- **Python 3.8+** (for auto-dependency installation)

## Installation Steps

### 1. Clone the Repository
```bash
git clone https://github.com/your-username/lmaobox-context-protocol.git
cd lmaobox-context-protocol
```

### 2. Build the Server
```bash
go build -o lmaobox-context-server.exe
```

### 3. Install Dependencies (Auto-Recommended)

**Option A: Automatic Setup (Recommended)**

Run the setup script once to pre-install everything:

```powershell
# Windows PowerShell
.\automations\setup-dependencies.ps1

# Or Windows Command Prompt
cd automations
setup-dependencies.bat
```

**Option B: Manual Installation**

Dependencies will be auto-installed when you first run the server. Or install manually:

```bash
# Lua 5.4+ (required)
pip install luaforwindows  # or download from https://luabinaries.sourceforge.net/

# luacheck (optional but recommended)
pip install luacheck
# OR
npm install -g luacheck
```

## Running the Server

Simply execute the built binary:

```powershell
./lmaobox-context-server.exe
```

Or if you're running from a different location:

```powershell
& 'C:\path\to\lmaobox-context-server.exe'
```

### What Happens on First Run

1. **Dependency Check**: Server verifies Lua compiler and luacheck are available
2. **Auto-Install** (if needed): Automatically downloads and installs missing dependencies
3. **Verification**: Confirms everything is working
4. **Ready**: Server starts and listens on stdio for MCP connections

### Example Output

```
✓ Dependencies satisfied: Lua compiler found, luacheck found
[2026-04-22 10:30:45] INFO Lmaobox Context Server v1.0.0 starting...
[2026-04-22 10:30:45] INFO MCP server listening on stdio
```

## Configuration

The server requires no configuration. All settings are provided via MCP tool calls.

### Environment Variables (Optional)

```bash
# Override deployment directory (default: %LOCALAPPDATA%/lua)
$env:LUA_DEPLOY_DIR = "C:\custom\lua\path"

# Override Lua compiler location (if auto-discovery fails)
$env:LUA_COMPILER = "C:\path\to\luac.exe"

# Override luacheck location
$env:LUACHECK_PATH = "C:\path\to\luacheck.exe"
```

## Troubleshooting

### "Lua compiler not found"

The server will attempt auto-install. If it fails:

```bash
# Manual installation
pip install luaforwindows

# Or download from: https://luabinaries.sourceforge.net/
# Then place luac.exe in: automations/bin/lua/luac54.exe
```

### "luacheck not found"

This is optional but recommended. Install with:

```bash
pip install luacheck
# OR
npm install -g luacheck
```

### "Python not found in PATH"

Install Python from https://www.python.org/ and ensure it's added to PATH.

### Port/Permission Issues

The server communicates via stdin/stdout (no network ports), so there are no port conflicts.

## Using with VS Code Copilot

The MCP server integrates with GitHub Copilot in VS Code. Configure it in `.vscode/settings.json`:

```json
{
  "github.copilot.chat.mcpServers": {
    "lmaobox-context": {
      "command": "C:\\path\\to\\lmaobox-context-server.exe"
    }
  }
}
```

## Project Structure

```
lmaobox-context-protocol/
├── main.go                     # MCP server implementation
├── go.mod                      # Go dependencies
├── Main.lua                    # Example Lua project
├── automations/
│   ├── install_lua.py          # Auto-installer for Lua
│   ├── install_luacheck.py     # Auto-installer for luacheck
│   ├── setup-dependencies.ps1  # Windows PowerShell setup
│   ├── setup-dependencies.bat  # Windows batch setup
│   └── bin/
│       ├── lua/                # Bundled Lua binaries
│       └── luacheck/           # Bundled luacheck
├── types/                      # Lmaobox Lua API type definitions
├── smart_context/              # Documentation and examples
└── README.md                   # Project documentation
```

## Development

### Adding New MCP Tools

Edit `main.go` and add tools in the `main()` function:

```go
myTool := mcp.NewTool(
    "tool_name",
    mcp.WithDescription("What this tool does"),
    mcp.WithString("param1", mcp.Required(), mcp.Description("...")),
)
s.AddTool(myTool, handleMyTool)

func handleMyTool(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
    // Implementation
}
```

### Running Tests

```bash
go test ./...
```

### Building for Distribution

```bash
# Windows
$env:GOOS = "windows"
$env:GOARCH = "amd64"
go build -o lmaobox-context-server-windows-amd64.exe

# Or use the Makefile
make build
```

## License

See [LICENSE](LICENSE) for details.

## Support

For issues or questions:

1. Check [Troubleshooting](#troubleshooting) above
2. Review the [ARCHITECTURE.md](docs/ARCHITECTURE.md)
3. Open an issue on GitHub
