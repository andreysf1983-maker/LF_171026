"""D0: lay hotfixes rows over the local DB2 CSVs.

The server loads each hotfix content table during LoadStores (replace or
insert by ID), then LoadHotfixData erases rows marked Deleted. This script
does those two steps in that order for every hotfix table that has a CSV
here. Tables without a CSV (broadcast_text, taxi_path, tact_key,
artifact_appearance) are reported and left alone.

    python tools/legion_db2/overlay_hotfixes.py
"""

import csv
import json
import re
import struct
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from wdc1 import DBC_DIR, LOAD_H, ROOT

OUT = Path(__file__).resolve().parent
MYSQL = Path(r"C:\Program Files\MySQL\MySQL Server 26.7\bin\mysql.exe")
CNF = ROOT / "setup_tmp" / "mysql.cnf"
HEADER = struct.Struct("<11IHh9I")

# Wago-style headers use different names than the hotfix SELECT lists.
EXPLICIT = {
    "PosX": "Pos_0",
    "PosY": "Pos_1",
    "PosZ": "Pos_2",
    "BoxLength": "Box_length",
    "BoxWidth": "Box_width",
    "BoxHeight": "Box_height",
    "BoxYaw": "Box_yaw",
}

# Header field 5 is the DB2 TableHash. These two pin the reader before any write.
EXPECTED_HASH = {
    "AreaTrigger": 441483745,
    "CriteriaTree": 1255424668,
}


def _mysql(sql):
    proc = subprocess.run(
        [str(MYSQL), "--defaults-extra-file=%s" % CNF, "-N", "-B", "hotfixes", "-e", sql],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or "mysql query failed")
    return proc.stdout


def _table_hash(path):
    with path.open("rb") as handle:
        return HEADER.unpack(handle.read(HEADER.size))[5]


def _csv_stem(table):
    return "".join(part.capitalize() for part in table.split("_"))


def _columns(table):
    raw = _mysql(
        "SELECT COLUMN_NAME FROM information_schema.COLUMNS "
        "WHERE TABLE_SCHEMA='hotfixes' AND TABLE_NAME='%s' ORDER BY ORDINAL_POSITION" % table
    )
    return [line.strip() for line in raw.splitlines() if line.strip()]


def _rows(table, columns):
    parts = ", ".join("'%s', `%s`" % (name.replace("'", ""), name) for name in columns)
    # HEX avoids the mysql client's extra backslash escaping, which breaks JSON.
    raw = _mysql("SELECT HEX(JSON_OBJECT(%s)) FROM `%s`" % (parts, table))
    rows = []
    for line in raw.splitlines():
        line = line.strip()
        if line:
            rows.append(json.loads(bytes.fromhex(line).decode("utf-8")))
    return rows


def _server_fields(stem):
    struct = stem + "LoadInfo"
    text = LOAD_H.read_text(encoding="utf-8", errors="replace")
    block = re.search(r"struct %s\b.*?fields\[\] =\s*\{(.*?)\};" % struct, text, re.S)
    if not block:
        return []
    return re.findall(r'\{\s*(?:true|false),\s*FT_\w+,\s*"([^"]+)"\s*\}', block.group(1))


def _positional_map(server_names, fieldnames):
    """Wago CSVs rename fields but keep server order. Use that order when it agrees with name matches."""
    if not server_names or len(server_names) != len(fieldnames):
        return {}
    mapped = {}
    for src, dest in zip(server_names, fieldnames):
        by_name = _resolve_name(src, fieldnames)
        if by_name and by_name != dest:
            return {}
        mapped[src] = dest
    if mapped.get("ID") != "ID":
        return {}
    return mapped


def _resolve(sql_name, fieldnames, positional):
    if sql_name in positional:
        return positional[sql_name]
    return _resolve_name(sql_name, fieldnames)


def _resolve_name(sql_name, fieldnames):
    if sql_name in EXPLICIT and EXPLICIT[sql_name] in fieldnames:
        return EXPLICIT[sql_name]
    if sql_name in fieldnames:
        return sql_name
    lang = sql_name + "_lang"
    if lang in fieldnames:
        return lang
    numbered = re.fullmatch(r"([A-Za-z]+)(\d+)", sql_name)
    if numbered:
        alt = "%s_%d" % (numbered.group(1), int(numbered.group(2)) - 1)
        if alt in fieldnames:
            return alt
        alt_lang = alt + "_lang"
        if alt_lang in fieldnames:
            return alt_lang
    snake = re.sub(r"(?<!^)(?=[A-Z])", "_", sql_name).lower()
    by_lower = {name.lower(): name for name in fieldnames}
    return by_lower.get(snake)


