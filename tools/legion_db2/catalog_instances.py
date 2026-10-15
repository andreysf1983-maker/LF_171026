"""Catalog of dungeons and raids through Legion, from the 7.3.5 client journal.

JournalInstance / JournalEncounter are the Adventure Guide the Legion client shows.
LFGDungeons supplies dungeon-vs-raid and expansion. The world database supplies
whether this server has a script name and any creature spawns.

    python tools/legion_db2/catalog_instances.py
"""

import csv
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from audit_instances import mysql, OUT

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "docs" / "quests" / "generated" / "INSTANCE-CATALOG.md"

# Journal rows that share a raid map but are world bosses or invasion points, not the raid.
SKIP_NAMES = {"Pandaria", "Draenor", "Broken Isles", "Invasion Points"}

EXPANSIONS = {
    "0": "Classic",
    "1": "The Burning Crusade",
    "2": "Wrath of the Lich King",
    "3": "Cataclysm",
    "4": "Mists of Pandaria",
    "5": "Warlords of Draenor",
    "6": "Legion",
}
INSTANCE_KIND = {"1": "dungeon", "2": "raid", "5": "scenario"}


def load(name):
    with (OUT / ("%s.csv" % name)).open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def collect():
    maps = {int(row["ID"]): row for row in load("Map")}
    journal = []
    for row in load("JournalInstance"):
        name = (row.get("F0") or "").strip()
        map_id = int(float(row.get("F6") or 0))
        if not name or not map_id or name in SKIP_NAMES:
            continue
        journal.append((int(row["ID"]), name, map_id))

    bosses = defaultdict(list)
    for row in load("JournalEncounter"):
        boss = (row.get("F0") or "").strip().strip('"')
        if not boss:
            continue
        journal_id = int(float(row.get("F6") or 0))
        order = int(float(row.get("F9") or 0))
        bosses[journal_id].append((order, boss))

    lfg_by_map = defaultdict(list)
    for row in load("LFGDungeons"):
        if row.get("TypeID") not in ("1", "2"):
            continue
        map_id = int(float(row.get("MapID") or 0))
        if map_id:
            lfg_by_map[map_id].append(row)

    templates = {}
    for line in mysql("SELECT map, script FROM instance_template").splitlines():
        if not line.strip():
            continue
        map_id, script = line.split("\t")
        templates[int(map_id)] = script
    spawns = {}
    for line in mysql("SELECT map, COUNT(*) FROM creature GROUP BY map").splitlines():
        if not line.strip():
            continue
        map_id, count = line.split("\t")
        spawns[int(map_id)] = int(count)

    grouped = defaultdict(list)
    for journal_id, name, map_id in journal:
        map_row = maps.get(map_id, {})
        kind = INSTANCE_KIND.get(map_row.get("InstanceType") or "", "")
        expansion = map_row.get("ExpansionID") or ""
        for lfg in lfg_by_map.get(map_id, []):
            if lfg.get("TypeID") == "2":
                kind = "raid"
            elif lfg.get("TypeID") == "1" and kind != "raid":
                kind = "dungeon"
            expansion = lfg.get("ExpansionLevel") or expansion
        if not kind:
            continue
        if expansion not in EXPANSIONS:
            continue
        boss_names = [boss for _order, boss in sorted(bosses.get(journal_id, []))]
        # The journal repeats a boss once per section. Keep first-seen order.
        seen = []
        for boss in boss_names:
            if boss not in seen:
                seen.append(boss)
        grouped[expansion].append({
            "name": name,
            "map": map_id,
            "kind": kind,
            "bosses": seen,
            "script": templates.get(map_id, ""),
            "spawns": spawns.get(map_id, 0),
            "in_template": map_id in templates,
        })
    return grouped


def main():
    grouped = collect()

    lines = [
        "# Dungeons and raids through Legion",
        "",
        "Built from the Legion 7.3.5 client Adventure Guide (`JournalInstance`, `JournalEncounter`) plus `LFGDungeons` and this server's `instance_template` and creature spawns.",
        "",
        "That is the same list the Legion client shows in the Dungeon Journal. Wowhead and Warcraft Wiki describe the same places in prose. The live retail site is a later expansion, so its dungeon list is a different game and is not the source for this server.",
        "",
        "A row is missing creatures when the spawn count is 0. A row is missing a script when the script column is blank or the map has no `instance_template` row. A script name in the database still needs a C++ file that the server actually loads.",
        "",
        "World bosses and invasion points are left out. They share map ids with raids in the journal and are not dungeon encounters.",
        "",
    ]
    for key in sorted(EXPANSIONS, key=int):
        rows = sorted(grouped.get(key, []), key=lambda item: (item["kind"], item["name"]))
        if not rows:
            continue
        dungeons = sum(1 for item in rows if item["kind"] == "dungeon")
        raids = sum(1 for item in rows if item["kind"] == "raid")
        lines.append("## %s (%s dungeons, %s raids)" % (EXPANSIONS[key], dungeons, raids))
        lines.append("")
        for item in rows:
            script = item["script"] or ("no template" if not item["in_template"] else "no script")
            lines.append("### %s — map %s, %s" % (item["name"], item["map"], item["kind"]))
            lines.append("")
            lines.append("Script: `%s`. Creatures spawned: %s." % (script, item["spawns"]))
            lines.append("")
            if item["bosses"]:
                for index, boss in enumerate(item["bosses"], start=1):
                    lines.append("%s. %s" % (index, boss))
            else:
                lines.append("No journal bosses.")
            lines.append("")

    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text("\n".join(lines), encoding="utf-8")
    print(REPORT)
    for key in sorted(EXPANSIONS, key=int):
        rows = grouped.get(key, [])
        empty = sum(1 for item in rows if item["spawns"] == 0)
        noscript = sum(1 for item in rows if not item["script"])
        print("%s: %s instances, %s with no script, %s with no creatures" % (
            EXPANSIONS[key], len(rows), noscript, empty))


if __name__ == "__main__":
    main()
