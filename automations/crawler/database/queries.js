import { getDatabase } from './schema.js';

export const db = {
	// Pages
	insertPage(page) {
		const db = getDatabase();
		const existing = this.getPage(page.url);

		// Preserve existing fields if not provided (especially parsed_data/path)
		const parsedDataValue = page.parsed_data !== undefined ? page.parsed_data : existing?.parsed_data || null;
		const pathValue = page.path !== undefined ? page.path : existing?.path || null;
		const titleValue = page.title !== undefined ? page.title : existing?.title || null;
		const contentHashValue = page.content_hash !== undefined ? page.content_hash : existing?.content_hash || null;
		const lastFetchedValue = page.last_fetched !== undefined ? page.last_fetched : existing?.last_fetched || null;
		const fetchCountValue = page.fetch_count !== undefined ? page.fetch_count : existing?.fetch_count || 0;
		const pageTypeValue = page.page_type !== undefined ? page.page_type : existing?.page_type || null;
		const parentUrlValue = page.parent_url !== undefined ? page.parent_url : existing?.parent_url || null;
		const depthValue = page.depth !== undefined ? page.depth : existing?.depth || 0;
		const sitemapOrderValue = page.sitemap_order !== undefined ? page.sitemap_order : existing?.sitemap_order || null;

		const stmt = db.prepare(`
			INSERT OR REPLACE INTO pages 
			(url, path, title, content_hash, last_fetched, fetch_count, page_type, parent_url, depth, sitemap_order, parsed_data)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		`);
		const parsedDataJson = typeof parsedDataValue === 'string' ? parsedDataValue : (parsedDataValue ? JSON.stringify(parsedDataValue) : null);

		return stmt.run(
			page.url,
			pathValue,
			titleValue,
			contentHashValue,
			lastFetchedValue || Date.now(),
			fetchCountValue,
			pageTypeValue,
			parentUrlValue,
			depthValue,
			sitemapOrderValue,
			parsedDataJson
		);
	},

	getPage(url) {
		const db = getDatabase();
		return db.prepare('SELECT * FROM pages WHERE url = ?').get(url);
	},

	getAllPages() {
		const db = getDatabase();
		return db.prepare('SELECT * FROM pages ORDER BY sitemap_order').all();
	},

	getAllPagesWithPaths() {
		const db = getDatabase();
		return db.prepare('SELECT * FROM pages WHERE path IS NOT NULL ORDER BY path').all();
	},

	getAllPagesWithParsedData() {
		const db = getDatabase();
		return db.prepare('SELECT * FROM pages WHERE parsed_data IS NOT NULL ORDER BY url').all();
	},

	updatePagePath(url, pathInfo) {
		const db = getDatabase();
		const stmt = db.prepare(`
			UPDATE pages 
			SET path = ?, parent_url = ?, depth = ?
			WHERE url = ?
		`);
		return stmt.run(pathInfo.path, pathInfo.parent || null, pathInfo.depth, url);
	},

	updatePageHash(url, hash) {
		const db = getDatabase();
		const stmt = db.prepare('UPDATE pages SET content_hash = ?, last_fetched = ?, fetch_count = fetch_count + 1 WHERE url = ?');
		return stmt.run(hash, Date.now(), url);
	},

	updatePageParsedData(url, parsedData) {
		const db = getDatabase();
		const stmt = db.prepare('UPDATE pages SET parsed_data = ? WHERE url = ?');
		return stmt.run(JSON.stringify(parsedData), url);
	},

	getAllGlobals() {
		const db = getDatabase();
		const pages = db.prepare('SELECT url, title, parsed_data FROM pages WHERE parsed_data IS NOT NULL').all();
		const globals = new Set();

		for (const page of pages) {
			try {
				const parsed = JSON.parse(page.parsed_data);
				const url = page.url.toLowerCase();
				const title = (page.title || '').toLowerCase();

				// Check if this is a globals page
				const isGlobalsPage = url.includes('global') || title.includes('global') ||
					url.includes('lua-globals') || title.includes('lua globals');

				// Functions that are not part of a class or library are globals
				if (parsed.functions && parsed.functions.length > 0) {
					const hasLibraries = parsed.libraries && parsed.libraries.length > 0;
					const hasClasses = parsed.classes && parsed.classes.length > 0;

					// If it's a globals page, or has no libraries/classes, functions are globals
					if (isGlobalsPage || (!hasLibraries && !hasClasses)) {
						for (const func of parsed.functions) {
							globals.add(func.name);
						}
					}
				}

				// Constants are always globals
				if (parsed.constants && parsed.constants.length > 0) {
					for (const constant of parsed.constants) {
						globals.add(constant.name);
					}
				}
			} catch (e) {
				// Skip invalid JSON
			}
		}

		return Array.from(globals).sort();
	},

	// Links
	insertLink(link) {
		const db = getDatabase();
		const stmt = db.prepare(`
			INSERT OR REPLACE INTO links (from_url, to_url, link_text, link_type)
			VALUES (?, ?, ?, ?)
		`);
		return stmt.run(link.from_url, link.to_url, link.link_text || null, link.link_type || 'internal');
	},

	getLinksFrom(url) {
		const db = getDatabase();
		return db.prepare('SELECT * FROM links WHERE from_url = ?').all(url);
	},

	getLinksTo(url) {
		const db = getDatabase();
		return db.prepare('SELECT * FROM links WHERE to_url = ?').all(url);
	},

	clearLinksForPage(url) {
		const db = getDatabase();
		return db.prepare('DELETE FROM links WHERE from_url = ?').run(url);
	},

	// Sitemap
	saveSitemapSnapshot(urls) {
		const db = getDatabase();
		const stmt = db.prepare(`
			INSERT INTO sitemap_snapshots (timestamp, url_count, urls_json)
			VALUES (?, ?, ?)
		`);
		return stmt.run(Date.now(), urls.length, JSON.stringify(urls));
	},

	getLatestSitemapSnapshot() {
		const db = getDatabase();
		return db.prepare('SELECT * FROM sitemap_snapshots ORDER BY timestamp DESC LIMIT 1').get();
	},

	// Type definitions
	saveTypeDefinition(url, path, content) {
		const db = getDatabase();
		const stmt = db.prepare(`
			INSERT OR REPLACE INTO type_definitions (url, path, generated_at, type_content)
			VALUES (?, ?, ?, ?)
		`);
		return stmt.run(url, path, Date.now(), content);
	},

	getTypeDefinition(url) {
		const db = getDatabase();
		return db.prepare('SELECT * FROM type_definitions WHERE url = ?').get(url);
	},

	// Update log
	logUpdate(updateType, pagesUpdated, durationMs) {
		const db = getDatabase();
		const stmt = db.prepare(`
			INSERT INTO update_log (timestamp, update_type, pages_updated, duration_ms)
			VALUES (?, ?, ?, ?)
		`);
		return stmt.run(Date.now(), updateType, pagesUpdated, durationMs);
	},

	// Symbols graph (materialized)
	clearMaterializedSymbols() {
		const db = getDatabase();
		db.exec(`
			DELETE FROM signatures;
			DELETE FROM examples;
			DELETE FROM constants;
			DELETE FROM docs;
			DELETE FROM symbols;
		`);
	},

	upsertSymbol(symbol) {
		const db = getDatabase();
		const stmt = db.prepare(`
			INSERT INTO symbols (full_name, kind, parent_full_name, page_url, path, title, description)
			VALUES (@full_name, @kind, @parent_full_name, @page_url, @path, @title, @description)
			ON CONFLICT(full_name) DO UPDATE SET
				kind=excluded.kind,
				parent_full_name=excluded.parent_full_name,
				page_url=excluded.page_url,
				path=excluded.path,
				title=excluded.title,
				description=excluded.description
		`);
		return stmt.run(symbol);
	},

	upsertSignature(sig) {
		const db = getDatabase();
		const stmt = db.prepare(`
			INSERT INTO signatures (symbol_full_name, signature, returns, params_json)
			VALUES (@symbol_full_name, @signature, @returns, @params_json)
			ON CONFLICT(symbol_full_name) DO UPDATE SET
				signature=excluded.signature,
				returns=excluded.returns,
				params_json=excluded.params_json
		`);
		return stmt.run(sig);
	},

	insertExample(example) {
		const db = getDatabase();
		const stmt = db.prepare(`
			INSERT INTO examples (symbol_full_name, example_text, source_url)
			VALUES (@symbol_full_name, @example_text, @source_url)
		`);
		return stmt.run(example);
	},

	insertConstant(constant) {
		const db = getDatabase();
		const stmt = db.prepare(`
			INSERT INTO constants (symbol_full_name, name, value, description, category)
			VALUES (@symbol_full_name, @name, @value, @description, @category)
		`);
		return stmt.run(constant);
	},

	upsertDoc(doc) {
		const db = getDatabase();
		const stmt = db.prepare(`
			INSERT INTO docs (symbol_full_name, summary, notes)
			VALUES (@symbol_full_name, @summary, @notes)
			ON CONFLICT(symbol_full_name) DO UPDATE SET
				summary=excluded.summary,
				notes=excluded.notes
		`);
		return stmt.run(doc);
	},

	clearDocsIndex() {
		const db = getDatabase();
		db.exec(`DELETE FROM docs_index;`);
	},

	insertDocsIndex(entry) {
		const db = getDatabase();
		const stmt = db.prepare(`
			INSERT INTO docs_index (url, path, title, page_type, depth, parent_url, has_type_definition, last_updated)
			VALUES (@url, @path, @title, @page_type, @depth, @parent_url, @has_type_definition, @last_updated)
			ON CONFLICT(url) DO UPDATE SET
				path=excluded.path,
				title=excluded.title,
				page_type=excluded.page_type,
				depth=excluded.depth,
				parent_url=excluded.parent_url,
				has_type_definition=excluded.has_type_definition,
				last_updated=excluded.last_updated
		`);
		return stmt.run(entry);
	}
};
