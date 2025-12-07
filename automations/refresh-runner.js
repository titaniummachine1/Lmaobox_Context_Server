#!/usr/bin/env node
/**
 * Shared refresh runner.
 * Modes:
 *  - full: runCrawler(force=true) + types + docs index (DB) + symbols graph
 *  - fast: types + docs index (DB) + symbols graph (no crawl)
 */
import fs from 'fs';
import path from 'path';
import { runCrawler } from './crawler/index.js';
import { generateTypesByShortestPath } from './crawler/parser/types.js';
import { generateDocsIndexDb } from './crawler/parser/docs-index-db.js';
import { materializeSymbolsFromParsedData } from './crawler/graph/materialize.js';
import { DB_PATH, WORKSPACE_ROOT } from './crawler/config.js';
import { seedPagesFromCache } from './crawler/cache-seed.js';

function resetDb() {
	// Remove docs-graph.db to avoid stale/invalid state; it will be recreated.
	try {
		if (fs.existsSync(DB_PATH)) {
			fs.rmSync(DB_PATH, { force: true });
			console.log('[RefreshRunner] Removed stale DB:', DB_PATH);
		}
	} catch (e) {
		console.warn('[RefreshRunner] Could not remove DB:', e.message);
	}
}

export async function runRefresh({ mode = 'fast' } = {}) {
	// Zero-trust assertions: ensure we can reach DB and functions exist
	if (typeof runCrawler !== 'function') {
		throw new Error('runCrawler missing');
	}
	if (typeof generateTypesByShortestPath !== 'function' || typeof generateDocsIndexDb !== 'function') {
		throw new Error('type/index generators missing');
	}
	if (typeof materializeSymbolsFromParsedData !== 'function') {
		throw new Error('materializeSymbolsFromParsedData missing');
	}

	// Reset DB for both modes to avoid FK/parsed_data corruption; fast uses cache seed
	resetDb();

	if (mode === 'full') {
		console.log('[RefreshRunner] Full crawl starting...');
		await runCrawler(true);
		console.log('[RefreshRunner] Full crawl done');
	} else {
		console.log('[RefreshRunner] Fast mode (no crawl)');
		const seeded = seedPagesFromCache();
		if (seeded === 0) {
			throw new Error('Fast mode: no cached pages to seed DB; run full refresh once.');
		}
	}

	console.log('[RefreshRunner] Generating types...');
	const generated = await generateTypesByShortestPath();
	console.log(`[RefreshRunner] Types regenerated (count: ${generated})`);

	console.log('[RefreshRunner] Generating docs index (DB)...');
	const indexed = await generateDocsIndexDb();
	console.log(`[RefreshRunner] Docs index regenerated (${indexed} pages)`);

	console.log('[RefreshRunner] Materializing symbols graph...');
	materializeSymbolsFromParsedData();
	console.log('[RefreshRunner] Symbols graph materialized');
}

if (import.meta.url === `file://${process.argv[1]}`) {
	const mode = process.argv.includes('--full') ? 'full' : 'fast';
	runRefresh({ mode })
		.then(() => console.log('[RefreshRunner] Done'))
		.catch((e) => {
			console.error('[RefreshRunner] Failed:', e);
			process.exit(1);
		});
}

