import { bundle } from "luabundle";
import { promises as fs } from "fs";

// Standalone worker script that can be killed if it hangs
async function runBundle() {
  try {
    const projectDir = process.argv[2];
    const entryFile = process.argv[3];
    
    if (!projectDir || !entryFile) {
      console.error('Usage: node bundle-worker.js <projectDir> <entryFile>');
      process.exit(1);
    }

    // Change to project directory
    process.chdir(projectDir);
    
    // Run bundle operation
    const result = bundle(entryFile, {
      metadata: false,
      paths: ["./?.lua", "./?/init.lua"],
      force: false,
    });
    
    // Write result to stdout for parent to read
    console.log('BUNDLE_SUCCESS');
    console.log(result);
  } catch (error) {
    console.error('BUNDLE_ERROR');
    console.error(error.message);
    process.exit(1);
  }
}

runBundle().catch((error) => {
  console.error('BUNDLE_ERROR');
  console.error(error.message);
  process.exit(1);
});
