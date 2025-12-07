import { API_BASE_URL, SITEMAP_URL } from '../config.js';
import { db } from '../database/queries.js';
import { fetchWithRetry } from '../fetcher/incremental.js';

export async function fetchAndParseSitemap() {
	console.log('[GraphBuilder] Fetching sitemap...');
	const sitemapXml = await fetchWithRetry(SITEMAP_URL);
	if (!sitemapXml) {
		throw new Error('Failed to fetch sitemap');
	}

	const urls = [];
	const urlMatches = sitemapXml.matchAll(/<loc>(.*?)<\/loc>/g);

	for (const match of urlMatches) {
		const url = match[1].trim();
		if (url.startsWith(API_BASE_URL)) {
			urls.push(url);
		}
	}

	console.log(`[GraphBuilder] Found ${urls.length} URLs in sitemap`);

	// Save snapshot
	const previousSnapshot = db.getLatestSitemapSnapshot();
	const previousUrls = previousSnapshot ? JSON.parse(previousSnapshot.urls_json) : [];

	const newUrls = urls.filter(u => !previousUrls.includes(u));
	const removedUrls = previousUrls.filter(u => !urls.includes(u));

	if (newUrls.length > 0 || removedUrls.length > 0) {
		console.log(`[GraphBuilder] Changes detected: ${newUrls.length} new, ${removedUrls.length} removed`);
	}

	db.saveSitemapSnapshot(urls);

	// Insert/update pages from sitemap
	for (let i = 0; i < urls.length; i++) {
		const url = urls[i];
		const existing = db.getPage(url);
		
		db.insertPage({
			url: url,
			sitemap_order: i,
			page_type: inferPageType(url),
			last_fetched: existing?.last_fetched || null,
			content_hash: existing?.content_hash || null,
			fetch_count: existing?.fetch_count || 0
		});
	}

	// Mark removed URLs (don't delete, just note they're not in sitemap anymore)
	for (const url of removedUrls) {
		const existing = db.getPage(url);
		if (existing) {
			// Keep the page but note it's removed from sitemap
			console.log(`[GraphBuilder] URL removed from sitemap: ${url}`);
		}
	}

	return { urls, newUrls, removedUrls };
}

function inferPageType(url) {
	const path = url.replace(API_BASE_URL, '');
	if (path.startsWith('classes/')) return 'class';
	if (path.includes('callback')) return 'callback';
	if (path.match(/^[a-z]+$/)) return 'library';
	return 'page';
}
