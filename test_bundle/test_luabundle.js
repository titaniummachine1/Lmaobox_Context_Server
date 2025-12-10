import {bundle} from 'luabundle';
import path from 'path';
import { existsSync } from 'fs';

const cwd = process.cwd();

// Test 3: Change CWD to test_bundle, use relative paths
console.log('=== Test 3: CWD=test_bundle, paths=["src"] ===');
const prevCwd = process.cwd();
process.chdir('test_bundle');
console.log('CWD:', process.cwd());
console.log('Entry file exists:', existsSync('src/Main.lua'));
console.log('Helper file exists:', existsSync('src/utils/helpers.lua'));
try {
    const result = bundle('src/Main.lua', {paths: ['src'], metadata: false});
    console.log('SUCCESS - Length:', result.length);
    console.log(result.substring(0, 500));
} catch (error) {
    console.error('FAILED:', error.message);
} finally {
    process.chdir(prevCwd);
}

