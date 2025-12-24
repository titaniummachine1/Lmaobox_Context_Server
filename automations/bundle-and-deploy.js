import { bundle } from "luabundle";
import { promises as fs, existsSync, readdirSync } from "fs";
import path from "path";
import os from "os";
import { execFileSync, spawn } from "child_process";

// Cached Lua compiler to prevent repeated lookups and console spam
let cachedLuac = null;

// Find Lua 5.4+ compiler - REQUIRED
function findLuac() {
  // Return cached result to prevent repeated console output
  if (cachedLuac) {
    return cachedLuac;
  }
  
  const scriptDir = path.dirname(
    new URL(import.meta.url).pathname.replace(/^\/([A-Z]:)/, "$1")
  );
  const bundledLuaDir = path.join(scriptDir, "bin", "lua");

  const candidates = [
    { cmd: path.join(bundledLuaDir, "luac54.exe"), version: "5.4" },
    { cmd: path.join(bundledLuaDir, "luac5.4.exe"), version: "5.4" },
    { cmd: path.join(bundledLuaDir, "luac.exe"), version: "5.4" },
    { cmd: "luac5.4", version: "5.4" },
    { cmd: "luac54", version: "5.4" },
    { cmd: "luac5.5", version: "5.5" },
    { cmd: "luac55", version: "5.5" },
  ];

  for (const { cmd, version } of candidates) {
    try {
      if (path.isAbsolute(cmd) && !existsSync(cmd)) {
        continue;
      }

      execFileSync(cmd, ["-v"], { timeout: 1000 });
      console.log(`[Bundle] Using Lua compiler: ${cmd} (version ${version})`);
      cachedLuac = { cmd, version };
      return cachedLuac;
    } catch (error) {
      continue;
    }
  }

  autoSetupLua();

  for (const { cmd, version } of candidates.slice(0, 3)) {
    if (existsSync(cmd)) {
      console.log(
        `[Bundle] Using auto-installed Lua: ${cmd} (version ${version})`
      );
      cachedLuac = { cmd, version };
      return cachedLuac;
    }
  }

  throw new Error(
    "Lua 5.4+ required but not found.\n" +
      "Install Lua 5.4.2+ from: https://luabinaries.sourceforge.net/\n" +
      "Lmaobox runtime uses Lua 5.4 features (bitwise operators: &, |, ~, <<).\n" +
      "Older Lua versions are NOT supported."
  );
}

// Auto-install Lua 5.4+ if not found
function autoSetupLua() {
  try {
    const scriptDir = path.dirname(
      new URL(import.meta.url).pathname.replace(/^\/([A-Z]:)/, "$1")
    );
    const installScript = path.join(scriptDir, "install_lua.py");

    if (!existsSync(installScript)) {
      console.warn("[Bundle] Auto-installer script not found, skipping");
      return;
    }

    console.log("[Bundle] Auto-installing Lua 5.4+ for frictionless usage...");
    const result = execFileSync("python", [installScript], {
      encoding: "utf8",
      timeout: 120000,
    });
    console.log("[Bundle] " + result);
  } catch (error) {
    console.warn(`[Bundle] Auto-install failed: ${error.message}`);
  }
}

// Get directory and optional entry file from CLI args or env vars
const cliDir = process.argv[2];
const cliEntry = process.argv[3];
const envDir = process.env.PROJECT_DIR;
const envEntry = process.env.ENTRY_FILE;

if (!cliDir && !envDir) {
  console.error("[Bundle] ERROR: No project directory specified.");
  console.error(
    "[Bundle] Usage: node bundle-and-deploy.js <path/to/lua/project> [entryFile.lua]"
  );
  console.error(
    "[Bundle] Or set PROJECT_DIR and optionally ENTRY_FILE environment variables."
  );
  console.error(
    "[Bundle] Example: node bundle-and-deploy.js my_project Main.lua"
  );
  console.error(
    "[Bundle] If entryFile is not Main.lua (case-insensitive), only that file will be deployed (no bundling)."
  );
  process.exit(1);
}

const PROJECT_DIR = path.resolve(cliDir || envDir);

// Entry file: specified by user or find Main.lua (case-insensitive)
function findEntryFile() {
  const specified = cliEntry || envEntry;
  if (specified) {
    return specified;
  }

  // Auto-find Main.lua (case-insensitive) in the project directory root
  if (existsSync(PROJECT_DIR)) {
    const files = readdirSync(PROJECT_DIR);
    const mainFile = files.find((f) => f.toLowerCase() === "main.lua");
    if (mainFile) {
      return mainFile;
    }
  }

  return "Main.lua"; // fallback
}

