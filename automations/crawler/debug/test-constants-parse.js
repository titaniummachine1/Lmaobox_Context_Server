import { promises as fs } from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { parseConstantsByCategory } from '../parser/types.js';
import { WORKSPACE_ROOT } from '../config.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Copy the parseConstantsByCategory function here for testing
function parseConstantsByCategory(html) {
	const sections = [];

	// Find h3 headings
	const h3Regex = /<h3[^>]*(?:id="([^"]+)")?[^>]*>([\s\S]*?)<\/h3>/gi;
	let h3Match;
	const h3Positions = [];
	while ((h3Match = h3Regex.exec(html)) !== null) {
		const id = h3Match[1] ? h3Match[1].trim() : null;
		let name = h3Match[2].replace(/<[^>]+>/g, '').trim();
		name = name.replace(/\s+/g, ' ').trim();
		if (name && name.length > 0) {
			h3Positions.push({ id, name, index: h3Match.index });
		}
	}

	console.log(`Found ${h3Positions.length} h3 headings`);
	h3Positions.forEach((h, i) => {
		console.log(`${i + 1}. ${h.name} (id: ${h.id || 'none'})`);
	});

	// Process each h3 section
	for (let i = 0; i < h3Positions.length; i++) {
		const current = h3Positions[i];
		const end = i + 1 < h3Positions.length ? h3Positions[i + 1].index : html.length;
		const section = html.slice(current.index, end);

		const constants = [];

		// Find the table
		const tableMatch = section.match(/<table[^>]*>([\s\S]*?)<\/table>/i);
		if (tableMatch) {
			const tableContent = tableMatch[1];
			const rowRegex = /<tr[^>]*>([\s\S]*?)<\/tr>/gi;
			let rowMatch;
			let isFirstRow = true;

			while ((rowMatch = rowRegex.exec(tableContent)) !== null) {
				if (isFirstRow) {
					isFirstRow = false;
					continue;
				}

				const rowContent = rowMatch[1];
				const cellRegex = /<td[^>]*>([\s\S]*?)<\/td>/gi;
				const cells = [];
				let cellMatch;

				while ((cellMatch = cellRegex.exec(rowContent)) !== null) {
					let cellText = cellMatch[1]
						.replace(/<[^>]+>/g, '')
						.replace(/&lt;/g, '<')
						.replace(/&gt;/g, '>')
						.replace(/&amp;/g, '&')
						.replace(/&quot;/g, '"')
						.replace(/&nbsp;/g, ' ')
						.replace(/\s+/g, ' ')
						.trim();
					cells.push(cellText);
				}

				if (cells.length >= 2) {
					const name = cells[0].trim();
					let value = cells[1].trim();
					value = value.replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&');
					if (name && /^[A-Z_][A-Z0-9_]*$/.test(name)) {
						constants.push({ name, value });
					}
				}
			}
		}

		if (constants.length > 0) {
			const cleanName = current.name.replace(/[^A-Za-z0-9_]/g, '_') || 'constants';
			sections.push({ name: cleanName, constants });
		} else {
			console.log(`⚠️  No constants found for: ${current.name}`);
		}
	}

	return sections;
}

async function main() {
	const htmlPath = path.join(WORKSPACE_ROOT, '.cache', 'docs', 'Lua_Constants.html');
	const html = await fs.readFile(htmlPath, 'utf8');

	console.log('Testing constants parsing...\n');
	const sections = parseConstantsByCategory(html);

	console.log(`\n\nGenerated ${sections.length} sections:\n`);
	sections.forEach((sec, i) => {
		console.log(`${i + 1}. ${sec.name} - ${sec.constants.length} constants`);
	});

	const expected = ['E_UserMessage', 'E_TFCOND', 'E_Character', 'E_GCResults'];
	const found = sections.map(s => s.name);

	console.log('\n\nChecking for missing sections:');
	expected.forEach(name => {
		if (found.includes(name)) {
			console.log(`✅ ${name}`);
		} else {
			console.log(`❌ ${name} - MISSING`);
		}
	});
}

main().catch(console.error);
