import { promises as fs } from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { parseDocumentationPage } from '../parser/html.js';
import { generateTypeForPage } from '../parser/types.js';
import { WORKSPACE_ROOT, TYPES_BASE_DIR } from '../config.js';
import { db } from '../database/queries.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function main() {
	const htmlPath = path.join(WORKSPACE_ROOT, '.cache', 'docs', 'Lua_Libraries', 'aimbot.html');
	const html = await fs.readFile(htmlPath, 'utf8');
	const parsed = parseDocumentationPage(html, 'https://lmaobox.net/lua/Lua_Libraries/aimbot/');
	parsed.url = 'https://lmaobox.net/lua/Lua_Libraries/aimbot/';
	parsed.path = 'Lua_Libraries/aimbot';

	console.log('Title:', parsed.title);
	console.log('Description:', parsed.description || '(none)');
	console.log('Examples:', parsed.examples.length);
	parsed.examples.forEach((ex, i) => {
		console.log(`\nExample ${i + 1} (${ex.length} chars):`);
		console.log(ex.substring(0, 100) + '...');
	});
	console.log('\nFunctions:');
	parsed.functions.forEach(func => {
		console.log(`  ${func.name}(${func.params.map(p => p.name).join(', ')})`);
		console.log(`    Description: ${func.description || '(none)'}`);
	});

	const result = await generateTypeForPage(parsed);
	if (result.filePath) {
		const content = await fs.readFile(result.filePath, 'utf8');
		const outputPath = path.join(__dirname, 'aimbot-test.d.lua');
		await fs.writeFile(outputPath, content, 'utf8');
		console.log(`\n✅ Generated test file: ${outputPath}`);
		console.log(`   Original: ${result.filePath}`);
	} else {
		console.log(`\n❌ File generation was skipped`);
	}
}

main().catch(console.error);