const ENTRY_FILENAME = findEntryFile();
const ENTRY_FILE = path.join(PROJECT_DIR, ENTRY_FILENAME);
const IS_MAIN = ENTRY_FILENAME.toLowerCase() === "main.lua";
const BUILD_DIR = process.env.BUNDLE_OUTPUT_DIR
  ? path.resolve(process.env.BUNDLE_OUTPUT_DIR)
  : path.join(PROJECT_DIR, "build");

// Track module dependency tree
const moduleGraph = new Map();
const circularDeps = new Set();

function resolveDeployDir() {
  const configured = process.env.DEPLOY_DIR;
  if (configured && configured.trim().length > 0) {
    return path.resolve(configured);
  }

  const base =
    process.env.LOCALAPPDATA || path.join(os.homedir(), "AppData", "Local");
  return path.resolve(path.join(base, "lua"));
}

async function readOutputName() {
  // Default: use project directory name
  const projectName = path.basename(PROJECT_DIR);
  let outputName = `${projectName}.lua`;

  console.log(`[Bundle] Output name: "${outputName}"`);
  return outputName;
}

async function ensureEntryExists() {
  try {
    const stats = await fs.stat(ENTRY_FILE);
    if (!stats.isFile()) {
      throw new Error(`[Bundle] Entry file is not a file: ${ENTRY_FILE}`);
    }
  } catch (error) {
    throw new Error(
      `[Bundle] Entry file missing. Expected at: ${ENTRY_FILE}. ${error.message}`
    );
  }
}

async function validateLuaSyntax(filePath) {
  const luac = findLuac();

  try {
    execFileSync(luac.cmd, ["-p", filePath], {
      encoding: "utf8",
      timeout: 5000,
    });
    return { valid: true, version: luac.version };
  } catch (error) {
    return {
      valid: false,
      error: error.stderr || error.message,
    };
  }
}

async function validateAllLuaFiles(projectDir) {
  const files = [];
  const visited = new Set();

  async function collectLuaFiles(dir) {
    const normalizedDir = path.resolve(dir);

    // Prevent infinite recursion by tracking visited directories
    if (visited.has(normalizedDir)) {
      return;
    }
    visited.add(normalizedDir);

    try {
      const entries = await fs.readdir(dir, { withFileTypes: true });
      for (const entry of entries) {
        const fullPath = path.join(dir, entry.name);
        if (
          entry.isDirectory() &&
          entry.name !== "build" &&
          entry.name !== "node_modules" &&
          !entry.name.startsWith(".")
        ) {
          await collectLuaFiles(fullPath);
        } else if (entry.isFile() && entry.name.endsWith(".lua")) {
          files.push(fullPath);
        }
      }
    } catch (error) {
      console.warn(
        `[Bundle] Warning: Cannot read directory ${dir}: ${error.message}`
      );
    }
  }

  await collectLuaFiles(projectDir);

  for (const file of files) {
    const result = await validateLuaSyntax(file);
    if (!result.valid) {
      const relPath = path.relative(projectDir, file);
      throw new Error(
        `Lua syntax error in ${relPath}:\n${result.error}\n\n` +
          `Fix syntax errors before bundling.`
      );
    }
  }

  return files.length;
}

async function writeBundle(outputPath, bundledLua) {
  await fs.mkdir(path.dirname(outputPath), { recursive: true });
  await fs.writeFile(outputPath, bundledLua, "utf8");
}

async function deployBundle(sourcePath, deployPath) {
  await fs.mkdir(path.dirname(deployPath), { recursive: true });
  await fs.copyFile(sourcePath, deployPath);
}

async function extractRequires(filePath, searchPaths) {
  const content = await fs.readFile(filePath, "utf8");
  const requires = [];
  const requirePattern = /require\s*\(\s*["']([^"']+)["']\s*\)/g;

  let match;
  while ((match = requirePattern.exec(content)) !== null) {
    requires.push(match[1]);
  }

  return requires;
}

async function resolveModulePath(moduleName, searchPaths) {
  // Convert dot notation to path separators (e.g., "utils.helpers" -> "utils/helpers")
  const modulePath = moduleName.replace(/\./g, path.sep);

  for (const searchPath of searchPaths) {
    const candidates = [
      path.join(searchPath, `${modulePath}.lua`),
      path.join(searchPath, modulePath, "init.lua"),
    ];

    for (const candidate of candidates) {
      try {
        const stats = await fs.stat(candidate);
        if (stats.isFile()) {
          return candidate;
        }
      } catch {
        continue;
      }
    }
  }
  return null;
}

