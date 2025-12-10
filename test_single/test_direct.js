import {bundle} from 'luabundle';
import {existsSync} from 'fs';

console.log('CWD:', process.cwd());
console.log('Main.lua exists:', existsSync('Main.lua'));
console.log('math_helpers.lua exists:', existsSync('math_helpers.lua'));

try {
    const result = bundle('Main.lua', {
        paths: ['.'],
        metadata: false
    });
    console.log('\n✓ SUCCESS\n');
    console.log(result.substring(0, 500));
} catch (error) {
    console.error('\n✗ FAILED\n');
    console.error(error.message);
}

