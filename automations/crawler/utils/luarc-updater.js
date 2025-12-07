import { promises as fs } from 'fs';
import path from 'path';
import { WORKSPACE_ROOT } from '../config.js';
import { db } from '../database/queries.js';

const LUARC_PATH = path.join(WORKSPACE_ROOT, '.vscode', '.luarc.json');

// Known globals that should always be included
const KNOWN_GLOBALS = [
	'client',
	'draw',
	'engine',
	'entities',
	'globals',
	'gui',
	'input',
	'render',
	'warp',
	'filesystem',
	'callbacks',
	'Lua__fileName',
	'printc',
	'KEY_NONE',
	'KEY_LSHIFT',
	'KEY_RSHIFT'
];

export async function updateLuarcGlobals() {
	console.log('[LuarcUpdater] Collecting globals from parsed pages...');

	// Get all discovered globals from database
	const discoveredGlobals = db.getAllGlobals();

	// Combine with known globals
	const allGlobals = new Set([...KNOWN_GLOBALS, ...discoveredGlobals]);
	const sortedGlobals = Array.from(allGlobals).sort();

	console.log(`[LuarcUpdater] Found ${discoveredGlobals.length} discovered globals, ${sortedGlobals.length} total`);

	// Read current luarc.json
	let luarcConfig;
	try {
		const content = await fs.readFile(LUARC_PATH, 'utf8');
		luarcConfig = JSON.parse(content);
	} catch (error) {
		console.error(`[LuarcUpdater] Failed to read ${LUARC_PATH}:`, error.message);
		return false;
	}

	// Update diagnostics.globals
	if (!luarcConfig['Lua.diagnostics']) {
		luarcConfig['Lua.diagnostics'] = {};
	}

	const previousGlobals = luarcConfig['Lua.diagnostics'].globals || [];
	const newGlobals = sortedGlobals.filter(g => !previousGlobals.includes(g));
	const removedGlobals = previousGlobals.filter(g => !sortedGlobals.includes(g));

	if (newGlobals.length > 0 || removedGlobals.length > 0) {
		console.log(`[LuarcUpdater] Updating globals: +${newGlobals.length} new, -${removedGlobals.length} removed`);
		luarcConfig['Lua.diagnostics'].globals = sortedGlobals;

		// Write updated config
		await fs.writeFile(LUARC_PATH, JSON.stringify(luarcConfig, null, 4), 'utf8');
		console.log(`[LuarcUpdater] ✅ Updated .luarc.json with ${sortedGlobals.length} globals`);
		return true;
	} else {
		console.log('[LuarcUpdater] No changes to globals');
		return false;
	}
}
