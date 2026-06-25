import os

repo_dir = r'E:\Games\clone\roblox-openworld-codex'
snapshot_dir = os.path.join(repo_dir, 'snapshots', 'CodexAvanceTest_Current')
manifest_path = os.path.join(snapshot_dir, 'MANIFEST.md')

mapping = {
    'ServerScriptService/Pasture/Main.lua': 'game.ServerScriptService.Pasture.Main',
    'ServerScriptService/Pasture/Monitor.lua': 'game.ServerScriptService.Pasture.Monitor',
    'ServerScriptService/Pasture/M/Cfg.lua': 'game.ServerScriptService.Pasture.M.Cfg',
    'ServerScriptService/Pasture/M/Rand.lua': 'game.ServerScriptService.Pasture.M.Rand',
    'ServerScriptService/Pasture/M/House.lua': 'game.ServerScriptService.Pasture.M.House',
    'ServerScriptService/Pasture/M/Flock.lua': 'game.ServerScriptService.Pasture.M.Flock',
    'ServerScriptService/Pasture/M/Sheep.lua': 'game.ServerScriptService.Pasture.M.Sheep'
}

with open(manifest_path, 'a', encoding='utf-8') as f:
    for rel_path, rb_path in mapping.items():
        file_path = os.path.join(snapshot_dir, rel_path.replace('/', '\\\\'))
        if os.path.exists(file_path):
            with open(file_path, 'r', encoding='utf-8') as sf:
                lines = len(sf.readlines())
            f.write(f"| {rel_path} | {rb_path} | Script/Module | {lines} | encontrado | exportado en snapshot |\n")
