import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { extractText } from '../parser/html.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const htmlPath = path.join(__dirname, '../../.cache/docs/Lua_Libraries/engine.html');
const html = fs.readFileSync(htmlPath, 'utf-8');

// Test description extraction for Con_IsVisible
const headingText = 'Con_IsVisible()';
const escapedText = headingText.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const headingRegex = new RegExp(`<h3[^>]*>\\s*${escapedText}\\s*</h3>`, 'i');
let headingMatch = html.match(headingRegex);

console.log('Heading text:', headingText);
console.log('Escaped text:', escapedText);
console.log('Regex:', headingRegex);
console.log('Match found:', !!headingMatch);

if (headingMatch) {
	console.log('Match index:', headingMatch.index);
	console.log('Match length:', headingMatch[0].length);
	console.log('Match content:', headingMatch[0].substring(0, 200));

	const headingEnd = headingMatch.index + headingMatch[0].length;
	const afterHeading = html.slice(headingEnd, headingEnd + 1500);

	console.log('\nAfter heading (first 500 chars):');
	console.log(afterHeading.substring(0, 500));

	const nextHeadingMatch = afterHeading.match(/<h[1-6][^>]*>/i);
	const searchLimit = nextHeadingMatch ? nextHeadingMatch.index : afterHeading.length;
	const searchArea = afterHeading.slice(0, searchLimit);

	console.log('\nSearch area (first 500 chars):');
	console.log(searchArea.substring(0, 500));

	const pMatches = searchArea.match(/<p[^>]*>([\s\S]*?)<\/p>/gi);
	console.log('\nParagraph matches found:', pMatches ? pMatches.length : 0);

	if (pMatches && pMatches.length > 0) {
		const description = pMatches.map(p => extractText(p)).join(' ').trim();
		console.log('\nExtracted description:', description);
	} else {
		console.log('\nNo paragraph matches found!');
	}
} else {
	// Try flexible match
	console.log('\nTrying flexible match...');
	const flexibleRegex = new RegExp(`<h3[^>]*>[\\s\\S]*?${escapedText}[\\s\\S]*?</h3>`, 'i');
	headingMatch = html.match(flexibleRegex);
	console.log('Flexible match found:', !!headingMatch);
	if (headingMatch) {
		console.log('Match content:', headingMatch[0].substring(0, 300));
	}
}
