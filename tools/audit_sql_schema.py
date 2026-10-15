#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LegionForge 7.3.5 (26124) - SQL schema audit.

Причина краша 2026-10-13: ядро (scripts/Custom/scenario_door.cpp) выполняло
SELECT по таблице world.scenario_npc_landing, а SQL-файл, создающий её
(sql/stitch/010_scenario_npc_landing.sql), не был подключён к установщику.
MySQLConnection::_HandleMySQLErrno на ER_NO_SUCH_TABLE (1146) и
ER_BAD_FIELD_ERROR (1054) делает std::abort() -> worldserver падает.

Инструмент статически ловит весь класс таких ошибок ДО запуска сервера:

  1. Собирает схему каждой базы (auth / characters / world / hotfixes) из
     sql/base/*.sql (+ ADB_world.sql / ADB_hotfixes.sql, если setup их уже
     распаковал, либо пути --adb-world / --adb-hotfixes), из всех SQL,
     которые реально применяет apply_play_sql.ps1, и из ensure_auth_schema.ps1.
  2. Извлекает ВСЕ SQL-запросы ядра: PrepareStatement(...) в
     database/Database/Implementation/*.cpp и прямые
     WorldDatabase/CharacterDatabase/LoginDatabase/HotfixDatabase
     .Query/PQuery/Execute/PExecute/DirectExecute/... в любых .cpp/.h.
  3. Проверяет, что каждая таблица (и колонки в однозначных запросах)
     существует в схеме той базы, к которой обращается запрос.
  4. Проверяет, что каждый SQL-файл с CREATE TABLE в sql/ и sql/stitch/
     подключён к apply_play_sql.ps1 (кроме *_rollback.sql и ручных отчётов).

Код выхода: 0 - критичных проблем нет; 1 - найдены таблицы, которых не будет
в базе (гарантированный abort() при первом обращении) или неподключённый SQL.

Запуск:  python tools/audit_sql_schema.py [--adb-world PATH] [--adb-hotfixes PATH]
                                          [--report logs/sql_schema_audit.md]
"""
import argparse
import os
import re
import sys
from collections import defaultdict

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
CORE = os.path.join(ROOT, "core", "src", "server")
SQL = os.path.join(ROOT, "sql")

POOL_TO_DB = {
    "WorldDatabase": "world",
    "CharacterDatabase": "characters",
    "LoginDatabase": "auth",
    "HotfixDatabase": "hotfixes",
}
IMPL_TO_DB = {
    "WorldDatabase.cpp": "world",
    "CharacterDatabase.cpp": "characters",
    "LoginDatabase.cpp": "auth",
    "HotfixDatabase.cpp": "hotfixes",
}
DB_NAMES = ("auth", "characters", "world", "hotfixes")

# SQL-файлы с CREATE TABLE, которые сознательно НЕ применяются автоматически.
MANUAL_OK = re.compile(r"(_rollback\.sql$|^16_quest_audit_queries\.sql$)", re.I)

SQL_KEYWORDS = {
    "select", "where", "set", "values", "on", "as", "dual", "if", "not", "exists",
    "ignore", "low_priority", "delayed", "high_priority", "quick", "lateral",
}


# --------------------------------------------------------------------------- schema
class Schema:
    def __init__(self):
        self.tables = defaultdict(lambda: defaultdict(set))  # db -> table -> {cols}

    def add_table(self, db, table, cols):
        self.tables[db][table.lower()] |= {c.lower() for c in cols}

    def has_table(self, db, table):
        return table.lower() in self.tables[db]

    def has_col(self, db, table, col):
        cols = self.tables[db].get(table.lower())
        return cols is None or not cols or col.lower() in cols


CREATE_RE = re.compile(r"CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?`?(\w+)`?\s*\(", re.I)
COLDEF_RE = re.compile(r"^\s*`(\w+)`\s+\w+", re.M)
ALTER_RE = re.compile(r"ALTER\s+TABLE\s+`?(\w+)`?\s+(.*?);", re.I | re.S)
ADD_COL_RE = re.compile(r"\bADD\s+(?:COLUMN\s+)?(?:IF\s+NOT\s+EXISTS\s+)?`(\w+)`", re.I)
CHANGE_COL_RE = re.compile(r"\b(?:CHANGE|RENAME)\s+(?:COLUMN\s+)?`(\w+)`\s+(?:TO\s+)?`(\w+)`", re.I)


DROP_RE = re.compile(r"DROP\s+TABLE\s+(?:IF\s+EXISTS\s+)?`?(\w+)`?\s*;", re.I)


def parse_sql_text(schema, db, text):
    text = re.sub(r"(?m)^\s*--[^\n]*", "", text)
    # DROP TABLE до CREATE в том же файле = пересоздание; DROP без CREATE = таблица исчезает.
    created = {m.group(1).lower() for m in CREATE_RE.finditer(text)}
    for m in DROP_RE.finditer(text):
        if m.group(1).lower() not in created:
            schema.tables[db].pop(m.group(1).lower(), None)
    for m in CREATE_RE.finditer(text):
        depth, i = 1, m.end()
        while i < len(text) and depth:
            ch = text[i]
            if ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
            i += 1
        schema.add_table(db, m.group(1), COLDEF_RE.findall(text[m.end():i - 1]))
    for m in ALTER_RE.finditer(text):
        table, body = m.group(1), m.group(2)
        cols = ADD_COL_RE.findall(body) + [new for _, new in CHANGE_COL_RE.findall(body)]
        if cols and schema.has_table(db, table):
            schema.tables[db][table.lower()] |= {c.lower() for c in cols}


def parse_big_dump(schema, db, path):
    """Потоковый разбор огромных дампов (ADB world ~350 МиБ): берём только CREATE TABLE."""
    buf, inside = [], False
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            if not inside:
                if line.lstrip().upper().startswith("CREATE TABLE"):
                    inside, buf = True, [line]
            else:
                buf.append(line)
                if line.lstrip().startswith(")"):
                    parse_sql_text(schema, db, "".join(buf))
                    inside = False


def read(path):
    with open(path, "r", encoding="utf-8-sig", errors="replace") as f:
        return f.read()


def applied_patches():
    """Список (db, relpath) из apply_play_sql.ps1 - то, что реально попадёт в базу."""
    text = read(os.path.join(ROOT, "apply_play_sql.ps1"))
    out = []
    for m in re.finditer(r"@\{\s*Db\s*=\s*(\$charDb|\"(\w+)\")\s*;\s*(File|Rel)\s*=\s*\"([^\"]+)\"", text):
        db = "characters" if m.group(1) == "$charDb" else m.group(2)
        out.append((db, m.group(4).replace("\\", "/")))
    # setup.bat / play.bat применяют часть патчей сами: call :APPLY <db> "...\\file.sql"
    for bat in ("setup.bat", "play.bat"):
        bp = os.path.join(ROOT, bat)
        if not os.path.exists(bp):
            continue
        with open(bp, "rb") as f:
            btext = f.read().decode("cp866", errors="replace")
        for m in re.finditer(r"(?im)^\s*call\s+:APPLY\s+(\w+)\s+\"([^\"]+\.sql)\"", btext):
            path = m.group(2).replace("\\", "/")
            path = re.sub(r"^%(SQL_DIR)%/", "", path)
            path = re.sub(r"^%ROOT%/sql/", "", path)
            out.append((m.group(1).lower(), path))
    return out


def build_schema(adb_world, adb_hotfixes):
    s = Schema()
    notes = []
    for db, name in (("auth", "auth.sql"), ("characters", "characters.sql")):
        p = os.path.join(SQL, "base", name)
        if os.path.exists(p):
            parse_sql_text(s, db, read(p))
        else:
            notes.append("нет sql/base/%s - схема %s неполная" % (name, db))
    for db, opt, explicit, defaults in (
        ("world", "--adb-world", adb_world, ["ADB_world.sql", "world.sql"]),
        ("hotfixes", "--adb-hotfixes", adb_hotfixes, ["ADB_hotfixes.sql", "hotfixes.sql"]),
    ):
        path = explicit
        if not path:
            for d in defaults:
                cand = os.path.join(SQL, "base", d)
                if os.path.exists(cand):
                    path = cand
                    break
        if path and os.path.exists(path):
            parse_big_dump(s, db, path)
        else:
            notes.append("дамп %s не найден (запустите setup.bat или укажите %s) - "
                         "таблицы %s проверяются только по патчам" % (db, opt, db))
    eas = os.path.join(ROOT, "ensure_auth_schema.ps1")
    if os.path.exists(eas):
        for t, c in re.findall(r"Table\s*=\s*'(\w+)';\s*Column\s*=\s*'(\w+)'", read(eas)):
            if s.has_table("auth", t):
                s.tables["auth"][t.lower()].add(c.lower())
    for db, rel in applied_patches():
        p = os.path.join(SQL, rel)
        if os.path.exists(p):
            parse_sql_text(s, db, read(p))
    return s, notes


# --------------------------------------------------------------------------- queries
STR_RE = re.compile(r'"((?:[^"\\]|\\.)*)"')


def collect_literals(src, pos):
    """Склеивает подряд идущие строковые литералы C++ начиная с pos."""
    parts, i, n = [], pos, len(src)
    while i < n:
        while i < n and src[i] in " \t\r\n":
            i += 1
        if src.startswith("//", i):
            i = src.find("\n", i)
            if i < 0:
                break
            continue
        if i < n and src[i] == '"':
            m = STR_RE.match(src, i)
            if not m:
                break
            parts.append(m.group(1))
            i = m.end()
            continue
        m = re.match(r"(UI64FMTD|SI64FMTD|SZFMTD)\b", src[i:i + 16])
        if m:
            parts.append("%llu")
            i += m.end()
            continue
        break
    return "".join(parts)


TABLE_REF_RE = re.compile(
    r"\b(FROM|JOIN|INTO|UPDATE|TABLE)\s+(?:IGNORE\s+|LOW_PRIORITY\s+)?(`?\w+`?(?:\.`?\w+`?)?)", re.I)


def tables_in(sql):
    out = []
    # строковые литералы внутри SQL ('...') не должны давать ложных таблиц
    clean = re.sub(r"'(?:[^'\\]|\\.)*'", "''", sql)
    clean = re.sub(r"(?i)\bKEY\s+UPDATE\b", "KEY_UPDATE", clean)
    for kw, ref in TABLE_REF_RE.findall(clean):
        ref = ref.replace("`", "")
        db = None
        if "." in ref:
            db, ref = ref.split(".", 1)
        if ref.lower() in SQL_KEYWORDS or ref.startswith("%") or ref.isdigit():
            continue
        out.append((db, ref, kw.upper()))
    return out


SIMPLE_SELECT_RE = re.compile(
    r"^\s*SELECT\s+(.*?)\s+FROM\s+`?(\w+)`?\s*(?:WHERE|ORDER|GROUP|LIMIT|$)", re.I | re.S)
INSERT_COLS_RE = re.compile(r"^\s*(?:INSERT|REPLACE)\s+(?:IGNORE\s+)?INTO\s+`?(\w+)`?\s*\(([^)]*)\)", re.I)


def columns_in(sql):
    """Колонки только для однозначных форм (одна таблица, без выражений)."""
    m = SIMPLE_SELECT_RE.match(sql)
    if m and " join " not in sql.lower() and "(" not in m.group(1):
        cols = []
        for c in m.group(1).split(","):
            c = c.strip().replace("`", "")
            if re.fullmatch(r"[A-Za-z_]\w*", c):
                cols.append(c)
        return m.group(2), cols
    m = INSERT_COLS_RE.match(sql)
    if m:
        return m.group(1), [c.strip().strip("`") for c in m.group(2).split(",") if c.strip()]
    return None, []


def strip_cpp_comments(src):
    """Убирает // и /* */ комментарии, сохраняя переводы строк (номера строк не съезжают)."""
    def repl(m):
        t = m.group(0)
        if t.startswith("/"):
            return re.sub(r"[^\n]", " ", t)
        return t
    return re.sub(r'//[^\n]*|/\*.*?\*/|"(?:[^"\\\n]|\\.)*"|\'(?:[^\'\\\n]|\\.)*\'', repl, src, flags=re.S)


def iter_queries():
    impl = os.path.join(CORE, "database", "Database", "Implementation")
    for fn, db in IMPL_TO_DB.items():
        p = os.path.join(impl, fn)
        if not os.path.exists(p):
            continue
        src = strip_cpp_comments(read(p))
        for m in re.finditer(r"PrepareStatement\s*\(\s*(\w+)\s*,", src):
            sql = collect_literals(src, m.end())
            if sql:
                yield db, sql, os.path.relpath(p, ROOT), src.count("\n", 0, m.start()) + 1, m.group(1)
    call_re = re.compile(
        r"\b(WorldDatabase|CharacterDatabase|LoginDatabase|HotfixDatabase)\s*\.\s*"
        r"(Query|PQuery|Execute|PExecute|DirectExecute|DirectPExecute|AsyncQuery|AsyncPQuery)\s*\(")
    for base, _, files in os.walk(CORE):
        for fn in files:
            if not fn.endswith((".cpp", ".h")):
                continue
            p = os.path.join(base, fn)
            src = strip_cpp_comments(read(p))
            for m in call_re.finditer(src):
                sql = collect_literals(src, m.end())
                if sql:
                    yield (POOL_TO_DB[m.group(1)], sql, os.path.relpath(p, ROOT),
                           src.count("\n", 0, m.start()) + 1, m.group(2))


# --------------------------------------------------------------------------- checks
def check_unapplied_sql():
    applied = {rel.lower() for _, rel in applied_patches()}
    issues = []
    for sub in ("", "stitch"):
        d = os.path.join(SQL, sub)
        for fn in sorted(os.listdir(d)):
            if not fn.endswith(".sql") or MANUAL_OK.search(fn):
                continue
            rel = (sub + "/" + fn) if sub else fn
            if CREATE_RE.search(read(os.path.join(d, fn))) and rel.lower() not in applied:
                issues.append(rel)
    return issues


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--adb-world")
    ap.add_argument("--adb-hotfixes")
    ap.add_argument("--report", default=os.path.join(ROOT, "logs", "sql_schema_audit.md"))
    ap.add_argument("--strict-columns", action="store_true", help="колонки тоже считать критичными")
    a = ap.parse_args()

    schema, notes = build_schema(a.adb_world, a.adb_hotfixes)
    have_full = {db: len(schema.tables[db]) > 20 for db in DB_NAMES}

    missing_tables, missing_cols, unknown = set(), [], set()
    total = 0
    for db, sql, path, line, name in iter_queries():
        total += 1
        for xdb, table, _kw in tables_in(sql):
            if xdb and xdb.lower() in ("information_schema", "mysql", "performance_schema"):
                continue
            tdb = xdb.lower() if xdb and xdb.lower() in DB_NAMES else db
            if schema.has_table(tdb, table):
                continue
            rec = (tdb, table, path.replace("\\", "/"), line, name)
            (missing_tables if have_full[tdb] else unknown).add(rec)
        t, cols = columns_in(sql)
        if t and schema.has_table(db, t):
            bad = [c for c in cols if not schema.has_col(db, t, c)]
            if bad:
                missing_cols.append((db, t, ",".join(bad), path.replace("\\", "/"), line, name))

    unapplied = check_unapplied_sql()

    out = ["# SQL schema audit (LegionForge 26124)", "",
           "Проверено запросов ядра: **%d**. Таблиц в схеме: %s." % (
               total, ", ".join("%s=%d" % (d, len(schema.tables[d])) for d in DB_NAMES))]
    out += ["- ⚠ " + n for n in notes]
    out += ["", "## 1. Таблицы, которых НЕ будет в базе (гарантированный abort() worldserver)", ""]
    out += ["- `%s.%s` ← %s:%d (%s)" % r for r in sorted(missing_tables)] or ["Нет."]
    out += ["", "## 2. SQL-файлы с CREATE TABLE, не подключённые к apply_play_sql.ps1", ""]
    out += ["- `sql/%s`" % u for u in unapplied] or ["Нет."]
    out += ["", "## 3. Колонки, отсутствующие в схеме (ER_BAD_FIELD_ERROR -> abort())", ""]
    out += ["- `%s.%s`: %s ← %s:%d (%s)" % r for r in missing_cols] or ["Нет."]
    out += ["", "## 4. Не удалось проверить (нет дампа базы)", ""]
    out += ["- `%s.%s` ← %s:%d" % r[:4] for r in sorted(unknown)] or ["Нет."]
    os.makedirs(os.path.dirname(a.report), exist_ok=True)
    with open(a.report, "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")

    crit = len(missing_tables) + len(unapplied) + (len(missing_cols) if a.strict_columns else 0)
    print("SQL audit: queries=%d missing_tables=%d unapplied_sql=%d missing_columns=%d unverified=%d"
          % (total, len(missing_tables), len(unapplied), len(missing_cols), len(unknown)))
    for r in sorted(missing_tables)[:60]:
        print("  [MISSING TABLE] %s.%s  <- %s:%d" % r[:4])
    for u in unapplied:
        print("  [NOT APPLIED]   sql/%s" % u)
    for r in missing_cols[:60]:
        print("  [MISSING COL]   %s.%s: %s  <- %s:%d" % r[:5])
    print("Report: %s" % os.path.relpath(a.report, ROOT))
    return 1 if crit else 0


if __name__ == "__main__":
    sys.exit(main())
