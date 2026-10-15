#!/usr/bin/env python3
"""LEGIONFORGE - column-level audit of the SQL patches against the core.

Added 2026-10-13 after setup.bat aborted on
  ERROR 1054 (42S22): Unknown column 'RewardSpellCast' in 'where clause'
(sql/101 rev.1). The ADB_735.10 dump is not available offline (RAR v6), but
the core's own SELECT/UPDATE/INSERT statements are: a column the worldserver
reads from a table is guaranteed to exist in the database (otherwise the
server would abort at startup). This tool

  1. extracts every WorldDatabase query from core/src/server (string
     literals are joined after stripping // comments, PrepareStatement()
     text included, LootMgr "FROM %s" expanded to every *_loot_template),
  2. adds CREATE TABLE / INSERT column lists from the repository's own SQL,
  3. checks every backticked identifier of the given patch files against the
     union of known columns of the tables the statement touches.

Usage:  python tools/audit_sql_columns.py [sql/101_x.sql ...]   (default: all
        files registered in apply_play_sql.ps1 + setup.bat 40-49 block)
Exit code 1 if any unverified column/table is found in a STRICT file
(sql/1xx_*.sql); other files are report-only (ADB-era conventions vary).
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CORE = ROOT / "core" / "src" / "server"
LOOT_TABLES = ("creature_loot_template", "gameobject_loot_template", "item_loot_template",
               "spell_loot_template", "disenchant_loot_template", "reference_loot_template",
               "fishing_loot_template", "skinning_loot_template", "pickpocketing_loot_template",
               "mail_loot_template", "milling_loot_template", "prospecting_loot_template",
               "world_quest_loot_template", "zone_loot_template", "luck_loot_template")
LOOT_COLS = {"entry", "item", "reference", "chance", "questrequired", "lootmode", "groupid",
             "mincount", "maxcount", "comment"}
STRICT = re.compile(r"^(1\d\d)_.*\.sql$")

_lit = re.compile(r'"((?:[^"\\]|\\.)*)"')


def core_strings():
    for p in CORE.rglob("*.cpp"):
        try:
            t = p.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        t = re.sub(r"//[^\n]*", "", t)                       # drop // comments between literals
        t = re.sub(r"/\*.*?\*/", "", t, flags=re.S)
        for m in re.finditer(r'(?:"(?:[^"\\]|\\.)*"\s*)+', t):
            yield "".join(_lit.findall(m.group(0)))


def build_schema():
    known = {}

    def add(table, cols):
        s = known.setdefault(table.lower(), set())
        for c in cols:
            c = c.strip().strip("`")
            c = re.sub(r"^\w+\.", "", c)
            c = re.sub(r"\s+AS\s+\w+$", "", c, flags=re.I)
            if re.fullmatch(r"\w+", c):
                s.add(c.lower())

    sel = re.compile(r"SELECT\s+(.*?)\s+FROM\s+`?(\w+)`?", re.I | re.S)
    upd = re.compile(r"UPDATE\s+`?(\w+)`?\s+SET\s+(.*?)(?:\s+WHERE\s+|$)", re.I | re.S)
    ins = re.compile(r"(?:INSERT|REPLACE)\s+(?:IGNORE\s+)?INTO\s+`?(\w+)`?\s*\(([^)]*)\)", re.I | re.S)
    whr = re.compile(r"(?:FROM|UPDATE)\s+`?(\w+)`?\b.*?WHERE\s+(.*)", re.I | re.S)
    for s in core_strings():
        for m in sel.finditer(s):
            add(m.group(2), re.split(r",", re.sub(r"\([^)]*\)", "", m.group(1))))
        for m in upd.finditer(s):
            add(m.group(1), [x.split("=")[0] for x in m.group(2).split(",")])
        for m in ins.finditer(s):
            add(m.group(1), m.group(2).split(","))
        for m in whr.finditer(s):
            add(m.group(1), re.findall(r"`?(\w+)`?\s*(?:=|<>|!=|>=|<=|>|<|\bIN\b|\bLIKE\b)", m.group(2)))
    for t in LOOT_TABLES:
        known.setdefault(t, set()).update(LOOT_COLS)
    # repository SQL: CREATE TABLE definitions and explicit INSERT column lists
    for p in list((ROOT / "sql").glob("*.sql")) + list((ROOT / "sql" / "stitch").glob("*.sql")) \
            + list((ROOT / "sql" / "updates").rglob("*.sql")) + list((ROOT / "sql" / "legionforge").rglob("*.sql")):
        try:
            s = p.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        for m in re.finditer(r"CREATE TABLE(?: IF NOT EXISTS)?\s+`?(\w+)`?\s*\((.*?)\)\s*(?:ENGINE|DEFAULT|$)", s, re.I | re.S):
            cols = re.findall(r"^\s*`(\w+)`", m.group(2), re.M)
            add(m.group(1), cols)
        for m in ins.finditer(s):
            add(m.group(1), m.group(2).split(","))
    return known


def statements(sql):
    sql = re.sub(r"--[^\n]*", "", sql)
    return [s.strip() for s in sql.split(";") if s.strip()]


def check_file(path, known):
    problems = []
    tbl_re = re.compile(r"(?<!KEY )(?:FROM|UPDATE|INTO|JOIN)\s+`(\w+)`", re.I)
    alias_re = re.compile(r"`\w+`\s+(?:AS\s+)?(\w+)\b", re.I)
    for st in statements(path.read_text(encoding="utf-8-sig", errors="ignore")):
        tables = {t.lower() for t in tbl_re.findall(st)}
        if not tables:
            continue
        aliases = {a.lower() for a in alias_re.findall(st)}
        idents = set(re.findall(r"`(\w+)`", st))
        out_aliases = {a.lower() for a in re.findall(r"\bAS\s+`(\w+)`", st, re.I)}
        for tb in tables:
            if tb not in known:
                problems.append(f"table `{tb}` is never used by the core")
        for c in idents:
            cl = c.lower()
            if cl in tables or cl in aliases or cl in out_aliases:
                continue
            if not any(cl in known.get(tb, set()) for tb in tables):
                problems.append(f"column `{c}` not verified for tables {sorted(tables)}")
    return problems


def default_files():
    files = []
    manifest = (ROOT / "apply_play_sql.ps1").read_text(encoding="utf-8-sig")
    for name in re.findall(r'File\s*=\s*"([^"]+\.sql)"', manifest):
        files.append(ROOT / "sql" / name)
    for name in re.findall(r'Rel\s*=\s*"([^"]+\.sql)"', manifest):
        files.append(ROOT / "sql" / name.replace("\\", "/"))
    return [f for f in files if f.exists()]


def main(argv):
    known = build_schema()
    files = [pathlib.Path(a) for a in argv] or default_files()
    rc = 0
    for f in files:
        probs = check_file(f, known)
        strict = bool(STRICT.match(f.name))
        tag = "STRICT" if strict else "report"
        if probs:
            print(f"[{tag}] {f.relative_to(ROOT) if f.is_relative_to(ROOT) else f}: {len(probs)} unverified")
            for p in sorted(set(probs)):
                print("    -", p)
            if strict:
                rc = 1
        else:
            print(f"[{tag}] {f.name}: OK")
    print(f"known world/other tables from core+repo: {len(known)}")
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
