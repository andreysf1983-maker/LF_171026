"""Resolve the encounters that did not match a spawned creature name exactly.

Writes sql/stitch/006_instance_encounter_credits_rest.sql.
A row is added only when one creature is that boss: the same name, the name
before a comma title, or the single boss_* script for that name.
Council fights, dev dummies, and bosses with no creature stay listed and are
not given a guessed credit.
"""

import re
from collections import defaultdict

from fix_instance_remainder import EMPTY_MAPS, load, mysql, norm

BAD = ("trigger", "dummy", "bunny", "image", "visual", "christmas", "tap list", "controller", "pre")
# Journal spelling differs from the creature template by one letter or an m.
TYPO = {
    "chalgra razorflank": "charlga razorflank",
    "salram the fleshcrafter": "salramm the fleshcrafter",
}
# One encounter, several bosses. No single kill credit.
COUNCIL = {
    "faction champions",
    "the four horsemen",
    "the stone guard",
    "will of the emperor",
    "the spirit kings",
    "trial of the king",
    "hans gar franzok",
    "the iron maidens",
    "twin ogron",
    "ancient protectors",
    "dragons of nightmare",
    "demonic inquisition",
    "sisters of the moon",
    "grimrail enforcers",
    "grand champions",
    "skarvold dalronn",
    "the soultakers",
}
DEV = {
    "ken s test encounter dnt",
    "raid boss dummy 5min",
    "raid boss dummy 10min",
    "timed damage dummy",
}


def leading(name):
    return norm(name.split(",")[0])


def drop_the(name):
    return " ".join(token for token in name.split() if token != "the")


# Creature entries named by the instance script headers.
OVERRIDE = {
    1299: 56173,    # Madness of Deathwing
    1756: 83846,    # Yalnu
    1864: 103769,   # Xavius
    1870: 104218,   # Advisor Melandrus, the level 112 combatant
    1873: 105393,   # Il'gynoth
    1876: 106087,   # Elerethe Renferal
    1877: 104636,   # Cenarius in the Emerald Nightmare
    1909: 18667,    # Blackheart the Inciter
    1914: 20912,    # Harbinger Skyriss
    1919: 17881,    # Aeonus
    1920: 17879,    # Chrono Lord Deja
    1921: 17880,    # Temporus
    2000: 36658,    # Scourgelord Tyrannus
    2002: 26529,    # Meathook
    2003: 26532,    # Chrono-Lord Epoch
    2004: 26530,    # Salramm the Fleshcrafter
    2010: 26731,    # Grand Magus Telestra
    2021: 35451,    # The Black Knight
    2037: 115767,   # Mistress Sassz'ine
    2051: 117269,   # Kil'jaeden in the Tomb of Sargeras
}


def clean_script(script):
    script = script or ""
    if script.startswith("boss_") and "illusion" not in script and not script.endswith("_pre") and "prop" not in script:
        return script
    return ""


