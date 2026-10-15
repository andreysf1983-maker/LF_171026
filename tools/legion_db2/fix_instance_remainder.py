"""Hide the 15 empty instances from the dungeon finder, and add boss-credit
rows where a spawned creature already has the encounter's name.

Does not write the database. Writes SQL under sql/stitch/.

    python tools/legion_db2/fix_instance_remainder.py
"""

import csv
import re
from collections import defaultdict
from pathlib import Path

from audit_instances import mysql

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
STITCH = ROOT / "sql" / "stitch"

# Adventure Guide instances with no creature rows in ADB 7.3.5.10.
EMPTY_MAPS = (
    996, 1001, 1007, 1098, 1136, 1208, 1448,
    1458, 1493, 1516, 1530, 1648, 1651, 1677, 1712,
)
# LFGDungeons.db2 table hash. A deleted hotfix removes the row from the finder.
LFG_HASH = 0xF02081A0


def norm(name):
    name = (name or "").lower().replace("'", "").replace("'", "")
    name = re.sub(r"[^a-z0-9]+", " ", name)
    return " ".join(name.split())


def load(name):
    with (OUT / ("%s.csv" % name)).open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def main():
    encounters = []
    for row in load("DungeonEncounter"):
        map_id = int(row["MapID"])
        if map_id in EMPTY_MAPS:
            continue
        encounters.append({
            "id": int(row["ID"]),
            "name": row["Name_lang"].strip().strip('"'),
            "map": map_id,
            "difficulty": int(row["DifficultyID"]),
        })

    lfg_rows = []
    for row in load("LFGDungeons"):
        map_id = int(float(row.get("MapID") or 0))
        if map_id not in EMPTY_MAPS:
            continue
        if row.get("TypeID") not in ("1", "2", "5"):
            continue
        lfg_rows.append((int(row["ID"]), map_id, row.get("Name_lang") or "", row.get("DifficultyID") or ""))

    present = set()
    for line in mysql("SELECT entry FROM instance_encounters").splitlines():
        if line.strip():
            present.add(int(line.strip()))

    maps = sorted({item["map"] for item in encounters})
    spawned = defaultdict(list)
    if maps:
        sql = (
            "SELECT c.map, c.id, ct.name, ct.rank, COUNT(*) "
            "FROM creature c JOIN creature_template ct ON ct.entry = c.id "
            "WHERE c.map IN (%s) GROUP BY c.map, c.id, ct.name, ct.rank"
            % ",".join(str(map_id) for map_id in maps)
        )
        for line in mysql(sql).splitlines():
            if not line.strip():
                continue
            map_id, entry, name, rank, count = line.split("\t")
            spawned[int(map_id)].append({
                "entry": int(entry),
                "name": name,
                "rank": int(rank),
                "count": int(count),
            })

    by_name = defaultdict(list)
    for map_id, rows in spawned.items():
        for row in rows:
            by_name[(map_id, norm(row["name"]))].append(row)

    credits = []
    skipped = []
    for item in encounters:
        if item["id"] in present:
            continue
        matches = by_name.get((item["map"], norm(item["name"])), [])
        bosses = [row for row in matches if row["rank"] >= 3]
        chosen = bosses or matches
        entries = {row["entry"] for row in chosen}
        if len(entries) != 1:
            skipped.append((item["map"], item["name"], len(entries)))
            continue
        credit = next(iter(entries))
        # lastEncounterDungeon stays 0. LFGDungeons.FinalEncounterID is not a
        # DungeonEncounter id, so using it would finish the wrong dungeon.
        credits.append((item["id"], credit, 0, item["name"].replace("'", "''")))

    hide_sql = [
        "-- Remove the 15 empty instances from the Dungeon Finder.",
        "-- ADB 7.3.5.10 has no creature rows for these maps. The deleted hotfix",
        "-- tells the client to drop the LFGDungeons row and the server stops offering it.",
        "-- The Adventure Guide is client JournalInstance data and is unchanged.",
        "",
    ]
    hide_rollback = [
        "-- Undo 004_hide_empty_instances.sql.",
        "",
    ]
    if lfg_rows:
        values = ",\n".join("(%s, %s, 1)" % (LFG_HASH, dungeon_id) for dungeon_id, _map, _name, _diff in lfg_rows)
        hide_sql.append("INSERT INTO `hotfix_data` (`TableHash`, `RecordId`, `Deleted`) VALUES")
        hide_sql.append(values + ";")
        hide_sql.append("")
        ids = ",".join(str(dungeon_id) for dungeon_id, _map, _name, _diff in lfg_rows)
        hide_rollback.append(
            "DELETE FROM `hotfix_data` WHERE `TableHash` = %s AND `Deleted` = 1 AND `RecordId` IN (%s);"
            % (LFG_HASH, ids)
        )
        hide_rollback.append("")

    credit_sql = [
        "-- Boss credit for encounters whose creature is already spawned under the same name.",
        "-- creditType 0 is a creature kill. Rows already present are left alone.",
        "",
    ]
    credit_rollback = [
        "-- Undo 005_instance_encounter_credits.sql.",
        "",
    ]
    if credits:
        values = ",\n".join(
            "(%s, 0, %s, %s, '%s')" % row for row in credits
        )
        ids = ",".join(str(row[0]) for row in credits)
        credit_sql.append(
            "INSERT INTO `instance_encounters` (`entry`, `creditType`, `creditEntry`, `lastEncounterDungeon`, `comment`)"
        )
        credit_sql.append("SELECT * FROM (")
        credit_sql.append("  SELECT %s AS entry, %s AS creditType, %s AS creditEntry, %s AS lastEncounterDungeon, '%s' AS comment" % (
            credits[0][0], 0, credits[0][1], credits[0][2], credits[0][3]
        ))
        for row in credits[1:]:
            credit_sql.append("  UNION ALL SELECT %s, 0, %s, %s, '%s'" % row)
        credit_sql.append(") AS proposed")
        credit_sql.append("WHERE NOT EXISTS (SELECT 1 FROM `instance_encounters` existing WHERE existing.entry = proposed.entry);")
        credit_sql.append("")
        credit_rollback.append("DELETE FROM `instance_encounters` WHERE `entry` IN (%s);" % ids)
        credit_rollback.append("")

    STITCH.mkdir(parents=True, exist_ok=True)
    (STITCH / "004_hide_empty_instances.sql").write_text("\n".join(hide_sql), encoding="utf-8")
    (STITCH / "004_hide_empty_instances_rollback.sql").write_text("\n".join(hide_rollback), encoding="utf-8")
    (STITCH / "005_instance_encounter_credits.sql").write_text("\n".join(credit_sql), encoding="utf-8")
    (STITCH / "005_instance_encounter_credits_rollback.sql").write_text("\n".join(credit_rollback), encoding="utf-8")

    print("lfg rows hidden: %s" % len(lfg_rows))
    print("encounter credits: %s" % len(credits))
    print("encounters skipped (no single spawned name): %s" % len(skipped))
    for map_id, name, count in skipped[:40]:
        print("  skip map %s %s matches=%s" % (map_id, name, count))


if __name__ == "__main__":
    main()
