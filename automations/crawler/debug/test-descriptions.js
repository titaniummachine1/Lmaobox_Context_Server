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
console.log('\n=== Checking descriptions ===');

const functionsWithDesc = page.functions.filter(f => f.description && f.description.length > 0);
const functionsWithoutDesc = page.functions.filter(f => !f.description || f.description.length === 0);

console.log(`Functions WITH description: ${functionsWithDesc.length}`);
console.log(`Functions WITHOUT description: ${functionsWithoutDesc.length}`);

if (functionsWithDesc.length > 0) {
	console.log('\n=== Sample functions WITH descriptions ===');
	functionsWithDesc.slice(0, 5).forEach(func => {
		console.log(`\n${func.name}:`);
		console.log(`  Description: "${func.description.substring(0, 100)}${func.description.length > 100 ? '...' : ''}"`);
	});
}

if (functionsWithoutDesc.length > 0) {
	console.log('\n=== Sample functions WITHOUT descriptions ===');
	functionsWithoutDesc.slice(0, 5).forEach(func => {
		console.log(`\n${func.name}:`);
		console.log(`  Section: "${func.section}"`);
	});
}

// Check specific functions
console.log('\n=== Specific checks ===');
const traceLine = page.functions.find(f => f.name === 'TraceLine');
if (traceLine) {
	console.log(`TraceLine description: "${traceLine.description}"`);
	console.log(`TraceLine section: "${traceLine.section}"`);
}

const getPoint = page.functions.find(f => f.name === 'GetPointContents');
if (getPoint) {
	console.log(`GetPointContents description: "${getPoint.description}"`);
}

const setView = page.functions.find(f => f.name === 'SetViewAngles');
if (setView) {
	console.log(`SetViewAngles description: "${setView.description}"`);
}

// Write full output to file
const output = {
	totalFunctions: page.functions.length,
	withDescription: functionsWithDesc.length,
	withoutDescription: functionsWithoutDesc.length,
	sampleWithDesc: functionsWithDesc.slice(0, 10).map(f => ({
		name: f.name,
		description: f.description,
		section: f.section
	})),
	sampleWithoutDesc: functionsWithoutDesc.slice(0, 10).map(f => ({
		name: f.name,
		section: f.section,
		hasParams: f.params.length > 0
	}))
};

fs.writeFileSync(
	path.join(__dirname, 'test-descriptions-output.json'),
	JSON.stringify(output, null, 2)
);

console.log('\n=== Full output written to test-descriptions-output.json ===');
