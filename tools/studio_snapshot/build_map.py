#!/usr/bin/env python3
"""Combina páginas JSON del exportador de Studio en índices del Place.

Ejemplo:
  python tools/studio_snapshot/build_map.py --pages ./captures/edit/ --out ./docs/studio_snapshot/current \
      --place-name CodexAvanceTest --studio-id ID --mode Edit

No accede a Roblox; nunca infiere instancias ausentes. Fallará si faltan páginas.
"""
import argparse
from collections import Counter, defaultdict
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import sys

CORE_SERVICES = {
    "Workspace", "ReplicatedStorage", "ServerScriptService", "ServerStorage",
    "StarterPlayer", "StarterGui", "Lighting", "SoundService"
}

def dump_json(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))

def write_jsonl(path, records):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as f:
        for record in records:
            f.write(dump_json(record) + "\n")

def clean_name(name):
    return str(name).replace("\r", " ").replace("\n", " ").replace("`", "'")

def read_pages(directory):
    paths = sorted(directory.rglob("*.json"))
    if not paths:
        raise ValueError(f"No se encontraron páginas JSON en {directory}")
    grouped = defaultdict(list)
    for path in paths:
        value = json.loads(path.read_text(encoding="utf-8"))
        if value.get("schemaVersion") != 1:
            raise ValueError(f"Esquema inesperado: {path}")
        service = value.get("service")
        if not isinstance(service, str) or not service:
            raise ValueError(f"Servicio ausente: {path}")
        grouped[service].append((path, value))
    return grouped

def validate_service(service, parts):
    parts = sorted(parts, key=lambda item: item[1]["startIndex"])
    total_set = {part["totalNodes"] for _, part in parts}
    place_set = {part.get("placeId") for _, part in parts}
    universe_set = {part.get("gameId") for _, part in parts}
    if len(total_set) != 1 or len(place_set) != 1 or len(universe_set) != 1:
        raise ValueError(f"{service}: páginas de distintos estados/Place; recapturar")
    total = next(iter(total_set))
    cursor = 1
    entries = []
    for path, page in parts:
        if page["startIndex"] != cursor:
            raise ValueError(f"{service}: índice faltante o duplicado antes de {path}; esperado {cursor}")
        if page.get("captureErrors"):
            raise ValueError(f"{service}: errores de captura en {path}: {page['captureErrors'][:3]}")
        expected = min(page["pageLimit"], total - cursor + 1)
        if expected <= 0 or len(page.get("records", [])) != expected:
            raise ValueError(f"{service}: tamaño incompleto de página {path}: esperado {expected}")
        entries.extend(page["records"])
        cursor += expected
    if cursor != total + 1:
        raise ValueError(f"{service}: faltan registros ({cursor-1}/{total})")
    paths = [item["path"] for item in entries]
    if len(paths) != len(set(paths)):
        raise ValueError(f"{service}: rutas duplicadas; la jerarquía cambió entre páginas")
    return entries, next(iter(place_set)), next(iter(universe_set))

def emit_tree(entries):
    out = ["# Workspace — árbol completo de instancias", "",
           "Generado exclusivamente desde capturas Studio MCP. No representa geometría completa.", "", "```text"]
    for row in entries:
        out.append(("  " * max(0, int(row["depth"]))) + clean_name(row["name"]) + " [" + row["className"] + "]")
    out.extend(["```", ""])
    return "\n".join(out)

