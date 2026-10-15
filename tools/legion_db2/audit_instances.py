"""Read-only instance path: client catalog vs world DB vs compiled scripts.

    python tools/legion_db2/audit_instances.py
"""

import csv
import re
import subprocess
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
MYSQL = Path(r"C:\Program Files\MySQL\MySQL Server 26.7\bin\mysql.exe")
CNF = ROOT / "setup_tmp" / "mysql.cnf"
SCRIPTS = ROOT / "core" / "src" / "server" / "scripts"
REPORT = ROOT / "docs" / "quests" / "generated" / "INSTANCE-PATH.md"

# Map.db2 InstanceType: dungeon, raid, scenario. Battlegrounds are a separate layer.
INSTANCE_TYPES = {"1": "dungeon", "2": "raid", "5": "scenario"}
LFG_TYPES = {"1": "dungeon", "2": "raid", "5": "heroic"}


def mysql(sql):
    proc = subprocess.run(
        [str(MYSQL), "--defaults-extra-file=%s" % CNF, "-N", "-B", "world", "-e", sql],
        capture_output=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.decode("utf-8", errors="replace").strip() or "mysql failed")
    return proc.stdout.decode("utf-8", errors="replace")


def load_ids(name, key="ID"):
    path = OUT / ("%s.csv" % name)
    ids = set()
    with path.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            ids.add(int(row[key]))
    return ids


def load_rows(name):
    path = OUT / ("%s.csv" % name)
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def sections(raw):
    current = None
    buckets = defaultdict(list)
    for line in raw.splitlines():
        if line.startswith("@@"):
            current = line[2:]
            continue
        if current and line.strip():
            buckets[current].append(line.split("\t"))
    return buckets


def _script_files():
    return list(SCRIPTS.rglob("*.cpp")) + list(SCRIPTS.rglob("*.h"))


def script_registry():
    """Names live in headers as #define WCScriptName "instance_wailing_caverns"."""
    names = set()
    defines = {}
    texts = {}
    for path in _script_files():
        text = path.read_text(encoding="utf-8", errors="replace")
        texts[path] = text
        for name in re.findall(r'"(instance_[^"]+)"', text):
            names.add(name)
        for symbol, name in re.findall(r'#define\s+(\w+)\s+"([^"]+)"', text):
            defines[symbol] = name
            names.add(name)
        for symbol, name in re.findall(r'(?:char const\*|const char\*)\s+(\w+)\s*=\s*"([^"]+)"', text):
            defines[symbol] = name
            names.add(name)
    bound = {}
    for path, text in texts.items():
        if path.suffix != ".cpp":
            continue
        for name, map_id in re.findall(r'InstanceMapScript\(\s*"([^"]+)"\s*,\s*(\d+)', text):
            bound[name] = (int(map_id), path)
        for symbol, map_id in re.findall(r"InstanceMapScript\(\s*(\w+)\s*,\s*(\d+)", text):
            name = defines.get(symbol)
            if name:
                bound[name] = (int(map_id), path)
    return names, bound, texts


def bullet(rows, limit=40):
    lines = []
    for row in rows[:limit]:
        lines.append("- %s" % row)
    extra = len(rows) - limit
    if extra > 0:
        lines.append("- … %s more" % extra)
    return lines


