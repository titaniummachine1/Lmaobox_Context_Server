import { promises as fs } from 'fs';
import path from 'path';
import { CACHE_DIR, SESSION_FILE } from '../config.js';
import { calculateContentHash } from '../utils/hashing.js';
import { db } from '../database/queries.js';

// Session cache: stores pages fetched during current crawl session
const sessionCache = new Map();
let lastFetchTime = 0;
const MIN_FETCH_DELAY = 1000; // 1 second between fetches for safety

// Rate limiting check
export async function shouldFetch() {
	try {
		const sessionData = await fs.readFile(SESSION_FILE, 'utf8');
		const session = JSON.parse(sessionData);
		const now = Date.now();
		const oneHour = 60 * 60 * 1000;

		if (session.lastFetch && (now - session.lastFetch) < oneHour) {
			return false;
		}
	} catch {
		// No session file, proceed
	}
	return true;
}

export async function updateSession() {
	const { promises: fs } = await import('fs');
	const sessionData = {
		lastFetch: Date.now(),
		lastFetchDate: new Date().toISOString()
	};
	await fs.writeFile(SESSION_FILE, JSON.stringify(sessionData, null, 2), 'utf8');
}

// Rate-limited fetch with session cache
async function ensureRateLimit() {
	const now = Date.now();
	const timeSinceLastFetch = now - lastFetchTime;
	if (timeSinceLastFetch < MIN_FETCH_DELAY) {
		const waitTime = MIN_FETCH_DELAY - timeSinceLastFetch;
		await new Promise(resolve => setTimeout(resolve, waitTime));
	}
	lastFetchTime = Date.now();
}

// Fetch with retry and rate limiting
export async function fetchWithRetry(url, retries = 3) {
	// Ensure rate limit before fetching
	await ensureRateLimit();
	
	for (let i = 0; i < retries; i++) {
		try {
			const response = await fetch(url, {
				headers: {
					'User-Agent': 'Mozilla/5.0 (compatible; Lmaobox-Lua-TypeGenerator/1.0)'
				}
			});
			if (response.ok) {
				return await response.text();
			}
		} catch (error) {
			if (i === retries - 1) {
				console.error(`[Fetcher] Failed to fetch ${url}: ${error.message}`);
				throw error;
			}
			// Wait before retry (with rate limit)
			await ensureRateLimit();
		}
	}
	return null;
}

// Clear session cache (call at start of new crawl)
export function clearSessionCache() {
	sessionCache.clear();
	lastFetchTime = 0;
	console.log('[Fetcher] Session cache cleared');
}

// Cache management
async function getCachePath(url) {
	const relativePath = url.replace('https://lmaobox.net/lua/', '').replace(/\/$/, '') || 'index';
	return path.join(CACHE_DIR, relativePath + '.html');
}

export async function saveCache(url, html) {
	const cachePath = await getCachePath(url);
	await fs.mkdir(path.dirname(cachePath), { recursive: true });
	await fs.writeFile(cachePath, html, 'utf8');
}

export async function loadCache(url) {
	try {
		const cachePath = await getCachePath(url);
		return await fs.readFile(cachePath, 'utf8');
	} catch {
		return null;
	}
}

// Check if page needs fetching
export async function needsFetch(url) {
	const page = db.getPage(url);
	if (!page) {
		return true; // New page
	}

	// Check if content might have changed (we'll verify with hash after fetch)
	// For now, if it's been more than 24 hours, check it
	const twentyFourHours = 24 * 60 * 60 * 1000;
	if (!page.last_fetched || (Date.now() - page.last_fetched) > twentyFourHours) {
		return true;
	}

	return false;
}

// Fetch page with change detection and session cache
export async function fetchPage(url, force = false) {
	// Check session cache first (pages fetched in current crawl)
	if (sessionCache.has(url)) {
		const cached = sessionCache.get(url);
		console.log(`[Fetcher] Using session cache: ${url}`);
		return cached;
	}
	
	// Check filesystem cache
	let html = await loadCache(url);
	let fetched = false;
	let changed = false;

	if (!html || force) {
		const canFetch = await shouldFetch();
		if (!canFetch && !force) {
			console.log(`[Fetcher] Rate limited, using filesystem cache for: ${url}`);
			html = await loadCache(url);
			if (!html) {
				return null; // No cache available
			}
		} else {
			console.log(`[Fetcher] Fetching: ${url}`);
			html = await fetchWithRetry(url);
			if (html) {
				await saveCache(url, html);
				fetched = true;
				if (canFetch) {
					await updateSession();
				}
			}
		}
	}

	if (html) {
		// Calculate hash and update DB
		const hash = calculateContentHash(html);
		const page = db.getPage(url);
		
		changed = !page || page.content_hash !== hash;
		if (changed) {
			db.updatePageHash(url, hash);
		}
		
		const result = { html, changed, fetched };
		
		// Store in session cache for this crawl
		sessionCache.set(url, result);
		
		return result;
	}

	return null;
}
