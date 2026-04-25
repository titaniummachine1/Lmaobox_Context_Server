const vscode = require('vscode');
const path = require('path');
const os = require('os');
const crypto = require('crypto');
const https = require('https');
const fs = require('fs/promises');
const extract = require('extract-zip');

const SERVER_ID = 'lmaobox-context';
const MCP_PROVIDER_ID = 'lmaobox-provider';
const SUMNEKO_EXTENSION_ID = 'sumneko.lua';
let setupInFlightPromise;
let setupInFlightOptions;
let warnedInvalidReleaseTag = false;

function activate(context) {
    context.subscriptions.push(
        vscode.commands.registerCommand('lmaoboxContext.installOrUpdateRuntime', async () => {
            await runAutomaticSetup(context, { interactive: true, force: true, reason: 'manual install command' });
        }),
        vscode.commands.registerCommand('lmaoboxContext.openRuntimeFolder', async () => {
            const runtime = await runAutomaticSetup(context, {
                interactive: false,
                force: false,
                reason: 'open runtime folder command',
                skipLegacyMcpConfig: true,
                skipExternalToolInjection: true,
                skipSumnekoInstall: true
            });
            await revealPath(runtime.runtimeDir);
        }),
        vscode.commands.registerCommand('lmaoboxContext.openBundledDocsFolder', async () => {
            const runtime = await runAutomaticSetup(context, {
                interactive: false,
                force: false,
                reason: 'open bundled docs command',
                skipLegacyMcpConfig: true,
                skipExternalToolInjection: true,
                skipSumnekoInstall: true
            });
            await revealPath(path.join(runtime.runtimeDir, 'smart_context'));
        }),
        vscode.commands.registerCommand('lmaoboxContext.syncExternalMcpConfigs', async () => {
            const runtime = await runAutomaticSetup(context, {
                interactive: false,
                force: false,
                reason: 'sync external configs command',
                skipLegacyMcpConfig: true,
                skipExternalToolInjection: true,
                skipSumnekoInstall: true
            });
            const result = await injectToExternalTools(runtime);
            void vscode.window.showInformationMessage(`Lmaobox Context synced ${result.updatedCount} external MCP config file(s).`);
        })
    );

    const providerRegistration = registerMcpServerDefinitionProvider(context);
    if (providerRegistration) {
        context.subscriptions.push(providerRegistration);
    }

    void bootstrapExtension(context);
}

function deactivate() { }

async function bootstrapExtension(context) {
    await runAutomaticSetup(context, { interactive: false, force: false, reason: 'extension activation' });
}

async function runAutomaticSetup(context, options) {
    const mergedOptions = {
        interactive: false,
        force: false,
        reason: 'automatic setup',
        skipLegacyMcpConfig: false,
        skipExternalToolInjection: false,
        skipSumnekoInstall: false,
        ...options
    };

    if (setupInFlightPromise) {
        if (mergedOptions.force && !(setupInFlightOptions && setupInFlightOptions.force)) {
            await setupInFlightPromise;
        } else {
            return setupInFlightPromise;
        }
    }

    const setupPromise = (async () => {
        try {
            if (!mergedOptions.skipSumnekoInstall) {
                await ensureSumnekoLuaLanguageServer({ interactive: mergedOptions.interactive });
            }
            const runtime = await ensureInstalledAndConfigured(context, {
                interactive: false,
                force: mergedOptions.force,
                skipLegacyMcpConfig: mergedOptions.skipLegacyMcpConfig,
                skipExternalToolInjection: mergedOptions.skipExternalToolInjection
            });

            if (mergedOptions.interactive) {
                void vscode.window.showInformationMessage(`Lmaobox Context setup completed. Runtime ${runtime.releaseTag} is installed and MCP integration is configured.`);
            }

            return runtime;
        } catch (err) {
            handleSetupError(err, mergedOptions.reason, mergedOptions.interactive);
            throw err;
        }
    })();

    setupInFlightPromise = setupPromise;
    setupInFlightOptions = mergedOptions;

    try {
        return await setupPromise;
    } finally {
        if (setupInFlightPromise === setupPromise) {
            setupInFlightPromise = undefined;
            setupInFlightOptions = undefined;
        }
    }
}

