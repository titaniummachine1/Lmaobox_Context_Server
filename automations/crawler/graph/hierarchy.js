import path from 'path';
import { promises as fs } from 'fs';
import { TYPES_BASE_DIR } from '../config.js';
import { buildFolderPath } from '../utils/paths.js';
import { db } from '../database/queries.js';

export async function generateFolderHierarchy() {
	console.log('[Hierarchy] Generating folder structure from shortest paths...');

	const pages = db.getAllPagesWithPaths();

	// Group by directory path
	const pagesByDir = {};
	for (const page of pages) {
		if (!page.path) continue;

		const dirPath = path.dirname(page.path) || '.';
		const sanitizedDir = buildFolderPath(dirPath);

		if (!pagesByDir[sanitizedDir]) {
			pagesByDir[sanitizedDir] = [];
		}
		pagesByDir[sanitizedDir].push(page);
	}

	// Create directory structure
	for (const [dirPath, dirPages] of Object.entries(pagesByDir)) {
		const typeDir = path.join(TYPES_BASE_DIR, dirPath === '.' ? '' : dirPath);
		await fs.mkdir(typeDir, { recursive: true });
		console.log(`[Hierarchy] Created directory: ${typeDir} (${dirPages.length} pages)`);
	}

	return pagesByDir;
}
