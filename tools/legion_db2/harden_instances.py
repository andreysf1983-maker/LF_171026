"""Check that every dungeon and raid through Legion has a script the server loads.

A database script name counts only when an uncommented AddSC function constructs
that InstanceMapScript for the same map. Creature counts of zero stay open:
the world database has no coordinates for those maps, and this pass does not
invent them.

    python tools/legion_db2/harden_instances.py
"""

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from audit_instances import SCRIPTS, mysql
from catalog_instances import EXPANSIONS, collect

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "docs" / "quests" / "generated" / "INSTANCE-HARDENING.md"

CALL_RE = re.compile(r"^AddSC_(\w+)\(\);")
DEF_RE = re.compile(r"^void (AddSC_\w+)\(")
QUOTED = re.compile(r'InstanceMapScript\(\s*"([^"]+)"\s*,\s*(\d+)\s*\)')
MACRO_CTOR = re.compile(r"InstanceMapScript\(\s*(\w+)\s*,\s*(\d+)\s*\)")
REGISTER = re.compile(r"RegisterInstanceScript\(\s*(\w+)\s*,\s*(\d+)\s*\)")
DEFINE = re.compile(r'#define\s+(\w+)\s+"([^"]+)"')
INCLUDE = re.compile(r'#include\s+"([^"]+)"')
SHELL = re.compile(r'\{\s*"([^"]+)"\s*,\s*(\d+)\s*,\s*(\d+)\s*\}')


def header_index():
    index = {}
    for path in SCRIPTS.rglob("*.h"):
        index.setdefault(path.name, []).append(path)
    return index


def resolve_header(include, source, index):
    name = Path(include).name
    candidates = index.get(name, [])
    suffix = include.replace("\\", "/")
    for candidate in candidates:
        if candidate.parent == source.parent:
            return candidate
    for candidate in candidates:
        if str(candidate).replace("\\", "/").endswith(suffix):
            return candidate
    if len(candidates) == 1:
        return candidates[0]
    return None


def file_defines(path, index, seen=None):
    if seen is None:
        seen = set()
    path = path.resolve()
    if path in seen or not path.exists():
        return {}
    seen.add(path)
    defines = {}
    for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.strip()
        if line.startswith("//"):
            continue
        match = DEFINE.search(line)
        if match:
            defines[match.group(1)] = match.group(2)
        included = INCLUDE.search(line)
        if not included or not included.group(1).endswith(".h"):
            continue
        header = resolve_header(included.group(1), path, index)
        if header:
            defines.update(file_defines(header, index, seen))
    return defines


def live_registrations():
    """A script name is live when its cpp file's AddSC function is called.

    The InstanceMapScript constructor usually sits on the class, and AddSC is
    the function the loader calls. If that call is commented out, the name is
    not live even though the string is still in the file. Script-name macros
    are resolved from the headers that cpp includes, because the same macro
    name is reused with a different string in different dungeons.
    """
    called = set()
    for path in SCRIPTS.rglob("*.cpp"):
        for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
            line = raw.strip()
            if line.startswith("//"):
                continue
            match = CALL_RE.match(line)
            if match:
                called.add("AddSC_" + match.group(1))

    headers = header_index()
    registered = {}
    shells = {}
    for path in SCRIPTS.rglob("*.cpp"):
        defined = set()
        lines = []
        for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
            line = raw.strip()
            if line.startswith("//"):
                continue
            lines.append(line)
            match = DEF_RE.match(line)
            if match:
                defined.add(match.group(1))
        if not (defined & called):
            continue
        defines = file_defines(path, headers)
        for line in lines:
            for match in QUOTED.finditer(line):
                registered[match.group(1)] = int(match.group(2))
            for match in MACRO_CTOR.finditer(line):
                name = defines.get(match.group(1))
                if name:
                    registered[name] = int(match.group(2))
            for match in REGISTER.finditer(line):
                name = defines.get(match.group(1), match.group(1))
                registered[name] = int(match.group(2))
            for match in SHELL.finditer(line):
                shells[match.group(1)] = (int(match.group(2)), int(match.group(3)))
                registered[match.group(1)] = int(match.group(2))
    return registered, shells