def main():
    present = set()
    for line in mysql("SELECT entry FROM instance_encounters").splitlines():
        if line.strip():
            present.add(int(line.strip()))

    missing = []
    for row in load("DungeonEncounter"):
        map_id = int(row["MapID"])
        if map_id in EMPTY_MAPS or int(row["ID"]) in present:
            continue
        missing.append({
            "id": int(row["ID"]),
            "name": row["Name_lang"].strip().strip('"'),
            "map": map_id,
        })

    templates = []
    sql = "SELECT entry, name, `rank`, minlevel, HealthModifier, IFNULL(ScriptName,'') FROM creature_template WHERE name <> ''"
    for line in mysql(sql).splitlines():
        if not line.strip():
            continue
        entry, name, rank, level, health, script = line.split("\t")
        if "(1)" in name or "(4)" in name or "(5)" in name or "(6)" in name or "(7)" in name:
            continue
        templates.append({
            "entry": int(entry),
            "name": name,
            "norm": norm(name),
            "rank": int(rank),
            "level": int(level),
            "health": float(health),
            "script": clean_script(script),
        })
    by_norm = defaultdict(list)
    for row in templates:
        by_norm[row["norm"]].append(row)

    spawned = set()
    map_ids = sorted({item["map"] for item in missing})
    if map_ids:
        spawn_sql = "SELECT map, id FROM creature WHERE map IN (%s) GROUP BY map, id" % ",".join(str(map_id) for map_id in map_ids)
        for line in mysql(spawn_sql).splitlines():
            if line.strip():
                map_id, entry = line.split("\t")
                spawned.add((int(map_id), int(entry)))

    credits = []
    council = []
    dev = []
    unresolved = []

    for item in missing:
        key = norm(item["name"])
        lead = leading(item["name"])
        if key in DEV:
            dev.append(item)
            continue
        if key in COUNCIL or lead in COUNCIL:
            council.append(item)
            continue
        wanted = TYPO.get(key, key)
        wanted_lead = TYPO.get(lead, lead)
        if item["id"] in OVERRIDE:
            chosen = next(row for row in templates if row["entry"] == OVERRIDE[item["id"]])
            credits.append((item["id"], chosen["entry"], item["name"].replace("'", "''"), chosen["name"].replace("'", "''")))
            continue
        pool = []
        for row in templates:
            creature = row["norm"]
            if any(bad in creature.split() for bad in ("trigger", "dummy", "bunny", "image", "visual", "christmas")):
                continue
            same = creature in (wanted, wanted_lead) or drop_the(creature) == drop_the(wanted)
            titled = wanted_lead.startswith(creature + " ") and len(creature) >= 6
            if same or titled:
                pool.append(row)
        # Prefer the closest name, then a boss script, then boss rank.
        if pool:
            best_len = max(len(row["norm"]) for row in pool)
            pool = [row for row in pool if len(row["norm"]) == best_len]
        if any(row["entry"] < 200000 for row in pool):
            pool = [row for row in pool if row["entry"] < 200000]
        if any(row["level"] > 1 for row in pool):
            pool = [row for row in pool if row["level"] > 1]
        on_map = [row for row in pool if (item["map"], row["entry"]) in spawned]
        if on_map:
            pool = on_map
        if pool:
            top = max(row["health"] for row in pool)
            if top >= 10:
                pool = [row for row in pool if row["health"] * 10 >= top]
        scripted = [row for row in pool if row["script"]]
        if len({row["entry"] for row in scripted}) == 1:
            chosen = scripted[0]
        else:
            bosses = [row for row in pool if row["rank"] >= 3]
            if len({row["entry"] for row in bosses}) == 1:
                chosen = bosses[0]
            elif len({row["entry"] for row in pool}) == 1:
                chosen = pool[0]
            else:
                chosen = None
        if not chosen:
            unresolved.append((item, sorted({(row["entry"], row["name"], row["script"] or row["rank"]) for row in pool})[:6]))
            continue
        credits.append((item["id"], chosen["entry"], item["name"].replace("'", "''"), chosen["name"].replace("'", "''")))

    lines = [
        "-- Boss credit for encounters whose creature name is the boss name plus a title,",
        "-- or whose creature_template carries the single boss script for that name.",
        "-- Council fights and developer dummy encounters are listed below and are not given a kill credit.",
        "",
    ]
    rollback = ["-- Undo 006_instance_encounter_credits_rest.sql.", ""]
    if credits:
        lines.append("INSERT INTO `instance_encounters` (`entry`, `creditType`, `creditEntry`, `lastEncounterDungeon`, `comment`)")
        lines.append("SELECT * FROM (")
        first = credits[0]
        lines.append("  SELECT %s AS entry, 0 AS creditType, %s AS creditEntry, 0 AS lastEncounterDungeon, '%s' AS comment" % (first[0], first[1], first[2]))
        for row in credits[1:]:
            lines.append("  UNION ALL SELECT %s, 0, %s, 0, '%s'" % (row[0], row[1], row[2]))
        lines.append(") AS proposed")
        lines.append("WHERE NOT EXISTS (SELECT 1 FROM `instance_encounters` existing WHERE existing.entry = proposed.entry);")
        lines.append("")
        rollback.append("DELETE FROM `instance_encounters` WHERE `entry` IN (%s);" % ",".join(str(row[0]) for row in credits))
        rollback.append("")
    lines.append("-- Council or multi-boss encounters. One kill is not the whole encounter:")
    for item in council:
        lines.append("-- %s map %s %s" % (item["id"], item["map"], item["name"]))
    lines.append("-- Developer placeholder encounters:")
    for item in dev:
        lines.append("-- %s map %s %s" % (item["id"], item["map"], item["name"]))
    lines.append("-- No single creature:")
    for item, pool in unresolved:
        lines.append("-- %s map %s %s candidates %s" % (item["id"], item["map"], item["name"], pool))

    from pathlib import Path
    root = Path(__file__).resolve().parents[2]
    (root / "sql" / "stitch" / "006_instance_encounter_credits_rest.sql").write_text("\n".join(lines) + "\n", encoding="utf-8")
    (root / "sql" / "stitch" / "006_instance_encounter_credits_rest_rollback.sql").write_text("\n".join(rollback) + "\n", encoding="utf-8")
    print("credits %s council %s dev %s unresolved %s" % (len(credits), len(council), len(dev), len(unresolved)))
    for row in credits:
        print("  credit %s -> %s %s" % (row[0], row[1], row[3]))
    print("--- unresolved ---")
    for item, pool in unresolved:
        print("  %s map %s %s %s" % (item["id"], item["map"], item["name"], pool))


if __name__ == "__main__":
    main()
