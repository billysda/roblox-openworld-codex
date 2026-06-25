import json
import os

repo_dir = r'E:\Games\clone\roblox-openworld-codex'
snapshot_dir = os.path.join(repo_dir, 'snapshots', 'CodexAvanceTest_Current', 'ServerScriptService', 'Pasture')
os.makedirs(os.path.join(snapshot_dir, 'M'), exist_ok=True)

with open(r'C:\Users\USER\.gemini\antigravity\brain\7850dd9b-7821-436f-a023-e8374f2a1baf\.system_generated\steps\36\output.txt', 'r', encoding='utf-8') as f:
    data = json.load(f)

exported = []
not_found = []
mapping = {
    'Main': 'Main.lua',
    'Monitor': 'Monitor.lua',
    'Cfg': 'M/Cfg.lua',
    'Rand': 'M/Rand.lua',
    'House': 'M/House.lua',
    'Flock': 'M/Flock.lua',
    'Sheep': 'M/Sheep.lua'
}

for k, v in mapping.items():
    content = data.get(k, 'NOT_FOUND')
    if content == 'NOT_FOUND':
        not_found.append(k)
    else:
        out_path = os.path.join(snapshot_dir, v.replace('/', '\\\\'))
        with open(out_path, 'w', encoding='utf-8', newline='\n') as out_f:
            out_f.write(content)
        exported.append(k)

print('Exported:', ', '.join(exported))
if not_found:
    print('Not Found:', ', '.join(not_found))
