import { db } from '../database/queries.js';
import { getDatabase } from '../database/schema.js';

function inferParent(parsed) {
	if (parsed.libraries && parsed.libraries.length === 1) {
		return parsed.libraries[0];
	}
	if (parsed.classes && parsed.classes.length === 1) {
		return parsed.classes[0];
	}
	return null;
}

function primarySymbol(parsed, page) {
	return inferParent(parsed) || (parsed.title || page.title) || page.url;
}

function fullName(child, parent) {
	return parent ? `${parent}.${child}` : child;
}

export function materializeSymbolsFromParsedData() {
	const conn = getDatabase();
	const pages = db.getAllPagesWithParsedData();
	db.clearMaterializedSymbols();

	for (const page of pages) {
		let parsed;
		try {
			parsed = JSON.parse(page.parsed_data);
		} catch {
			continue;
		}

		const parent = inferParent(parsed);
		const baseSymbol = primarySymbol(parsed, page);

		const baseSymbolRow = {
			full_name: baseSymbol,
			kind: 'page',
			parent_full_name: null,
			page_url: page.url,
			path: page.path,
			title: page.title || parsed.title || baseSymbol,
			description: parsed.description || ''
		};
		db.upsertSymbol(baseSymbolRow);
		db.upsertDoc({ symbol_full_name: baseSymbol, summary: parsed.description || '', notes: '' });

		// Libraries
		for (const lib of parsed.libraries || []) {
			db.upsertSymbol({
				full_name: lib,
				kind: 'library',
				parent_full_name: null,
				page_url: page.url,
				path: page.path,
				title: lib,
				description: parsed.description || ''
			});
		}

		// Classes
		for (const cls of parsed.classes || []) {
			db.upsertSymbol({
				full_name: cls,
				kind: 'class',
				parent_full_name: null,
				page_url: page.url,
				path: page.path,
				title: cls,
				description: parsed.description || ''
			});
		}

		// Constants
		for (const c of parsed.constants || []) {
			const parentName = parent || baseSymbol;
			const full = fullName(c.name || c.constant || c.value || 'CONST', parentName);
			db.upsertSymbol({
				full_name: full,
				kind: 'constant',
				parent_full_name: parentName,
				page_url: page.url,
				path: page.path,
				title: c.name || full,
				description: c.description || c.desc || ''
			});
			db.insertConstant({
				symbol_full_name: full,
				name: c.name || full,
				value: c.value || '',
				description: c.description || c.desc || '',
				category: c.category || ''
			});
		}

		// Functions
		for (const fn of parsed.functions || []) {
			const parentName = parent || baseSymbol;
			const full = fullName(fn.name || 'fn', parentName);
			db.upsertSymbol({
				full_name: full,
				kind: 'function',
				parent_full_name: parentName,
				page_url: page.url,
				path: page.path,
				title: fn.name || full,
				description: fn.description || fn.desc || ''
			});
			db.upsertSignature({
				symbol_full_name: full,
				signature: fn.signature || fn.name || full,
				returns: fn.returns ? JSON.stringify(fn.returns) : null,
				params_json: fn.params ? JSON.stringify(fn.params) : null
			});
		}

		// Examples (attach to parent/base)
		for (const ex of parsed.examples || []) {
			const target = parent || baseSymbol;
			db.insertExample({
				symbol_full_name: target,
				example_text: ex,
				source_url: page.url
			});
		}
	}

	conn.close();
}

if (import.meta.url === `file://${process.argv[1]}`) {
	materializeSymbolsFromParsedData();
	console.log('[Materialize] Symbols graph populated from parsed_data');
}

