import { readFileSync } from 'fs';
import { join } from 'path';
import { WORKSPACE_ROOT } from '../config.js';

const htmlPath = join(WORKSPACE_ROOT, '.cache', 'docs', 'Lua_Constants.html');
const html = readFileSync(htmlPath, 'utf8');

// Test h3 regex
const h3Regex = /<h3[^>]*(?:id="([^"]+)")?[^>]*>([\s\S]*?)<\/h3>/gi;
const matches = [];
let match;
while ((match = h3Regex.exec(html)) !== null) {
	const id = match[1] ? match[1].trim() : null;
	let name = match[2].replace(/<[^>]+>/g, '').trim();
	name = name.replace(/\s+/g, ' ').trim();
	if (name) {
		matches.push({ id, name });
	}
}

console.log(`Found ${matches.length} h3 headings\n`);
console.log('Looking for missing ones:');
['E_UserMessage', 'E_TFCOND', 'E_Character', 'E_GCResults'].forEach(needle => {
	const found = matches.find(m => m.name === needle);
	if (found) {
		console.log(`✅ ${needle} - Found (id: ${found.id || 'none'})`);
	} else {
		console.log(`❌ ${needle} - NOT FOUND`);
		// Try to find similar
		const similar = matches.filter(m => m.name.toLowerCase().includes(needle.toLowerCase().replace(/_/g, '')));
		if (similar.length > 0) {
			console.log(`   Similar: ${similar.map(s => s.name).join(', ')}`);
		}
	}
});
