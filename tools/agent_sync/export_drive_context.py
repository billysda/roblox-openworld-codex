#!/usr/bin/env python3
"""Exporta contexto Git inmutable para Gemini Web via una carpeta SINCRONIZADA de Drive.

Solo escribe archivos locales fuera del checkout. NO autentica Google Drive, NO
ejecuta git fetch, NO edita Roblox Studio ni publica el contenido por si mismo.
Antigravity debe comprobar que Drive realmente subio la version y que Argon la leyo.

Ejemplo:
  python tools/agent_sync/export_drive_context.py --out "G:\\Mi unidad\\OpenWorld_AgentBridge" --ref origin/main
  python tools/agent_sync/export_drive_context.py --out "<CARPETA_DRIVE_REAL>" --ref origin/main --inventory

No copiar .git, archivos no rastreados, credenciales, backups o dumps completos por defecto.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
REPO_NAME = "billysda/roblox-openworld-codex"
DOCS = {
    "AGENTS.md", "CODEX_RULES.md", "STATUS.md", "ROBLOX_STRUCTURE.md",
    "docs/agent_sync/PROTOCOL.md",
    "docs/agent_sync/BASELINE_REVIEW.md",
    "docs/agent_sync/DRIVE_BRIDGE.md",
    "docs/studio_snapshot/current/INDEX.md",
    "docs/studio_snapshot/current/CONNECTIONS.md",
    "docs/studio_snapshot/current/SCRIPT_INDEX.md",
    "docs/studio_snapshot/current/CAPTURE_LIMITATIONS.md",
    "docs/studio_snapshot/current/WORKSPACE_TREE.md",
    "docs/studio_snapshot/current/SPATIAL_INDEX.md",
    "docs/studio_snapshot/current/DIFF_FROM_PREVIOUS.md",
}
SECRET = re.compile(
    rb"(?:gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|"
    rb"AIza[0-9A-Za-z_-]{30,}|-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----|"
    rb"sk-[A-Za-z0-9]{24,})"
)
CHUNK_SIZE = 150_000


def git(*args: str) -> bytes:
    p = subprocess.run(["git", *args], cwd=ROOT, capture_output=True)
    if p.returncode:
        raise RuntimeError(f"git {' '.join(args)}: {p.stderr.decode('utf-8','replace')}")
    return p.stdout


def sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def safe_path(out: Path) -> None:
    root = ROOT.resolve()
    target = out.resolve()
    if target == root:
        raise ValueError("La carpeta Drive no puede ser el checkout")
    try:
        if os.path.commonpath([str(root), str(target)]) == str(root):
            raise ValueError("No poner el puente Drive dentro del repo/.git")
    except ValueError as e:
        if "No poner" in str(e):
            raise
        # Distintas unidades Windows: commonpath arroja ValueError; permitido.
    remote = git("remote", "get-url", "origin").decode().strip().lower()
    if REPO_NAME not in remote:
        raise RuntimeError(f"Remoto Git no es OpenWorld Codex: {remote}")


def include(path: str, inventory: bool) -> bool:
    if path in DOCS:
        return True
    if path.lower().endswith((".lua", ".luau")) and not path.startswith((".git/", "backups/")):
        return True
    if inventory and (
        path.startswith("docs/studio_snapshot/current/instances/")
        or path == "docs/studio_snapshot/current/spatial_index.jsonl"
    ):
        return path.endswith(".jsonl")
    return False


def fence(src: str) -> str:
    runs = [len(x) for x in re.findall(r"`+", src)]
    return "`" * max(5, (max(runs) if runs else 0) + 1)


def atomic_write(path: Path, raw: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".incomplete")
    tmp.write_bytes(raw)
    tmp.replace(path)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", type=Path, required=True, help="Ruta real de carpeta sincronizada Drive")
    ap.add_argument("--ref", default="origin/main", help="Ref Git a exportar (ej. origin/main)")
    ap.add_argument("--inventory", action="store_true", help="Incluye JSONL del DataModel archivado")
    args = ap.parse_args()

    safe_path(args.out)
    commit = git("rev-parse", "--verify", f"{args.ref}^{{commit}}").decode().strip()
    if not re.fullmatch(r"[a-f0-9]{40}", commit):
        raise RuntimeError("Git no devolvio un commit SHA valido")
    tracked = git("ls-tree", "-r", "--name-only", "-z", commit).split(b"\x00")
    paths = [p.decode("utf-8") for p in tracked if p]
    paths = sorted(p for p in paths if include(p, args.inventory))
    if not paths:
        raise RuntimeError("No se encontraron archivos autorizados")

    entries: list[dict] = []
    parts: list[bytes] = []
    chunk_parts: list[str] = []
    size = 0

    def flush() -> None:
        nonlocal chunk_parts, size
        if chunk_parts:
            parts.append(("".join(chunk_parts)).encode("utf-8"))
            chunk_parts = []
            size = 0

    for path in paths:
        raw = git("show", f"{commit}:{path}")
        if SECRET.search(raw):
            raise RuntimeError(f"Posible credencial en {path}; bloquear exportacion y revisar localmente")
        src = raw.decode("utf-8")  # Fallar ante bytes invalidos, nunca corromper Source.
        sep = fence(src)
        part_text = (
            f"## Archivo: {path}\n\n"
            f"SHA-256 del Source UTF-8: `{sha256(raw)}` | Bytes: {len(raw)}\n\n"
            f"{sep}text\n{src}{'' if src.endswith(chr(10)) else chr(10)}{sep}\n\n"
        )
        part_size = len(part_text.encode("utf-8"))
        if chunk_parts and size + part_size > CHUNK_SIZE:
            flush()
        part_index = len(parts) + 1
        chunk_parts.append(part_text)
        size += part_size
        entries.append({"path": path, "sha256": sha256(raw), "bytes": len(raw),
                        "part": f"CODE_PART_{part_index:04d}.md"})
    flush()

    revision_dir = args.out / "revisions" / commit
    ready = revision_dir / "READY.json"
    if ready.exists():
        raise RuntimeError(f"Revision ya publicada localmente, no sobrescribir: {ready}")
    revision_dir.mkdir(parents=True, exist_ok=True)

    part_entries = []
    for ix, raw in enumerate(parts, 1):
        name = f"CODE_PART_{ix:04d}.md"
        atomic_write(revision_dir / name, raw)
        part_entries.append({"file": name, "sha256": sha256(raw), "bytes": len(raw)})

    manifest = {
        "schemaVersion": 1, "repository": REPO_NAME, "ref": args.ref,
        "commitSha": commit, "generatedAtUtc": datetime.now(timezone.utc).isoformat(),
        "mode": "snapshot-of-committed-Git-blobs", "inventoryIncluded": args.inventory,
        "fileCount": len(entries), "partCount": len(parts),
        "sourceFiles": entries, "parts": part_entries,
        "notes": "No incluye cambios sin commit ni estados runtime de Roblox Studio. "
                 "Esperar a que Drive suba todos los archivos; Argon debe confirmar "
                 "commitSha y contenido de partes antes de programar.",
    }
    manifest_bytes = (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode()
    atomic_write(revision_dir / "MANIFEST.json", manifest_bytes)
    atomic_write(ready, (json.dumps(
        {"commitSha": commit, "manifestSha256": sha256(manifest_bytes),
         "partCount": len(parts), "fileCount": len(entries)},
        indent=2) + "\n").encode())
    state = (
        "# OpenWorld Codex — contexto listo para Argon 4\n\n"
        f"- **Repositorio:** `{REPO_NAME}`\n"
        f"- **Ref:** `{args.ref}`\n"
        f"- **Commit exacto:** `{commit}`\n"
        f"- **Archivos:** {len(entries)} | **Partes:** {len(parts)}\n"
        f"- **Ubicacion:** `revisions/{commit}/`\n"
        f"- **Manifest:** `revisions/{commit}/MANIFEST.json`\n"
        f"- **Sello de finalizacion local:** `revisions/{commit}/READY.json`\n\n"
        "**Importante:** este archivo NO confirma subida a Google Drive. "
        "Verificar con Drive para escritorio y con Gemini Web que la revision completa "
        "sea accesible y corresponda al mismo commit antes de entregar una tarea.\n"
    )
    atomic_write(args.out / "CURRENT_SYNC_STATE.md", state.encode("utf-8"))
    print(json.dumps({"commitSha": commit, "parts": len(parts),
                      "files": len(entries), "localOutput": str(revision_dir),
                      "driveUploadConfirmed": False}, indent=2))


if __name__ == "__main__":
    try:
        main()
    except Exception as ex:
        print(f"[ARGON-DRIVE-BRIDGE] ERROR: {ex}", file=sys.stderr)
        sys.exit(1)
