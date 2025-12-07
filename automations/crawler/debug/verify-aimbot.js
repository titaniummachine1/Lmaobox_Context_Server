import { promises as fs } from 'fs';
import path from 'path';
import { parseDocumentationPage } from '../parser/html.js';
import { generateTypeForPage } from '../parser/types.js';
import { WORKSPACE_ROOT } from '../config.js';

async function main() {
	const htmlPath = path.join(WORKSPACE_ROOT, '.cache', 'docs', 'Lua_Libraries', 'aimbot.html');
	if (!await fs.access(htmlPath).then(() => true).catch(() => false)) {
		console.error('HTML file not found:', htmlPath);
		return;
	}

	const html = await fs.readFile(htmlPath, 'utf8');
	const parsed = parseDocumentationPage(html, 'https://lmaobox.net/lua/Lua_Libraries/aimbot/');
	parsed.url = 'https://lmaobox.net/lua/Lua_Libraries/aimbot/';
	parsed.path = 'Lua_Libraries/aimbot';

	console.log('=== Parser Results ===');
	console.log('Title:', parsed.title);
	console.log('Description:', parsed.description || '(none)');
	console.log('Libraries:', parsed.libraries);
	console.log('Functions found:', parsed.functions.length);
	parsed.functions.forEach((f, i) => {
		console.log(`  ${i + 1}. ${f.name}(${f.params.map(p => p.name).join(', ')}) - desc: ${f.description ? 'YES' : 'NO'}`);
	});
	console.log('Examples found:', parsed.examples.length);
	parsed.examples.forEach((ex, i) => {
		console.log(`  ${i + 1}. ${ex.substring(0, 50)}...`);
	});

	console.log('\n=== Generating File ===');
	const result = await generateTypeForPage(parsed);
	console.log('Result:', result);
	if (result.filePath) {
		const content = await fs.readFile(result.filePath, 'utf8');
		console.log('\n=== Generated Content (first 500 chars) ===');
		console.log(content.substring(0, 500));
	} else {
		console.log('File generation was skipped');
	}
}

main().catch(err => {
	console.error('Error:', err);
	console.error(err.stack);
	process.exit(1);
});
