import json
import os
import hashlib
from pathlib import Path

# 1. SCRIPT_INDEX.md
with open('studio_scripts_inventory.json', 'r', encoding='utf-8') as f:
    scripts = json.load(f)

script_index_lines = [
    "# Índice de Scripts (Roblox Studio -> Exportación Actual)",
    "",
    f"Total scripts exportados con Source íntegro y SHA-256: **{len(scripts)}**",
    "",
    "| Instancia DataModel | Clase | Estado | Bytes | SHA-256 | Archivo Local |",
    "|---|---|---|---|---|---|"
]

for s in scripts:
    en = f"Enabled={s['enabled']}" if s['enabled'] is not None else "Module"
    rel_disk = s['diskPath']
    script_index_lines.append(
        f"| `{s['fullName']}` | `{s['className']}` | {en} | {s['sourceLen']} | `{s['sha256']}` | [{Path(rel_disk).name}]({rel_disk}) |"
    )

with open('docs/studio_snapshot/current/SCRIPT_INDEX.md', 'w', encoding='utf-8') as f:
    f.write("\n".join(script_index_lines) + "\n")

print("Generated docs/studio_snapshot/current/SCRIPT_INDEX.md")

# 2. DIFF_FROM_PREVIOUS.md (Compare Studio Scripts vs GitHub snapshots/CodexAvanceTest_Current/)
repo_snapshot_dir = Path("snapshots/CodexAvanceTest_Current")
diff_lines = [
    "# Comparación: Studio Actual vs. Snapshots en GitHub",
    "",
    "Comparación de SHA-256 entre el estado actual de Roblox Studio (`docs/studio_snapshot/current/scripts/`) y el snapshot previo en el repositorio (`snapshots/CodexAvanceTest_Current/`).",
    "",
    "## Resumen de Divergencias",
    "",
    "| Script Studio | Hash Studio Actual | Hash GitHub Repo | Estado |",
    "|---|---|---|---|"
]

# Map repo files to candidate fullName
repo_files = {}
for p in repo_snapshot_dir.rglob("*.lua"):
    rel = p.relative_to(repo_snapshot_dir).as_posix()
    with open(p, 'rb') as rf:
        content = rf.read()
    h = hashlib.sha256(content).hexdigest()
    repo_files[rel] = {
        'path': p,
        'sha256': h,
        'bytes': len(content)
    }

# Find matches
matched_repo_keys = set()
for s in scripts:
    fn = s['fullName']
    # candidate relative paths in repo
    parts = fn.split('.')
    service = parts[0]
    rest = '/'.join(parts[1:])
    
    candidates = []
    if s['className'] == 'Script':
        candidates.append(f"{service}/{rest}.server.lua")
        candidates.append(f"{service}/{rest}.lua")
    elif s['className'] == 'LocalScript':
        candidates.append(f"{service}/{rest}.client.lua")
        candidates.append(f"{service}/{rest}.lua")
    else:
        candidates.append(f"{service}/{rest}.lua")
        candidates.append(f"{service}/{rest}.luau")

    match = None
    for c in candidates:
        if c in repo_files:
            match = c
            matched_repo_keys.add(c)
            break
            
    if match:
        repo_sha = repo_files[match]['sha256']
        if repo_sha == s['sha256']:
            status = "MATCH (Idéntico)"
        else:
            status = "**DIFFERENT (Modificado en Studio)**"
        diff_lines.append(f"| `{fn}` | `{s['sha256'][:16]}...` | `{repo_sha[:16]}...` | {status} |")
    else:
        diff_lines.append(f"| `{fn}` | `{s['sha256'][:16]}...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |")

# List files that exist in repo but not in Studio
repo_only = set(repo_files.keys()) - matched_repo_keys
if repo_only:
    diff_lines.extend([
        "",
        "## Archivos en GitHub Repo ausentes en Studio (REPO_ONLY)",
        "",
        "| Archivo en GitHub | SHA-256 | Estado |",
        "|---|---|---|"
    ])
    for ro in sorted(repo_only):
        diff_lines.append(f"| `{ro}` | `{repo_files[ro]['sha256'][:16]}...` | REPO_ONLY |")

with open('docs/studio_snapshot/current/DIFF_FROM_PREVIOUS.md', 'w', encoding='utf-8') as f:
    f.write("\n".join(diff_lines) + "\n")

print("Generated docs/studio_snapshot/current/DIFF_FROM_PREVIOUS.md")

# 3. CONNECTIONS.md (Extract Remotes, Constraints, Welds, Motor6Ds, Attachments)
connections_lines = [
    "# Relaciones y Conexiones del DataModel",
    "",
    "Extracción formal de Remotes, Constraints, Welds, Motor6Ds, Attachments y referencias entre instancias.",
    "",
    "## 1. RemoteEvents y RemoteFunctions en ReplicatedStorage",
    "",
    "| Nombre | Clase | Ruta DataModel |",
    "|---|---|---|"
]

