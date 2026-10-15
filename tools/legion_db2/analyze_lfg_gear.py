"""Summarize Legion 7.3.5 LFG sizes, raid difficulties, and mount riding gates."""
import csv
import os
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))


def load(name):
    with open(os.path.join(HERE, name), newline="", encoding="utf-8-sig") as f:
        return list(csv.DictReader(f))


print("=== Difficulty.db2 (official raid/dungeon sizes) ===")
for r in load("Difficulty.csv"):
    print(
        f"  id={r['ID']:>2} {r['Name_lang']:<22} inst={r['InstanceType']} "
        f"min={r['MinPlayers']:>2} max={r['MaxPlayers']:>2}"
    )

print("\n=== LFGDungeons by TypeID / Expansion ===")
# TypeID: 1 dungeon, 2 raid, 5 heroic, 6 random
type_names = {1: "DUNGEON", 2: "RAID", 5: "HEROIC", 6: "RANDOM"}
by_exp = defaultdict(lambda: defaultdict(int))
role_samples = []
for r in load("LFGDungeons.csv"):
    tid = int(r["TypeID"])
    exp = int(r["ExpansionLevel"])
    by_exp[exp][tid] += 1
    if int(r["MapID"]) >= 1456 or "Emerald Nightmare" in r["Name_lang"] or "Tomb of Sargeras" in r["Name_lang"] or "Antorus" in r["Name_lang"] or "Nighthold" in r["Name_lang"] or "Trial of Valor" in r["Name_lang"]:
        role_samples.append(r)

print("Expansion -> type counts:")
for exp in sorted(by_exp):
    parts = [f"{type_names.get(t, t)}={c}" for t, c in sorted(by_exp[exp].items())]
    print(f"  exp {exp}: {', '.join(parts)}")

print("\n=== Legion raid/dungeon LFG rows (name, map, diff, type, tanks/heals/dps, minlvl) ===")
for r in sorted(role_samples, key=lambda x: (int(x["MapID"]), int(x["DifficultyID"]), x["Name_lang"])):
    print(
        f"  {r['ID']:>4} map={r['MapID']:>4} diff={r['DifficultyID']:>2} type={r['TypeID']} "
        f"roles={r['Count_tank']}/{r['Count_healer']}/{r['Count_damage']} "
        f"lvl={r['MinLevel']}-{r['MaxLevel']} {r['Name_lang'][:50]}"
    )

print("\n=== Role composition by TypeID (unique patterns) ===")
patterns = defaultdict(int)
for r in load("LFGDungeons.csv"):
    key = (int(r["TypeID"]), r["Count_tank"], r["Count_healer"], r["Count_damage"], r["Min_count_tank"], r["Min_count_healer"])
    patterns[key] += 1
for k, c in sorted(patterns.items(), key=lambda x: -x[1]):
    print(f"  type={k[0]} count {k[1]}/{k[2]}/{k[3]} min {k[4]}/{k[5]}  ({c} entries)")

print("\n=== MapDifficulty MaxPlayers for a few Legion raids ===")
watch = {1520: "EN", 1530: "NH", 1648: "ToV", 1676: "ToS", 1712: "Antorus", 1669: "Argus", 409: "MC", 631: "ICC", 720: "FL"}
md = defaultdict(list)
for r in load("MapDifficulty.csv"):
    mid = int(r["MapID"])
    if mid in watch:
        md[mid].append((int(r["DifficultyID"]), int(r["MaxPlayers"] or 0)))
for mid, name in watch.items():
    print(f"  {mid} {name}: {sorted(md.get(mid, []))}")

print("\n=== Mount types (first 15 unique MountTypeID) ===")
types = defaultdict(int)
for r in load("Mount.csv"):
    types[int(r["MountTypeID"])] += 1
print("  type counts:", dict(sorted(types.items())))