function handleSetupError(err, reason, interactive) {
    const details = err instanceof Error ? err.message : String(err);
    const guidance = getSuggestedFix(details);
    const fullMessage = `Lmaobox Context automatic setup failed during ${reason}: ${details}${guidance ? ` Suggested fix: ${guidance}` : ''}`;

    console.error(fullMessage, err);
    if (interactive) {
        void vscode.window.showErrorMessage(fullMessage);
    } else {
        void vscode.window.showWarningMessage(fullMessage);
    }
}

function getSuggestedFix(details) {
    const normalized = String(details || '').toLowerCase();
    if (normalized.includes('unexpected eof') || normalized.includes('unexpected end of json input')) {
        return 'A config file was corrupted during write. Delete ~/.cursor/mcp.json, ~/.codeium/windsurf/mcp_config.json, or %APPDATA%/Claude/claude_desktop_config.json and try again.';
    }
    if (details.includes('checksums.txt') || details.includes('runtime_') || details.includes('HTTP 404')) {
        return 'Publish a GitHub release with checksums.txt and runtime archives, or set lmaoboxContext.releaseTag to a valid released version.';
    }
    if (details.includes('Unsupported platform')) {
        return 'Use a runtime release built for your OS and CPU architecture.';
    }
    if (details.includes('Checksum verification failed')) {
        return 'Rebuild and republish the runtime archive and checksums.txt so they match.';
    }
    return 'Run "Lmaobox Context: Install Or Update Runtime" again after verifying the extension release assets exist.';
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
    const mergedOptions = {
        interactive: false,
        force: false,
        skipLegacyMcpConfig: false,
        skipExternalToolInjection: false,
        ...options
    };

    const releaseTag = getReleaseTag(context);
    const hasTagOverride = hasValidReleaseTagOverride();
    let effectiveTag = releaseTag;
    let runtimeDir = path.join(context.globalStorageUri.fsPath, 'runtime', effectiveTag);
    let serverPath = path.join(runtimeDir, getBinaryName());

    await fs.mkdir(context.globalStorageUri.fsPath, { recursive: true });

    if (mergedOptions.force || !(await pathExists(serverPath))) {
        const installResult = await installRuntime(context, releaseTag, { allowFallbackToLatest: !hasTagOverride });
        effectiveTag = installResult.releaseTag;
        runtimeDir = installResult.runtimeDir;
        serverPath = installResult.serverPath;
    }

    if (!mergedOptions.skipLegacyMcpConfig && shouldUseLegacyMcpConfiguration() && getExtensionConfig().get('autoConfigureMcp', true)) {
        await configureMcp(serverPath, runtimeDir);
    }

    if (!mergedOptions.skipExternalToolInjection && getExtensionConfig().get('autoInjectExternalMcpConfigs', true)) {
        await injectToExternalTools({ releaseTag: effectiveTag, runtimeDir, serverPath });
    }

    if (mergedOptions.interactive) {
        void vscode.window.showInformationMessage('Lmaobox Context runtime is installed and MCP settings are configured.');
    }

    return { releaseTag: effectiveTag, runtimeDir, serverPath };
}

function registerMcpServerDefinitionProvider(context) {
    if (!isMcpProviderApiAvailable()) {
        return undefined;
    }

    return vscode.lm.registerMcpServerDefinitionProvider(MCP_PROVIDER_ID, {
        provideMcpServerDefinitions: async () => {
            const runtime = await runAutomaticSetup(context, {
                interactive: false,
                force: false,
                reason: 'provider definitions request',
                skipLegacyMcpConfig: true,
                skipExternalToolInjection: true,
                skipSumnekoInstall: true
            });
            return [createMcpServerDefinition(runtime)];
        },
        resolveMcpServerDefinition: async () => {
            const runtime = await runAutomaticSetup(context, {
                interactive: false,
                force: false,
                reason: 'provider resolve request',
                skipLegacyMcpConfig: true,
                skipExternalToolInjection: true,
                skipSumnekoInstall: true
            });

            if (!(await pathExists(runtime.serverPath))) {
                void vscode.window.showErrorMessage('Lmaobox runtime missing. Run "Lmaobox Context: Install Or Update Runtime".');
                return undefined;
            }

            return createMcpServerDefinition(runtime);
        }
    });
}

