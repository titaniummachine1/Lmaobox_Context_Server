import { promises as fs } from 'fs';
import path from 'path';
import { parseDocumentationPage } from '../parser/html.js';
import { WORKSPACE_ROOT } from '../config.js';

async function main() {
	const htmlPath = path.join(WORKSPACE_ROOT, '.cache', 'docs', 'Lua_Libraries', 'aimbot.html');
	const html = await fs.readFile(htmlPath, 'utf8');
	const parsed = parseDocumentationPage(html, 'https://lmaobox.net/lua/Lua_Libraries/aimbot/');

	console.log('Title:', parsed.title);
	console.log('Description:', parsed.description || '(none)');
	console.log('Examples:', parsed.examples.length);
	parsed.examples.forEach((ex, i) => {
		console.log(`\nExample ${i + 1}:`);
		console.log(ex);
	});
	console.log('\nFunctions:');
	parsed.functions.forEach(func => {
		console.log(`  ${func.name}(${func.params.map(p => p.name).join(', ')})`);
		console.log(`    Description: ${func.description || '(none)'}`);
	});
}

main().catch(console.error);
