import { bundle } from "luabundle";
import { promises as fs } from "fs";
import path from "path";

// Standalone worker script that can be killed if it hangs
async function runBundle() {
  try {
    const projectDir = process.argv[2];
    const entryFile = process.argv[3];
    
    if (!projectDir || !entryFile) {
      console.error('BUNDLE_ERROR');
      console.error('Usage: node bundle-worker.js <projectDir> <entryFile>');
      process.exit(1);
    }

    // Verify project directory exists
    try {
      await fs.access(projectDir);
    } catch (error) {
      console.error('BUNDLE_ERROR');
      console.error(`Project directory does not exist: ${projectDir}`);
      process.exit(1);
    }

    // Verify entry file exists
    const entryPath = path.join(projectDir, entryFile);
    try {
      await fs.access(entryPath);
    } catch (error) {
      console.error('BUNDLE_ERROR');
      console.error(`Entry file does not exist: ${entryPath}`);
      process.exit(1);
    }

    // Change to project directory
    process.chdir(projectDir);
    
    // Set a timeout for the bundle operation itself
    const bundleTimeout = setTimeout(() => {
      console.error('BUNDLE_ERROR');
      console.error('Bundle operation timed out (possible circular dependency or infinite loop)');
      process.exit(1);
    }, 25000); // 25 second timeout for bundle operation
    
    try {
      // Run bundle operation with more explicit error handling
      const result = bundle(entryFile, {
        metadata: false,
        paths: ["./?.lua", "./?/init.lua"],
        force: false,
      });
      
      clearTimeout(bundleTimeout);
      
      // Verify we got a result
      if (!result || typeof result !== 'string') {
        console.error('BUNDLE_ERROR');
        console.error('Bundle operation returned empty or invalid result');
        process.exit(1);
      }
      
      // Write result to stdout for parent to read
      console.log('BUNDLE_SUCCESS');
      console.log(result);
    } catch (bundleError) {
      clearTimeout(bundleTimeout);
      
      // Provide more detailed error information
      let errorMsg = bundleError.message || bundleError.toString();
      
      // Check for common error patterns
      if (errorMsg.includes('module not found')) {
        errorMsg += '\n\nThis usually means a require() statement references a file that doesn\'t exist.';
        errorMsg += '\nCheck that all your require() paths are correct and the files exist.';
      } else if (errorMsg.includes('circular')) {
        errorMsg += '\n\nCircular dependency detected. Check your require() statements for loops.';
      } else if (errorMsg.includes('syntax')) {
        errorMsg += '\n\nSyntax error in Lua code. Check for missing ends, invalid syntax, etc.';
      }
      
      console.error('BUNDLE_ERROR');
      console.error(errorMsg);
      process.exit(1);
    }
  } catch (error) {
    console.error('BUNDLE_ERROR');
    console.error(`Worker error: ${error.message || error.toString()}`);
    process.exit(1);
  }
}

// Handle unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
  console.error('BUNDLE_ERROR');
  console.error(`Unhandled rejection: ${reason}`);
  process.exit(1);
});

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  console.error('BUNDLE_ERROR');
  console.error(`Uncaught exception: ${error.message || error.toString()}`);
  process.exit(1);
});

runBundle().catch((error) => {
  console.error('BUNDLE_ERROR');
  console.error(`Run error: ${error.message || error.toString()}`);
  process.exit(1);
});
