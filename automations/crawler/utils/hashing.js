import crypto from 'crypto';

export function calculateContentHash(content) {
	return crypto.createHash('sha256').update(content).digest('hex');
}

export function getPageName(url) {
	// Extract page name from URL
	// https://lmaobox.net/lua/client -> client
	// https://lmaobox.net/lua/classes/vector3 -> vector3
	const match = url.match(/\/([^\/]+)\/?$/);
	return match ? match[1] : 'index';
}