# Read replicatedstorage.jsonl
with open('docs/studio_snapshot/current/instances/services/replicatedstorage.jsonl', 'r', encoding='utf-8') as f:
    rs_records = [json.loads(line) for line in f]

for r in rs_records:
    if r['className'] in ['RemoteEvent', 'RemoteFunction', 'UnreliableRemoteEvent']:
        connections_lines.append(f"| `{r['name']}` | `{r['className']}` | `{r['path']}` |")

# Read workspace.jsonl for constraints, joints, and attachments
connections_lines.extend([
    "",
    "## 2. Constraints, Joints y Ensambles en Workspace",
    "",
    "| Instancia | Clase | Part0 / Adornee | Part1 / Referencia | Ruta |",
    "|---|---|---|---|---|"
] )

with open('docs/studio_snapshot/current/instances/workspace.jsonl', 'r', encoding='utf-8') as f:
    ws_records = [json.loads(line) for line in f]

constraint_classes = [
    'Weld', 'WeldConstraint', 'Motor6D', 'AlignOrientation', 'LinearVelocity',
    'BallSocketConstraint', 'HingeConstraint', 'RodConstraint', 'SpringConstraint',
    'RopeConstraint', 'PrismaticConstraint', 'Attachment'
]

constraint_count = 0
for r in ws_records:
    cname = r['className']
    if cname in constraint_classes:
        props = r.get('properties', {})
        p0 = props.get('Part0') or props.get('Attachment0') or props.get('Adornee') or '-'
        p1 = props.get('Part1') or props.get('Attachment1') or '-'
        if isinstance(p0, dict): p0 = p0.get('fullName', str(p0))
        if isinstance(p1, dict): p1 = p1.get('fullName', str(p1))
        connections_lines.append(f"| `{r['name']}` | `{cname}` | `{p0}` | `{p1}` | `{r['path']}` |")
        constraint_count += 1

print(f"Extracted {constraint_count} constraints and joints in Workspace.")

with open('docs/studio_snapshot/current/CONNECTIONS.md', 'w', encoding='utf-8') as f:
    f.write("\n".join(connections_lines) + "\n")

print("Generated docs/studio_snapshot/current/CONNECTIONS.md")

# 4. CAPTURE_LIMITATIONS.md
limitations_text = """# Limitaciones de la Captura del DataModel

1. **ServerStorage y RBX_ANIMSAVES**:
   - `ServerStorage.RBX_ANIMSAVES` contiene 1,016,383 descendientes generados automáticamente por el *Roblox Animation Clip Editor* (almacén de keyframes y poses por fotograma para rigs como Gallina, Oveja, wyvernfbx y DragonModel).
   - Por diseño estricto para evitar generar un archivo JSONL de ~500 MB (que excedería el límite de 100 MB de GitHub y tardaría más de 1.8 horas de exportación de red), se exportó el nodo raíz de `RBX_ANIMSAVES` pero se omitió la recursión sobre su millón de fotogramas efímeros de editor.
   - Los assets jugables reales en `ServerStorage.Assets` (186 instancias), `_Reference_DragonClassic` (592 instancias) y `_Reference_DragonTierraLegacy` (498 instancias) fueron exportados al 100% sin truncamiento.

2. **StarterPack**:
   - `StarterPack` contiene un `Script` (deshabilitado) y otra carpeta secundaria `RBX_ANIMSAVES` de 23,609 keyframes de editor.

3. **Geometría Binaria y Assets**:
   - Las instancias `MeshPart`, `SpecialMesh`, `Decal`, `Texture` y `Animation` registran sus propiedades (`MeshId`, `TextureID`, `AnimationId`, `Size`, `CFrame`, etc.), pero los binarios 3D de Roblox (`rbxassetid://`) no se almacenan como blobs en el árbol JSONL.

4. **Terrain**:
   - La instancia `Workspace.Terrain` está registrada con sus propiedades principales de iluminación/material, pero la voxelgrid tridimensional de Terrain requiere exportación específica de voxels (`Terrain:CopyRegion`).

5. **Modo de Captura**:
   - Esta captura fue realizada 100% en modo **Edit** (`RunService:IsEdit() == true`).
   - Las instancias creadas exclusivamente por scripts durante **Play** (como `DT_ClientSaddleProxy`, efectos de partículas temporales, o personajes `Player.Character`) no existen en Edit y deben documentarse a través de sus generadores en código o en una captura Play complementaria.
"""

with open('docs/studio_snapshot/current/CAPTURE_LIMITATIONS.md', 'w', encoding='utf-8') as f:
    f.write(limitations_text)

print("Generated docs/studio_snapshot/current/CAPTURE_LIMITATIONS.md")
