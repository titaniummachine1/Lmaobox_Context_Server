import {bundle} from 'luabundle';

try {
    const result = bundle('Main.lua', {paths: ['.'], metadata: false});
    console.log('SUCCESS');
    console.log(result);
} catch (error) {
    console.error('FAILED:', error.message);
}