async function isGlobalModule(moduleName) {
  // Check if module exists in global lua directory (runtime accessible)
  const globalLuaDir = resolveDeployDir();
  const modulePath = moduleName.replace(/\./g, path.sep);

  const candidates = [
    path.join(globalLuaDir, `${modulePath}.lua`),
    path.join(globalLuaDir, modulePath, "init.lua"),
  ];

  for (const candidate of candidates) {
    try {
      const stats = await fs.stat(candidate);
      if (stats.isFile()) {
        return true;
      }
    } catch {
      continue;
    }
  }
  return false;
}

// Run bundle operation in separate process with timeout to prevent freezes
async function runBundleWithTimeout(projectDir, entryFile, timeoutMs) {
  const scriptDir = path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Z]:)/, "$1"));
  const workerScript = path.join(scriptDir, "bundle-worker.js");

  return new Promise((resolve, reject) => {
    let isResolved = false;
    
    const child = spawn("node", [workerScript, projectDir, entryFile], {
      stdio: ['ignore', 'pipe', 'pipe'],
      detached: false,
    });

    let stdout = '';
    let stderr = '';

    child.stdout.on('data', (data) => {
      stdout += data.toString();
    });

    child.stderr.on('data', (data) => {
      stderr += data.toString();
    });

    const timeout = setTimeout(() => {
      if (!isResolved) {
        isResolved = true;
        child.kill('SIGTERM');
        // Force kill if SIGTERM doesn't work
        setTimeout(() => child.kill('SIGKILL'), 1000);
        reject(new Error(
          `Bundle operation timed out after ${timeoutMs/1000} seconds. This usually indicates:\n` +
          '1. Circular dependency loop\n' +
          '2. Very large project (try splitting into smaller modules)\n' +
          '3. Invalid require() paths causing infinite resolution\n' +
          'Check your dependencies for cycles and fix require() paths.'
        ));
      }
    }, timeoutMs);

    child.on('close', (code, signal) => {
      if (isResolved) return;
      isResolved = true;
      clearTimeout(timeout);

      if (signal) {
        reject(new Error(`Bundle worker was killed with signal ${signal}`));
        return;
      }

      if (code === 0) {
        const lines = stdout.trim().split('\n');
        if (lines.length >= 2 && lines[0] === 'BUNDLE_SUCCESS') {
          const bundledLua = lines.slice(1).join('\n');
          resolve(bundledLua);
        } else {
          reject(new Error(`Unexpected worker output: ${stdout}`));
        }
      } else {
        const errorLines = stderr.trim().split('\n');
        if (errorLines.length >= 2 && errorLines[0] === 'BUNDLE_ERROR') {
          reject(new Error(errorLines.slice(1).join('\n')));
        } else {
          reject(new Error(`Bundle worker failed with code ${code}: ${stderr}`));
        }
      }
    });

    child.on('error', (error) => {
      if (!isResolved) {
        isResolved = true;
        clearTimeout(timeout);
        reject(new Error(`Failed to start bundle worker: ${error.message}`));
      }
    });
  });
}

async function buildDependencyTree(
  entryFile,
  searchPaths,
  visited = new Set(),
  stack = new Set()
) {
  const normalizedEntry = path.normalize(entryFile);

  if (stack.has(normalizedEntry)) {
    circularDeps.add(normalizedEntry);
    return;
  }

  if (visited.has(normalizedEntry)) {
    return;
  }

  visited.add(normalizedEntry);
  stack.add(normalizedEntry);

  const requires = await extractRequires(normalizedEntry, searchPaths);
  const dependencies = [];

  for (const moduleName of requires) {
    const modulePath = await resolveModulePath(moduleName, searchPaths);
    if (modulePath) {
      const normalizedModule = path.normalize(modulePath);
      dependencies.push({
        name: moduleName,
        path: normalizedModule,
      });

      await buildDependencyTree(modulePath, searchPaths, visited, stack);
    } else {
      // Check if it's a global module (exists in runtime lua directory)
      const isGlobal = await isGlobalModule(moduleName);
      dependencies.push({
        name: moduleName,
        path: null,
        unresolved: !isGlobal,
        global: isGlobal,
      });
    }
  }

  moduleGraph.set(normalizedEntry, dependencies);
  stack.delete(normalizedEntry);
}

