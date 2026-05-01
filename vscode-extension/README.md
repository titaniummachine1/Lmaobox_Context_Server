# Lmaobox Context VS Code Extension

This extension is a zero-config MCP server for Lmaobox Lua inside VS Code. It installs the runtime automatically, registers the MCP server, and exposes Lmaobox tools in Copilot Chat and other MCP-capable clients.

## Quick Start

1. Install the extension from the VS Code Marketplace.
2. Wait a few seconds after VS Code startup. The extension activates on startup and installs/configures the MCP runtime automatically.
3. Open Copilot Chat and use MCP tools. No manual server install is required in the normal case.

If auto-setup did not run, use this one-command fallback:

1. Run `Lmaobox Context: Install Or Update Runtime` from the Command Palette.

If you use Cursor/Windsurf/Claude and want to force external config sync, run:

1. `Lmaobox Context: Sync External MCP Configs`

You can also ask your AI assistant to do setup for you with this prompt:

```text
Run "Lmaobox Context: Install Or Update Runtime", then run "Lmaobox Context: Sync External MCP Configs", then confirm Lmaobox Context MCP tools are available.
```

## What it does

1. Downloads the runtime archive matching the extension version from GitHub Releases.
2. Verifies the archive with the published `checksums.txt` file.
3. Extracts the server binary plus `smart_context`, `types`, and bundled automation assets into the extension runtime folder.
4. Writes the `modelContextProtocol.servers.lmaobox-context` entry into user settings.

The goal is "install extension and it just works": runtime download, MCP registration, and docs/types availability are handled by the extension.

## Lua Language Server Requirement

This extension requires a Lua language server extension and attempts to install it automatically during setup.

- If `sumneko.lua` is already installed, setup proceeds immediately.
- If it is missing, the extension requests installation automatically.
- If installation cannot complete (offline policy/store issue), MCP still starts, but Lua lint diagnostics may be reduced until a Lua language server extension is available.

MCP is configured with `--prefer-lua-ls`, so the Lua language server is the primary lint/diagnostic source for predictable workspace-aware checks.

## Included Lua Snippets

The extension also ships first-party Lua snippets for common Lmaobox scripting patterns, including:

- callback registration templates
- local player guards
- common client, draw, and trace helpers

Start typing prefixes such as `lm.createMove`, `lm.draw`, `lm.localPlayer`, or `lm.traceLine` in a Lua file.

## Expected release assets

The extension expects these files on the GitHub release matching the extension version tag:

- `lmaobox-context-runtime_windows_amd64.zip`
- `lmaobox-context-runtime_linux_amd64.zip`
- `lmaobox-context-runtime_linux_arm64.zip`
- `lmaobox-context-runtime_darwin_amd64.zip`
- `lmaobox-context-runtime_darwin_arm64.zip`
- `checksums.txt`

## Publishing

1. Update this extension `version` to match the Go runtime release tag without the leading `v`.
2. Publish the GitHub tag so `.github/workflows/release.yml` produces the runtime archives.
3. Package or publish this extension to the VS Code Marketplace.

## Commands

- `Lmaobox Context: Install Or Update Runtime`
- `Lmaobox Context: Sync External MCP Configs`
- `Lmaobox Context: Open Runtime Folder`
- `Lmaobox Context: Open Bundled Docs Folder`

## Configuration

- `lmaoboxContext.autoConfigureMcp` (default: `true`)
: Automatically writes/updates the MCP server entry in VS Code user settings.
- `lmaoboxContext.releaseTag` (default: empty)
: Override runtime tag. Empty means `v<extension-version>`.
- `lmaoboxContext.repoOwner` / `lmaoboxContext.repoName`
: Override GitHub source for runtime release assets.

## Troubleshooting

If MCP does not start or tools are missing:

1. Run `Lmaobox Context: Install Or Update Runtime`.
2. Run `Lmaobox Context: Sync External MCP Configs` (for Cursor/Windsurf/Claude).
3. Run `Lmaobox Context: Open Runtime Folder` and verify files exist:
: `lmaobox-context-server(.exe)`, `types`, and `smart_context`.
4. Open VS Code settings JSON and verify:
: `modelContextProtocol.servers.lmaobox-context` exists and points to the runtime executable.
5. Restart the editor after reinstall.

If GitHub release assets are unavailable for your version, set `lmaoboxContext.releaseTag` temporarily to a valid tag.

## Notes On Snippets

This extension includes first-party snippets maintained with the MCP/runtime integration. It does not bundle third-party snippet packs.
