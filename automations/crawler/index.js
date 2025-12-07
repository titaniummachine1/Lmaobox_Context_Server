import { API_BASE_URL, TWENTY_FOUR_HOURS, LAST_UPDATE_FILE } from './config.js';
import { promises as fs } from 'fs';
import { fetchAndParseSitemap } from './graph/builder.js';
import { analyzeLinks, calculateShortestPaths } from './graph/analyzer.js';
import { generateFolderHierarchy } from './graph/hierarchy.js';
import { fetchPage, needsFetch as pageNeedsFetch, clearSessionCache } from './fetcher/incremental.js';
import { parseDocumentationPage } from './parser/html.js';
import { generateTypesByShortestPath, generateTypeForPage } from './parser/types.js';
import { db } from './database/queries.js';
import { updateLuarcGlobals } from './utils/luarc-updater.js';

async function getLastUpdateTime() {
	try {
		const data = await fs.readFile(LAST_UPDATE_FILE, 'utf8');
		const json = JSON.parse(data);
		return json.lastUpdate || null;
	} catch {
		return null;
	}
}

async function updateLastUpdateTime() {
	const data = { lastUpdate: Date.now(), lastUpdateDate: new Date().toISOString() };
	await fs.writeFile(LAST_UPDATE_FILE, JSON.stringify(data, null, 2), 'utf8');
}

async function shouldRunFullUpdate() {
	const lastUpdate = await getLastUpdateTime();
	if (!lastUpdate) {
		return true; // First run
	}

	const now = Date.now();
	return (now - lastUpdate) >= TWENTY_FOUR_HOURS;
}

export async function runCrawler(force = false) {
	const startTime = Date.now();
	console.log('[Crawler] Starting smart crawler...\n');

	// Clear session cache at start of crawl
	clearSessionCache();

	try {
		// Check if we should run full update
		const needsFullUpdate = force || await shouldRunFullUpdate();

		if (!needsFullUpdate) {
			console.log('[Crawler] Last update was less than 24 hours ago, skipping full crawl');
			console.log('[Crawler] Ensuring types are loaded...');
			// Just ensure types exist
			return { type: 'skip', pagesUpdated: 0 };
		}

		// Step 1: Fetch and parse sitemap
		const { urls, newUrls, removedUrls } = await fetchAndParseSitemap();

		// Step 2: Fetch pages (incremental - only new/changed)
		let fetched = 0;
		let changed = 0;

		console.log('\n[Crawler] Fetching pages (with 1s rate limit and session cache)...');

		// Track planned/processed pages
		const pagesToProcess = new Set();
		const processedUrls = new Set();
		const queuedUrls = new Set();

		// Helper: enqueue with priority for new/unknown pages
		const enqueue = (targetUrl, priority = false) => {
			if (processedUrls.has(targetUrl) || queuedUrls.has(targetUrl)) return;
			queuedUrls.add(targetUrl);
			pagesToProcess.add(targetUrl);
			if (priority) {
				queue.unshift(targetUrl);
			} else {
				queue.push(targetUrl);
			}
		};

		// Process pages, following links (BFS-style) with prioritization
		const queue = [];

		// Seed queue: prioritize newly discovered URLs or URLs not yet in DB
		for (const url of urls) {
			const isNew = newUrls.includes(url) || !db.getPage(url);
			enqueue(url, isNew);
		}

		while (queue.length > 0) {
			const url = queue.shift();

			if (processedUrls.has(url)) {
				continue; // Already processed (session cache handles this, but double-check)
			}

			const progress = `[${processedUrls.size + 1}/${pagesToProcess.size}]`;
			processedUrls.add(url);

			// Show progress every 10 pages or on first page
			if (processedUrls.size % 10 === 1 || processedUrls.size === 1) {
				console.log(`${progress} Processing: ${url.substring(API_BASE_URL.length)}`);
			}

			const shouldFetch = await pageNeedsFetch(url);
			if (force || shouldFetch || newUrls.includes(url)) {
				const result = await fetchPage(url, force);
				if (result) {
					if (result.fetched) fetched++;
					if (result.changed) changed++;

					// Parse page
					const parsed = parseDocumentationPage(result.html, url);

					// Derive path from URL immediately (URL hierarchy)
					const relativePath = url.replace(API_BASE_URL, '').replace(/\/$/, '') || 'index';

					// Update page in DB with parsed data
					db.insertPage({
						url: url,
						title: parsed.title,
						page_type: inferPageType(url),
						path: relativePath,
						parsed_data: parsed
					});

					// Also update parsed_data separately to ensure it's saved
					db.updatePageParsedData(url, parsed);

					// Store links
					await analyzeLinks(url, parsed.links);

					// Generate type immediately for this page
					try {
						await generateTypeForPage({
							...parsed,
							path: relativePath
						});
					} catch (e) {
						console.warn(`[Crawler] Type generation failed for ${url}: ${e.message}`);
					}

					// Add linked pages to queue if they're in our scope and not yet processed
					for (const link of parsed.links) {
						if (!link.to_url.startsWith(API_BASE_URL)) {
							continue;
						}

						const isNewLink = newUrls.includes(link.to_url) || !db.getPage(link.to_url);
						enqueue(link.to_url, isNewLink);
					}
				}
			}
		}

		console.log(`\n[Crawler] Fetched: ${fetched}, Changed: ${changed}`);

		// Step 3: Calculate shortest paths
		console.log('\n[Crawler] Calculating shortest paths...');
		await calculateShortestPaths(API_BASE_URL);

		// Step 4: Generate folder hierarchy
		console.log('\n[Crawler] Generating folder hierarchy...');
		await generateFolderHierarchy();

		// Step 5: Generate type definitions
		console.log('\n[Crawler] Generating type definitions...');
		const generated = await generateTypesByShortestPath();

		// Step 6: Update .luarc.json with discovered globals
		console.log('\n[Crawler] Updating .luarc.json with discovered globals...');
		await updateLuarcGlobals();

		// Step 7: Update timestamp
		await updateLastUpdateTime();

		const duration = Date.now() - startTime;
		const pagesUpdated = fetched + changed;

		db.logUpdate('full', pagesUpdated, duration);

		console.log(`\n[Crawler] ✅ Complete! Generated ${generated} type files in ${duration}ms`);

		return { type: 'full', pagesUpdated, duration, generated };

	} catch (error) {
		console.error('[Crawler] Error:', error);
		throw error;
	}
}

function inferPageType(url) {
	const path = url.replace(API_BASE_URL, '');
	if (path.startsWith('classes/')) return 'class';
	if (path.includes('callback')) return 'callback';
	if (path.match(/^[a-z]+$/)) return 'library';
	return 'page';
}
