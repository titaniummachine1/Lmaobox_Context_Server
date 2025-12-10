import { bundle } from "luabundle";
import { promises as fs, existsSync, readdirSync } from "fs";
import path from "path";
import os from "os";

// Get directory from CLI arg or env var
const cliDir = process.argv[2];
const envDir = process.env.PROJECT_DIR;

if (!cliDir && !envDir) {
	console.error("[Bundle] ERROR: No project directory specified.");
	console.error("[Bundle] Usage: node bundle-and-deploy.js <path/to/lua/project>");
	console.error("[Bundle] Or set PROJECT_DIR environment variable.");
	process.exit(1);
}

const PROJECT_DIR = path.resolve(cliDir || envDir);
const ENTRY_FILE = path.join(PROJECT_DIR, "Main.lua");
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
		const relativePath = path.relative(PROJECT_DIR, normalizedPath);
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
			console.log(`  - ${path.relative(PROJECT_DIR, dep)}`);
		});
	}
	
	console.log("\n[Bundle] === End Dependency Tree ===\n");
}

async function main() {
	console.log(`[Bundle] Project directory: ${PROJECT_DIR}`);
	console.log(`[Bundle] Entry: ${ENTRY_FILE}`);

	await ensureEntryExists();
	const outputName = await readOutputName();
	await fs.mkdir(BUILD_DIR, { recursive: true });

	// Build dependency tree (for AI visibility)
	console.log("[Bundle] Analyzing dependencies...");
	await buildDependencyTree(ENTRY_FILE, [PROJECT_DIR]);
	printDependencyTree();

	// Bundle from project directory
	const prevCwd = process.cwd();
	
	try {
		process.chdir(PROJECT_DIR);
		
		let bundledLua;
		try {
			bundledLua = bundle("Main.lua", {
				metadata: false,
				paths: ["."],
				expressionHandler: (module, expression) => {
					if (expression?.loc?.start) {
						const start = expression.loc.start;
						console.warn(
							`⚠️  Non-literal require in '${module.name}' at ${start.line}:${start.column}`,
						);
					} else {
						console.warn(
							`⚠️  Non-literal require in '${module.name}' at unknown location`,
						);
					}
				},
			});
		} catch (bundleError) {
			throw new Error(
				`Bundling failed: ${bundleError.message}\n` +
				`\nProject directory: ${PROJECT_DIR}\n` +
				`Entry file: Main.lua\n` +
				`\nMake sure:\n` +
				`  1. Main.lua exists in project directory\n` +
				`  2. All require() statements use valid module paths\n` +
				`  3. Required modules exist in the project directory\n` +
				`\nOriginal error: ${bundleError.stack || bundleError.message}`
			);
		}

		const outputPath = path.join(BUILD_DIR, outputName);
		await writeBundle(outputPath, bundledLua);
		console.log(`[Bundle] ✓ Created: ${outputPath}`);

		const deployDir = resolveDeployDir();
		const deployPath = path.join(deployDir, outputName);
		await deployBundle(outputPath, deployPath);
		console.log(`[Bundle] ✓ Deployed: ${deployPath}`);
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

