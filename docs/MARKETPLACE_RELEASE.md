# Marketplace Release Flow

This repository now contains the pieces needed for a zero-clone Marketplace install:

1. GitHub Actions builds tagged runtime archives on GitHub infrastructure.
2. The VS Code extension downloads the matching archive from GitHub Releases.
3. The extension verifies the runtime with `checksums.txt` before extraction.
4. The extension configures `modelContextProtocol.servers.lmaobox-context` automatically.

## Runtime release

The runtime release workflow is [`.github/workflows/release.yml`](../.github/workflows/release.yml).

When you push a tag such as `v1.0.0`, GitHub builds zipped runtime archives for each platform and publishes:

- `lmaobox-context-runtime_windows_amd64.zip`
- `lmaobox-context-runtime_linux_amd64.zip`
- `lmaobox-context-runtime_linux_arm64.zip`
- `lmaobox-context-runtime_darwin_amd64.zip`
- `lmaobox-context-runtime_darwin_arm64.zip`
- `checksums.txt`

Each archive contains:

- `lmaobox-context-server[.exe]`
- `smart_context/`
- `types/`
- `automations/bin/` when present
- `README.md`
- `LICENSE`

That layout matches the Go runtime path resolution in `main.go`, so the packaged server can read bundled docs and type data from its own install directory.

## VS Code extension

The extension source is in [`vscode-extension`](../vscode-extension).

On activation it:

1. Resolves the release tag from the extension version unless `lmaoboxContext.releaseTag` overrides it.
2. Downloads the matching runtime archive and `checksums.txt` from GitHub Releases.
3. Verifies the SHA-256 checksum.
4. Extracts the runtime into the extension `globalStorageUri`.
5. Writes the MCP server entry into user settings.

The optional extension packaging and publish workflow is [`.github/workflows/publish-extension.yml`](../.github/workflows/publish-extension.yml).
If you configure the `VSCE_PAT` repository secret, the workflow can publish the packaged `.vsix` to the VS Code Marketplace after a release is published.

## Publish checklist

1. Update the runtime/extension version together.
2. Commit and push to the protected branch.
3. Push the matching tag, for example `v1.0.0`.
4. Wait for GitHub Actions to publish the runtime release assets.
5. Let [`.github/workflows/publish-extension.yml`](../.github/workflows/publish-extension.yml) package the extension and optionally publish it if `VSCE_PAT` is configured.

## Marketplace outcome

After the extension is published, a user should be able to:

1. Open Extensions in VS Code.
2. Install `Lmaobox Context`.
3. Wait for first activation to finish.
4. Use the MCP server without cloning the repository or building local binaries.
