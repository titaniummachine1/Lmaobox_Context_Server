import { API_BASE_URL } from '../config.js';
import { db } from '../database/queries.js';
import { getPageName } from '../utils/hashing.js';
import { getParentFromPath } from '../utils/paths.js';

export async function analyzeLinks(url, links) {
	// Store links in database
	db.clearLinksForPage(url);
	
	for (const link of links) {
		if (link.to_url.startsWith(API_BASE_URL)) {
			// Check if target page exists in DB
			const targetPage = db.getPage(link.to_url);
			if (targetPage) {
				db.insertLink({
					from_url: url,
					to_url: link.to_url,
					link_text: link.link_text,
					link_type: 'internal'
				});
			}
		}
	}
}

export async function calculateShortestPaths(sitemapRootUrl) {
	console.log('[LinkAnalyzer] Calculating shortest paths from sitemap root...');
	
	// Get all pages
	const allPages = db.getAllPages();
	const pagesByUrl = new Map(allPages.map(p => [p.url, p]));
	
	// Build adjacency list from links
	const graph = new Map();
	for (const page of allPages) {
		graph.set(page.url, []);
	}
	
	const allLinks = db.getLinksFrom ? 
		allPages.flatMap(p => {
			const links = db.getLinksFrom(p.url);
			return links.map(l => ({ from: p.url, to: l.to_url }));
		}) :
		[];
	
	for (const link of allLinks) {
		if (graph.has(link.from) && pagesByUrl.has(link.to)) {
			graph.get(link.from).push(link.to);
		}
	}
	
	// BFS from sitemap root
	const paths = new Map();
	const queue = [{ url: sitemapRootUrl, path: '', depth: 0, parent: null }];
	const visited = new Set([sitemapRootUrl]);
	
	// Initialize sitemap root
	if (pagesByUrl.has(sitemapRootUrl)) {
		paths.set(sitemapRootUrl, { path: '', depth: 0, parent: null });
	}
	
	while (queue.length > 0) {
		const { url, path, depth, parent } = queue.shift();
		
		// Update shortest path if this is shorter
		const existing = paths.get(url);
		if (!existing || existing.depth > depth) {
			paths.set(url, { path, depth, parent });
			db.updatePagePath(url, { path, depth, parent });
		}
		
		// Get all links from this page
		const links = db.getLinksFrom(url);
		for (const link of links) {
			const toUrl = link.to_url;
			if (toUrl.startsWith(API_BASE_URL) && pagesByUrl.has(toUrl) && !visited.has(toUrl)) {
				visited.add(toUrl);
				const pageName = getPageName(toUrl);
				const newPath = path ? `${path}/${pageName}` : pageName;
				queue.push({
					url: toUrl,
					path: newPath,
					depth: depth + 1,
					parent: url
				});
			}
		}
		
		// Also check sitemap order for direct children
		const page = pagesByUrl.get(url);
		if (page && page.sitemap_order !== null) {
			// Check if there are pages that should be children based on URL structure
			const urlPath = url.replace(API_BASE_URL, '');
			for (const otherPage of allPages) {
				if (otherPage.url !== url && !visited.has(otherPage.url)) {
					const otherPath = otherPage.url.replace(API_BASE_URL, '');
					if (otherPath.startsWith(urlPath + '/')) {
						const pageName = getPageName(otherPage.url);
						const newPath = path ? `${path}/${pageName}` : pageName;
						if (!paths.has(otherPage.url) || paths.get(otherPage.url).depth > depth + 1) {
							visited.add(otherPage.url);
							paths.set(otherPage.url, { path: newPath, depth: depth + 1, parent: url });
							db.updatePagePath(otherPage.url, { path: newPath, depth: depth + 1, parent: url });
							queue.push({
								url: otherPage.url,
								path: newPath,
								depth: depth + 1,
								parent: url
							});
						}
					}
				}
			}
		}
	}
	
	console.log(`[LinkAnalyzer] Calculated shortest paths for ${paths.size} pages`);
	return paths;
}