function printDependencyTree() {
  // Collect all unique files and their direct dependencies
  const allFiles = new Map();

  function collectDeps(filePath) {
    const normalized = path.normalize(filePath);
    if (allFiles.has(normalized)) return;

    const deps = moduleGraph.get(normalized) || [];
    allFiles.set(normalized, deps);

    deps.forEach((dep) => {
      if (dep.path) {
        collectDeps(dep.path);
      }
    });
  }

  collectDeps(ENTRY_FILE);

  // Print flat dependency list
  console.log("\n[Bundle] Dependencies (what requires what):\n");

  allFiles.forEach((deps, filePath) => {
    const relPath = path.relative(PROJECT_DIR, filePath);
    const fileName = path.basename(relPath);

    if (deps.length === 0) {
      console.log(`  ${fileName}`);
    } else {
      const depNames = deps.map((d) => {
        if (d.global) return `${d.name} (global)`;
        if (d.unresolved) return `${d.name} (missing)`;
        return path.basename(
          path.relative(PROJECT_DIR, path.normalize(d.path))
        );
      });
      console.log(`  ${fileName} → ${depNames.join(", ")}`);
    }
  });

  // Print tree structure
  console.log("\n[Bundle] Full Tree:\n");

  const shown = new Set();

  function printTree(filePath, prefix = "", isLast = true) {
    const normalized = path.normalize(filePath);
    const relPath = path.relative(PROJECT_DIR, normalized);
    const fileName = path.basename(relPath);

    // Print current node
    if (prefix === "") {
      console.log(`  ${fileName}`);
    }

    const isCircular = circularDeps.has(normalized);
    const wasShown = shown.has(normalized);

    if (wasShown || isCircular) {
      return;
    }

    shown.add(normalized);

    const deps = moduleGraph.get(normalized) || [];

    deps.forEach((dep, i) => {
      const isLastDep = i === deps.length - 1;
      const branch = isLastDep ? "└─ " : "├─ ";
      const extension = isLastDep ? "   " : "│  ";

      if (dep.global) {
        console.log(`  ${prefix}${branch}${dep.name} (global)`);
      } else if (dep.unresolved) {
        console.log(`  ${prefix}${branch}${dep.name} (missing)`);
      } else if (dep.path) {
        const depNormalized = path.normalize(dep.path);
        const depFileName = path.basename(
          path.relative(PROJECT_DIR, depNormalized)
        );
        const depWasShown = shown.has(depNormalized);

        if (depWasShown) {
          console.log(`  ${prefix}${branch}${depFileName} (...)`);
        } else {
          console.log(`  ${prefix}${branch}${depFileName}`);
          printTree(dep.path, prefix + extension, isLastDep);
        }
      }
    });
  }

  printTree(ENTRY_FILE);

  if (circularDeps.size > 0) {
    console.log("\n  ⚠ Circular dependencies:");
    circularDeps.forEach((dep) => {
      console.log(`    • ${path.relative(PROJECT_DIR, dep)}`);
    });
  }

  console.log("");
}

