import { db } from '../database/queries.js';
import { TYPES_NAMESPACE } from '../config.js';

export async function generateDocsIndexDb() {
	const pages = db.getAllPages();
	db.clearDocsIndex();

	for (const page of pages) {
		const hasTypeDefinition = !!db.getTypeDefinition(page.url);
		db.insertDocsIndex({
			url: page.url,
			path: `${TYPES_NAMESPACE}/${page.path || ''}`,
			title: page.title || page.path || page.url,
			page_type: page.page_type || 'page',
			depth: page.depth || 0,
			parent_url: page.parent_url || null,
			has_type_definition: hasTypeDefinition ? 1 : 0,
			last_updated: page.last_fetched || null
		});
	}

	return pages.length;
}

if (import.meta.url === `file://${process.argv[1]}`) {
	generateDocsIndexDb()
		.then((count) => console.log(`[DocsIndexDB] Indexed ${count} pages`))
		.catch((err) => {
			console.error('[DocsIndexDB] Failed:', err);
			process.exit(1);
		});
}

