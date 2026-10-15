#!/usr/bin/env python3
"""Print a Legion play session as a timeline.

Usage:
  python tools/telemetry/story.py
  python tools/telemetry/story.py server/logs/runs/<runId>
  python tools/telemetry/story.py --session s-1-1-1710000000
"""

import json
import sys
from pathlib import Path


def repo_root():
    return Path(__file__).resolve().parents[2]


def runs_root():
    for candidate in (repo_root() / "server" / "logs" / "runs", repo_root() / "logs" / "runs"):
        if candidate.is_dir():
            return candidate
    return repo_root() / "server" / "logs" / "runs"


def latest_run():
    root = runs_root()
    runs = [p for p in root.iterdir() if p.is_dir()] if root.is_dir() else []
    if not runs:
        return None
    return max(runs, key=lambda p: p.stat().st_mtime)


def load_jsonl(path):
    rows = []
    if not path.is_file():
        return rows
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            rows.append(json.loads(line))
        except json.JSONDecodeError:
            rows.append({"ts": "", "cat": "parse", "evt": "bad_line", "data": {"raw": line[:180]}})
    return rows


def fmt(event):
    where = ""
    if "map" in event:
        zone = event.get("zone", "")
        where = " map={0}".format(event.get("map"))
        if zone != "":
            where += " zone={0}".format(zone)
    who = ""
    if event.get("charName"):
        who = " {0}".format(event["charName"])
    obj = event.get("obj") or {}
    target = ""
    if obj.get("name") or obj.get("entry"):
        target = " -> {0} ({1})".format(obj.get("name", ""), obj.get("entry", ""))
    data = event.get("data") or {}
    extra = ""
    if data:
        parts = []
        for key in sorted(data):
            parts.append("{0}={1}".format(key, data[key]))
        extra = " " + " ".join(parts)
    return "{ts}  {cat}.{evt}{who}{where}{target}{extra}".format(
        ts=event.get("ts", ""),
        cat=event.get("cat", "?"),
        evt=event.get("evt", "?"),
        who=who,
        where=where,
        target=target,
        extra=extra,
    )


def main(argv):
    session_filter = None
    run_dir = None
    args = argv[1:]
    i = 0
    while i < len(args):
        if args[i] == "--session" and i + 1 < len(args):
            session_filter = args[i + 1]
            i += 2
            continue
        run_dir = Path(args[i])
        if not run_dir.is_absolute():
            run_dir = repo_root() / run_dir
        i += 1

    if run_dir is None:
        run_dir = latest_run()
    if run_dir is None or not run_dir.is_dir():
        print("No run folder yet. Start with play.bat after rebuilding worldserver.")
        print("Expected: {0}".format(runs_root()))
        return 1

    print("run {0}".format(run_dir.name))
    process = []
    for event in load_jsonl(run_dir / "events.jsonl"):
        if event.get("cat") in ("launcher", "client", "server") or not event.get("sess"):
            if event.get("cat") in ("launcher", "client", "server"):
                process.append(event)
    if process:
        print("-- process --")
        for event in process:
            print(fmt(event))

    sessions = sorted((run_dir / "sessions").glob("*/events.jsonl")) if (run_dir / "sessions").is_dir() else []
    if session_filter:
        sessions = [p for p in sessions if p.parent.name == session_filter]
    if not sessions:
        print("No character session in this run yet.")
        return 0

    for path in sessions:
        print("-- session {0} --".format(path.parent.name))
        for event in load_jsonl(path):
            print(fmt(event))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
