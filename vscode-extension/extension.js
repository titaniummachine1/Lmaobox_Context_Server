const vscode = require('vscode');
const path = require('path');
const os = require('os');
const crypto = require('crypto');
const https = require('https');
const fs = require('fs/promises');
const extract = require('extract-zip');

const SERVER_ID = 'lmaobox-context';
const SUMNEKO_EXTENSION_ID = 'sumneko.lua';

function activate(context) {
    context.subscriptions.push(
        vscode.commands.registerCommand('lmaoboxContext.installOrUpdateRuntime', async () => {
            await ensureSumnekoLuaLanguageServer({ interactive: true });
            await ensureInstalledAndConfigured(context, { interactive: true, force: true });
        }),
        vscode.commands.registerCommand('lmaoboxContext.openRuntimeFolder', async () => {
            const runtime = await ensureInstalledAndConfigured(context, { interactive: true, force: false });
            await revealPath(runtime.runtimeDir);
        }),
        vscode.commands.registerCommand('lmaoboxContext.openBundledDocsFolder', async () => {
            const runtime = await ensureInstalledAndConfigured(context, { interactive: true, force: false });
            await revealPath(path.join(runtime.runtimeDir, 'smart_context'));
        })
    );

    void bootstrapExtension(context);
}

function deactivate() { }

async function bootstrapExtension(context) {
    await ensureSumnekoLuaLanguageServer({ interactive: false });
    await ensureInstalledAndConfigured(context, { interactive: false, force: false });
}

async function ensureSumnekoLuaLanguageServer(options) {
    const alreadyInstalled = vscode.extensions.getExtension(SUMNEKO_EXTENSION_ID);
    if (alreadyInstalled) {
        return true;
    }

    try {
        await vscode.commands.executeCommand('workbench.extensions.installExtension', SUMNEKO_EXTENSION_ID);
    } catch (err) {
        const message = `Failed to auto-install ${SUMNEKO_EXTENSION_ID}. MCP will still run, but Lua diagnostics may be reduced until it is installed.`;
        console.warn(message, err);
        if (options.interactive) {
            void vscode.window.showWarningMessage(message);
        }
        return false;
    }

    const installedNow = vscode.extensions.getExtension(SUMNEKO_EXTENSION_ID);
    if (!installedNow) {
        const message = `${SUMNEKO_EXTENSION_ID} install was requested but is not available yet. Restart Extensions if prompted.`;
        console.warn(message);
        if (options.interactive) {
            void vscode.window.showWarningMessage(message);
        }
        return false;
    }

    return true;
}

async function ensureInstalledAndConfigured(context, options) {
    const releaseTag = getReleaseTag(context);
    const runtimeDir = path.join(context.globalStorageUri.fsPath, 'runtime', releaseTag);
    const serverPath = path.join(runtimeDir, getBinaryName());

    await fs.mkdir(context.globalStorageUri.fsPath, { recursive: true });

    if (options.force || !(await pathExists(serverPath))) {
        await installRuntime(context, releaseTag, runtimeDir);
    }

    if (getExtensionConfig().get('autoConfigureMcp', true)) {
        await configureMcp(serverPath, runtimeDir);
    }

    if (options.interactive) {
        void vscode.window.showInformationMessage('Lmaobox Context runtime is installed and MCP settings are configured.');
    }

    return { releaseTag, runtimeDir, serverPath };
}

function getExtensionConfig() {
    return vscode.workspace.getConfiguration('lmaoboxContext');
}

function getReleaseTag(context) {
    const override = getExtensionConfig().get('releaseTag', '').trim();
    if (override) {
        return override;
    }
    return `v${context.extension.packageJSON.version}`;
}

function getBinaryName() {
    return process.platform === 'win32' ? 'lmaobox-context-server.exe' : 'lmaobox-context-server';
}

function getRuntimeAssetName() {
    const platformMap = {
        win32: 'windows',
        linux: 'linux',
        darwin: 'darwin'
    };
    const archMap = {
        x64: 'amd64',
        arm64: 'arm64'
    };

    const platform = platformMap[process.platform];
    const arch = archMap[process.arch];
    if (!platform || !arch) {
        throw new Error(`Unsupported platform for Lmaobox Context runtime: ${process.platform}/${process.arch}`);
    }

    return `lmaobox-context-runtime_${platform}_${arch}.zip`;
}

