import { parseDocumentationPage } from '../parser/html.js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const htmlPath = path.join(__dirname, '../../.cache/docs/Lua_Libraries/engine.html');
const html = fs.readFileSync(htmlPath, 'utf-8');

const page = parseDocumentationPage(html, 'https://lmaobox.net/lua/Lua_Libraries/engine/');

// Check Con_IsVisible specifically
const conIsVisible = page.functions.find(f => f.name === 'Con_IsVisible');
console.log('Con_IsVisible function:');
console.log('  Name:', conIsVisible?.name);
console.log('  Has description:', !!conIsVisible?.description);
console.log('  Description:', conIsVisible?.description || '(none)');
console.log('  Params:', conIsVisible?.params?.length || 0);
console.log('  Section:', conIsVisible?.section);

// Check a few more
console.log('\n=== First 5 functions ===');
page.functions.slice(0, 5).forEach(f => {
	console.log(`${f.name}: description="${f.description ? f.description.substring(0, 50) + '...' : '(none)'}"`);
});

// Write full data
fs.writeFileSync(
	path.join(__dirname, 'test-simple-desc-output.json'),
	JSON.stringify({
		total: page.functions.length,
		withDesc: page.functions.filter(f => f.description).length,
		withoutDesc: page.functions.filter(f => !f.description).length,
		sample: page.functions.slice(0, 10).map(f => ({
			name: f.name,
			hasDesc: !!f.description,
			descLength: f.description?.length || 0,
			description: f.description?.substring(0, 100) || null
		}))
	}, null, 2)
);

console.log('\n=== Output written to test-simple-desc-output.json ===');
