#!/usr/bin/env python3
"""Direct test of Zero-Mutation policy checker."""
from pathlib import Path
import sys
import re

def _check_zero_mutation_policy(content: str, file_path: Path) -> list:
    """Enforce Zero-Mutation Lbox protocol: no callback mutations at runtime."""
    violations = []
    lines = content.split('\n')
    
    # Track depth and callback registrations
    depth = 0
    function_depth_start = {}
    registers = {}  # (event, id) -> line_num
    unregisters = {}  # (event, id) -> line_num
    
    for line_num, line in enumerate(lines, 1):
        stripped = line.strip()
        
        # Track function nesting depth
        if 'function' in stripped and '(' in stripped:
            depth += 1
            
        # Check for unregister calls
        if 'callbacks.Unregister' in line or 'callbacks.unregister' in line:
            # Extract event and id from: callbacks.Unregister("Event", "id")
            match = re.search(r'callbacks\.(?:Un|un)register\s*\(\s*["\']([^"\']+)["\']\s*,\s*["\']([^"\']+)["\']\s*\)', line)
            if match:
                event, uid = match.groups()
                key = (event, uid)
                
                # RULE: Unregister must be at depth 0 (global scope only)
                if depth > 0:
                    violations.append({
                        "line": line_num,
                        "message": f"CRITICAL: Illegal Unregister inside function scope (including Unload). Runtime callback table mutation is forbidden. Move callbacks.Unregister to global scope (Depth 0)."
                    })
                else:
                    unregisters[key] = line_num
        
        # Check for register calls
        if 'callbacks.Register' in line or 'callbacks.register' in line:
            match = re.search(r'callbacks\.(?:R|r)egister\s*\(\s*["\']([^"\']+)["\']\s*,\s*["\']([^"\']+)["\']\s*', line)
            if match:
                event, uid = match.groups()
                key = (event, uid)
                registers[key] = line_num
                
                # RULE: Kill-Switch - unregister must precede register
                if key not in unregisters or unregisters[key] >= registers[key]:
                    if key in unregisters:
                        violations.append({
                            "line": registers[key],
                            "message": f"CRITICAL: Kill-Switch violation for id '{uid}' on event '{event}': callbacks.Unregister must appear before callbacks.Register at depth 0"
                        })
        
        # Track function ends (simplified: count closing braces)
        if 'end' in stripped:
            if depth > 0:
                depth -= 1
    
    return violations

if __name__ == "__main__":
    test_file = Path("test_zero_mutation.lua")
    if test_file.exists():
        content = test_file.read_text()
        violations = _check_zero_mutation_policy(content, test_file)
        print(f"Violations found: {len(violations)}")
        for v in violations:
            print(f"  Line {v['line']}: {v['message']}")
    else:
        print(f"Test file not found: {test_file}")
