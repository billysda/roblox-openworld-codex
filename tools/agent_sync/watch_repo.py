#!/usr/bin/env python3
"""Observa cambios de GitHub por SHA; nunca sincroniza ni altera Roblox Studio.

Uso (desde cualquier ruta dentro del checkout):
  python tools/agent_sync/watch_repo.py --once
  python tools/agent_sync/watch_repo.py --watch --interval 120
  python tools/agent_sync/watch_repo.py --ack origin/main --sha <40-char-GIT-SHA>

Crea estado LOCAL bajo .git/agent_sync/ (NO se publica).
--ack es confirmación HUMANA/AGENTE de que se LEYÓ el código completo.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import subprocess
import sys
import time

HERE = Path(__file__).resolve()
ROOT = HERE.parents[2]
EXPECTED_REPO = "billysda/roblox-openworld-codex"

def git(*args, check=True):
    proc = subprocess.run(["git", *args], cwd=ROOT, capture_output=True,
                          text=True, encoding="utf-8", errors="replace")
    if check and proc.returncode:
        raise RuntimeError(f"git {' '.join(args)} -> {proc.returncode}: {proc.stderr.strip()}")
    return proc.stdout.strip()

def repo_state_dir():
    p = Path(git("rev-parse", "--absolute-git-dir")) / "agent_sync"
    p.mkdir(exist_ok=True, parents=True)
    return p

def read_json(path):
    if not path.is_file():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))

def write_json_atomic(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(value, indent=2, ensure_ascii=False, sort_keys=True)+"\n", encoding="utf-8")
    tmp.replace(path)

def verify_repo():
    top = Path(git("rev-parse", "--show-toplevel")).resolve()
    if top != ROOT:
        raise RuntimeError(f"Script fuera del checkout: {top} != {ROOT}")
    remote = git("remote", "get-url", "origin")
    if EXPECTED_REPO.lower() not in remote.lower():
        raise RuntimeError(f"Remoto no autorizado: {remote} (esperado {EXPECTED_REPO})")

def remote_refs():
    output = git("for-each-ref", "--format=%(refname:short) %(objectname)", "refs/remotes/origin")
    found = {}
    for line in output.splitlines():
        parts = line.split(" ", 1)
        if len(parts) == 2 and re.fullmatch(r"[a-f0-9]{40}", parts[1]):
            if parts[0] != "origin/HEAD":
                found[parts[0]] = parts[1]
    return dict(sorted(found.items()))

def changed_paths(before, after, ref):
    if before and before != after:
        base = before
    elif not before and ref != "origin/main":
        base = git("merge-base", "origin/main", after, check=False) or None
    else:
        base = None
    if not base:
        return [], []
    diff = git("diff", "--name-status", base, after)
    logs = git("log", "--format=%H %s", "--no-decorate", f"{base}..{after}")
    return diff.splitlines() if diff else [], logs.splitlines() if logs else []

def scan(fetch=True):
    verify_repo()
    if fetch:
        print("[AGENT_SYNC] Fetching GitHub remote...", flush=True)
        git("fetch", "origin", "--prune")
    path = repo_state_dir()
    seen = read_json(path / "reviewed.json")
    refs = remote_refs()
    current = {}
    for name, sha in refs.items():
        old = seen.get(name)
        if old != sha:
            files, commits = changed_paths(old, sha, name)
            current[name] = {
                "lastReviewedSha": old,
                "currentHeadSha": sha,
                "changedPathsFull": files,
                "newCommits": commits,
                "firstObservation": old is None,
                "mustReadFullCodeAndDiff": True,
            }
    payload = {
        "generatedAtUtc": datetime.now(timezone.utc).isoformat(),
        "repository": EXPECTED_REPO,
        "currentHeads": refs,
        "pendingReview": current,
        "localDirtyState": git("status", "--porcelain"),
        "instruction": "No hacer --ack hasta leer Source y diff completos; no hacer auto-deploy en Studio.",
    }
    write_json_atomic(path / "pending.json", payload)
    print(json.dumps({
        "time":payload["generatedAtUtc"], "pendingRefs":len(current),
        "pending":{k:{"previous":v["lastReviewedSha"],"head":v["currentHeadSha"],
                       "changedPaths":len(v["changedPathsFull"]),
                       "newCommits":len(v["newCommits"])} for k,v in current.items()},
        "pendingFile":str(path / "pending.json"),
        "dirty":bool(payload["localDirtyState"])
    }, ensure_ascii=False, indent=2), flush=True)

def ack(ref, sha):
    verify_repo()
    if not re.fullmatch(r"[a-f0-9]{40}", sha):
        raise ValueError("SHA inválido")
    heads = remote_refs()
    if heads.get(ref) != sha:
        raise ValueError(f"{ref} ya cambió de SHA (ahora {heads.get(ref)}). Actualizar y revisar.")
    path = repo_state_dir() / "reviewed.json"
    data = read_json(path)
    data[ref] = sha
    write_json_atomic(path, data)
    print(f"[AGENT_SYNC] ACK de lectura para {ref}@{sha}; no implica integración en Studio.")

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--once", action="store_true")
    p.add_argument("--watch", action="store_true")
    p.add_argument("--interval", type=int, default=120)
    p.add_argument("--ack", metavar="REF", help="p.ej. origin/main")
    p.add_argument("--sha", help="SHA exacto leído, obligatorio para --ack")
    args = p.parse_args()
    if args.ack:
        if not args.sha:
            p.error("--ack requiere --sha")
        ack(args.ack, args.sha)
        return
    if args.sha:
        p.error("--sha requiere --ack")
    if args.watch:
        if args.interval < 30:
            p.error("Intervalo mínimo 30 segundos")
        while True:
            try:
                scan()
            except Exception as exc:
                print(f"[AGENT_SYNC] ERROR: {exc}", file=sys.stderr, flush=True)
            time.sleep(args.interval)
    else:
        scan()

if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"[AGENT_SYNC] ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