function createMcpServerDefinition(runtime) {
    const version = runtime.releaseTag.replace(/^v/i, '');
    const env = {
        LMAOBOX_CONTEXT_RUNTIME_CWD: runtime.runtimeDir
    };
    return new vscode.McpStdioServerDefinition(
        'Lmaobox Context',
        runtime.serverPath,
        ['--prefer-lua-ls'],
        env,
        version
    );
}

function isMcpProviderApiAvailable() {
    return Boolean(
        vscode &&
        vscode.lm &&
        typeof vscode.lm.registerMcpServerDefinitionProvider === 'function' &&
        typeof vscode.McpStdioServerDefinition === 'function'
    );
}

function shouldUseLegacyMcpConfiguration() {
    return !isMcpProviderApiAvailable();
}

function getExternalMcpTargets() {
    const homeDir = os.homedir();
    const appData = process.env.APPDATA || path.join(homeDir, 'AppData', 'Roaming');
    const localAppData = process.env.LOCALAPPDATA || path.join(homeDir, 'AppData', 'Local');

    const customTargetRaw = getExtensionConfig().get('externalMcpConfigPath', '').trim();
    const targets = [
        {
            name: 'Cursor',
            configPath: path.join(homeDir, '.cursor', 'mcp.json')
        },
        {
            name: 'Windsurf Legacy',
            configPath: path.join(homeDir, '.codeium', 'windsurf', 'mcp_config.json')
        },
        {
            name: 'Claude Desktop',
            configPath: path.join(appData, 'Claude', 'claude_desktop_config.json')
        },
        {
            name: 'Antigravity',
            configPath: path.join(homeDir, '.antigravity', 'mcp.json')
        },
        {
            name: 'Antigravity Windows',
            configPath: path.join(appData, 'Antigravity', 'mcp.json')
        },
        {
            name: 'Antigravity Windows Local',
            configPath: path.join(localAppData, 'Antigravity', 'mcp.json')
        }
    ];

    if (customTargetRaw) {
        targets.push({
            name: 'Custom MCP Config',
            configPath: path.resolve(customTargetRaw)
        });
    }

    return targets;
}

function createExternalServerSpec(runtime) {
    return {
        command: runtime.serverPath,
        args: ['--prefer-lua-ls'],
        env: {
            LMAOBOX_CONTEXT_RUNTIME_CWD: runtime.runtimeDir
        }
    };
}

async function injectToExternalTools(runtime) {
    const targets = getExternalMcpTargets();
    const serverName = getExtensionConfig().get('externalMcpServerName', 'lmaobox-context').trim() || 'lmaobox-context';
    const desired = createExternalServerSpec(runtime);

    let updatedCount = 0;
    const results = [];

    for (const target of targets) {
        try {
            const targetDir = path.dirname(target.configPath);
            if (!(await pathExists(targetDir))) {
                results.push(`${target.name}: skipped (dir not found)`);
                continue;
            }

            const updated = await upsertExternalMcpConfig(target.configPath, serverName, desired);
            if (updated) {
                updatedCount += 1;
                results.push(`${target.name}: updated`);
            } else {
                results.push(`${target.name}: no changes`);
            }
        } catch (err) {
            results.push(`${target.name}: error - ${err.message}`);
            console.error(`Failed to inject MCP config for ${target.name} at ${target.configPath}:`, err);
        }
    }

    console.log(`External MCP injection results:\n${results.join('\n')}`);
    return { updatedCount, results };
}

