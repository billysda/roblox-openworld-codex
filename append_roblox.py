import os

repo_dir = r'E:\Games\clone\roblox-openworld-codex'
struct_path = os.path.join(repo_dir, 'ROBLOX_STRUCTURE.md')

with open(struct_path, 'a', encoding='utf-8') as f:
    f.write("\n## Actualizacion 2026-06-16\nSe agrego Pasture.M.GrazingService para el sistema de pastoreo v0, usando atributos de Player.\n")