def spatial_record(row):
    p = row.get("properties", {})
    class_name = row["className"]
    has_position = ("CFrame" in p or "Position" in p or "WorldPivot" in p)
    if not has_position:
        return None
    # Vector3 y CFrame contienen coordenadas en arrays; sin aproximar posiciones ausentes.
    cf = p.get("CFrame") or p.get("WorldPivot")
    pos = p.get("Position")
    location = None
    if isinstance(cf, dict) and cf.get("type") == "CFrame":
        location = cf["value"][:3]
    elif isinstance(pos, dict) and pos.get("type") == "Vector3":
        location = pos["value"]
    return {
        "path": row["path"], "className": class_name, "name": row["name"],
        "worldPosition": location, "cframe": cf,
        "size": p.get("Size"), "anchored": p.get("Anchored"),
        "material": p.get("Material"), "meshId": p.get("MeshId")
    }

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pages", type=Path, required=True, help="Directorio de páginas MCP (.json)")
    ap.add_argument("--out", type=Path, required=True, help="Destino del mapa generado")
    ap.add_argument("--place-name", required=True)
    ap.add_argument("--studio-id", default="UNKNOWN")
    ap.add_argument("--mode", choices=["Edit", "Play"], required=True)
    ap.add_argument("--git-revision", default="UNKNOWN")
    ap.add_argument("--allow-partial-services", action="store_true")
    args = ap.parse_args()

    grouped = read_pages(args.pages)
    missing = CORE_SERVICES - set(grouped)
    if missing and not args.allow_partial_services:
        raise ValueError("Faltan servicios; capturar antes de publicar: " + ", ".join(sorted(missing)))
    if "Workspace" not in grouped:
        raise ValueError("Falta Workspace, no se puede construir el mapa solicitado")

    by_service = {}
    places, universes = set(), set()
    for service, pages in sorted(grouped.items()):
        entries, place, universe = validate_service(service, pages)
        by_service[service] = entries
        places.add(place)
        universes.add(universe)
    if len(places) != 1 or len(universes) != 1:
        raise ValueError("Los servicios pertenecen a distintos Place/Universes")

    args.out.mkdir(parents=True, exist_ok=True)
    all_records = [r for _, rows in sorted(by_service.items()) for r in rows]
    for service, records in sorted(by_service.items()):
        file = (args.out / "instances" / "workspace.jsonl") if service == "Workspace" else \
               (args.out / "instances" / "services" / (service.lower() + ".jsonl"))
        write_jsonl(file, records)

    (args.out / "WORKSPACE_TREE.md").write_text(
        emit_tree(by_service["Workspace"]), encoding="utf-8")
    spatial = [item for record in by_service["Workspace"]
               if (item := spatial_record(record)) is not None]
    write_jsonl(args.out / "spatial_index.jsonl", spatial)

    counts = Counter(r["className"] for r in all_records)
    spatial_lines = [
        "# Índice espacial (Workspace)", "",
        f"Se exportaron {len(spatial)} instancias con posición/pivote accesibles.",
        "El archivo `spatial_index.jsonl` conserva el índice completo; esta vista enseña las primeras 200.",
        "", "| Ruta | Clase | Posición XYZ (studs) |",
        "|---|---|---|"]
    for item in spatial[:200]:
        xyz = item["worldPosition"]
        label = ", ".join(map(str,xyz)) if xyz is not None else "No disponible"
        spatial_lines.append(f"| `{clean_name(item['path'])}` | {item['className']} | {label} |")
    (args.out / "SPATIAL_INDEX.md").write_text("\n".join(spatial_lines) + "\n", encoding="utf-8")

    sha = hashlib.sha256()
    for row in all_records:
        sha.update((dump_json(row) + "\n").encode("utf-8"))
    metadata = {
        "schemaVersion": 1, "placeName": args.place_name, "studioId": args.studio_id,
        "placeId": next(iter(places)), "universeId": next(iter(universes)),
        "mode": args.mode, "capturedAtUtc": datetime.now(timezone.utc).isoformat(),
        "referenceGitRevision": args.git_revision, "services": {k:len(v) for k,v in by_service.items()},
        "totalInstances": len(all_records), "workspaceInstances":len(by_service["Workspace"]),
        "spatialEntries": len(spatial), "canonicalSha256": sha.hexdigest(),
        "missingCoreServices": sorted(missing),
        "warning": "Sin Source, binarios Mesh/CSG, assets externos, voxels Terrain o garantía de estado Play"
    }
    (args.out / "metadata.json").write_text(json.dumps(metadata,ensure_ascii=False,indent=2,sort_keys=True)+"\n", encoding="utf-8")
    index = ["# OpenWorld Codex — snapshot del DataModel", "",
             f"- Place declarado: `{args.place_name}`",
             f"- PlaceId: `{metadata['placeId']}`",
             f"- Modo: `{args.mode}`",
             f"- Total instancias: **{len(all_records)}**",
             f"- Workspace: **{len(by_service['Workspace'])}**",
             f"- Captura SHA-256: `{metadata['canonicalSha256']}`", "",
             "## Servicios", ""]
    for name, entries in sorted(by_service.items()):
        index.append(f"- `{name}`: {len(entries)} instancias")
    index.extend(["", "## Clases más frecuentes", ""])
    for name, count in counts.most_common(25):
        index.append(f"- `{name}`: {count}")
    index.extend(["", "## Documentos", "",
                  "- [Árbol completo](WORKSPACE_TREE.md)",
                  "- [Índice espacial resumido](SPATIAL_INDEX.md)",
                  "- [Registros espaciales completos](spatial_index.jsonl)",
                  "- [Metadata y estado](metadata.json)", "",
                  "## Limitaciones", "",
                  "Sin código Source de scripts, referencias dinámicas inferidas, voxels de Terrain ni geometría mesh binaria; capturar por separado.", ""])
    (args.out / "INDEX.md").write_text("\n".join(index), encoding="utf-8")
    print(f"VALIDADO: {len(all_records)} instancias, Workspace={len(by_service['Workspace'])}; salida={args.out}")
    print(f"SHA256 {metadata['canonicalSha256']}")

if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("ERROR de integridad del inventario:", exc, file=sys.stderr)
        raise SystemExit(1)