async function upsertExternalMcpConfig(configPath, serverName, desiredServerSpec) {
    let root = {};
    if (await pathExists(configPath)) {
        try {
            const raw = await fs.readFile(configPath, 'utf8');
            root = raw.trim() ? JSON.parse(raw) : {};
        } catch (err) {
            // If file is invalid JSON, preserve by skipping mutation.
            console.warn(`Skipping ${configPath} due to invalid JSON: ${err.message}`);
            return false;
        }
    }

    if (!root || typeof root !== 'object' || Array.isArray(root)) {
        root = {};
    }

    if (!root.mcpServers || typeof root.mcpServers !== 'object' || Array.isArray(root.mcpServers)) {
        root.mcpServers = {};
    }

    const current = root.mcpServers[serverName];
    const desiredJson = JSON.stringify(desiredServerSpec);
    const currentJson = JSON.stringify(current || null);
    if (currentJson === desiredJson) {
        return false;
    }

    root.mcpServers[serverName] = desiredServerSpec;

    // Write to temp file first, then rename atomically to prevent corruption
    const tempPath = `${configPath}.tmp`;
    const content = `${JSON.stringify(root, null, 2)}\n`;
    try {
        await fs.writeFile(tempPath, content, 'utf8');
        // Verify the written content is valid JSON before committing
        const written = await fs.readFile(tempPath, 'utf8');
        JSON.parse(written);
        // Move temp to actual location atomically
        await fs.rm(configPath, { force: true });
        await fs.rename(tempPath, configPath);
    } catch (err) {
        // Clean up temp file on error
        await fs.rm(tempPath, { force: true });
        throw new Error(`Failed to write MCP config to ${configPath}: ${err.message}`);
    }
    return true;
}

function getExtensionConfig() {
    return vscode.workspace.getConfiguration('lmaoboxContext');
}

function getReleaseTag(context) {
    const override = getExtensionConfig().get('releaseTag', '').trim();
    const normalizedOverride = normalizeReleaseTag(override);
    if (normalizedOverride) {
        return normalizedOverride;
    }

    if (override) {
        warnInvalidReleaseTag(override, context.extension.packageJSON.version);
    }

    return `v${context.extension.packageJSON.version}`;
}

function hasValidReleaseTagOverride() {
    const override = getExtensionConfig().get('releaseTag', '').trim();
    return Boolean(normalizeReleaseTag(override));
}

