#!/usr/bin/env python3
"""Build lfg_dungeon_template rows for every 7.3.5 dungeon/raid LFG slot.

Priority per map:
  1. Lowest-ID in-map AreaTrigger (usually the entrance volume)
  2. Published instance start (LegionForge game_tele / well-known raid breach)
WorldSafeLocs and areatrigger_teleport still fill leftovers at worldserver load.
"""
from __future__ import annotations

import csv
import os

HERE = os.path.dirname(os.path.abspath(__file__))
SQL_OUT = os.path.normpath(os.path.join(HERE, "..", "..", "sql", "09_lfg_dungeon_entrances.sql"))

# Maps with no in-map AreaTrigger. Coords are inside the instance, not the world portal.
# Source: LEGIONFORGE issue #25574 game_tele + common raid-breach starts.
MAP_STARTS = {
    1448: (3948.050000, -1394.730000, 8.750000, 2.040000),  # Hellfire Citadel
    1456: (-3917.170000, 4543.340000, 87.321100, 5.833490),  # Eye of Azshara
    1458: (2964.950000, 1298.220000, -10.000000, 3.800000),  # Neltharion's Lair
    1466: (3231.440000, 1827.230000, 233.304000, 3.339880),  # Darkheart Thicket
    1477: (3191.970000, 2899.360000, 639.659000, 2.130330),  # Halls of Valor
    1492: (7146.920000, 7323.320000, 13.791000, 6.070210),  # Maw of Souls
    1493: (4184.470000, -761.060000, 269.521000, 1.568610),  # Vault of the Wardens
    1501: (3501.550000, 7647.830000, -7.680250, 3.264480),  # Black Rook Hold
    1516: (3522.290000, 4804.850000, 590.072000, 3.143320),  # The Arcway
    1520: (1835.040000, 1405.570000, 363.912000, 5.067470),  # Emerald Nightmare
    1530: (465.436000, 3376.460000, 44.761300, 3.212280),  # The Nighthold
    1544: (4674.160000, 4013.730000, 91.750000, 3.140000),  # Assault on Violet Hold
    1571: (1054.000000, 3529.000000, 3.878870, 5.180850),  # Court of Stars
    1648: (3610.120000, 5604.600000, 38.793200, 2.328700),  # Trial of Valor
    1651: (-11034.200000, -2006.400000, 176.600000, 0.610000),  # Return to Karazhan
    1676: (6541.970000, -787.175000, 1508.690000, 6.260590),  # Tomb of Sargeras
    1677: (-700.783000, 2529.790000, 332.085000, 6.248780),  # Cathedral of Eternal Night
    1712: (-3416.060000, 9527.610000, 8.803240, 0.219028),  # Antorus
    1753: (5401.200000, 10819.900000, 20.422300, 5.299250),  # Seat of the Triumvirate
}


def load(name):
    with open(os.path.join(HERE, name), newline="", encoding="utf-8-sig") as f:
        return list(csv.DictReader(f))


def main():
    ats_by_map = {}
    for row in load("AreaTrigger.csv"):
        mid = int(row["ContinentID"])
        if mid <= 1:
            continue
        ats_by_map.setdefault(mid, []).append(
            (
                int(row["ID"]),
                float(row["Pos_0"]),
                float(row["Pos_1"]),
                float(row["Pos_2"]),
            )
        )
    for mid in ats_by_map:
        ats_by_map[mid].sort()

    maps = {int(r["ID"]): r["MapName_lang"] for r in load("Map.csv")}
    rows = []
    missing_playable = []
    skipped = []
    seen_maps = set()
    for r in load("LFGDungeons.csv"):
        did = int(r["ID"])
        mid = int(r["MapID"] or 0)
        typ = int(r["TypeID"] or 0)
        sid = int(r["ScenarioID"] or 0)
        name = (r["Name_lang"] or "").replace("'", "''")
        if mid <= 0:
            continue

        source = ""
        if mid in ats_by_map:
            atid, x, y, z = ats_by_map[mid][0]
            o = 0.0
            source = f"AT {atid}"
        elif mid in MAP_STARTS:
            x, y, z, o = MAP_STARTS[mid]
            source = "map start"
        else:
            if typ in (1, 2, 5) and sid == 0:
                missing_playable.append((did, mid, name))
            else:
                skipped.append((did, mid, name))
            continue

        rows.append((did, name, x, y, z, o, mid, source))
        seen_maps.add(mid)

    with open(SQL_OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("-- LFG entrance coords for 7.3.5.25996 dungeon/raid slots.\n")
        f.write("-- Applied by setup.bat / play.bat. INSERT IGNORE so host overrides stay.\n")
        f.write("INSERT IGNORE INTO `lfg_dungeon_template`\n")
        f.write("  (`dungeonId`, `name`, `position_x`, `position_y`, `position_z`, `orientation`, `requiredItemLevel`, `VerifiedBuild`)\n")
        f.write("VALUES\n")
        for i, (did, name, x, y, z, o, mid, source) in enumerate(rows):
            comma = "," if i + 1 < len(rows) else ";"
            f.write(
                f"  ({did}, '{name}', {x:.6f}, {y:.6f}, {z:.6f}, {o:.6f}, 0, 25996){comma} -- map {mid} {source}\n"
            )
        f.write(f"\n-- {len(rows)} LFG slots covered, {len(seen_maps)} unique maps.\n")
        if missing_playable:
            f.write(f"-- Playable dungeon/raid still without a baked start ({len(missing_playable)}):\n")
            f.write("-- worldserver fills these from areatrigger_teleport / WorldSafeLocs at load.\n")
            for did, mid, name in missing_playable:
                mname = maps.get(mid, "?")
                f.write(f"--   LFG {did} map {mid} ({mname}) {name}\n")
        if skipped:
            f.write(f"-- Skipped {len(skipped)} scenario / test / continent LFG rows (not party LFG).\n")

    print(f"Wrote {SQL_OUT}")
    print(f"  {len(rows)} entrances, {len(missing_playable)} playable leftover, {len(skipped)} skipped")


if __name__ == "__main__":
    main()
