import path from 'path';
import { promises as fs } from 'fs';
import { TYPES_DIR, TYPES_BASE_DIR, TYPES_NAMESPACE, API_BASE_URL, CACHE_DIR, WORKSPACE_ROOT } from '../config.js';
import { buildFolderPath } from '../utils/paths.js';
import { db } from '../database/queries.js';
import { parseDocumentationPage } from './html.js';

async function walkCache(dir, results = []) {
	const entries = await fs.readdir(dir, { withFileTypes: true });
	for (const entry of entries) {
		const full = path.join(dir, entry.name);
		if (entry.isDirectory()) {
			await walkCache(full, results);
		} else if (entry.isFile() && entry.name.endsWith('.html')) {
			results.push(full);
		}
	}
	return results;
}

// Lua reserved keywords that cannot be used as parameter names
const LUA_RESERVED_KEYWORDS = new Set([
	'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function',
	'goto', 'if', 'in', 'local', 'nil', 'not', 'or', 'repeat', 'return',
	'then', 'true', 'until', 'while'
]);

const SKIP_BASE_NAMES = new Set(['index', 'API_changelog']);

const MASTER_ANNOTATIONS_ROOT = path.join(WORKSPACE_ROOT, 'types', 'Lmaobox-Annotations-master', 'library');

// Map reserved keywords to safe alternatives
function sanitizeParameterName(name) {
	if (LUA_RESERVED_KEYWORDS.has(name.toLowerCase())) {
		// Map common reserved keywords to safe alternatives
		const replacements = {
			'function': 'callback',
			'end': 'endValue',
			'local': 'localValue',
			'return': 'returnValue',
			'true': 'trueValue',
			'false': 'falseValue',
			'nil': 'nilValue',
			'and': 'andValue',
			'or': 'orValue',
			'not': 'notValue',
			'if': 'ifValue',
			'then': 'thenValue',
			'else': 'elseValue',
			'elseif': 'elseifValue',
			'while': 'whileValue',
			'for': 'forValue',
			'do': 'doValue',
			'break': 'breakValue',
			'repeat': 'repeatValue',
			'until': 'untilValue',
			'goto': 'gotoValue',
			'in': 'inValue'
		};
		return replacements[name.toLowerCase()] || name + 'Value';
	}
	return name;
}

function mapTypeToLua(docType) {
	const typeMap = {
		'integer': 'number', 'int': 'number', 'number': 'number', 'float': 'number',
		'string': 'string', 'bool': 'boolean', 'boolean': 'boolean',
		'vector': 'Vector3', 'vector3': 'Vector3', 'eulerangles': 'EulerAngles',
		'entity': 'Entity|nil', 'item': 'Item|nil', 'material': 'Material|nil',
		'color': 'Color|nil', 'table': 'table', 'usercmd': 'UserCmd',
		'gameevent': 'GameEvent', 'drawmodelcontext': 'DrawModelContext',
		'viewsetup': 'ViewSetup', 'netmessage': 'NetMessage', 'stringcmd': 'string',
		'any': 'any', 'function': 'function', 'void': 'void'
	};
	return typeMap[docType.toLowerCase()] || 'any';
}

function inferConstantLuaType(value) {
	const v = (value || '').trim();
	if (/^(true|false)$/i.test(v)) return 'boolean';
	if (/^-?0x[0-9a-f]+$/i.test(v)) return 'integer';
	if (/^-?\d+$/.test(v)) return 'integer';
	if (/^-?\d+\.\d+$/.test(v)) return 'number';
	return 'any';
}