function normalizeReleaseTag(rawTag) {
    if (!rawTag) {
        return '';
    }

    const cleaned = String(rawTag).trim().replace(/^refs\/tags\//i, '');
    if (!cleaned) {
        return '';
    }

    // Reject path-like values to prevent malformed release URLs like C:\Users\...
    if (cleaned.includes('\\') || cleaned.includes('/') || cleaned.includes(':')) {
        return '';
    }

    if (cleaned.length > 64 || /^\.+$/.test(cleaned)) {
        return '';
    }

    if (!/^[A-Za-z0-9._-]+$/.test(cleaned)) {
        return '';
    }

    return cleaned;
}

function warnInvalidReleaseTag(rawTag, suggestedVersion) {
    const message = `Ignoring invalid lmaoboxContext.releaseTag value "${rawTag}". Use a GitHub tag like "v${suggestedVersion}".`;
    console.warn(message);
    if (warnedInvalidReleaseTag) {
        return;
    }

    warnedInvalidReleaseTag = true;
    void vscode.window.showWarningMessage(message);
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

async function installRuntime(context, releaseTag, options = { allowFallbackToLatest: false }) {
    const repoOwner = getExtensionConfig().get('repoOwner', 'titaniummachine1').trim();
    const repoName = getExtensionConfig().get('repoName', 'Lmaobox_Context_Server').trim();
    const assetName = getRuntimeAssetName();
    const downloadDir = path.join(context.globalStorageUri.fsPath, 'downloads');
    const archivePath = path.join(downloadDir, assetName);

    await fs.mkdir(downloadDir, { recursive: true });
    let effectiveTag = releaseTag;
    let checksumsPath = path.join(downloadDir, `${effectiveTag}-checksums.txt`);

    try {
        await downloadReleaseAsset(repoOwner, repoName, effectiveTag, 'checksums.txt', checksumsPath);
    } catch (err) {
        if (options.allowFallbackToLatest && isHttpStatusError(err, 404)) {
            const candidateTags = await fetchReleaseFallbackTags(repoOwner, repoName);
            let resolvedFallback = false;
            for (const candidateTag of candidateTags) {
                if (!candidateTag || candidateTag === effectiveTag) {
                    continue;
                }

                try {
                    effectiveTag = candidateTag;
                    checksumsPath = path.join(downloadDir, `${effectiveTag}-checksums.txt`);
                    await downloadReleaseAsset(repoOwner, repoName, effectiveTag, 'checksums.txt', checksumsPath);
                    resolvedFallback = true;
                    break;
                } catch (fallbackErr) {
                    if (!isHttpStatusError(fallbackErr, 404)) {
                        throw fallbackErr;
                    }
                }
            }

            if (!resolvedFallback) {
                throw new Error(`No published runtime release assets were found for ${repoOwner}/${repoName}.`);
            }
        } else {
            throw err;
        }
    }

    const runtimeDir = path.join(context.globalStorageUri.fsPath, 'runtime', effectiveTag);
    await fs.rm(runtimeDir, { recursive: true, force: true });
    await fs.mkdir(runtimeDir, { recursive: true });

    await downloadReleaseAsset(repoOwner, repoName, effectiveTag, assetName, archivePath);

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

    return {
        releaseTag: effectiveTag,
        runtimeDir,
        serverPath
    };
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
    if (await pathExists(bundledSnippets)) {
        await fs.mkdir(runtimeSnippets, { recursive: true });
        const snippetFiles = await fs.readdir(bundledSnippets, { withFileTypes: true });
        for (const entry of snippetFiles) {
            if (!entry.isFile()) {
                continue;
            }
            const sourceFile = path.join(bundledSnippets, entry.name);
            const targetFile = path.join(runtimeSnippets, entry.name);
            await fs.copyFile(sourceFile, targetFile);
        }
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
    const encodedTag = encodeURIComponent(tag);
    const encodedAssetName = encodeURIComponent(assetName);
    const url = `https://github.com/${owner}/${repo}/releases/download/${encodedTag}/${encodedAssetName}`;
    const response = await downloadWithRedirects(url);

    if (response.statusCode !== 200) {
        const error = new Error(`Failed to download ${assetName} from ${url} (HTTP ${response.statusCode}).`);
        error.httpStatusCode = response.statusCode;
        throw error;
    }

    const chunks = [];
    for await (const chunk of response) {
        chunks.push(chunk);
    }
    await fs.writeFile(destination, Buffer.concat(chunks));
}

function isHttpStatusError(err, statusCode) {
    return Boolean(err && typeof err === 'object' && err.httpStatusCode === statusCode);
}

async function fetchReleaseFallbackTags(owner, repo) {
    const url = `https://api.github.com/repos/${owner}/${repo}/releases?per_page=20`;
    const response = await downloadWithRedirects(url, 0, {
        'Accept': 'application/vnd.github+json'
    });

    if (response.statusCode !== 200) {
        const error = new Error(`Failed to query published releases from ${url} (HTTP ${response.statusCode}).`);
        error.httpStatusCode = response.statusCode;
        throw error;
    }

    const chunks = [];
    for await (const chunk of response) {
        chunks.push(chunk);
    }

    const payload = JSON.parse(Buffer.concat(chunks).toString('utf8'));
    if (!Array.isArray(payload) || payload.length === 0) {
        throw new Error(`No published releases were returned from ${url}.`);
    }

    const tags = [];
    for (const release of payload) {
        if (!release || typeof release !== 'object') {
            continue;
        }

        const tagName = typeof release.tag_name === 'string' ? release.tag_name.trim() : '';
        if (!tagName) {
            continue;
        }

        tags.push(tagName);
    }

    if (tags.length === 0) {
        throw new Error(`No usable release tags were returned from ${url}.`);
    }

    return tags;
}

function downloadWithRedirects(url, redirectCount = 0, extraHeaders = undefined) {
    return new Promise((resolve, reject) => {
        if (redirectCount > 5) {
            reject(new Error(`Too many redirects while downloading ${url}`));
            return;
        }

        https.get(url, {
            headers: {
                'User-Agent': 'lmaobox-context-vscode-extension',
                ...(extraHeaders || {})
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
