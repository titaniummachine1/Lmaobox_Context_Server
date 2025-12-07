import { parseDocumentationPage } from '../parser/html.js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const htmlPath = path.join(__dirname, '../../../.cache/docs/Lua_Libraries/engine.html');
const html = fs.readFileSync(htmlPath, 'utf-8');

console.log('Parsing engine page...\n');
const page = parseDocumentationPage(html, 'https://lmaobox.net/lua/Lua_Libraries/engine/');

console.log(`Total functions: ${page.functions.length}`);
console.log(`Functions with descriptions: ${page.functions.filter(f => f.description && f.description.length > 0).length}\n`);

// Test specific functions
const testFuncs = ['Con_IsVisible', 'TraceLine', 'GetPointContents', 'SetViewAngles', 'SendKeyValues'];
testFuncs.forEach(name => {
	const func = page.functions.find(f => f.name === name);
	if (func) {
		console.log(`${name}:`);
		console.log(`  Description: "${func.description || '(none)'}"`);
		console.log(`  Params: ${func.params.length}`);
	} else {
		console.log(`${name}: NOT FOUND`);
	}
});

// Write detailed output
const output = {
	total: page.functions.length,
	withDesc: page.functions.filter(f => f.description).length,
	withoutDesc: page.functions.filter(f => !f.description).length,
	functions: page.functions.map(f => ({
		name: f.name,
		hasDesc: !!f.description,
		desc: f.description || null,
		descLength: f.description ? f.description.length : 0,
		paramsCount: f.params.length
	}))
};

fs.writeFileSync(
	path.join(__dirname, 'engine-extraction-test.json'),
	JSON.stringify(output, null, 2)
);

console.log('\n=== Full output written to engine-extraction-test.json ===');