def encounter_counts():
    present = set()
    for line in mysql("SELECT entry FROM instance_encounters").splitlines():
        if line.strip():
            present.add(int(line.strip()))
    counts = {}
    path = Path(__file__).resolve().parent / "DungeonEncounter.csv"
    import csv
    with path.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            if int(row["ID"]) not in present:
                continue
            map_id = int(row["MapID"])
            counts[map_id] = counts.get(map_id, 0) + 1
    return counts


def main():
    registered, shells = live_registrations()
    encounters = encounter_counts()
    grouped = collect()

    script_fail = []
    map_mismatch = []
    boss_mismatch = []
    empty = []
    shell_with_spawns = []
    ok = []

    for key in sorted(EXPANSIONS, key=int):
        for item in grouped.get(key, []):
            label = "%s — map %s (%s)" % (item["name"], item["map"], EXPANSIONS[key])
            script = item["script"]
            bound = registered.get(script)
            if not script or bound is None:
                script_fail.append((label, script or "(blank)"))
                continue
            if bound != item["map"]:
                map_mismatch.append((label, script, bound))
                continue
            shell = shells.get(script)
            if shell and shell[1] != len(item["bosses"]):
                boss_mismatch.append((label, shell[1], len(item["bosses"])))
            if item["spawns"] == 0:
                empty.append((label, script, encounters.get(item["map"], 0)))
            elif shell:
                shell_with_spawns.append((label, script, item["spawns"], encounters.get(item["map"], 0)))
            else:
                ok.append((label, script, item["spawns"], encounters.get(item["map"], 0)))

    lines = [
        "# Instance hardening",
        "",
        "Checked after the journal shells were registered and the blank MoP and WoD script names were filled.",
        "A script passes when the database name is constructed by an `AddSC` function the loader actually calls, on the same map id.",
        "",
        "Script failures: %s. Map mismatches: %s. Shell boss-count mismatches: %s." % (
            len(script_fail), len(map_mismatch), len(boss_mismatch)),
        "Loaded scripts with spawns: %s, of which %s are shells (boss abilities still unwritten)." % (
            len(ok) + len(shell_with_spawns), len(shell_with_spawns)),
        "Loaded scripts with no creature rows: %s. Those maps stay empty. Spawn coordinates are not in the world database and were not invented." % len(empty),
        "",
    ]

    def section(title, rows):
        lines.append("## %s" % title)
        lines.append("")
        if not rows:
            lines.append("None.")
            lines.append("")
            return
        for row in rows:
            lines.append("- " + " — ".join(str(part) for part in row))
        lines.append("")

    section("Script not loaded", script_fail)
    section("Script registered for a different map", map_mismatch)
    section("Shell boss count does not match the journal", boss_mismatch)
    section("Shell loaded, creatures already spawned", shell_with_spawns)
    section("Script loaded, no creatures in the database", empty)
    section("Script loaded from an existing C++ file", ok)

    lines.extend([
        "## Still open",
        "",
        "The empty maps can take a script now, and several maps that already had creatures can load an instance script. Neither of those is a filled Adventure Guide encounter. Boss spell scripts, doors, and creature positions for the empty maps are still missing. The number at the end of each loaded row is how many `instance_encounters` credit rows exist for that map. The new shells have none, so a boss kill still does not complete the dungeon until those credit rows exist.",
        "",
        "Commented boss files for Neltharion's Lair, Vault of the Wardens, Violet Hold, and most of Eye of Azshara were left commented. Their `AddSC` bodies are empty, so loading them does not create the fight.",
        "",
        "## Next step",
        "",
        "After this dungeon and raid pass, the next stitch is encounters that are not inside a dungeon or raid, and the transitions between the open world and an instance and back. That pass is per level, per quest, and per area: a quest step or area that pulls the player into an instance, the moment they come back out, and the fight that never changes map.",
        "",
    ])

    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text("\n".join(lines), encoding="utf-8")
    print(REPORT)
    print("fail %s mismatch %s boss %s empty %s shell %s ok %s" % (
        len(script_fail), len(map_mismatch), len(boss_mismatch), len(empty), len(shell_with_spawns), len(ok)))
    if script_fail or map_mismatch or boss_mismatch:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
