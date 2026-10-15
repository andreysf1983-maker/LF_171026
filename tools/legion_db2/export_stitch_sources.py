"""D0: export the client DB2 tables the stitcher needs, then apply hotfixes.

Existing Spell/Item/Map exports are left untouched; other tools read those
headers. This script fills the gaps, overlays hotfix rows onto the CSVs,
then checks known client IDs and known hotfix rows.

    python tools/legion_db2/export_stitch_sources.py
"""

import csv
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from wdc1 import DBC_DIR, ROOT, load_metas, open_table, write_csv

OUT = Path(__file__).resolve().parent

# Section 2 of docs/systems/DB-STITCHER.md, plus the display/family/cost/title
# tables the domain maps reference.
REQUIRED = [
    "Item", "ItemSparse", "Spell", "SpellEffect", "Map", "MapDifficulty",
    "AreaTable", "WorldMapArea", "Phase", "PhaseXPhaseGroup", "LFGDungeons",
    "JournalInstance", "JournalEncounter", "DungeonEncounter", "CreatureDisplayInfo",
    "Faction", "FactionTemplate", "CriteriaTree", "Criteria", "AreaTrigger",
    "SkillLine", "SkillLineAbility", "QuestV2", "GameObjectDisplayInfo",
    "CreatureFamily", "ItemExtendedCost", "CurrencyTypes", "CharTitles",
    "TaxiNodes", "TaxiPath", "TaxiPathNode", "BroadcastText", "ArtifactAppearance", "TactKey",
]

EXPORT = [
    "AreaTable", "WorldMapArea", "Phase", "PhaseXPhaseGroup", "JournalInstance",
    "JournalEncounter", "CreatureDisplayInfo", "Faction", "FactionTemplate",
    "CriteriaTree", "Criteria", "QuestV2", "GameObjectDisplayInfo", "CreatureFamily",
    "ItemExtendedCost", "CurrencyTypes", "CharTitles",
    "TaxiNodes", "TaxiPath", "TaxiPathNode", "BroadcastText", "ArtifactAppearance", "TactKey",
]


def _ids(path):
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        if "ID" not in (reader.fieldnames or []):
            raise RuntimeError("%s has no ID column" % path.name)
        ids = []
        for row in reader:
            ids.append(int(row["ID"]))
    return ids


def export_missing():
    metas = load_metas(EXPORT)
    for name in EXPORT:
        dest = OUT / ("%s.csv" % name)
        print("export %s" % name, flush=True)
        table = open_table(name, metas)
        write_csv(table, dest)
        print("  %s rows -> %s" % (len(table.rows()), dest.name), flush=True)


def validate():
    failures = []
    for name in REQUIRED:
        db2 = DBC_DIR / ("%s.db2" % name)
        csv_path = OUT / ("%s.csv" % name)
        if not db2.is_file():
            failures.append("missing db2 %s" % name)
        if not csv_path.is_file() or csv_path.stat().st_size == 0:
            failures.append("missing csv %s" % name)
            continue
        ids = _ids(csv_path)
        if len(ids) != len(set(ids)):
            failures.append("duplicate IDs in %s" % name)
        if not ids:
            failures.append("empty %s" % name)

    display = set(_ids(OUT / "CreatureDisplayInfo.csv"))
    if 4449 not in display:
        failures.append("CreatureDisplayInfo is missing classic imp display 4449")
    if 68486 in display:
        failures.append("CreatureDisplayInfo unexpectedly contains 68486")

    areas = {}
    with (OUT / "AreaTable.csv").open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            areas[int(row["ID"])] = row.get("AreaName") or row.get("ZoneName")
    if areas.get(14) != "Durotar":
        failures.append("AreaTable 14 is %r, expected Durotar" % areas.get(14))
    if 1637 not in areas:
        failures.append("AreaTable is missing Orgrimmar (1637)")

    quests = set(_ids(OUT / "QuestV2.csv"))
    if 24626 not in quests:
        failures.append("QuestV2 is missing quest 24626")

    failures.extend(_hotfix_checks())

    if failures:
        print("FAIL")
        for item in failures:
            print(" -", item)
        return 1
    print("PASS %s tables, display 4449 present, 68486 absent, Durotar and quest 24626 resolve, hotfix rows visible" % len(REQUIRED))
    return 0


def _row(path, record_id):
    with path.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            if int(row["ID"]) == record_id:
                return row
    return None


def _hotfix_checks():
    failures = []
    phase = _row(OUT / "PhaseXPhaseGroup.csv", 10000)
    if not phase or phase.get("PhaseID") != "176" or phase.get("PhaseGroupID") != "10000":
        failures.append("PhaseXPhaseGroup 10000 is %r, expected phase 176 group 10000" % (phase,))
    zero = _row(OUT / "PhaseXPhaseGroup.csv", 0)
    if not zero or zero.get("PhaseID") != "169" or zero.get("PhaseGroupID") != "696":
        failures.append("PhaseXPhaseGroup 0 is %r, expected phase 169 group 696" % (zero,))

    spell = _row(OUT / "Spell.csv", 14313)
    if not spell or spell.get("Name_lang") != "Summon Enraged Gryphon":
        failures.append("Spell 14313 name is %r" % (None if not spell else spell.get("Name_lang")))

    effect = _row(OUT / "SpellEffect.csv", 600000)
    if not effect or effect.get("SpellID") != "14313" or effect.get("Effect") != "28":
        failures.append("SpellEffect 600000 is %r, expected spell 14313 effect 28" % (effect,))

    item = _row(OUT / "ItemSparse.csv", 138019)
    if not item or item.get("Display_lang") != "Mythic Keystone":
        failures.append("ItemSparse 138019 name is %r" % (None if not item else item.get("Display_lang")))

    trigger = _row(OUT / "AreaTrigger.csv", 3646)
    if not trigger or abs(float(trigger.get("Pos_0") or "0") - 1540.64) > 0.001 or trigger.get("ContinentID") != "489":
        failures.append("AreaTrigger 3646 is %r, expected pos 1540.64 continent 489" % (trigger,))

    misc = _row(OUT / "SpellMisc.csv", 500000)
    if not misc or misc.get("Attributes_0") != "256":
        failures.append("SpellMisc 500000 Attributes_0 is %r, expected 256" % (None if not misc else misc.get("Attributes_0")))

    if 63736 in set(_ids(OUT / "CriteriaTree.csv")):
        failures.append("CriteriaTree 63736 is still present after the hotfix delete")

    path = _row(OUT / "TaxiPath.csv", 6054)
    if not path or path.get("FromTaxiNode") != "1928" or path.get("ToTaxiNode") != "1944":
        failures.append("TaxiPath 6054 is %r, expected 1928 -> 1944" % (path,))
    if _row(OUT / "TaxiNodes.csv", 1928) is None:
        failures.append("TaxiNodes is missing node 1928")

    text = _row(OUT / "BroadcastText.csv", 1)
    if not text or text.get("Text") != "Help help!  I'm being repressed!":
        failures.append("BroadcastText 1 is %r" % (None if not text else text.get("Text")))

    tact = _row(OUT / "TactKey.csv", 58)
    if not tact or tact.get("Key1") != "209":
        failures.append("TactKey 58 Key1 is %r, expected 209" % (None if not tact else tact.get("Key1")))

    if _row(OUT / "ArtifactAppearance.csv", 0) is None:
        failures.append("ArtifactAppearance is missing hotfix id 0")
    return failures


if __name__ == "__main__":
    export_missing()
    from overlay_hotfixes import apply_overlay
    apply_overlay()
    sys.exit(validate())
