import { parseDocumentationPage } from '../parser/html.js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const htmlPath = path.join(__dirname, '../../.cache/docs/Lua_Libraries/engine.html');
const html = fs.readFileSync(htmlPath, 'utf-8');

const page = parseDocumentationPage(html, 'https://lmaobox.net/lua/Lua_Libraries/engine/');

const output = [];

output.push('\n=== Functions ===');
page.functions.forEach(func => {
	output.push(`\n${func.name}(${func.params.map(p => `${p.name}${p.optional ? '?' : ''}: ${p.type}`).join(', ')})`);
	output.push(`  Description: "${func.description}"`);
	output.push(`  Section: "${func.section}"`);
});

output.push('\n=== TraceLine specifically ===');
const traceLine = page.functions.find(f => f.name === 'TraceLine');
if (traceLine) {
	output.push('Params: ' + JSON.stringify(traceLine.params, null, 2));
	output.push('Description: ' + traceLine.description);
}

output.push('\n=== GetPointContents specifically ===');
const getPoint = page.functions.find(f => f.name === 'GetPointContents');
if (getPoint) {
	output.push('Params: ' + JSON.stringify(getPoint.params, null, 2));
	output.push('Description: ' + getPoint.description);
}

output.push('\n=== SetViewAngles specifically ===');
const setView = page.functions.find(f => f.name === 'SetViewAngles');
if (setView) {
	output.push('Params: ' + JSON.stringify(setView.params, null, 2));
	output.push('Description: ' + setView.description);
}

output.push('\n=== SendKeyValues specifically ===');
const sendKey = page.functions.find(f => f.name === 'SendKeyValues');
if (sendKey) {
	output.push('Params: ' + JSON.stringify(sendKey.params, null, 2));
	output.push('Description: ' + sendKey.description);
}

fs.writeFileSync(path.join(__dirname, 'test-engine-output.txt'), output.join('\n'));
console.log('Output written to test-engine-output.txt');
