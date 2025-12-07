import path from 'path';

export function getParentFromPath(filePath) {
	if (!filePath || filePath === '.') return null;
	const parent = path.dirname(filePath);
	return parent === '.' ? null : parent;
}

export function sanitizePath(filePath) {
	// Remove invalid characters for file paths
	return filePath
		.replace(/[<>:"|?*]/g, '_')
		.replace(/\.\./g, '_')
		.replace(/\/+/g, '/')
		.replace(/^\/|\/$/g, '');
}

export function buildFolderPath(shortestPath) {
	if (!shortestPath) return '.';
	return sanitizePath(shortestPath);
}
