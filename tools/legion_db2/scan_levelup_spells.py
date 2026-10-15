#!/usr/bin/env python3
"""Scan Legion DB2 dumps for level-up double-learn and warlock pet clues."""
from __future__ import annotations

import csv
import os
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))


def load(name: str):
    with open(os.path.join(HERE, name), newline="", encoding="utf-8-sig") as f:
        return list(csv.DictReader(f))


def main():
    levels = {int(r["SpellID"]): int(r["SpellLevel"] or 0) for r in load("SpellLevels.csv")}
    names = {int(r["ID"]): r.get("Name_lang", "") for r in load("Spell.csv")}
    spec = load("SpecializationSpells.csv")
    chr_spec = {int(r["ID"]): int(r["ClassID"]) for r in load("ChrSpecialization.csv")}
    sla = load("SkillLineAbility.csv")

    class_mask = {1: 1, 2: 2, 3: 4, 4: 8, 5: 16, 6: 32, 7: 64, 8: 128, 9: 256, 10: 512, 11: 1024, 12: 2048}
    sla_by: dict[int, set[int]] = defaultdict(set)
    for r in sla:
        cm = int(r.get("ClassMask") or 0)
        for cid, m in class_mask.items():
            if cm & m:
                sla_by[cid].add(int(r["Spell"]))

    print("=== Summon Imp / warlock pets ===")
    for sid in (688, 691, 697, 712, 30146, 112866, 137706, 111771):
        print(f"  {sid} {names.get(sid)} SpellLevel={levels.get(sid)}")

    print("\n=== Spec+SkillLine overlaps SpellLevel 2-12 (hotbar spam candidates) ===")
    hits = []
    for r in spec:
        sid = int(r["SpellID"])
        cid = chr_spec.get(int(r["SpecID"]))
        lvl = levels.get(sid, 0)
        if cid and 2 <= lvl <= 12 and sid in sla_by[cid]:
            hits.append((cid, int(r["SpecID"]), lvl, sid, names.get(sid), r["OverridesSpellID"]))
    for row in sorted(hits):
        print("  class=%s spec=%s L%s %s %s overrides=%s" % row)
    print("total overlaps L2-12:", len(hits))

    print("\n=== Spec overrides L2-20 (old+new both on bar risk) ===")
    for r in spec:
        sid = int(r["SpellID"])
        ov = int(r["OverridesSpellID"] or 0)
        lvl = levels.get(sid, 0)
        if ov and 2 <= lvl <= 20:
            cid = chr_spec.get(int(r["SpecID"]))
            print(f"  class={cid} L{lvl} {sid} {names.get(sid)} overrides {ov} {names.get(ov)}")


if __name__ == "__main__":
    main()
