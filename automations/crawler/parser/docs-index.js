import { promises as fs } from 'fs';
import path from 'path';
import { TYPES_DIR, TYPES_NAMESPACE } from '../config.js';
import { db } from '../database/queries.js';

export async function generateDocsIndex() {
	console.log('[DocsIndex] Generating docs-index.json for AI access...');

	const pages = db.getAllPages();
	const index = {};

	for (const page of pages) {
		if (!page.path) continue;
		const base = path.basename(page.path);
		if (base === 'index' || base === 'API_changelog') continue;

		const key = path.basename(page.path) || 'index';
		const typeDef = db.getTypeDefinition(page.url);

		index[key] = {
			url: page.url,
			path: `${TYPES_NAMESPACE}/${page.path}`,
			title: page.title || key,
			page_type: page.page_type || 'page',
			depth: page.depth || 0,
			parent_url: page.parent_url || null,
			has_type_definition: !!typeDef,
			last_updated: page.last_fetched || null
		};

		// Try to extract function/class names from type definition if available
		if (typeDef && typeDef.type_content) {
			const content = typeDef.type_content;
			const functions = [];
			const classes = [];

			// Extract function names
			const funcMatches = content.matchAll(/function\s+(\w+)\.(\w+)/g);
			for (const match of funcMatches) {
				functions.push(`${match[1]}.${match[2]}`);
			}

			// Extract class names
			const classMatches = content.matchAll(/---@class\s+(\w+)/g);
			for (const match of classMatches) {
				classes.push(match[1]);
			}

			if (functions.length > 0) index[key].functions = functions;
			if (classes.length > 0) index[key].classes = classes;
		}
	}

	const indexPath = path.join(TYPES_DIR, 'docs-index.json');
	await fs.writeFile(indexPath, JSON.stringify(index, null, 2), 'utf8');

	console.log(`[DocsIndex] Generated index with ${Object.keys(index).length} entries`);
	return index;
}
