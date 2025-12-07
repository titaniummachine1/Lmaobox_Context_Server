import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { extractText } from '../parser/html.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const htmlPath = path.join(__dirname, '../../.cache/docs/Lua_Libraries/engine.html');
const html = fs.readFileSync(htmlPath, 'utf-8');

// Test Con_IsVisible description extraction
const headingPattern = /<h3[^>]*>(.*?)<\/h3>/gi;
let match;
while ((match = headingPattern.exec(html)) !== null) {
	const text = extractText(match[1]);
	if (text === 'Con_IsVisible()') {
		console.log('Found Con_IsVisible heading');
		console.log('Match index:', match.index);
		console.log('Match length:', match[0].length);
		console.log('Full match:', match[0]);

		const headingEnd = match.index + match[0].length;
		const afterHeading = html.slice(headingEnd, headingEnd + 200);
		console.log('\nAfter heading (first 200 chars):');
		console.log(afterHeading);

		const nextHeadingMatch = afterHeading.match(/<h[1-6][^>]*>/i);
		const searchLimit = nextHeadingMatch ? nextHeadingMatch.index : afterHeading.length;
		const searchArea = afterHeading.slice(0, searchLimit);

		console.log('\nSearch area:');
		console.log(searchArea);

		const pMatches = searchArea.match(/<p[^>]*>([\s\S]*?)<\/p>/gi);
		console.log('\nParagraph matches:', pMatches ? pMatches.length : 0);
		if (pMatches) {
			pMatches.forEach((p, i) => {
				const desc = extractText(p);
				console.log(`  Paragraph ${i + 1}: "${desc}"`);
			});
		}
		break;
	}
}