async function main() {
  const DRY_RUN = process.env.DRY_RUN === "true";

  console.log(`[Bundle] Project directory: ${PROJECT_DIR}`);
  console.log(`[Bundle] Entry file: ${ENTRY_FILENAME}`);
  if (DRY_RUN) {
    console.log(`[Bundle] Mode: DRY RUN (validation only, no deployment)`);
  }

  if (!IS_MAIN) {
    console.log(`[Bundle] ⚠️  Entry file is not Main.lua (case-insensitive)`);
    console.log(`[Bundle] Mode: Single-file deployment (no bundling)`);
  }

  await ensureEntryExists();
  const outputName = await readOutputName();
  await fs.mkdir(BUILD_DIR, { recursive: true });

  // Fast syntax validation BEFORE bundling (prevents hangs)
  console.log("[Bundle] Pre-validating Lua syntax...");
  const fileCount = await validateAllLuaFiles(PROJECT_DIR);
  console.log(`[Bundle] ✓ Validated ${fileCount} file(s)`);

  // Build dependency tree (for AI visibility)
  console.log("[Bundle] Analyzing dependencies...");
  await buildDependencyTree(ENTRY_FILE, [PROJECT_DIR]);
  printDependencyTree();

  // If not Main.lua, just validate syntax and deploy single file
  if (!IS_MAIN) {
    console.log(`[Bundle] Validating Lua syntax...`);
    const prevCwd = process.cwd();
    try {
      process.chdir(PROJECT_DIR);

      // Try to parse with luabundle (syntax check) with timeout protection
      try {
        await runBundleWithTimeout(PROJECT_DIR, ENTRY_FILENAME, 10000);
        console.log(`[Bundle] ✓ Syntax valid`);
      } catch (syntaxError) {
        throw new Error(
          `Lua syntax error in ${ENTRY_FILENAME}:\n` +
            `${syntaxError.message}\n\n` +
            `Fix syntax errors before deployment.`
        );
      }

      // Deploy single file directly
      if (!DRY_RUN) {
        const content = await fs.readFile(ENTRY_FILE, "utf8");
        const deployDir = resolveDeployDir();
        const deployPath = path.join(deployDir, ENTRY_FILENAME);
        await fs.mkdir(deployDir, { recursive: true });
        await fs.writeFile(deployPath, content, "utf8");
        console.log(`[Bundle] ✓ Deployed single file: ${deployPath}`);
      } else {
        console.log(`[Bundle] ✓ Syntax valid (DRY RUN - skipped deployment)`);
      }
      return;
    } finally {
      process.chdir(prevCwd);
    }
  }

  // Bundle Main.lua with dependencies
  const prevCwd = process.cwd();

  // Collect all global modules that need stub files for bundling
  const globalModules = [];
  const stubFiles = [];

  function collectGlobalModules(filePath) {
    const normalizedPath = path.normalize(filePath);
    const deps = moduleGraph.get(normalizedPath) || [];

    for (const dep of deps) {
      if (dep.global) {
        globalModules.push(dep.name);
      } else if (dep.path) {
        collectGlobalModules(dep.path);
      }
    }
  }

  collectGlobalModules(ENTRY_FILE);

  try {
    process.chdir(PROJECT_DIR);

    // Create temporary stub files for global modules
    if (globalModules.length > 0) {
      console.log(
        `[Bundle] Processing ${globalModules.length} global module(s)...`
      );
    }

    for (const moduleName of globalModules) {
      const modulePath = moduleName.replace(/\./g, path.sep);
      const stubPath = path.join(PROJECT_DIR, `${modulePath}.lua`);
      const stubDir = path.dirname(stubPath);

      try {
        await fs.mkdir(stubDir, { recursive: true });
        // Create empty stub that just returns empty table
        await fs.writeFile(
          stubPath,
          `-- Temporary stub for global module '${moduleName}'\nreturn {}`,
          "utf8"
        );
        stubFiles.push(stubPath);
      } catch (stubError) {
        console.warn(
          `[Bundle] ⚠️  Failed to create stub for ${moduleName}: ${stubError.message}`
        );
      }
    }

    let bundledLua;
    try {
      // Run bundle in separate process with hard timeout to prevent freezes
      bundledLua = await runBundleWithTimeout(PROJECT_DIR, ENTRY_FILENAME, 30000);
    } catch (bundleError) {
      throw new Error(
        `Bundling failed: ${bundleError.message}\n` +
          `\nProject directory: ${PROJECT_DIR}\n` +
          `Entry file: ${ENTRY_FILENAME}\n` +
          `\nMake sure:\n` +
          `  1. ${ENTRY_FILENAME} exists in project directory\n` +
          `  2. All require() statements use valid module paths\n` +
          `  3. Required modules exist in the project directory\n` +
          `\nOriginal error: ${bundleError.stack || bundleError.message}`
      );
    }

    // Clean up stub files
    for (const stubFile of stubFiles) {
      try {
        await fs.unlink(stubFile);
      } catch (cleanupError) {
        console.warn(`[Bundle] ⚠️  Cleanup failed: ${cleanupError.message}`);
      }
    }

    // Post-process bundle: remove global module registrations and restore runtime require()
    if (globalModules.length > 0) {
      for (const moduleName of globalModules) {
        // Remove the __bundle_register call for this module
        const escapedName = moduleName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
        const registerPattern = new RegExp(
          `__bundle_register\\("${escapedName}",\\s*function\\([^)]*\\)[\\s\\S]*?\\nend\\)\\s*`,
          "g"
        );
        bundledLua = bundledLua.replace(registerPattern, "");
      }
      console.log(`[Bundle] ✓ Global modules preserved for runtime`);
    }

    const outputPath = path.join(BUILD_DIR, outputName);
    await writeBundle(outputPath, bundledLua);
    console.log(`[Bundle] ✓ Bundle created: ${outputPath}`);

    if (!DRY_RUN) {
      const deployDir = resolveDeployDir();
      const deployPath = path.join(deployDir, outputName);
      await deployBundle(outputPath, deployPath);
      console.log(`[Bundle] ✓ Deployed: ${deployPath}`);
    } else {
      console.log(`[Bundle] ✓ Bundle validated (DRY RUN - skipped deployment)`);
    }
  } finally {
    process.chdir(prevCwd);
  }
}

main().catch((error) => {
  console.error("\n[Bundle] ❌ FAILED");
  console.error("Error:", error.message);
  if (error.stack) {
    console.error("\nStack trace:");
    console.error(error.stack);
  }
  process.exit(1);
});
