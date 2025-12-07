import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { parseDocumentationPage } from '../parser/html.js';
import { WORKSPACE_ROOT } from '../config.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

try {
	const htmlPath = path.join(WORKSPACE_ROOT, '.cache', 'docs', 'Lua_Classes', 'BitBuffer.html');
	const html = fs.readFileSync(htmlPath, 'utf8');
	const parsed = parseDocumentationPage(html, 'https://lmaobox.net/lua/Lua_Classes/BitBuffer/');
	const outputPath = path.join(__dirname, 'parsed-bitbuffer.json');
	fs.writeFileSync(outputPath, JSON.stringify(parsed, null, 2));
	console.log('OK', parsed.title, parsed.functions.length, parsed.classes, parsed.libraries, parsed.constants.length, parsed.examples.length);
} catch (e) {
	console.error('ERR', e);
	const errorPath = path.join(__dirname, 'parsed-bitbuffer-error.txt');
	fs.writeFileSync(errorPath, String(e.stack || e));
}
