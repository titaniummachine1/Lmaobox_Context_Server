import { parseDocumentationPage } from '../parser/html.js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const htmlPath = path.join(__dirname, '../../.cache/docs/Lua_Libraries/engine.html');
const html = fs.readFileSync(htmlPath, 'utf-8');

const page = parseDocumentationPage(html, 'https://lmaobox.net/lua/Lua_Libraries/engine/');

console.log('Total functions:', page.functions.length);
console.log('Functions with descriptions:', page.functions.filter(f => f.description && f.description.length > 0).length);

// Check specific functions
const testFunctions = ['Con_IsVisible', 'TraceLine', 'GetPointContents', 'SetViewAngles', 'SendKeyValues'];
testFunctions.forEach(funcName => {
	const func = page.functions.find(f => f.name === funcName);
	if (func) {
		console.log(`\n${funcName}:`);
		console.log(`  Has description: ${!!func.description}`);
		console.log(`  Description: "${func.description || '(none)'}"`);
		console.log(`  Params count: ${func.params.length}`);
		console.log(`  Section: "${func.section}"`);
	} else {
		console.log(`\n${funcName}: NOT FOUND`);
	}
});

// Write to file
const output = {
	total: page.functions.length,
	withDesc: page.functions.filter(f => f.description).length,
	withoutDesc: page.functions.filter(f => !f.description).length,
	functions: page.functions.map(f => ({
		name: f.name,
		hasDesc: !!f.description,
		desc: f.description || null,
		paramsCount: f.params.length
	}))
};

fs.writeFileSync(
	path.join(__dirname, 'test-engine-real-output.json'),
	JSON.stringify(output, null, 2)
);

console.log('\n=== Full output written to test-engine-real-output.json ===');
