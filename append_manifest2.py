import os

repo_dir = r'E:\Games\clone\roblox-openworld-codex'
snapshot_dir = os.path.join(repo_dir, 'snapshots', 'CodexAvanceTest_Current')
manifest_path = os.path.join(snapshot_dir, 'MANIFEST.md')

with open(manifest_path, 'a', encoding='utf-8') as f:
    f.write("| ServerScriptService/Pasture/M/GrazingService.lua | game.ServerScriptService.Pasture.M.GrazingService | ModuleScript | 262 | creado | exportado en snapshot, Pastoreo v0 |\n")
