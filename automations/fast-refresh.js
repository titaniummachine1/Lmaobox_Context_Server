// Fast refresh without re-scraping: reuse cached HTML + parsed_data,
// regenerate types/docs index, and materialize symbols graph for smart context.
import { runRefresh } from './refresh-runner.js';

async function main() {
	console.log('[FastRefresh] Starting (no network crawl)...');
	await runRefresh({ mode: 'fast' });
	console.log('[FastRefresh] Done');
}

main().catch((e) => {
	console.error('[FastRefresh] Failed:', e);
	process.exit(1);
});

