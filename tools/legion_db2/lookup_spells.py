import csv
import os

HERE = os.path.dirname(os.path.abspath(__file__))


def load(name):
    with open(os.path.join(HERE, name), newline="", encoding="utf-8-sig") as f:
        return list(csv.DictReader(f))


names = {int(r["ID"]): r["Name_lang"] for r in load("Spell.csv")}
need = [
    "Swipe",
    "Power Word: Shield",
    "Soothing Mist",
    "Haunt",
    "Shadow Bolt",
    "Kill Shot",
    "Flame Shock",
    "Mindbender",
    "Shadowfiend",
    "Netherwalk",
    "Bestow Faith",
    "Dire Frenzy",
    "Dire Beast",
    "Renewing Mist",
    "Drain Life",
    "Malefic Grasp",
    "Unstable Affliction",
]
rev = {}
for sid, n in names.items():
    if n in need:
        rev.setdefault(n, []).append(sid)

for n, ids in sorted(rev.items()):
    shown = ids[:15]
    extra = "..." if len(ids) > 15 else ""
    print(f"{n}: {shown}{extra}")

spec = {}
for r in load("SpecializationSpells.csv"):
    spec.setdefault(int(r["SpecID"]), set()).add(int(r["SpellID"]))
classline = {}
for r in load("SkillLineAbility.csv"):
    classline.setdefault(int(r["SkillLine"]), set()).add(int(r["Spell"]))


def where(sid):
    specs = [s for s, sp in spec.items() if sid in sp]
    lines = [l for l, sp in classline.items() if sid in sp]
    return specs, lines


checks = {
    "Swipe candidates": [779, 106785, 213764, 213771, 202028],
    "PW:S": [17],
    "Soothing Mist": [115175, 209525, 198533],
    "Renewing Mist": [115151, 119611],
    "Flame Shock": [8050, 188389],
    "Mindbender/fiend": [34433, 200174, 123040],
    "Netherwalk/Blur": [196555, 198589],
    "Kill Shot": [53351, 190928],
    "Haunt/SB": [48181, 686, 232670, 234153],
    "Bestow Faith": [223306],
    "Holy Nova": [132157],
}
print("\n--- membership ---")
for label, ids in checks.items():
    print(label)
    for sid in ids:
        n = names.get(sid, "?")
        print(f"  {sid} {n} specs={where(sid)[0]} lines={where(sid)[1]}")

# dump active-looking spells on priest class line and holy spec
print("\n--- Priest class 804 / Holy 257 containing Shield or Heal ---")
for sid in sorted(classline.get(804, set()) | spec.get(257, set())):
    n = names.get(sid, "?")
    if any(x in n for x in ("Shield", "Heal", "Renew", "Prayer", "Nova", "Serenity")):
        print(f"  {sid} {n}")

print("\n--- Druid class 798 / Guardian 104 containing Swipe/Thrash ---")
for sid in sorted(classline.get(798, set()) | spec.get(104, set())):
    n = names.get(sid, "?")
    if any(x in n for x in ("Swipe", "Thrash", "Maul", "Mangle")):
        print(f"  {sid} {n}")

print("\n--- Shaman class 924 / Enh 263 Flame/Rock ---")
for sid in sorted(classline.get(924, set()) | spec.get(263, set())):
    n = names.get(sid, "?")
    if any(x in n for x in ("Flame", "Rockbiter", "Storm", "Lava", "Crash", "Lightning")):
        print(f"  {sid} {n}")

print("\n--- Affliction 265 / Warlock 849 ---")
for sid in sorted(classline.get(849, set()) | spec.get(265, set())):
    n = names.get(sid, "?")
    if any(x in n for x in ("Bolt", "Drain", "Agony", "Corrupt", "Unstable", "Haunt", "Seed", "Life")):
        print(f"  {sid} {n}")

print("\n--- Monk 829 / MW 270 mist ---")
for sid in sorted(classline.get(829, set()) | spec.get(270, set())):
    n = names.get(sid, "?")
    if any(x in n for x in ("Mist", "Vivify", "Font", "Cocoon", "Revival", "Tea")):
        print(f"  {sid} {n}")

print("\n--- Hunter 795 / BM 253 ---")
for sid in sorted(classline.get(795, set()) | spec.get(253, set())):
    n = names.get(sid, "?")
    if any(x in n for x in ("Cobra", "Kill", "Dire", "Shot", "Beast", "Wrath", "Aspect", "Exhilar")):
        print(f"  {sid} {n}")

print("\n--- Shadow 258 ---")
for sid in sorted(classline.get(804, set()) | spec.get(258, set())):
    n = names.get(sid, "?")
    if any(x in n for x in ("Mind", "Void", "Shadow Word", "Vampiric", "Dispersion", "fiend", "bender")):
        print(f"  {sid} {n}")

print("\n--- Havoc 577 ---")
for sid in sorted(classline.get(1848, set()) | spec.get(577, set())):
    n = names.get(sid, "?")
    if any(x in n for x in ("Nether", "Blur", "Chaos", "Blade", "Eye", "Glaive", "Meta")):
        print(f"  {sid} {n}")