def _cell(value):
    if value is None:
        return ""
    if isinstance(value, bool):
        return "1" if value else "0"
    if isinstance(value, float):
        return "%.6g" % value
    return str(value)


def _apply_csv(path, upserts, delete_ids):
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        fieldnames = list(reader.fieldnames or [])
        rows = list(reader)
    if "ID" not in fieldnames:
        raise RuntimeError("%s has no ID column" % path.name)

    positional = _positional_map(_server_fields(path.stem), fieldnames)
    server_names = set(positional) or set(_server_fields(path.stem))

    def resolve(column):
        return _resolve(column, fieldnames, positional)

    unmapped = []
    if upserts:
        for column in upserts[0]:
            if column not in server_names:
                continue
            if resolve(column) is None:
                unmapped.append(column)
    if unmapped:
        print("  unmapped columns: %s" % ", ".join(unmapped), flush=True)
    mapped_names = [column for column in (upserts[0] if upserts else []) if resolve(column)]
    if upserts and "ID" not in mapped_names:
        raise RuntimeError("%s hotfix rows have no ID column that matches the CSV" % path.name)

    by_id = {}
    order = []
    for row in rows:
        key = int(row["ID"])
        by_id[key] = row
        order.append(key)

    replaced = 0
    inserted = 0
    for src in upserts:
        mapped = {resolve(column): _cell(src[column]) for column in src if resolve(column)}
        key = int(mapped["ID"])
        if key in by_id:
            by_id[key].update(mapped)
            replaced += 1
        else:
            fresh = {name: "" for name in fieldnames}
            fresh.update(mapped)
            by_id[key] = fresh
            order.append(key)
            inserted += 1

    deleted = 0
    absent = 0
    for key in delete_ids:
        if key in by_id:
            del by_id[key]
            deleted += 1
        else:
            absent += 1
    order = [key for key in order if key in by_id]

    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        for key in order:
            writer.writerow(by_id[key])

    return replaced, inserted, deleted, absent


def apply_overlay():
    for name, expected in EXPECTED_HASH.items():
        found = _table_hash(DBC_DIR / ("%s.db2" % name))
        if found != expected:
            raise RuntimeError("%s.db2 table hash %s != %s" % (name, found, expected))

    hash_to_csv = {}
    for db2 in DBC_DIR.glob("*.db2"):
        csv_path = OUT / ("%s.csv" % db2.stem)
        if csv_path.is_file():
            hash_to_csv[_table_hash(db2)] = csv_path

    deletes = {}
    raw = _mysql("SELECT TableHash, RecordId, Deleted FROM hotfix_data")
    skipped_hashes = set()
    for line in raw.splitlines():
        table_hash, record_id, deleted = line.split("\t")
        if deleted != "1":
            continue
        path = hash_to_csv.get(int(table_hash))
        if path is None:
            skipped_hashes.add(int(table_hash))
            continue
        deletes.setdefault(path, set()).add(int(record_id))

    tables = [line.strip() for line in _mysql("SHOW TABLES").splitlines() if line.strip()]
    upserts = {}
    skipped_tables = []
    for table in tables:
        if table == "hotfix_data" or table.endswith("_locale"):
            continue
        csv_path = OUT / ("%s.csv" % _csv_stem(table))
        if not csv_path.is_file():
            count = _mysql("SELECT COUNT(*) FROM `%s`" % table).strip()
            if count != "0":
                skipped_tables.append("%s (%s rows, no csv)" % (table, count))
            continue
        columns = _columns(table)
        rows = _rows(table, columns)
        if not rows and csv_path not in deletes:
            continue
        upserts[csv_path] = rows

    targets = sorted(set(upserts) | set(deletes), key=lambda path: path.name)
    print("overlay %s csvs" % len(targets), flush=True)
    for path in targets:
        replaced, inserted, deleted, absent = _apply_csv(path, upserts.get(path, []), deletes.get(path, set()))
        print(
            "  %s replace %s insert %s delete %s already-absent %s" % (
                path.name, replaced, inserted, deleted, absent
            ),
            flush=True,
        )
    for note in skipped_tables:
        print("  skip %s" % note, flush=True)
    for table_hash in sorted(skipped_hashes):
        print("  skip delete hash %s (no csv)" % table_hash, flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(apply_overlay())
