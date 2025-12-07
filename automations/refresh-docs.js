#!/usr/bin/env node
/**
 * Refresh Documentation Types
 *
 * Manually triggers the crawler to fetch latest docs and generate type definitions.
 * This bypasses the 24-hour rate limit and forces a full refresh.
 *
 * Usage:
 *   node automations/refresh-docs.js
 *   node automations/refresh-docs.js --url=https://lmaobox.net/lua/Lua_Constants/   # single-page debug
 */

import path from 'path';
import { promises as fs } from 'fs';

import { generateTypeForPage } from './crawler/parser/types.js';
import { parseDocumentationPage } from './crawler/parser/html.js';
import { API_BASE_URL, CACHE_DIR } from './crawler/config.js';
import { runRefresh } from './refresh-runner.js';
import { materializeSymbolsFromParsedData } from './crawler/graph/materialize.js';

// Check if dependencies are installed
async function checkDependencies() {
	try {
		await import('better-sqlite3');
	} catch (error) {
		console.error('❌ Missing dependencies!');
		console.error('Please run: cd automations && npm install');
		console.error('\nOr use the VS Code task: Ctrl+Shift+P → Tasks: Run Task → 🔄 Refresh Documentation Types');
		process.exit(1);
	}
}

async function runSinglePage(target) {
	const targetUrl = target.startsWith('http')
		? target
		: new URL(target, API_BASE_URL).href;

	const rel = targetUrl.replace(API_BASE_URL, '').replace(/\/$/, '') || 'index';
	const cachePath = path.join(CACHE_DIR, rel + '.html');

	try {
		const html = await fs.readFile(cachePath, 'utf8');
		const parsed = parseDocumentationPage(html, targetUrl);
		parsed.url = targetUrl;
		parsed.path = rel;

		console.log('═══════════════════════════════════════════════════════════');
		console.log('  🔍 Single-page generation (debug mode)');
		console.log('═══════════════════════════════════════════════════════════\n');
		console.log(`[Single] Using cache: ${cachePath}`);
		console.log(`[Single] Generating type for: ${parsed.path}`);
		console.log(`[Single] Description: ${parsed.description || '(none)'}`);
		console.log(`[Single] Functions: ${parsed.functions.length}`);
		const funcsWithDesc = parsed.functions.filter(f => f.description && f.description.length > 0);
		console.log(`[Single] Functions with descriptions: ${funcsWithDesc.length}`);
		if (funcsWithDesc.length > 0) {
			console.log(`[Single] Sample descriptions:`);
			funcsWithDesc.slice(0, 3).forEach(f => {
				console.log(`  - ${f.name}: "${f.description.substring(0, 50)}..."`);
			});
		}
		console.log(`[Single] Examples: ${parsed.examples.length}`);

		const result = await generateTypeForPage(parsed);
		console.log(`[Single] Generated file: ${result.filePath || '(skipped)'}`);
		await generateDocsIndex();

		console.log('\n[Single] ✅ Done.');
		console.log('═══════════════════════════════════════════════════════════');
		return;
	} catch (error) {
		console.error(`[Single] ❌ Could not process ${targetUrl}: ${error.message}`);
		process.exit(1);
	}
}

async function main() {
	// Optional debug mode: generate types for a single page from cache
	const singleArg = process.argv.find(arg => arg.startsWith('--url=') || arg.startsWith('--page='));
	if (singleArg) {
		const target = singleArg.split('=')[1];
		if (!target) {
			console.error('[Single] ❌ Missing value for --url= or --page=');
			process.exit(1);
		}
		await checkDependencies();
		await runSinglePage(target);
		return;
	}

	// Check dependencies first
	await checkDependencies();

	console.log('═══════════════════════════════════════════════════════════');
	console.log('  🔄 Refreshing Documentation Types');
	console.log('═══════════════════════════════════════════════════════════\n');

	try {
		await runRefresh({ mode: 'full' });

		console.log('═══════════════════════════════════════════════════════════');
		console.log('  ✅ Refresh Complete!');
		console.log('═══════════════════════════════════════════════════════════');
		console.log('\n💡 Tip: Reload VS Code window (Ctrl+Shift+P → "Developer: Reload Window")');
		console.log('   to see the new type definitions in action.\n');

	} catch (error) {
		console.error('\n[Refresh] ❌ Error:', error);
		console.error(error.stack);
		process.exit(1);
	}
}

main();
