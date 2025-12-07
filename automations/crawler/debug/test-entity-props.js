import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { WORKSPACE_ROOT } from '../config.js';

function mapTypeToLua(docType) {
	const t = docType.toLowerCase();
	if (['integer', 'int', 'number', 'float', 'double'].includes(t)) return 'number';
	if (t === 'string') return 'string';
	if (t === 'bool' || t === 'boolean') return 'boolean';
	if (t === 'vector' || t === 'vector3') return 'Vector3';
	if (t === 'datatable' || t === 'array' || t === 'table') return 'table';
	if (t === 'entity') return 'Entity|nil';
	return 'any';
}

function parseEntityPropsFromHtml(html) {
	const entities = [];
	const h3Regex = /<h3[^>]*>([^<]+)<\/h3>/gi;
	let match;
	const positions = [];
	while ((match = h3Regex.exec(html)) !== null) {
		positions.push({ name: match[1].trim(), index: match.index });
	}
	for (let i = 0; i < positions.length; i++) {
		const current = positions[i];
		const end = i + 1 < positions.length ? positions[i + 1].index : html.length;
		const section = html.slice(current.index, end);
		const props = [];
		const propRegex = /([A-Za-z0-9_]+)\s*:\s*([A-Za-z]+)/g;
		let pm;
		while ((pm = propRegex.exec(section)) !== null) {
			const propName = pm[1];
			const propType = mapTypeToLua(pm[2]);
			props.push({ name: propName, type: propType });
		}
		if (props.length > 0) {
			const cleanName = current.name.replace(/[^A-Za-z0-9_]/g, '');
			entities.push({ name: cleanName, props });
		}
	}
	return entities;
}

const html = fs.readFileSync(path.join(WORKSPACE_ROOT, '.cache', 'docs', 'TF2_props.html'), 'utf8');
const ents = parseEntityPropsFromHtml(html);
const outputPath = path.join(path.dirname(fileURLToPath(import.meta.url)), 'entities-debug.json');
fs.writeFileSync(outputPath, JSON.stringify({ count: ents.length, sample: ents.slice(0, 5) }, null, 2));