def main():
    raw = mysql(
        "SELECT '@@TEMPLATE'; SELECT map, parent, script FROM instance_template; "
        "SELECT '@@LFG'; SELECT dungeonId, position_x, position_y, position_z FROM lfg_dungeon_template; "
        "SELECT '@@REWARD'; SELECT dungeonId, firstQuestId, otherQuestId FROM lfg_dungeon_rewards; "
        "SELECT '@@ACCESS'; SELECT mapid, difficulty, item, item2, quest_done_A, quest_done_H, completed_achievement FROM access_requirement; "
        "SELECT '@@AT'; SELECT ID, PortLocID FROM areatrigger_teleport; "
        "SELECT '@@ENC'; SELECT entry, creditType, creditEntry, lastEncounterDungeon FROM instance_encounters; "
        "SELECT '@@SPELL'; SELECT spell_id, ScriptName FROM spell_script_names WHERE ScriptName LIKE '%dungeon%' OR ScriptName LIKE '%instance%'; "
        "SELECT '@@QUESTS'; SELECT ID FROM quest_template; "
        "SELECT '@@CREATURES'; SELECT entry, ScriptName FROM creature_template; "
        "SELECT '@@SPAWN'; SELECT map, COUNT(*) FROM creature GROUP BY map;"
    )
    data = sections(raw)
    names, bound, script_texts = script_registry()

    maps = {}
    for row in load_rows("Map"):
        maps[int(row["ID"])] = row
    lfg = {}
    for row in load_rows("LFGDungeons"):
        lfg[int(row["ID"])] = row
    area_ids = load_ids("AreaTrigger")
    difficulties = defaultdict(set)
    for row in load_rows("MapDifficulty"):
        difficulties[int(row["MapID"])].add(int(row["DifficultyID"]))
    encounters = {}
    for row in load_rows("DungeonEncounter"):
        encounters[int(row["ID"])] = row
    spell_ids = load_ids("Spell")

    import sys
    sys.path.insert(0, str(OUT))
    from wdc1 import load_metas, open_table
    safe_rows = open_table("WorldSafeLocs", load_metas(["WorldSafeLocs"])).rows()
    safe = {rid: values for rid, values in safe_rows}
    # ID, AreaName, LocX, LocY, LocZ, Facing, MapID
    safe_map = {rid: int(values[6]) for rid, values in safe.items()}
    safe_on_map = set(safe_map.values())
    trigger_on_map = set()
    for row in load_rows("AreaTrigger"):
        trigger_on_map.add(int(float(row.get("ContinentID") or 0)))

    templates = {}
    for map_id, parent, script in ((int(r[0]), int(r[1]), r[2]) for r in data["TEMPLATE"]):
        templates[map_id] = (parent, script)

    instance_maps = {mid: row for mid, row in maps.items() if row.get("InstanceType") in INSTANCE_TYPES}
    quests = {int(r[0]) for r in data["QUESTS"]}
    items = load_ids("ItemSparse")
    creatures = {int(r[0]): r[1] for r in data["CREATURES"]}
    spawns = {int(r[0]): int(r[1]) for r in data["SPAWN"]}

    missing_template = []
    for mid, row in sorted(instance_maps.items()):
        if mid not in templates:
            missing_template.append("%s %s (%s)" % (mid, row.get("MapName_lang") or row.get("Directory"), INSTANCE_TYPES[row["InstanceType"]]))

    bad_template_map = []
    empty_script = []
    missing_script = []
    script_map_mismatch = []
    for mid, (parent, script) in sorted(templates.items()):
        row = maps.get(mid)
        if row is None:
            bad_template_map.append("map %s is not in the client Map list" % mid)
            continue
        if row.get("InstanceType") not in INSTANCE_TYPES and row.get("InstanceType") not in ("3", "4"):
            bad_template_map.append("map %s %s InstanceType %s" % (mid, row.get("MapName_lang"), row.get("InstanceType")))
        if parent and parent not in maps:
            bad_template_map.append("map %s parent %s is not a client map" % (mid, parent))
        if not script:
            empty_script.append("%s %s" % (mid, row.get("MapName_lang") or mid))
            continue
        if script not in names:
            missing_script.append("%s %s script %s" % (mid, row.get("MapName_lang") or mid, script))
        elif script in bound and bound[script][0] != mid:
            script_map_mismatch.append("%s db map %s, C++ map %s (%s)" % (script, mid, bound[script][0], bound[script][1].name))

    lfg_rows = {int(r[0]): (r[1], r[2], r[3]) for r in data["LFG"]}
    wrong_lfg = []
    no_entrance = []
    at_rows = []
    for rec in data["AT"]:
        at_rows.append((int(rec[0]), int(rec[1])))
    entrance_maps = set()
    missing_at = []
    missing_port = []
    for trigger_id, port_id in at_rows:
        if trigger_id > 0 and trigger_id not in area_ids:
            missing_at.append(trigger_id)
        if port_id not in safe_map:
            missing_port.append((trigger_id, port_id))
        else:
            entrance_maps.add(safe_map[port_id])

    for dungeon_id, coords in sorted(lfg_rows.items()):
        if dungeon_id not in lfg:
            wrong_lfg.append(dungeon_id)
            continue
        row = lfg[dungeon_id]
        if row.get("TypeID") not in LFG_TYPES:
            continue
        x, y, z = coords
        if float(x) == 0 and float(y) == 0 and float(z) == 0:
            map_id = int(row.get("MapID") or 0)
            if map_id and map_id not in entrance_maps and map_id not in safe_on_map and map_id not in trigger_on_map:
                no_entrance.append("%s %s map %s" % (dungeon_id, row.get("Name_lang"), map_id))

    # LFG dungeons the client knows that have no server entrance row and no teleport onto their map.
    client_lfg_gap = []
    for dungeon_id, row in sorted(lfg.items()):
        if row.get("TypeID") not in LFG_TYPES:
            continue
        map_id = int(row.get("MapID") or 0)
        if not map_id:
            continue
        coords = lfg_rows.get(dungeon_id)
        if coords and not (float(coords[0]) == 0 and float(coords[1]) == 0 and float(coords[2]) == 0):
            continue
        # The server also accepts a safe location or an area trigger inside the map.
        if map_id in entrance_maps or map_id in safe_on_map or map_id in trigger_on_map:
            continue
        client_lfg_gap.append("%s %s map %s" % (dungeon_id, row.get("Name_lang"), map_id))

    bad_access = []
    for rec in data["ACCESS"]:
        map_id, difficulty, item, item2, quest_a, quest_h, achievement = (int(x) for x in rec[:7])
        if map_id not in maps:
            bad_access.append("map %s does not exist" % map_id)
        elif difficulty not in difficulties.get(map_id, ()):
            bad_access.append("map %s has no difficulty %s" % (map_id, difficulty))
        if item and item not in items:
            bad_access.append("map %s key item %s is not in the client item list" % (map_id, item))
        if item2 and item2 not in items:
            bad_access.append("map %s key item2 %s is not in the client item list" % (map_id, item2))
        if quest_a and quest_a not in quests:
            bad_access.append("map %s alliance quest %s is not in quest_template" % (map_id, quest_a))
        if quest_h and quest_h not in quests:
            bad_access.append("map %s horde quest %s is not in quest_template" % (map_id, quest_h))

    bad_encounter = []
    credit_missing = []
    no_spawn = []
    seen_final = {}
    for entry, credit_type, credit_entry, final_id in (
        (int(r[0]), int(r[1]), int(r[2]), int(r[3])) for r in data["ENC"]
    ):
        enc = encounters.get(entry)
        if enc is None:
            bad_encounter.append("encounter %s is not in client DungeonEncounter" % entry)
            continue
        if final_id and final_id not in lfg:
            bad_encounter.append("encounter %s final dungeon %s is not an LFG dungeon" % (entry, final_id))
        if final_id:
            if final_id in seen_final:
                bad_encounter.append("dungeon %s has two final encounters %s and %s" % (final_id, seen_final[final_id], entry))
            else:
                seen_final[final_id] = entry
        map_id = int(enc.get("MapID") or 0)
        if credit_type == 0:
            if credit_entry not in creatures:
                credit_missing.append("encounter %s creature %s missing" % (entry, credit_entry))
            elif spawns.get(map_id, 0) and credit_entry not in creatures:
                pass
        elif credit_type == 1:
            if credit_entry not in spell_ids:
                credit_missing.append("encounter %s spell %s missing" % (entry, credit_entry))
        else:
            bad_encounter.append("encounter %s credit type %s" % (entry, credit_type))

    # Static boss spawns: one grouped query for credit creatures.
    credit_ids = sorted({
        int(r[2]) for r in data["ENC"] if int(r[1]) == 0 and int(r[2]) in creatures
    })
    spawn_on = defaultdict(set)
    if credit_ids:
        chunk = 400
        for start in range(0, len(credit_ids), chunk):
            ids = ",".join(str(i) for i in credit_ids[start:start + chunk])
            for rec in mysql("SELECT id, map FROM creature WHERE id IN (%s) GROUP BY id, map" % ids).splitlines():
                if not rec.strip():
                    continue
                cid, cmap = rec.split("\t")
                spawn_on[int(cid)].add(int(cmap))
    for entry, credit_type, credit_entry, _final in (
        (int(r[0]), int(r[1]), int(r[2]), int(r[3])) for r in data["ENC"]
    ):
        if credit_type != 0 or credit_entry not in creatures:
            continue
        enc = encounters.get(entry)
        if not enc:
            continue
        map_id = int(enc.get("MapID") or 0)
        if map_id not in spawn_on.get(credit_entry, ()):
            no_spawn.append("encounter %s %s creature %s not spawned on map %s" % (
                entry, enc.get("Name_lang"), credit_entry, map_id))

    boss_script_missing = []
    quoted_scripts = set()
    for text in script_texts.values():
        quoted_scripts.update(re.findall(r'"([^"]+)"', text))
    seen_boss = set()
    for entry, credit_type, credit_entry, _final in (
        (int(r[0]), int(r[1]), int(r[2]), int(r[3])) for r in data["ENC"]
    ):
        if credit_type != 0:
            continue
        script = creatures.get(credit_entry, "")
        if not script or script in quoted_scripts or (credit_entry, script) in seen_boss:
            continue
        seen_boss.add((credit_entry, script))
        boss_script_missing.append("creature %s script %s" % (credit_entry, script))

    empty_instances = []
    for mid, row in sorted(instance_maps.items()):
        if mid in templates and spawns.get(mid, 0) == 0:
            empty_instances.append("%s %s" % (mid, row.get("MapName_lang") or row.get("Directory")))

    dungeon_credit = [r for r in data["SPELL"] if "dungeon_credit" in r[1] or r[0] == "58630"]
    credit_spell_missing = []
    for spell_id, script_name in data["SPELL"]:
        if int(spell_id) not in spell_ids:
            credit_spell_missing.append("spell %s script %s is not in the client spell list" % (spell_id, script_name))

    lines = []
    def add(title, rows, meaning):
        lines.append("## %s (%s)" % (title, len(rows)))
        lines.append("")
        lines.append(meaning)
        lines.append("")
        lines.extend(bullet(rows))
        lines.append("")

    lines.append("# Instance path")
    lines.append("")
    lines.append("Read-only. Client files plus the world database plus compiled script names. Nothing was written to the server.")
    lines.append("")
    lines.append("Client instance maps: %s. Server instance_template rows: %s. Compiled instance script names: %s." % (
        len(instance_maps), len(templates), len([n for n in names if n.startswith("instance_")])))
    lines.append("")
    lines.append("These are separate breaks. A fix for one pattern does not repair the others. Inside a single pattern, the same kind of edit repeats, but each dungeon still has its own map, script name, and bosses.")
    lines.append("")

    add("Missing instance template", missing_template,
        "The client says this map is a dungeon, raid, or scenario, and the server has no instance_template row.")
    add("Template points at a bad map or parent", bad_template_map,
        "instance_template names a map or parent the client Map list does not have, or the map is not an instance.")
    add("Instance has no script name", empty_script,
        "The template row exists and the script column is blank. Doors, bosses, and lockouts for that map have no script to run.")
    add("Script name has no C++ script", missing_script,
        "The database names a script the core never registers. This is the mogu'shan vault pattern. Each name is a different script, so one new file does not cover the list.")
    add("Script is compiled for a different map", script_map_mismatch,
        "The name exists in C++, and the map id in that file is not the database map.")
    add("LFG row is not a client dungeon", [str(i) for i in wrong_lfg],
        "lfg_dungeon_template.dungeonId is not in LFGDungeons. The server logs this as coordinates for the wrong dungeon.")
    add("LFG dungeon has no entrance", no_entrance,
        "The server row has position 0,0,0 and no areatrigger teleport lands on that map.")
    add("Client LFG dungeon with no server entrance", client_lfg_gap,
        "The client dungeon is not in lfg_dungeon_template and nothing teleports onto its map.")
    add("Teleport trigger is not in the client", [str(i) for i in sorted(set(missing_at))],
        "areatrigger_teleport.ID is not in AreaTrigger. The client cannot fire that entrance.")
    add("Teleport destination is not in WorldSafeLocs", ["trigger %s port %s" % pair for pair in missing_port[:]],
        "PortLocID is not in the client safe-location list, so the teleport has nowhere to send the player.")
    add("Access requirement is wrong", bad_access,
        "The key, quest, map, or difficulty on access_requirement does not exist. The server drops that requirement at startup.")
    add("Encounter row does not match the client", bad_encounter,
        "instance_encounters.entry is not a client DungeonEncounter, the final-dungeon id is wrong, or two rows claim the same final boss.")
    add("Encounter credit does not exist", credit_missing,
        "The kill creature is not in creature_template, or the credit spell is not in the client spell list.")
    add("Encounter creature has no static spawn on its map", no_spawn,
        "The creature exists, and no creature row stands on the encounter map. Some of these are summoned by a script. An instance whose script is also missing cannot summon them either.")
    add("Encounter creature script is not compiled", boss_script_missing,
        "creature_template.ScriptName for an encounter credit is not registered in core/src/server/scripts.")
    add("Instance map has no creature spawns", empty_instances,
        "The map is an instance in the client and in instance_template, and the creature table has zero rows on it.")
    add("Dungeon spell script points at a missing spell", credit_spell_missing,
        "spell_script_names names a spell the client does not have. spell_gen_dungeon_credit on 58630 is this pattern.")

    if dungeon_credit:
        lines.append("Dungeon-credit bindings seen: %s." % ", ".join("%s=%s" % (a, b) for a, b in dungeon_credit))
        lines.append("")

    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text("\n".join(lines), encoding="utf-8")
    print(REPORT)
    for line in lines:
        if line.startswith("## ") or line.startswith("Client ") or line.startswith("These "):
            print(line)


if __name__ == "__main__":
    main()