function inferReturnType(funcName, params, description = '') {
	// Check description first for explicit return type info
	const desc = description.toLowerCase();

	// Multiple return values - check first before other patterns
	// Must check this before other "returns" patterns
	if (desc.includes('returns 2 values') || desc.includes('returns 2')) {
		if (desc.includes('mask') && (desc.includes('entity') || desc.includes('Entity'))) {
			return 'number, Entity|nil';
		}
	}
	if (desc.includes('returns 3 values') || desc.includes('returns 3') ||
		desc.includes('3 return values') || desc.includes('3 values') ||
		desc.includes('3 separate') || desc.includes('as 3 return')) {
		if (desc.includes('vector') || desc.includes('forward, right, and up')) {
			return 'Vector3, Vector3, Vector3';
		}
		if (desc.includes('coordinates') || desc.includes('x, y, z') || desc.includes('separate variables')) {
			return 'number, number, number';
		}
	}

	// Explicit return type mentions
	if (desc.includes('returns trace') || desc.includes('returns trace class')) {
		return 'Trace';
	}
	if (desc.includes('returns true') || desc.includes('returns false') || desc.includes('returns true if') ||
		desc.includes('whether') || desc.includes('returns boolean')) {
		return 'boolean';
	}
	if (desc.includes('returns map name') || desc.includes('returns server ip') ||
		desc.includes('returns game install directory') || (desc.includes('returns') && desc.includes('ip'))) {
		return 'string';
	}
	if (desc.includes('returns') && desc.includes('string') && !desc.includes('returns 2') && !desc.includes('returns 3')) {
		return 'string';
	}
	if (desc.includes('returns') && desc.includes('number') && !desc.includes('returns 2') && !desc.includes('returns 3')) {
		return 'number';
	}
	if (desc.includes('returns') && desc.includes('integer') && !desc.includes('returns 2') && !desc.includes('returns 3')) {
		return 'number';
	}
	// Check for "Sets" functions that don't return anything (must come before name pattern check)
	if (desc.includes('sets ') && !desc.includes('returns')) {
		return 'void';
	}
	// Check for "Sends" functions that return boolean
	if (desc.includes('sends') && desc.includes('returns true')) {
		return 'boolean';
	}

	// Function name patterns
	if (funcName.startsWith('Is') || funcName.startsWith('Has') || funcName.startsWith('Can') ||
		funcName.startsWith('Con_Is') || funcName.includes('IsVisible') || funcName.includes('IsOpen')) {
		return 'boolean';
	}
	if (funcName.includes('Int') || funcName.includes('Count') || funcName.includes('Index') ||
		funcName.includes('Time') || funcName.includes('Size') || funcName.includes('Length')) {
		return 'number';
	}
	if (funcName.includes('Float')) {
		return 'number';
	}
	if (funcName.includes('String') || funcName.includes('Name') || funcName.includes('Text') ||
		funcName.includes('Path') || funcName.includes('Dir') || funcName.includes('IP') ||
		funcName.includes('GetMap') || funcName.includes('GetGame')) {
		return 'string';
	}
	if (funcName.includes('Vector') || funcName.includes('Origin') || funcName.includes('Position') ||
		funcName.includes('Angles') || funcName.includes('Velocity') || funcName.includes('GetView')) {
		return 'Vector3';
	}
	if (funcName.includes('Entity') || funcName.includes('Player') || funcName.includes('Weapon')) {
		return 'Entity|nil';
	}
	if (funcName.startsWith('Set') && !desc.includes('returns')) {
		return 'void';
	}
	if (funcName.includes('Play') && funcName.includes('Sound')) {
		return 'void';
	}
	if (funcName.includes('Clear') && !desc.includes('returns')) {
		return 'void';
	}
	if (funcName.includes('RandomSeed')) {
		return 'void';
	}

	return 'any';
}

async function tryLoadMasterAnnotation(parsedData) {
	const candidates = new Set();
	const lowerPath = (parsedData.path || '').toLowerCase();
	const lowerUrl = (parsedData.url || '').toLowerCase();

	// Globals
	if (lowerPath.includes('lua_globals') || lowerUrl.includes('lua_globals')) {
		candidates.add(path.join(MASTER_ANNOTATIONS_ROOT, '_G.lua'));
	}

	// Libraries
	if (parsedData.libraries && parsedData.libraries.length > 0) {
		for (const lib of parsedData.libraries) {
			candidates.add(path.join(MASTER_ANNOTATIONS_ROOT, 'Libraries', `${lib}.lua`));
			candidates.add(path.join(MASTER_ANNOTATIONS_ROOT, 'Libraries', `${lib.toLowerCase()}.lua`));
		}
	}

	// Classes
	if (parsedData.classes && parsedData.classes.length > 0) {
		for (const cls of parsedData.classes) {
			candidates.add(path.join(MASTER_ANNOTATIONS_ROOT, 'Classes', `${cls}.lua`));
			candidates.add(path.join(MASTER_ANNOTATIONS_ROOT, 'Classes', `${cls.toLowerCase()}.lua`));
		}
	}

	for (const candidate of candidates) {
		try {
			await fs.access(candidate);
			const content = await fs.readFile(candidate, 'utf8');
			return content;
		} catch {
			continue;
		}
	}
	return null;
}

