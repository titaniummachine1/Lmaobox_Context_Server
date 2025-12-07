import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export const API_BASE_URL = 'https://lmaobox.net/lua/';
export const SITEMAP_URL = 'https://lmaobox.net/lua/sitemap.xml';
export const WORKSPACE_ROOT = path.resolve(__dirname, '../..');

// Allow consumers to override where generated types should live.
// - TYPES_ROOT: absolute or workspace-relative base directory for generated types (default: <workspace>/types)
// - TYPES_NAMESPACE: nested folder name for the API surface (default: lmaobox_lua_api)
const CUSTOM_TYPES_ROOT = process.env.TYPES_ROOT
	? path.resolve(WORKSPACE_ROOT, process.env.TYPES_ROOT)
	: path.join(WORKSPACE_ROOT, 'types');
export const TYPES_ROOT = CUSTOM_TYPES_ROOT;
export const TYPES_NAMESPACE = process.env.TYPES_NAMESPACE || 'lmaobox_lua_api';
export const TYPES_BASE_DIR = path.join(TYPES_ROOT, TYPES_NAMESPACE);

// Backwards compatibility: keep the old name but point at the overridable root
export const TYPES_DIR = TYPES_ROOT;
export const CACHE_DIR = path.join(WORKSPACE_ROOT, '.cache', 'docs');
export const DB_PATH = path.join(WORKSPACE_ROOT, '.cache', 'docs-graph.db');
export const LAST_UPDATE_FILE = path.join(WORKSPACE_ROOT, '.cache', 'last-update.json');
export const SESSION_FILE = path.join(TYPES_BASE_DIR, '.session');
export const TWENTY_FOUR_HOURS = 24 * 60 * 60 * 1000;
