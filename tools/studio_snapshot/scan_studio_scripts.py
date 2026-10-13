import subprocess
import json
import hashlib
import os
import sys

ROBLOX_DIR = os.path.expandvars(r'%LOCALAPPDATA%\Roblox\Versions')
exe_path = None
for root, dirs, files in os.walk(ROBLOX_DIR):
    if 'StudioMCP.exe' in files:
        exe_path = os.path.join(root, 'StudioMCP.exe')
        break

if not exe_path:
    print("ERROR: StudioMCP.exe not found")
    sys.exit(1)

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
        'clientInfo': {'name': 'scan_agent', 'version': '1.0'}
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

# Step 1: get script list
list_code = """
local HttpService = game:GetService('HttpService')
local scriptsList = {}
local function scan(root)
    for _, desc in ipairs(root:GetDescendants()) do
        if desc:IsA('LuaSourceContainer') then
            local enabled = nil
            if desc:IsA('Script') or desc:IsA('LocalScript') then
                enabled = desc.Enabled
            end
            table.insert(scriptsList, {
                fullName = desc:GetFullName(),
                className = desc.ClassName,
                enabled = enabled,
                sourceLen = #desc.Source
            })
        end
    end
end

scan(game:GetService('Workspace'))
scan(game:GetService('ReplicatedStorage'))
scan(game:GetService('ServerScriptService'))
scan(game:GetService('ServerStorage'))
scan(game:GetService('StarterPlayer'))
scan(game:GetService('StarterGui'))
scan(game:GetService('StarterPack'))

return HttpService:JSONEncode(scriptsList)
"""

raw_list = execute_luau(list_code)
scripts = json.loads(raw_list)
print(f"Total scripts found in Studio: {len(scripts)}")

# Step 2: fetch source for each script
inventory = []
base_export_dir = os.path.join(os.getcwd(), 'docs', 'studio_snapshot', 'current', 'scripts')
os.makedirs(base_export_dir, exist_ok=True)

for i, s in enumerate(scripts):
    full_name = s['fullName']
    fetch_code = f"""
    local HttpService = game:GetService('HttpService')
    local function resolve(path)
        local segments = string.split(path, ".")
        local current = game
        for i = 1, #segments do
            local seg = segments[i]
            if i == 1 and seg == "Workspace" then
                current = workspace
            elseif i == 1 then
                current = game:GetService(seg)
            else
                current = current:FindFirstChild(seg)
            end
            if not current then return nil end
        end
        return current
    end
    local obj = resolve({json.dumps(full_name)})
    if obj and obj:IsA('LuaSourceContainer') then
        return obj.Source
    end
    return ""
    """
    source = execute_luau(fetch_code)
    source_bytes = source.encode('utf-8')
    sha256 = hashlib.sha256(source_bytes).hexdigest()
    
    # Save script to disk in docs/studio_snapshot/current/scripts/...
    # Convert fullName to path
    rel_path = full_name.replace('.', os.sep)
    if s['className'] == 'Script':
        rel_path += '.server.lua'
    elif s['className'] == 'LocalScript':
        rel_path += '.client.lua'
    else:
        rel_path += '.lua'
    
    file_path = os.path.join(base_export_dir, rel_path)
    os.makedirs(os.path.dirname(file_path), exist_ok=True)
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(source)
    
    enabled_val = s.get('enabled')
    enabled_str = f"Enabled={enabled_val}" if enabled_val is not None else "Module"
    print(f"[{i+1}/{len(scripts)}] {s['className']:13} | {enabled_str:13} | len: {len(source):6} | sha256: {sha256[:16]}... | {full_name}")
    
    inventory.append({
        'fullName': full_name,
        'className': s['className'],
        'enabled': enabled_val,
        'sourceLen': len(source),
        'sha256': sha256,
        'diskPath': os.path.relpath(file_path, os.getcwd()).replace(os.sep, '/')
    })

proc.terminate()

with open('studio_scripts_inventory.json', 'w', encoding='utf-8') as f:
    json.dump(inventory, f, indent=2, ensure_ascii=False)

print(f"\nCompleted! Exported {len(inventory)} scripts to docs/studio_snapshot/current/scripts/")
