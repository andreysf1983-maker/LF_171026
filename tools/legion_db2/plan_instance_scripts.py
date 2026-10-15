"""Propose instance_template script corrections from compiled InstanceMapScript map ids.

Prints SQL only. Does not write to the database.
"""

import csv
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from audit_instances import mysql, script_registry, OUT

names, bound, _texts = script_registry()

by_map = {}
conflicts = []
for name, (map_id, path) in sorted(bound.items()):
    if map_id in by_map and by_map[map_id][0] != name:
        conflicts.append((map_id, by_map[map_id][0], name))
    else:
        by_map[map_id] = (name, path.name)

raw = mysql("SELECT map, parent, script FROM instance_template ORDER BY map")
templates = {}
for line in raw.splitlines():
    if not line.strip():
        continue
    map_id, parent, script = line.split("\t")
    templates[int(map_id)] = (int(parent), script)

map_names = {}
with (OUT / "Map.csv").open(newline="", encoding="utf-8") as handle:
    for row in csv.DictReader(handle):
        map_names[int(row["ID"])] = row.get("MapName_lang") or row.get("Directory") or ""

print("CONFLICTS %s" % len(conflicts))
for row in conflicts:
    print("  two scripts for map %s: %s and %s" % row)

print("MOVE script off the wrong map")
for map_id, (parent, script) in sorted(templates.items()):
    if not script or script not in bound:
        continue
    right = bound[script][0]
    if right == map_id:
        continue
    right_script = templates.get(right, (None, None))[1]
    compiled_here = by_map.get(map_id, (None,))[0]
    print("  map %s %r has %s, compiled for %s %r (that map script=%r, compiled-for-here=%r)" % (
        map_id, map_names.get(map_id, "?"), script, right, map_names.get(right, "?"), right_script, compiled_here))

print("ATTACH compiled script onto its own map")
for map_id, (name, filename) in sorted(by_map.items()):
    if map_id not in templates:
        print("  NO ROW map %s %r script %s (%s)" % (map_id, map_names.get(map_id, "?"), name, filename))
        continue
    current = templates[map_id][1]
    if current == name:
        continue
    if current and current in bound and bound[current][0] == map_id:
        print("  KEEP map %s already has %s, also compiled %s" % (map_id, current, name))
        continue
    print("  SET map %s %r %r -> %s (%s)" % (map_id, map_names.get(map_id, "?"), current, name, filename))

spells = mysql("SELECT spell_id, ScriptName FROM spell_script_names WHERE ScriptName='spell_gen_dungeon_credit' ORDER BY spell_id")
have = set()
with (OUT / "Spell.csv").open(newline="", encoding="utf-8") as handle:
    for row in csv.DictReader(handle):
        have.add(int(row["ID"]))
print("DUNGEON CREDIT")
for line in spells.splitlines():
    if not line.strip():
        continue
    spell_id, script_name = line.split("\t")
    print("  %s %s in client=%s" % (spell_id, script_name, int(spell_id) in have))
