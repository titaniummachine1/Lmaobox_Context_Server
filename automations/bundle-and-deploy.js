import { bundle } from "luabundle";
import { promises as fs, existsSync, readdirSync } from "fs";
import path from "path";
import os from "os";

const WORKSPACE_ROOT = process.cwd();

// Allow override via env var or CLI arg (e.g., ENTRY_FILE=path/to/file.lua)
function resolveEntryFile() {
	const envEntry = process.env.ENTRY_FILE;
	const cliEntry = process.argv[2];
	
	if (cliEntry) {
		return path.resolve(WORKSPACE_ROOT, cliEntry);
	}
	if (envEntry) {
		return path.resolve(WORKSPACE_ROOT, envEntry);
	}
	
	// Default: try src/Main.lua, fallback to any .lua in workspace root
	const defaultEntry = path.resolve(WORKSPACE_ROOT, "src", "Main.lua");
	if (existsSync(defaultEntry)) {
		return defaultEntry;
	}
	
	// Look for any .lua file in root as fallback
	const rootLuaFiles = readdirSync(WORKSPACE_ROOT)
		.filter(f => f.endsWith(".lua"));
	if (rootLuaFiles.length > 0) {
		return path.resolve(WORKSPACE_ROOT, rootLuaFiles[0]);
	}
	
	// Return default anyway, will fail gracefully
	return defaultEntry;
}

const ENTRY_FILE = resolveEntryFile();
const BUILD_DIR = path.resolve(
	process.env.BUNDLE_OUTPUT_DIR
		? path.resolve(process.env.BUNDLE_OUTPUT_DIR)
		: path.join(WORKSPACE_ROOT, "build"),
);
const TITLE_FILE = path.resolve(WORKSPACE_ROOT, "automations", "title.txt");

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
	// Default: use workspace folder name as bundle name
	const workspaceName = path.basename(WORKSPACE_ROOT);
	let outputName = `${workspaceName}.lua`;
	let source = "workspace folder name (fallback)";
	
	try {
		const titleContents = (await fs.readFile(TITLE_FILE, "utf8")).trim();
		if (titleContents.length > 0) {
			outputName = titleContents.endsWith(".lua") ? titleContents : `${titleContents}.lua`;
			source = `title.txt (${path.relative(WORKSPACE_ROOT, TITLE_FILE)})`;
		}
	} catch {
		// Missing title.txt is fine; use workspace name fallback.
	}
	
	console.log(`[Bundle] Output name: "${outputName}" from ${source}`);
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
			`[Bundle] Entry file missing. Expected at: ${ENTRY_FILE}. ${error.message}`,
		);
	}
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

async function buildDependencyTree(entryFile, searchPaths, visited = new Set(), stack = new Set()) {
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
			dependencies.push({
				name: moduleName,
				path: null,
				unresolved: true,
			});
		}
	}

	moduleGraph.set(normalizedEntry, dependencies);
	stack.delete(normalizedEntry);
}

function printDependencyTree() {
	console.log("\n[Bundle] === Dependency Tree ===");
	
	const printed = new Set();
	
	function printNode(filePath, indent = 0, prefix = "") {
		const normalizedPath = path.normalize(filePath);
		const relativePath = path.relative(WORKSPACE_ROOT, normalizedPath);
		const isCircular = circularDeps.has(normalizedPath);
		const marker = isCircular ? " [CIRCULAR]" : "";
		
		console.log(`${" ".repeat(indent)}${prefix}${relativePath}${marker}`);
		
		if (printed.has(normalizedPath) || isCircular) {
			return;
		}
		
		printed.add(normalizedPath);
		
		const deps = moduleGraph.get(normalizedPath) || [];
		deps.forEach((dep, index) => {
			const isLast = index === deps.length - 1;
			const connector = isLast ? "└─" : "├─";
			const childIndent = indent + 2;
			
			if (dep.unresolved) {
				console.log(`${" ".repeat(childIndent)}${connector}${dep.name} [UNRESOLVED]`);
			} else if (dep.path) {
				printNode(dep.path, childIndent, connector);
			}
		});
	}
	
	printNode(ENTRY_FILE);
	
	if (circularDeps.size > 0) {
		console.log("\n[Bundle] ⚠️  Circular dependencies detected:");
		circularDeps.forEach(dep => {
			console.log(`  - ${path.relative(WORKSPACE_ROOT, dep)}`);
		});
	}
	
	console.log("\n[Bundle] === End Dependency Tree ===\n");
}

async function main() {
	console.log(`[Bundle] Working directory: ${WORKSPACE_ROOT}`);
	console.log(`[Bundle] Entry: ${ENTRY_FILE}`);

	await ensureEntryExists();

	const outputName = await readOutputName();
	await fs.mkdir(BUILD_DIR, { recursive: true });

	// Detect if entry is in src/ structure or standalone
	const entryDir = path.dirname(ENTRY_FILE);
	const isInSrc = entryDir.includes(path.join(WORKSPACE_ROOT, "src"));
	
	let bundlePaths;
	if (isInSrc) {
		// Project has src/ structure: search src/ first, then root
		console.log("[Bundle] Mode: Structured project (src/ detected)");
		bundlePaths = [
			path.join(WORKSPACE_ROOT, "src"),
			WORKSPACE_ROOT
		];
	} else {
		// Standalone file or flat structure: search entry dir and workspace root
		console.log("[Bundle] Mode: Standalone file (no src/ structure)");
		bundlePaths = [
			entryDir,
			WORKSPACE_ROOT
		];
	}

	// Build dependency tree before bundling
	console.log("[Bundle] Analyzing dependencies...");
	await buildDependencyTree(ENTRY_FILE, bundlePaths);
	printDependencyTree();

	const bundledLua = bundle(ENTRY_FILE, {
		metadata: false,
		paths: bundlePaths,
		expressionHandler: (module, expression) => {
			if (expression?.loc?.start) {
				const start = expression.loc.start;
				console.warn(
					`WARNING: Non-literal require in '${module.name}' at ${start.line}:${start.column}`,
				);
			} else {
				console.warn(
					`WARNING: Non-literal require in '${module.name}' at unknown location`,
				);
			}
		},
	});

	const outputPath = path.join(BUILD_DIR, outputName);
	await writeBundle(outputPath, bundledLua);
	console.log(`[Bundle] Library created at ${outputPath}`);

	const deployDir = resolveDeployDir();
	const deployPath = path.join(deployDir, outputName);
	await deployBundle(outputPath, deployPath);
	console.log(`[Bundle] Deployed to ${deployPath}`);
}

main().catch((error) => {
	console.error(`[Bundle] Failed: ${error.message}`);
	process.exit(1);
});

