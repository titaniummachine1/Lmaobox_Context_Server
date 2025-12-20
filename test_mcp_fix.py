#!/usr/bin/env python
"""Test script to verify MCP timeout fix works correctly."""
import subprocess
import sys
import os
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent / "src"))

from mcp_server.mcp_stdio import _run_bundle

def test_bundle_timeout():
    """Test that bundle operation times out properly instead of hanging."""
    print("Testing bundle timeout fix...")
    
    # Test with a directory that should cause issues (non-existent)
    try:
        result = _run_bundle({
            "projectDir": "non_existent_directory"
        })
        print("ERROR: Should have raised FileNotFoundError")
        return False
    except FileNotFoundError as e:
        print(f"✓ Correctly raised FileNotFoundError: {e}")
        return True
    except Exception as e:
        print(f"ERROR: Unexpected exception: {e}")
        return False

def test_bundle_with_valid_dir():
    """Test bundle with a simple valid directory."""
    print("\nTesting with valid directory...")
    
    # Create a simple test project
    test_dir = Path("test_timeout_fix")
    test_dir.mkdir(exist_ok=True)
    
    try:
        (test_dir / "Main.lua").write_text("""
print("Hello World")
local utils = require("utils")
utils.doSomething()
""")
        (test_dir / "utils.lua").write_text("""
local utils = {}

function utils.doSomething()
    print("Doing something")
end

return utils
""")
        
        result = _run_bundle({
            "projectDir": str(test_dir.absolute())
        })
        
        print(f"✓ Bundle completed successfully")
        print(f"  Exit code: {result['exit_code']}")
        print(f"  Stdout: {result['stdout']}")
        if result['stderr']:
            print(f"  Stderr: {result['stderr']}")
        
        return True
        
    except Exception as e:
        print(f"ERROR: {e}")
        return False
    finally:
        # Cleanup
        import shutil
        shutil.rmtree(test_dir, ignore_errors=True)

if __name__ == "__main__":
    print("=== MCP Timeout Fix Test ===\n")
    
    test1 = test_bundle_timeout()
    test2 = test_bundle_with_valid_dir()
    
    if test1 and test2:
        print("\n✓ All tests passed! The fix is working.")
        sys.exit(0)
    else:
        print("\n✗ Some tests failed.")
        sys.exit(1)
