import { promises as fs } from 'fs';
import path from 'path';
import { parseConstantsByCategory } from '../parser/types.js';
import { WORKSPACE_ROOT } from '../config.js';

async function main() {
	const htmlPath = path.join(WORKSPACE_ROOT, '.cache', 'docs', 'Lua_Constants.html');
	const html = await fs.readFile(htmlPath, 'utf8');

	console.log('Parsing constants...\n');
	const sections = parseConstantsByCategory(html);

	console.log(`Found ${sections.length} sections:\n`);
	sections.forEach((sec, i) => {
		console.log(`${i + 1}. ${sec.name} - ${sec.constants.length} constants`);
	});

	console.log('\n\nChecking for missing sections...');
	const expected = ['E_UserMessage', 'E_TFCOND', 'E_Character', 'E_GCResults'];
	const found = sections.map(s => s.name);

	expected.forEach(name => {
		if (!found.includes(name)) {
			console.log(`❌ MISSING: ${name}`);
			// Check if it exists in HTML
			const regex = new RegExp(`<h3[^>]*>.*${name.replace('_', '[_ ]')}.*</h3>`, 'i');
			if (regex.test(html)) {
				console.log(`   → Found in HTML but not parsed!`);
			} else {
				console.log(`   → Not found in HTML`);
			}
		} else {
			console.log(`✅ Found: ${name}`);
		}
	});
}

main().catch(console.error);