async function installRuntime(context, releaseTag, runtimeDir) {
    const repoOwner = getExtensionConfig().get('repoOwner', 'titaniummachine1').trim();
    const repoName = getExtensionConfig().get('repoName', 'lmaobox-context-protocol').trim();
    const assetName = getRuntimeAssetName();
    const downloadDir = path.join(context.globalStorageUri.fsPath, 'downloads');
    const archivePath = path.join(downloadDir, assetName);
    const checksumsPath = path.join(downloadDir, `${releaseTag}-checksums.txt`);

    await fs.mkdir(downloadDir, { recursive: true });
    await fs.rm(runtimeDir, { recursive: true, force: true });
    await fs.mkdir(runtimeDir, { recursive: true });

    await downloadReleaseAsset(repoOwner, repoName, releaseTag, 'checksums.txt', checksumsPath);
    await downloadReleaseAsset(repoOwner, repoName, releaseTag, assetName, archivePath);

    const expectedHash = await findExpectedHash(checksumsPath, assetName);
    const actualHash = await computeSha256(archivePath);
    if (actualHash !== expectedHash) {
        throw new Error(`Checksum verification failed for ${assetName}. Expected ${expectedHash}, got ${actualHash}.`);
    }

    await extract(archivePath, { dir: runtimeDir });

    const serverPath = path.join(runtimeDir, getBinaryName());
    if (!(await pathExists(serverPath))) {
        throw new Error(`Installed runtime is missing ${path.basename(serverPath)} after extraction.`);
    }
    // Ensure critical assets exist: if the release ZIP did not include `types` or
    // `smart_context`, copy bundled assets shipped inside the extension `assets/`
    // directory into the runtime folder so the server has what it needs.
    try {
        await ensureBundledAssets(runtimeDir, context);
    } catch (err) {
        // Don't block installation for optional bundling failures, but report.
        console.warn('Failed to copy bundled assets into runtime:', err);
    }
}

async function ensureBundledAssets(runtimeDir, context) {
    const bundledRoot = path.join(context.extensionPath, 'assets');
    const assets = [
        { name: 'types', dest: path.join(runtimeDir, 'types') },
        { name: 'smart_context', dest: path.join(runtimeDir, 'smart_context') }
    ];

    for (const a of assets) {
        const src = path.join(bundledRoot, a.name);
        const existsInRuntime = await pathExists(a.dest);
        if (existsInRuntime) {
            continue;
        }

        const srcExists = await pathExists(src);
        if (!srcExists) {
            // bundled asset not present inside extension - skip
            continue;
        }

        // copy bundled asset into runtime dir
        await fs.cp(src, a.dest, { recursive: true });
    }

    const bundledSnippets = path.join(context.extensionPath, 'snippets');
    const runtimeSnippets = path.join(runtimeDir, 'snippets');
    if (!(await pathExists(runtimeSnippets)) && (await pathExists(bundledSnippets))) {
        await fs.cp(bundledSnippets, runtimeSnippets, { recursive: true });
    }
}

async function configureMcp(serverPath, runtimeDir) {
    const configuration = vscode.workspace.getConfiguration('modelContextProtocol');
    const servers = Object.assign({}, configuration.get('servers', {}));

    servers[SERVER_ID] = {
        type: 'stdio',
        command: serverPath,
        cwd: runtimeDir,
        args: ['--prefer-lua-ls'],
        disabled: false
    };

    await configuration.update('servers', servers, vscode.ConfigurationTarget.Global);
}

async function revealPath(targetPath) {
    await fs.mkdir(targetPath, { recursive: true });
    await vscode.commands.executeCommand('revealFileInOS', vscode.Uri.file(targetPath));
}

async function findExpectedHash(checksumsPath, assetName) {
    const content = await fs.readFile(checksumsPath, 'utf8');
    const lines = content.split(/\r?\n/);
    for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed) {
            continue;
        }
        const match = trimmed.match(/^([a-fA-F0-9]{64})\s+\*?(.+)$/);
        if (!match) {
            continue;
        }
        if (match[2] === assetName) {
            return match[1].toLowerCase();
        }
    }
    throw new Error(`Could not find checksum entry for ${assetName}.`);
}

async function computeSha256(filePath) {
    const data = await fs.readFile(filePath);
    return crypto.createHash('sha256').update(data).digest('hex');
}

async function downloadReleaseAsset(owner, repo, tag, assetName, destination) {
    const url = `https://github.com/${owner}/${repo}/releases/download/${tag}/${assetName}`;
    const response = await downloadWithRedirects(url);

    if (response.statusCode !== 200) {
        throw new Error(`Failed to download ${assetName} from ${url} (HTTP ${response.statusCode}).`);
    }

    const chunks = [];
    for await (const chunk of response) {
        chunks.push(chunk);
    }
    await fs.writeFile(destination, Buffer.concat(chunks));
}

function downloadWithRedirects(url, redirectCount = 0) {
    return new Promise((resolve, reject) => {
        if (redirectCount > 5) {
            reject(new Error(`Too many redirects while downloading ${url}`));
            return;
        }

        https.get(url, {
            headers: {
                'User-Agent': 'lmaobox-context-vscode-extension'
            }
        }, response => {
            const statusCode = response.statusCode || 0;
            if (statusCode >= 300 && statusCode < 400 && response.headers.location) {
                response.resume();
                resolve(downloadWithRedirects(response.headers.location, redirectCount + 1));
                return;
            }
            resolve(response);
        }).on('error', reject);
    });
}

async function pathExists(targetPath) {
    try {
        await fs.access(targetPath);
        return true;
    } catch {
        return false;
    }
}

module.exports = {
    activate,
    deactivate
};
