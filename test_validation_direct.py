import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent / "src"))

from mcp_server.mcp_stdio import _run_luacheck

test_file = Path(__file__).parent / "test_modern_lua.lua"

result = _run_luacheck({
    'filePath': str(test_file),
    'checkBundle': False
})

print("=" * 60)
print("VALIDATION TEST RESULT")
print("=" * 60)
print(f"Status: {'VALID' if result['valid'] else 'INVALID'}")
print(f"Lua Version: {result.get('lua_version', 'unknown')}")
print(f"Exit Code: {result['exit_code']}")
print()

if result.get('warning'):
    print("WARNING:")
    print(result['warning'])
    print()

if result.get('stderr'):
    print("Error Output:")
    print(result['stderr'])
    print()

if result['valid']:
    print("SUCCESS: Validation passed!")
else:
    print("FAILED: Validation rejected the code")
