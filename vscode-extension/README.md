# Lmaobox Context VS Code Extension

This extension installs the Lmaobox MCP runtime from GitHub Releases into VS Code storage and writes the MCP server entry automatically.

## What it does

1. Downloads the runtime archive matching the extension version from GitHub Releases.
2. Verifies the archive with the published `checksums.txt` file.
3. Extracts the server binary plus `smart_context`, `types`, and bundled automation assets into the extension runtime folder.
4. Writes the `modelContextProtocol.servers.lmaobox-context` entry into user settings.

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
- `Lmaobox Context: Open Runtime Folder`
- `Lmaobox Context: Open Bundled Docs Folder`
