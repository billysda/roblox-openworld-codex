import subprocess
import json
import os
import sys
import time
from pathlib import Path

ROBLOX_DIR = os.path.expandvars(r'%LOCALAPPDATA%\Roblox\Versions')
exe_path = None
for root, dirs, files in os.walk(ROBLOX_DIR):
    if 'StudioMCP.exe' in files:
        exe_path = os.path.join(root, 'StudioMCP.exe')
        break

if not exe_path:
    print("ERROR: StudioMCP.exe not found")
    sys.exit(1)

print(f"Using StudioMCP: {exe_path}")

proc = subprocess.Popen(
    [exe_path],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
    encoding='utf-8',
    errors='replace'
)

def send_msg(m):
    proc.stdin.write(json.dumps(m) + '\n')
    proc.stdin.flush()

def read_msg():
    line = proc.stdout.readline()
    if not line:
        return None
    return json.loads(line)

send_msg({
    'jsonrpc': '2.0',
    'id': 1,
    'method': 'initialize',
    'params': {
        'protocolVersion': '2024-11-05',
        'capabilities': {},
        'clientInfo': {'name': 'capture_agent', 'version': '1.0'}
    }
})
read_msg()
send_msg({'jsonrpc': '2.0', 'method': 'notifications/initialized'})

msg_id = 2

def execute_luau(code, mode='Edit'):
    global msg_id
    send_msg({
        'jsonrpc': '2.0',
        'id': msg_id,
        'method': 'tools/call',
        'params': {
            'name': 'execute_luau',
            'arguments': {
                'code': code,
                'datamodel_type': mode
            }
        }
    })
    msg_id += 1
    resp = read_msg()
    content = resp.get('result', {}).get('content', [{}])[0].get('text', '')
    return content

# Read base export_inventory.lua
with open('tools/studio_snapshot/export_inventory.lua', 'r', encoding='utf-8') as f:
    base_template = f.read()

# Modify template to omit recursing into RBX_ANIMSAVES keyframes (which contains 1M nodes)
# Note: RBX_ANIMSAVES itself is recorded as a node, but not its 1M descendants
safe_template = base_template.replace(
    'local children = safe(function() return instance:GetChildren() end)',
    'if instance.Name == "RBX_ANIMSAVES" then return end\n    local children = safe(function() return instance:GetChildren() end)'
)

services_to_export = [
    "Workspace",
    "ReplicatedStorage",
    "ServerScriptService",
    "ServerStorage",
    "StarterPlayer",
    "StarterGui",
    "Lighting",
    "SoundService",
    "TextChatService"
]

captures_dir = Path("captures/edit")
captures_dir.mkdir(parents=True, exist_ok=True)

# Clean previous capture pages in captures/edit
for old_file in captures_dir.glob("*.json"):
    old_file.unlink()

PAGE_LIMITS = {
    "ServerStorage": 40,
}
DEFAULT_PAGE_LIMIT = 80
stats = {}

print("Starting DataModel capture across all services...")
t_start = time.time()

for sname in services_to_export:
    print(f"\n--- Exporting Service: {sname} ---")
    start_index = 1
    page_num = 1
    service_nodes = 0
    page_limit = PAGE_LIMITS.get(sname, DEFAULT_PAGE_LIMIT)
    
    while True:
        # Build script for this page
        code = safe_template.replace(
            'local SERVICE_NAME = "Workspace"',
            f'local SERVICE_NAME = "{sname}"'
        ).replace(
            'local START_INDEX = 1',
            f'local START_INDEX = {start_index}'
        ).replace(
            'local PAGE_LIMIT = 80',
            f'local PAGE_LIMIT = {page_limit}'
        )
        
        t0 = time.time()
        res_text = execute_luau(code, mode='Edit')
        t1 = time.time()
        
        try:
            page_data = json.loads(res_text)
        except Exception as e:
            print(f"ERROR: Failed to parse JSON response for {sname} page {page_num}: {e}")
            print("Raw response preview:", res_text[:300])
            sys.exit(1)
        
        total_nodes = page_data.get('totalNodes', 0)
        records_count = len(page_data.get('records', []))
        has_more = page_data.get('hasMore', False)
        service_nodes = total_nodes
        
        # Save page JSON file
        out_page_path = captures_dir / f"{sname.lower()}_page_{page_num:04d}.json"
        with open(out_page_path, 'w', encoding='utf-8') as pf:
            json.dump(page_data, pf, ensure_ascii=False, indent=2)
            
        print(f"  Page {page_num:03d} (nodes {start_index}-{start_index+records_count-1} of {total_nodes}) "
              f"-> {records_count} records ({t1-t0:.2f}s) saved to {out_page_path.name}")
        
        if not has_more or records_count == 0:
            break
            
        start_index += page_limit
        page_num += 1

    stats[sname] = {
        'totalNodes': service_nodes,
        'pages': page_num
    }

proc.terminate()
t_end = time.time()

print(f"\n==========================================")
print(f"DataModel Capture Complete in {t_end - t_start:.2f}s!")
print(f"==========================================")
for sname, info in stats.items():
    print(f"  {sname:20}: {info['totalNodes']:6} nodes ({info['pages']} pages)")

total_captured = sum(info['totalNodes'] for info in stats.values())
print(f"Total nodes captured across all services: {total_captured}")