function parseEntityPropsFromHtml(html) {
	const entities = [];
	// Find entity sections by h3
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
		// Collect from code blocks first (props are often inside <pre><code>)
		const codeBlocks = [];
		const codeRegex = /<pre[^>]*>([\s\S]*?)<\/pre>/gi;
		let c;
		while ((c = codeRegex.exec(section)) !== null) {
			codeBlocks.push(c[1]);
		}
		const rawText = codeBlocks.length > 0 ? codeBlocks.join('\n') : section;
		const sectionText = rawText
			.replace(/<[^>]+>/g, ' ')
			.replace(/&nbsp;/g, ' ')
			.replace(/\s+/g, ' ')
			.trim();
		const props = [];
		const propRegex = /([A-Za-z0-9_]+)\s*:\s*([A-Za-z]+)/g;
		let pm;
		while ((pm = propRegex.exec(sectionText)) !== null) {
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

export function parseConstantsByCategory(html) {
	const sections = [];

	// Find h3 headings (these are the constant category names like E_UserCmd, E_ButtonCode, etc.)
	// Try with id first (more specific) - handle both with and without id
	const h3Regex = /<h3[^>]*(?:id="([^"]+)")?[^>]*>([\s\S]*?)<\/h3>/gi;
	let h3Match;
	const h3Positions = [];
	while ((h3Match = h3Regex.exec(html)) !== null) {
		const id = h3Match[1] ? h3Match[1].trim() : null;
		let name = h3Match[2].replace(/<[^>]+>/g, '').trim();
		// Clean up name - remove extra whitespace and normalize
		name = name.replace(/\s+/g, ' ').trim();
		if (name && name.length > 0) {
			h3Positions.push({ id, name, index: h3Match.index });
		}
	}

	// Debug: log found h3 headings for constants page
	if (h3Positions.length > 20) {
		console.log(`[ConstantsParser] Found ${h3Positions.length} h3 headings`);
		const missing = ['E_UserMessage', 'E_TFCOND', 'E_Character', 'E_GCResults'];
		const found = h3Positions.map(h => h.name);
		missing.forEach(m => {
			if (!found.includes(m)) {
				console.warn(`[ConstantsParser] Missing h3 heading: ${m}`);
			}
		});
	}

	// Process each h3 section
	for (let i = 0; i < h3Positions.length; i++) {
		const current = h3Positions[i];
		const end = i + 1 < h3Positions.length ? h3Positions[i + 1].index : html.length;
		const section = html.slice(current.index, end);

		const constants = [];

		// Find the table after the h3 heading
		const h3End = section.indexOf('</h3>');
		if (h3End === -1) continue;

		const afterH3 = section.slice(h3End + 5);
		// Find table using regex
		const tableMatch = afterH3.match(/<table[^>]*>([\s\S]*?)<\/table>/i);
		if (tableMatch && tableMatch[1]) {
			const tableContent = tableMatch[1];

			// Extract table rows (skip the header row)
			const rowRegex = /<tr[^>]*>([\s\S]*?)<\/tr>/gi;
			let rowMatch;
			let isFirstRow = true;

			while ((rowMatch = rowRegex.exec(tableContent)) !== null) {
				// Skip header row
				if (isFirstRow) {
					isFirstRow = false;
					continue;
				}

				const rowContent = rowMatch[1];

				// Extract table cells
				const cellRegex = /<td[^>]*>([\s\S]*?)<\/td>/gi;
				const cells = [];
				let cellMatch;

				while ((cellMatch = cellRegex.exec(rowContent)) !== null) {
					let cellText = cellMatch[1]
						.replace(/<[^>]+>/g, '')
						.replace(/&lt;/g, '<')
						.replace(/&gt;/g, '>')
						.replace(/&amp;/g, '&')
						.replace(/&quot;/g, '"')
						.replace(/&nbsp;/g, ' ')
						.replace(/\s+/g, ' ')
						.trim();
					cells.push(cellText);
				}

				// First cell is name, second cell is value
				if (cells.length >= 2) {
					const name = cells[0].trim();
					let value = cells[1].trim();

					// Clean up the value - handle HTML entities and expressions
					value = value
						.replace(/&lt;/g, '<')
						.replace(/&gt;/g, '>')
						.replace(/&amp;/g, '&');

					// Normalize stray parentheses that break Lua parsing
					// Many table cells start with "(" but omit the closing ")"
					if (value.startsWith('(') && value.endsWith(')')) {
						value = value.slice(1, -1).trim();
					} else if (value.startsWith('(') && !value.includes(')')) {
						value = value.slice(1).trim();
					}

					// Only add if name looks like a constant
					// Accept: UPPER_CASE, PascalCase, k_Prefix, or single letters
					if (name && /^[A-Za-z_]/.test(name)) {
						constants.push({ name, value });
					}
				}
			}
		}

		// Fallback: try to extract from text if no table found
		if (constants.length === 0) {
			const sectionText = section
				.replace(/<[^>]+>/g, ' ')
				.replace(/&nbsp;/g, ' ')
				.replace(/&lt;/g, '<')
				.replace(/&gt;/g, '>')
				.replace(/&amp;/g, '&')
				.replace(/\s+/g, ' ')
				.trim();
			const constRegex = /([A-Z_][A-Z0-9_]+)\s*=\s*([^\s,;]+)/g;
			let cm;
			while ((cm = constRegex.exec(sectionText)) !== null) {
				const name = cm[1];
				const value = cm[2];
				if (name && value) {
					constants.push({ name, value });
				}
			}
		}

		if (constants.length > 0) {
			const cleanName = current.name.replace(/[^A-Za-z0-9_]/g, '_') || 'constants';
			sections.push({ name: cleanName, constants });
		} else {
			// Debug: log sections with no constants found (only for known missing ones)
			const missingOnes = ['E_UserMessage', 'E_TFCOND', 'E_Character', 'E_GCResults'];
			if (missingOnes.includes(current.name)) {
				const h3End = section.indexOf('</h3>');
				const afterH3 = h3End !== -1 ? section.slice(h3End + 5, h3End + 500) : 'no </h3> found';
				const hasTable = section.includes('<table');
				const tableMatch = afterH3.match(/<table[^>]*>/i);
				console.warn(`[ConstantsParser] No constants found for: ${current.name}`);
				console.warn(`  - Has </h3>: ${h3End !== -1}, Has <table> in section: ${hasTable}, Table match: ${!!tableMatch}`);
				if (tableMatch) {
					console.warn(`  - Table found at position: ${tableMatch.index}`);
				}
			}
		}
	}

	return sections;
}

function generateTypeDefinition(page) {
	let content = `---@meta\n\n`;
	content += `-- Lmaobox Lua API: ${page.title || 'Documentation'}\n`;
	content += `-- Auto-generated from: ${page.url}\n`;
	content += `-- Path: ${page.path}\n`;
	content += `-- Last updated: ${new Date().toISOString()}\n\n`;

	// Add class/page description if available
	if (page.description) {
		content += `-- ${page.description}\n\n`;
	}

	// Include all examples (not just first 2) for better AI context
	if (page.examples && page.examples.length > 0) {
		content += `-- Examples:\n`;
		page.examples.forEach((example, idx) => {
			content += `-- Example ${idx + 1}:\n`;
			const lines = example.split('\n');
			lines.forEach(line => {
				content += `-- ${line}\n`;
			});
			content += `\n`;
		});
	}

	// Generate library definitions
	if (page.libraries && page.libraries.length > 0) {
		for (const libName of [...new Set(page.libraries)]) {
			content += `---@class ${libName}\n`;
			content += `${libName} = {}\n\n`;

			// Special handling: callbacks library benefits from explicit alias and signatures
			if (libName === 'callbacks') {
				content += `---@alias CallbackID\n`;
				content += `---| "Draw"\n`;
				content += `---| "DrawModel"\n`;
				content += `---| "DrawStaticProps"\n`;
				content += `---| "CreateMove"\n`;
				content += `---| "FireGameEvent"\n`;
				content += `---| "DispatchUserMessage"\n`;
				content += `---| "SendStringCmd"\n`;
				content += `---| "FrameStageNotify"\n`;
				content += `---| "PostPropUpdate"\n`;
				content += `---| "RenderView"\n`;
				content += `---| "PostRenderView"\n`;
				content += `---| "RenderViewModel"\n`;
				content += `---| "ServerCmdKeyValues"\n`;
				content += `---| "OnFakeUncrate"\n`;
				content += `---| "OnLobbyUpdated"\n`;
				content += `---| "SetRichPresence"\n`;
				content += `---| "GCSendMessage"\n`;
				content += `---| "GCRetrieveMessage"\n`;
				content += `---| "SendNetMsg"\n`;
				content += `---| "DoPostScreenSpaceEffects"\n`;
				content += `---| "ProcessTempEntities"\n`;
				content += `---| "Unload"\n\n`;

				content += `---@param id CallbackID\n`;
				content += `---@param callback fun(...)\n`;
				content += `---@return boolean success\n`;
				content += `function callbacks.Register(id, callback) end\n\n`;

				content += `---@param id CallbackID\n`;
				content += `---@param unique string\n`;
				content += `---@param callback fun(...)\n`;
				content += `---@return boolean success\n`;
				content += `function callbacks.Register(id, unique, callback) end\n\n`;

				content += `---@param id CallbackID\n`;
				content += `---@param unique string\n`;
				content += `---@return boolean success\n`;
				content += `function callbacks.Unregister(id, unique) end\n\n`;
				continue;
			}

			if (page.functions && page.functions.length > 0) {
				page.functions.forEach(func => {
					// Add function description if available
					if (func.description) {
						content += `-- ${func.description}\n`;
					}

					func.params.forEach(param => {
						const sanitizedName = sanitizeParameterName(param.name);
						const luaType = param.type ? mapTypeToLua(param.type) : 'any';
						content += `---@param ${sanitizedName} ${luaType}\n`;
					});

					const returnType = inferReturnType(func.name, func.params, func.description || '');
					if (returnType !== 'void') {
						content += `---@return ${returnType}\n`;
					}

					const paramList = func.params.map(p => sanitizeParameterName(p.name)).join(', ');
					content += `function ${libName}.${func.name}(${paramList}) end\n\n`;
				});
			}
		}
	}

	// Generate class definitions
	if (page.classes && page.classes.length > 0) {
		for (const className of [...new Set(page.classes)]) {
			content += `---@class ${className}\n`;

			// Add fields first (properties like x, y, z)
			if (page.fields && page.fields.length > 0) {
				page.fields.forEach(field => {
					content += `---@field ${field.name} ${field.type}\n`;
				});
			}

			// Then add methods/functions
			if (page.functions && page.functions.length > 0) {
				page.functions.forEach(func => {
					// Add function description if available
					if (func.description) {
						content += `-- ${func.description}\n`;
					}

					func.params.forEach(param => {
						const sanitizedName = sanitizeParameterName(param.name);
						const luaType = param.type ? mapTypeToLua(param.type) : 'any';
						const optional = param.optional ? '?' : '';
						content += `---@param ${sanitizedName}${optional} ${luaType}\n`;
					});

					const returnType = inferReturnType(func.name, func.params, func.description || '');
					if (returnType !== 'void') {
						content += `---@return ${returnType}\n`;
					}

					const paramTypes = func.params.map(p => {
						const sanitizedName = sanitizeParameterName(p.name);
						const pType = p.type ? mapTypeToLua(p.type) : 'any';
						return `${sanitizedName}: ${pType}`;
					}).join(', ');
					content += `---@field ${func.name} fun(self: ${className}${func.params.length > 0 ? ', ' : ''}${paramTypes})${returnType !== 'void' ? `: ${returnType}` : ''}\n`;
				});
			}

			content += `local ${className} = {}\n\n`;
		}
	}

	// Fallback: global functions when no classes/libraries
	if ((!page.classes || page.classes.length === 0) && (!page.libraries || page.libraries.length === 0)) {
		if (page.functions && page.functions.length > 0) {
			for (const func of page.functions) {
				// Add function description if available
				if (func.description) {
					content += `-- ${func.description}\n`;
				}

				func.params.forEach(param => {
					const sanitizedName = sanitizeParameterName(param.name);
					const luaType = param.type ? mapTypeToLua(param.type) : 'any';
					const optional = param.optional ? '?' : '';
					content += `---@param ${sanitizedName}${optional} ${luaType}\n`;
				});

				const returnType = inferReturnType(func.name, func.params, func.description || '');
				if (returnType !== 'void') {
					content += `---@return ${returnType}\n`;
				}

				const paramList = func.params.map(p => sanitizeParameterName(p.name)).join(', ');
				content += `function ${func.name}(${paramList}) end\n\n`;
			}
		}
	}

	// Generate constants (filter out false positives)
	if (page.constants && page.constants.length > 0) {
		// Filter out useless constants (short names, common false positives, or nil values from fallback)
		const validConstants = page.constants.filter(c => {
			// Skip if value is nil (from fallback extraction)
			if (c.value === 'nil' || c.value === '') return false;
			// Skip very short names that are likely false positives
			if (c.name.length < 4) return false;
			// Skip common false positives
			if (['API', 'API_', 'HTTP', 'SVG', 'XML', 'HTML', 'CSS', 'URL', 'DOM'].includes(c.name)) return false;
			// Skip if name doesn't look like a constant (needs underscore or all caps)
			if (!c.name.includes('_') && !c.name.match(/^[A-Z]{3,}$/)) return false;
			return true;
		});

		if (validConstants.length > 0) {
			content += `-- Constants:\n`;
			for (const constant of validConstants) {
				const constType = inferConstantLuaType(constant.value);
				content += `---@type ${constType}\n`;
				content += `${constant.name} = ${constant.value}\n\n`;
			}
		}
	}

	return content;
}

function buildPathFromUrl(url) {
	const relative = url.replace(API_BASE_URL, '').replace(/\/+$/, '');
	if (!relative) return 'index';
	return relative;
}

export async function generateTypeForPage(parsedDataInput) {
	// Skip non-actionable top-level pages that pollute output
	const candidatePath = parsedDataInput.path || buildPathFromUrl(parsedDataInput.url);
	const base = path.basename(candidatePath);
	if (SKIP_BASE_NAMES.has(base)) {
		return { filePath: null };
	}

	// Special case: entity props page emits many per-entity files
	if (parsedDataInput.url && parsedDataInput.url.toLowerCase().includes('tf2_props')) {
		try {
			const rel = parsedDataInput.url.replace(API_BASE_URL, '').replace(/\/$/, '') || 'TF2_props';
			const cachePath = path.join(CACHE_DIR, rel + '.html');
			const html = await fs.readFile(cachePath, 'utf8');
			const entities = parseEntityPropsFromHtml(html);
			if (entities.length > 0) {
				const baseDir = path.join(TYPES_BASE_DIR, 'entity_props');
				await fs.mkdir(baseDir, { recursive: true });
				for (const ent of entities) {
					let content = `---@meta\n\n`;
					content += `-- Entity Props: ${ent.name}\n`;
					content += `-- Auto-generated from: ${parsedDataInput.url}\n`;
					content += `-- Last updated: ${new Date().toISOString()}\n\n`;
					content += `---@class ${ent.name}\n`;
					for (const prop of ent.props) {
						content += `---@field ${prop.name} ${prop.type}\n`;
					}
					content += `local ${ent.name} = {}\n`;
					const filePath = path.join(baseDir, `${ent.name}.d.lua`);
					await fs.writeFile(filePath, content, 'utf8');
				}
			}
		} catch (e) {
			console.warn(`[TypeGenerator] Entity props generation failed: ${e.message}`);
		}
		// Do not write a single monolith file for TF2_props; handled above
		return { filePath: null };
	}

	// Special case: constants page emits many per-category files
	if (parsedDataInput.url && parsedDataInput.url.toLowerCase().includes('lua_constants')) {
		try {
			const rel = parsedDataInput.url.replace(API_BASE_URL, '').replace(/\/$/, '') || 'Lua_Constants';
			const cachePath = path.join(CACHE_DIR, rel + '.html');
			const html = await fs.readFile(cachePath, 'utf8');
			const sections = parseConstantsByCategory(html);
			if (sections.length > 0) {
				const baseDir = path.join(TYPES_BASE_DIR, 'constants');
				await fs.mkdir(baseDir, { recursive: true });
				for (const sec of sections) {
					let content = `---@meta\n\n`;
					content += `-- Constants: ${sec.name}\n`;
					content += `-- Auto-generated from: ${parsedDataInput.url}\n`;
					content += `-- Last updated: ${new Date().toISOString()}\n\n`;
					for (const c of sec.constants) {
						const constType = inferConstantLuaType(c.value);
						content += `---@type ${constType}\n`;
						content += `${c.name} = ${c.value}\n\n`;
					}
					const filePath = path.join(baseDir, `${sec.name}.d.lua`);
					await fs.writeFile(filePath, content, 'utf8');
				}
			}
		} catch (e) {
			console.warn(`[TypeGenerator] Constants generation failed: ${e.message}`);
		}
		// Do not write a single monolith file for Lua_Constants; handled above
		return { filePath: null };
	}

	const pagePath = parsedDataInput.path || buildPathFromUrl(parsedDataInput.url);
	const dirPath = path.dirname(pagePath) || '.';
	const sanitizedDir = buildFolderPath(dirPath);
	const typeDir = path.join(TYPES_BASE_DIR, sanitizedDir === '.' ? '' : sanitizedDir);
	await fs.mkdir(typeDir, { recursive: true });

	const fileName = path.basename(pagePath) + '.d.lua';
	const filePath = path.join(typeDir, fileName);

	// Prefer master annotations when available; fall back to generated types
	const masterContent = await tryLoadMasterAnnotation(parsedDataInput);
	if (masterContent) {
		await fs.writeFile(filePath, masterContent, 'utf8');
		db.saveTypeDefinition(parsedDataInput.url, pagePath, masterContent);
		return { filePath };
	}

	const content = generateTypeDefinition(parsedDataInput);
	await fs.writeFile(filePath, content, 'utf8');
	db.saveTypeDefinition(parsedDataInput.url, pagePath, content);
	return { filePath };
}

export async function generateEntityPropsFromCache() {
	try {
		const htmlPath = path.join(WORKSPACE_ROOT, '.cache', 'docs', 'TF2_props.html');
		const html = await fs.readFile(htmlPath, 'utf8');
		const entities = parseEntityPropsFromHtml(html);
		if (!entities || entities.length === 0) {
			console.log('[TypeGenerator] No entity props found in cache.');
			return 0;
		}
		const baseDir = path.join(TYPES_BASE_DIR, 'entity_props');
		await fs.mkdir(baseDir, { recursive: true });
		let count = 0;
		for (const ent of entities) {
			let content = `---@meta\n\n`;
			content += `-- Entity Props: ${ent.name}\n`;
			content += `-- Auto-generated from: https://lmaobox.net/lua/TF2_props/\n`;
			content += `-- Last updated: ${new Date().toISOString()}\n\n`;
			content += `---@class ${ent.name}\n`;
			for (const prop of ent.props) {
				content += `---@field ${prop.name} ${prop.type}\n`;
			}
			content += `local ${ent.name} = {}\n`;
			const filePath = path.join(baseDir, `${ent.name}.d.lua`);
			await fs.writeFile(filePath, content, 'utf8');
			count++;
		}
		console.log(`[TypeGenerator] Generated ${count} entity prop files`);
		return count;
	} catch (e) {
		console.warn(`[TypeGenerator] Entity props generation failed: ${e.message}`);
		return 0;
	}
}

export async function generateConstantsByCategoryFromCache() {
	try {
		const htmlPath = path.join(WORKSPACE_ROOT, '.cache', 'docs', 'Lua_Constants.html');
		const html = await fs.readFile(htmlPath, 'utf8');
		const sections = parseConstantsByCategory(html);
		if (!sections || sections.length === 0) {
			console.log('[TypeGenerator] No constants found in cache.');
			return 0;
		}
		const baseDir = path.join(TYPES_BASE_DIR, 'constants');
		await fs.mkdir(baseDir, { recursive: true });
		let count = 0;
		for (const sec of sections) {
			let content = `---@meta\n\n`;
			content += `-- Constants: ${sec.name}\n`;
			content += `-- Auto-generated from: https://lmaobox.net/lua/Lua_Constants/\n`;
			content += `-- Last updated: ${new Date().toISOString()}\n\n`;
			for (const c of sec.constants) {
				const constType = inferConstantLuaType(c.value);
				content += `---@type ${constType}\n`;
				content += `${c.name} = ${c.value}\n\n`;
			}
			const filePath = path.join(baseDir, `${sec.name}.d.lua`);
			await fs.writeFile(filePath, content, 'utf8');
			count++;
		}

		// Delete the old main Lua_Constants.d.lua file if it exists (we use folder structure now)
		const oldMainFile = path.join(TYPES_BASE_DIR, 'Lua_Constants.d.lua');
		try {
			await fs.unlink(oldMainFile);
			console.log(`[TypeGenerator] Removed old main constants file: ${oldMainFile}`);
		} catch (e) {
			// File doesn't exist, that's fine
		}

		console.log(`[TypeGenerator] Generated ${count} constants files`);
		return count;
	} catch (e) {
		console.warn(`[TypeGenerator] Constants generation failed: ${e.message}`);
		return 0;
	}
}

export async function generateTypesByShortestPath() {
	console.log('[TypeGenerator] Generating type definitions by shortest path...');

	// Use all pages that have parsed data (even if path not computed)
	const pages = db.getAllPagesWithParsedData();
	if (!pages || pages.length === 0) {
		console.log('[TypeGenerator] No pages with parsed data, will fall back to cache crawl.');
	}

	let generated = 0;

	const processPage = async (page) => {
		// Special handling: entity props page emits many files
		if (page.url.toLowerCase().includes('tf2_props')) {
			try {
				const rel = page.url.replace(API_BASE_URL, '').replace(/\/$/, '') || 'TF2_props';
				const cachePath = path.join(CACHE_DIR, rel + '.html');
				const html = await fs.readFile(cachePath, 'utf8');
				const entities = parseEntityPropsFromHtml(html);
				if (entities.length > 0) {
					const baseDir = path.join(TYPES_BASE_DIR, 'entity_props');
					await fs.mkdir(baseDir, { recursive: true });
					for (const ent of entities) {
						let content = `---@meta\n\n`;
						content += `-- Entity Props: ${ent.name}\n`;
						content += `-- Auto-generated from: ${page.url}\n`;
						content += `-- Last updated: ${new Date().toISOString()}\n\n`;
						content += `---@class ${ent.name}\n`;
						for (const prop of ent.props) {
							content += `---@field ${prop.name} ${prop.type}\n`;
						}
						content += `local ${ent.name} = {}\n`;
						const filePath = path.join(baseDir, `${ent.name}.d.lua`);
						await fs.writeFile(filePath, content, 'utf8');
						generated++;
					}
					return;
				}
			} catch (e) {
				console.warn(`[TypeGenerator] Entity props parse failed: ${e.message}`);
			}
		}

		// Determine output path
		const pagePath = page.path || buildPathFromUrl(page.url);
		const baseName = path.basename(pagePath);
		if (SKIP_BASE_NAMES.has(baseName)) {
			return;
		}
		const dirPath = path.dirname(pagePath) || '.';
		const sanitizedDir = buildFolderPath(dirPath);
		const typeDir = path.join(TYPES_BASE_DIR, sanitizedDir === '.' ? '' : sanitizedDir);
		await fs.mkdir(typeDir, { recursive: true });

		const fileName = path.basename(pagePath) + '.d.lua';
		const filePath = path.join(typeDir, fileName);

		// Get parsed page data from database
		let parsedData = {
			url: page.url,
			title: page.title,
			path: pagePath,
			examples: [],
			libraries: [],
			classes: [],
			functions: [],
			constants: []
		};

		if (page.parsed_data) {
			try {
				const parsed = JSON.parse(page.parsed_data);
				parsedData = {
					...parsedData,
					examples: parsed.examples || [],
					libraries: parsed.libraries || [],
					classes: parsed.classes || [],
					functions: parsed.functions || [],
					constants: parsed.constants || []
				};
			} catch (e) {
				console.warn(`[TypeGenerator] Failed to parse stored data for ${page.url}: ${e.message}`);
			}
		}

		// Fallback: if functions/examples/constants are empty, try re-parsing cached HTML
		const needsEnrich = (!parsedData.functions || parsedData.functions.length === 0) ||
			(!parsedData.constants || parsedData.constants.length === 0) ||
			(!parsedData.examples || parsedData.examples.length === 0);
		if (needsEnrich) {
			try {
				const relative = page.url.replace(API_BASE_URL, '').replace(/\/$/, '') || 'index';
				const cachePath = path.join(CACHE_DIR, relative + '.html');
				const html = await fs.readFile(cachePath, 'utf8');
				const reparsed = parseDocumentationPage(html, page.url);

				// Fallback function extraction directly from HTML if still empty
				if (!reparsed.functions || reparsed.functions.length === 0) {
					const funcMatches = html.matchAll(/<h3[^>]*>(.*?)<\/h3>/gi);
					const funcs = [];
					for (const m of funcMatches) {
						const raw = m[1];
						const text = raw.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
						const fm = text.match(/^(\w+)\s*\(([^)]*)\)/);
						if (fm) {
							const name = fm[1];
							const paramsStr = fm[2].trim();
							const params = [];
							if (paramsStr) {
								const paramPattern = /\[?(\w+):(\w+)\]?/g;
								let pm;
								while ((pm = paramPattern.exec(paramsStr)) !== null) {
									params.push({ name: pm[1], type: pm[2] });
								}
							}
							funcs.push({ name, params, section: text });
						}
					}
					if (funcs.length > 0) {
						reparsed.functions = funcs;
					}
				}

				parsedData = {
					...parsedData,
					title: parsedData.title || reparsed.title,
					examples: parsedData.examples?.length ? parsedData.examples : (reparsed.examples || []),
					libraries: parsedData.libraries?.length ? parsedData.libraries : (reparsed.libraries || []),
					classes: parsedData.classes?.length ? parsedData.classes : (reparsed.classes || []),
					functions: parsedData.functions?.length ? parsedData.functions : (reparsed.functions || []),
					constants: parsedData.constants?.length ? parsedData.constants : (reparsed.constants || [])
				};
			} catch (e) {
				console.warn(`[TypeGenerator] Could not enrich from cache for ${page.url}: ${e.message}`);
			}
		}

		const content = generateTypeDefinition(parsedData);
		const masterContent = await tryLoadMasterAnnotation(parsedData);
		if (masterContent) {
			await fs.writeFile(filePath, masterContent, 'utf8');
			db.saveTypeDefinition(page.url, pagePath, masterContent);
			generated++;
			return;
		}
		await fs.writeFile(filePath, content, 'utf8');
		db.saveTypeDefinition(page.url, pagePath, content);
		generated++;
	};

	if (pages && pages.length > 0) {
		for (const page of pages) {
			await processPage(page);
		}
	} else {
		// Fallback: crawl cache HTML files directly
		const htmlFiles = await walkCache(CACHE_DIR);
		for (const file of htmlFiles) {
			const relativeHtml = path.relative(CACHE_DIR, file).replace(/\\/g, '/');
			const url = new URL('./' + relativeHtml.replace(/\.html$/, ''), API_BASE_URL).href;
			const page = {
				url,
				path: relativeHtml.replace(/\.html$/, ''),
				title: path.basename(relativeHtml, '.html'),
				parsed_data: null
			};
			// Skip non-api files like assets if any
			if (!url.startsWith(API_BASE_URL)) continue;

			// Re-parse HTML
			try {
				const html = await fs.readFile(file, 'utf8');
				const parsed = parseDocumentationPage(html, url);
				page.parsed_data = parsed;
				page.title = parsed.title || page.title;
			} catch (e) {
				console.warn(`[TypeGenerator] Cache parse failed for ${file}: ${e.message}`);
			}
			await processPage(page);
		}
	}

	console.log(`[TypeGenerator] Generated ${generated} type definition files`);
	return generated;
}
