#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""LEGIONFORGE 7.3.5 - аудит рас и форм превращений по ДАННЫМ КЛИЕНТА.

Зачем. Сервер не хранит модели и внешность: он читает те же DB2-файлы, что и клиент
(server/data/dbc/<locale>/*.db2, см. DB2Stores.cpp: db2Path = dataPath + "dbc/").
Поэтому вопрос "есть ли в моём клиенте Харанир/Вульперы/Механогномы и друид-формы
из новых дополнений" решается только по файлам клиента. Этот скрипт читает их тем же
парсером, которым пользуется DB-stitcher проекта (wdc1.py + метаданные ядра), и пишет
отчёт logs/race_form_audit.md.

Запуск:
    python tools/legion_db2/audit_races_forms.py
    python tools/legion_db2/audit_races_forms.py --dbc-dir "D:\\WoW_Client\\Data\\dbc\\enUS"
    python tools/legion_db2/audit_races_forms.py --check-metadata   # без файлов клиента

Что проверяется:
  * ChrRaces.db2        - какие ID рас знает клиент (и их имена);
  * CharSections.db2    - есть ли компоненты внешности для каждой расы;
  * CharStartOutfit.db2 - есть ли стартовая экипировка раса/класс/пол;
  * SpellShapeshiftForm.db2 - какие формы превращений (в т.ч. друидские) есть и
                          существуют ли их CreatureDisplayID в CreatureDisplayInfo.db2.
Вывод по расам >= 31: таких рас в 7.3.5 (build 26124) не существует - они появились
в 8.3/9.x. Если они всё же найдены, значит клиент не 26124 или DB2 подменены.
"""

import argparse
import sys
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import wdc1  # noqa: E402
from wdc1 import DBC_DIR, ROOT, load_metas, open_table  # noqa: E402

TABLES = ["ChrRaces", "CharSections", "CharStartOutfit", "SpellShapeshiftForm", "CreatureDisplayInfo"]

RACE_GROUPS = {
    "core (Vanilla-Cata)": list(range(1, 12)),
    "Worgen": [22],
    "Pandaren": [24, 25, 26],
    "Legion allied races": [27, 28, 29, 30],
}
ALLIED = {27: "Nightborne", 28: "Highmountain Tauren", 29: "Void Elf", 30: "Lightforged Draenei"}


def _rows(table):
    header = list(table.header())
    out = []
    for rid, values in table.rows():
        row = dict(zip(header, values))
        row["__id"] = rid
        out.append(row)
    return header, out


def _int(row, name):
    value = row.get(name)
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _text(row, name):
    value = row.get(name)
    if value is None:
        return ""
    return str(value).strip()


def audit(dbc_dir):
    dbc_dir = Path(dbc_dir)
    report = []
    add = report.append

    add("# LEGIONFORGE: аудит рас и форм по данным клиента")
    add("")
    add("Каталог DB2: `%s`" % dbc_dir)
    add("")

    missing = [t for t in TABLES if not (dbc_dir / ("%s.db2" % t)).exists()]
    if missing:
        add("## ОШИБКА: не найдены файлы")
        add("")
        for name in missing:
            add("- `%s.db2`" % name)
        add("")
        add("Скопируйте DB2 из клиента (или выполните `extract_maps.bat`): server\\data\\dbc\\<locale>\\*.db2")
        return "\n".join(report), 1

    metas = load_metas(TABLES)
    # open_table() берёт путь из wdc1.DBC_DIR, поэтому для --dbc-dir подменяем его.
    original = wdc1.DBC_DIR
    wdc1.DBC_DIR = dbc_dir
    try:
        data = {name: _rows(open_table(name, metas)) for name in TABLES}
    finally:
        wdc1.DBC_DIR = original

    # ---- races ----
    header, races = data["ChrRaces"]
    add("## 1. Расы в ChrRaces.db2")
    add("")
    add("Всего строк: %d" % len(races))
    add("")
    add("| ID | Имя | Флаги | MaleDisplayId | Группа |")
    add("|---|---|---|---|---|")
    ids = set()
    newer = []
    for row in sorted(races, key=lambda r: (_int(r, "ID") or 0)):
        rid = _int(row, "ID")
        if rid is None:
            continue
        ids.add(rid)
        group = "другое"
        for label, members in RACE_GROUPS.items():
            if rid in members:
                group = label
                break
        if rid >= 31:
            group = "НОВОЕ ДОПОЛНЕНИЕ (8.3/9.x)"
            newer.append((rid, _text(row, "Name")))
        add("| %d | %s | %s | %s | %s |" % (
            rid, _text(row, "Name"), _text(row, "Flags"), _text(row, "MaleDisplayId"), group))
    add("")
    for label, members in RACE_GROUPS.items():
        present = [m for m in members if m in ids]
        add("- %s: %s" % (label, sorted(present) if present else "НЕТ"))
    add("")
    if newer:
        add("### Найдены расы ID >= 31")
        add("")
        for rid, name in newer:
            add("- %d %s" % (rid, name))
        add("")
        add("В 7.3.5 build 26124 таких рас нет. Значит клиент новее 26124 или DB2 заменены;")
        add("с этим сервером такой клиент не соединится (протокол 7.3.5).")
    else:
        add("Рас с ID >= 31 нет: клиент соответствует 7.3.5 (Haranir/Vulpera/Mechagnome отсутствуют).")
    add("")

    # ---- customization coverage ----
    _, sections = data["CharSections"]
    _, outfits = data["CharStartOutfit"]
    sec_by_race = defaultdict(int)
    for row in sections:
        rid = _int(row, "RaceID")
        if rid is not None:
            sec_by_race[rid] += 1
    out_by_race = defaultdict(int)
    for row in outfits:
        rid = _int(row, "RaceID")
        if rid is not None:
            out_by_race[rid] += 1

    add("## 2. Готовность рас к созданию персонажа (данные клиента)")
    add("")
    add("| ID расы | CharSections | CharStartOutfit | Вывод |")
    add("|---|---|---|---|")
    interesting = sorted(set(list(RACE_GROUPS["Legion allied races"]) + [22, 24, 25, 26]) | ids)
    for rid in interesting:
        if rid not in ids:
            continue
        sec = sec_by_race.get(rid, 0)
        out = out_by_race.get(rid, 0)
        verdict = "готово" if sec and out else ("нет стартового набора" if not out else "нет компонентов внешности")
        label = ALLIED.get(rid, "")
        add("| %d %s | %d | %d | %s |" % (rid, label, sec, out, verdict))
    add("")
    add("Серверная сторона для рас 27-30 уже есть в ADB_735.10 (стартовые зоны Suramar/Highmountain,")
    add("player_levelstats, стартовый маунт). Включается патчами `sql/48_legion_allied_races.sql`")
    add("и `sql/49_legion_allied_races_hotbar.sql` + одна строка ядра (docs/FEATURE-AUDIT.md).")
    add("")

    # ---- shapeshift forms ----
    fheader, forms = data["SpellShapeshiftForm"]
    _, displays = data["CreatureDisplayInfo"]
    display_ids = {_int(row, "ID") for row in displays}
    add("## 3. Формы превращений (в т.ч. друидские) в SpellShapeshiftForm.db2")
    add("")
    add("Всего форм: %d; записей CreatureDisplayInfo: %d" % (len(forms), len(displays)))
    add("")
    add("| ID | Название | CreatureDisplayID | Есть в CreatureDisplayInfo |")
    add("|---|---|---|---|")
    broken = 0
    for row in sorted(forms, key=lambda r: (_int(r, "ID") or 0)):
        ids_list = []
        for col in ("CreatureDisplayID1", "CreatureDisplayID2", "CreatureDisplayID3", "CreatureDisplayID4"):
            value = _int(row, col)
            if value:
                ids_list.append(value)
        ok = all(d in display_ids for d in ids_list) if ids_list else True
        if not ok:
            broken += 1
        add("| %s | %s | %s | %s |" % (
            _text(row, "ID") or row["__id"], _text(row, "Name"),
            ", ".join(str(d) for d in ids_list) or "-", "да" if ok else "НЕТ"))
    add("")
    if broken:
        add("Форм с отсутствующими дисплеями: %d - их использовать нельзя (клиент не найдёт модель)." % broken)
    else:
        add("У всех форм дисплеи на месте.")
    add("")
    add("Формы из дополнений новее Legion (8.x/9.x) в этом списке отсутствуют, если клиент 26124:")
    add("модели и строки DB2 таких форм физически не входят в CASC 7.3.5, а сервер может")
    add("сослаться только на существующий ID.")
    add("")
    return "\n".join(report), 0


def main():
    parser = argparse.ArgumentParser(description="Audit client DB2 for races and shapeshift forms")
    parser.add_argument("--dbc-dir", default=str(DBC_DIR), help="каталог с *.db2 (по умолчанию server/data/dbc/enUS)")
    parser.add_argument("--out", default=str(ROOT / "logs" / "race_form_audit.md"))
    parser.add_argument("--check-metadata", action="store_true",
                        help="только проверить, что метаданные ядра описывают нужные таблицы (файлы клиента не нужны)")
    args = parser.parse_args()

    if args.check_metadata:
        metas = load_metas(TABLES)
        for name in TABLES:
            meta = metas[name]
            print("%-22s fields=%d index_field=%d" % (name, meta.field_count, meta.index_field))
        print("OK: метаданные ядра описывают все таблицы аудита")
        return 0

    text, code = audit(args.dbc_dir)
    print(text)
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(text + "\n", encoding="utf-8")
    print("\nОтчёт записан: %s" % out)
    return code


if __name__ == "__main__":
    sys.exit(main())
