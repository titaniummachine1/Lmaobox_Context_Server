#!/usr/bin/env python3
"""Test script to verify MCP tools work correctly"""

import json
import subprocess
import sys
import time

def send_mcp_request(exe_path, method, params):
    """Send MCP request and get response"""
    request = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": method,
        "params": params
    }
    
    request_json = json.dumps(request) + "\n"
    
    proc = subprocess.Popen(
        [exe_path],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )
    
    stdout, stderr = proc.communicate(input=request_json, timeout=20)
    
    if stderr:
        print(f"STDERR: {stderr}", file=sys.stderr)
    
    # Parse response
    for line in stdout.split('\n'):
        if line.strip():
            try:
                return json.loads(line)
            except json.JSONDecodeError:
                continue
    
    return None

def test_trace_bundle_error():
    """Test trace_bundle_error tool"""
    print("=" * 60)
    print("TEST 1: trace_bundle_error tool")
    print("=" * 60)
    
    exe_path = r"C:\Users\Terminatort8000\Desktop\Lmaobox_Context_Server\lmaobox-context-server.exe"
    
    # First, initialize
    init_response = send_mcp_request(exe_path, "initialize", {
        "protocolVersion": "2024-11-05",
        "capabilities": {},
        "clientInfo": {
            "name": "test-client",
            "version": "1.0.0"
        }
    })
    
    print(f"Initialize response: {json.dumps(init_response, indent=2)}\n")
    
    # Test trace_bundle_error with simtest.lua
    print("Testing trace_bundle_error with simtest.lua:1514...")
    start_time = time.time()
    
    trace_response = send_mcp_request(exe_path, "tools/call", {
        "name": "trace_bundle_error",
        "arguments": {
            "bundledFilePath": r"C:\Users\Terminatort8000\AppData\Local\lua\simtest.lua",
            "errorLine": 1514
        }
    })
    
    elapsed = time.time() - start_time
    
    if trace_response and "result" in trace_response:
        print(f"✓ Tool executed in {elapsed:.2f}s")
        print("\nResult:")
        print(trace_response["result"]["content"][0]["text"])
    else:
        print(f"✗ Tool failed")
        print(f"Response: {json.dumps(trace_response, indent=2)}")
    
    return trace_response is not None

def test_bundle_blocking():
    """Test bundle tool blocking behavior"""
    print("\n" + "=" * 60)
    print("TEST 2: Bundle tool blocking behavior")
    print("=" * 60)
    
    exe_path = r"C:\Users\Terminatort8000\Desktop\Lmaobox_Context_Server\lmaobox-context-server.exe"
    project_dir = r"C:\Users\Terminatort8000\Desktop\Lmaobox_Context_Server\test_project"
    
    print(f"Bundling project: {project_dir}")
    print("This should BLOCK and complete within 15 seconds...")
    
    start_time = time.time()
    
    try:
        bundle_response = send_mcp_request(exe_path, "tools/call", {
            "name": "bundle",
            "arguments": {
                "projectDir": project_dir
            }
        })
        
        elapsed = time.time() - start_time
        
        print(f"\n✓ Bundle completed in {elapsed:.2f}s")
        
        if bundle_response and "result" in bundle_response:
            print("\nResult:")
            print(bundle_response["result"]["content"][0]["text"])
            
            if elapsed > 15:
                print(f"\n⚠ WARNING: Took longer than 15s timeout!")
                return False
            else:
                print(f"\n✓ Completed within 15s timeout")
                return True
        else:
            print(f"✗ Bundle failed")
            print(f"Response: {json.dumps(bundle_response, indent=2)}")
            return False
            
    except subprocess.TimeoutExpired:
        elapsed = time.time() - start_time
        print(f"\n✗ TIMEOUT after {elapsed:.2f}s - tool did not respond!")
        return False

if __name__ == "__main__":
    print("Testing MCP Tools\n")
    
    test1_pass = test_trace_bundle_error()
    test2_pass = test_bundle_blocking()
    
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    print(f"trace_bundle_error: {'✓ PASS' if test1_pass else '✗ FAIL'}")
    print(f"bundle blocking:    {'✓ PASS' if test2_pass else '✗ FAIL'}")
    
    sys.exit(0 if (test1_pass and test2_pass) else 1)
