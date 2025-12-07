import path from 'path';
import fs from 'fs';
import { CACHE_DIR, API_BASE_URL } from './config.js';
import { parseDocumentationPage } from './parser/html.js';
import { db } from './database/queries.js';

function collectHtmlFiles(dir) {
	const out = [];
	const entries = fs.readdirSync(dir, { withFileTypes: true });
	for (const ent of entries) {
		const full = path.join(dir, ent.name);
		if (ent.isDirectory()) {
			out.push(...collectHtmlFiles(full));
		} else if (ent.isFile() && ent.name.toLowerCase().endsWith('.html')) {
			out.push(full);
		}
	}
	return out;
}

export function seedPagesFromCache() {
	if (!fs.existsSync(CACHE_DIR)) {
		console.log('[CacheSeed] No cache dir, skipping seed.');
		return 0;
	}
	const files = collectHtmlFiles(CACHE_DIR);
	if (files.length === 0) {
		console.log('[CacheSeed] No cached HTML files found.');
		return 0;
	}

	let inserted = 0;
	for (const file of files) {
		try {
			const rel = path.relative(CACHE_DIR, file).replace(/\\/g, '/').replace(/\.html$/i, '');
			const url = new URL(rel, API_BASE_URL).href;
			const html = fs.readFileSync(file, 'utf8');
			const parsed = parseDocumentationPage(html, url);
			parsed.url = url;
			parsed.path = rel || 'index';
			db.insertPage({
				url,
				path: parsed.path,
				title: parsed.title || parsed.path,
				parsed_data: parsed,
				last_fetched: Date.now()
			});
			inserted++;
		} catch (e) {
			console.warn(`[CacheSeed] Failed to seed from ${file}: ${e.message}`);
		}
	}
	console.log(`[CacheSeed] Seeded ${inserted} pages from cached HTML`);
	return inserted;
}

if (import.meta.url === `file://${process.argv[1]}`) {
	seedPagesFromCache();
}

