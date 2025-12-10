import { bundle } from "luabundle";
import { promises as fs } from "fs";
import path from "path";
import os from "os";

const WORKSPACE_ROOT = process.cwd();
const ENTRY_FILE = path.resolve(WORKSPACE_ROOT, "src", "Main.lua");
const BUILD_DIR = path.resolve(
	process.env.BUNDLE_OUTPUT_DIR
		? path.resolve(process.env.BUNDLE_OUTPUT_DIR)
		: path.join(WORKSPACE_ROOT, "build"),
);
const TITLE_FILE = path.resolve(WORKSPACE_ROOT, "automations", "title.txt");

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
	let outputName = "Melee_Tools.lua";
	try {
		const titleContents = (await fs.readFile(TITLE_FILE, "utf8")).trim();
		if (titleContents.length > 0) {
			outputName = titleContents;
		}
	} catch {
		// Missing title.txt is fine; default is used.
	}
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

async function main() {
	console.log(`[Bundle] Working directory: ${WORKSPACE_ROOT}`);
	console.log(`[Bundle] Entry: ${ENTRY_FILE}`);

	await ensureEntryExists();

	const outputName = await readOutputName();
	await fs.mkdir(BUILD_DIR, { recursive: true });

	const bundlePaths = [path.join(WORKSPACE_ROOT, "src"), WORKSPACE_ROOT];

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

