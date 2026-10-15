"""Scenario maps and the quests that use them.

Dungeons (InstanceType 1) and raids (InstanceType 2) are skipped. A scenario
map cannot be created until instance_template has a row for it.

    python tools/legion_db2/catalog_quest_instances.py
"""

import csv
from collections import defaultdict
from pathlib import Path

from audit_instances import mysql

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
REPORT = ROOT / "docs" / "quests" / "generated" / "QUEST-INSTANCES.md"
SQL = ROOT / "sql" / "stitch" / "009_scenario_instance_templates.sql"
ROLLBACK = ROOT / "sql" / "stitch" / "009_scenario_instance_templates_rollback.sql"


def junk(name):
    text = name.lower()
    return any(token in text for token in ("unused", "delete", "development", "zzold", " test"))


def load_scenarios():
    scenarios = {}
    with (OUT / "Map.csv").open(newline="", encoding="utf-8-sig") as handle:
        for row in csv.DictReader(handle):
            if row.get("InstanceType") != "5":
                continue
            map_id = int(row["ID"])
            name = (row.get("MapName_lang") or "").strip()
            scenarios[map_id] = name
    return scenarios


def main():
    scenarios = load_scenarios()
    templates = set()
    for line in mysql("SELECT map FROM instance_template").splitlines():
        if line.strip():
            templates.add(int(line.split("\t")[0]))
    spawns = {}
    for line in mysql("SELECT map, COUNT(*) FROM creature GROUP BY map").splitlines():
        if not line.strip():
            continue
        map_id, count = line.split("\t")
        spawns[int(map_id)] = int(count)

    quests_by_map = defaultdict(set)
    maps_by_quest = defaultdict(set)
    titles = {}
    quest_sql = (
        "SELECT DISTINCT qo.QuestID, REPLACE(REPLACE(qt.LogTitle, '\\t', ' '), '\\n', ' '), c.map "
        "FROM quest_objectives qo "
        "JOIN quest_template qt ON qt.ID = qo.QuestID "
        "JOIN creature c ON c.id = qo.ObjectID "
        "WHERE qo.Type = 0"
    )
    for line in mysql(quest_sql).splitlines():
        if not line.strip():
            continue
        quest_id, title, map_id = line.split("\t")
        quest_id = int(quest_id)
        map_id = int(map_id)
        titles[quest_id] = title
        quests_by_map[map_id].add(quest_id)
        maps_by_quest[quest_id].add(map_id)

    real = {map_id: name for map_id, name in scenarios.items() if name and not junk(name)}
    missing = sorted(map_id for map_id in real if map_id not in templates)
    with_creatures = [map_id for map_id in missing if spawns.get(map_id, 0)]
    empty = [map_id for map_id in missing if not spawns.get(map_id, 0)]
    already = sorted(map_id for map_id in real if map_id in templates)

    scenario_only = []
    for quest_id, maps in maps_by_quest.items():
        if maps and all(map_id in scenarios for map_id in maps):
            scenario_only.append(quest_id)

    lines = [
        "# Quest instances",
        "",
        "Scenarios only. Dungeons and raids are not in this list. A scenario map does not load until `instance_template` has its row.",
        "",
        "Client scenario maps: %s. Named and not marked unused: %s. Already have a template: %s. Template added by `sql/stitch/009_scenario_instance_templates.sql`: %s, of which %s already have creatures."
        % (len(scenarios), len(real), len(already), len(missing), len(with_creatures)),
        "",
        "Kill-credit quests whose creatures spawn only on scenario maps: %s." % len(scenario_only),
        "",
        "## Template added, creatures already spawned",
        "",
    ]
    if with_creatures:
        for map_id in with_creatures:
            lines.append("- %s %s — %s creatures — %s quests" % (
                map_id, real[map_id], spawns.get(map_id, 0), len(quests_by_map.get(map_id, ()))))
    else:
        lines.append("None.")
    lines.extend(["", "## Template added, no creatures yet", ""])
    if empty:
        for map_id in empty:
            lines.append("- %s %s — %s quests point at a creature that also exists here" % (
                map_id, real[map_id], len(quests_by_map.get(map_id, ()))))
    else:
        lines.append("None.")
    lines.extend(["", "## Already had a template", ""])
    for map_id in already:
        lines.append("- %s %s — %s creatures — %s quests" % (
            map_id, real[map_id], spawns.get(map_id, 0), len(quests_by_map.get(map_id, ()))))
    lines.extend(["", "## Quests whose kills are only inside a scenario", ""])
    if scenario_only:
        for quest_id in sorted(scenario_only):
            map_names = ", ".join("%s %s" % (map_id, scenarios.get(map_id, "")) for map_id in sorted(maps_by_quest[quest_id]))
            lines.append("- %s %s — %s" % (quest_id, titles.get(quest_id, ""), map_names))
    else:
        lines.append("None.")
    lines.append("")
    REPORT.write_text("\n".join(lines), encoding="utf-8")

    id_list = ", ".join(str(map_id) for map_id in missing)
    SQL.write_text(
        "-- Let scenario maps load. Dungeons and raids are not included.\n"
        "-- parent 0 matches the scenario rows already in instance_template.\n"
        "-- A blank script does not invent boss AI. Maps with no creature rows stay empty.\n\n"
        "INSERT INTO `instance_template` (`map`, `parent`, `script`, `allowMount`, `insideResurrection`)\n"
        "SELECT * FROM (\n  SELECT %s AS map, 0 AS parent, '' AS script, 0 AS allowMount, 0 AS insideResurrection\n"
        % missing[0] + "".join(
            "\n  UNION ALL SELECT %s, 0, '', 0, 0" % map_id for map_id in missing[1:]
        ) + "\n) AS `rows`\n"
        "WHERE NOT EXISTS (SELECT 1 FROM `instance_template` AS `existing` WHERE `existing`.`map` = `rows`.`map`);\n",
        encoding="utf-8",
    )
    ROLLBACK.write_text(
        "-- Undo 009_scenario_instance_templates.sql.\n\n"
        "DELETE FROM `instance_template` WHERE `map` IN (%s) AND `script` = '';\n" % id_list,
        encoding="utf-8",
    )
    print("scenarios", len(real), "missing", len(missing), "with creatures", len(with_creatures), "quest-only", len(scenario_only))


if __name__ == "__main__":
    main()
