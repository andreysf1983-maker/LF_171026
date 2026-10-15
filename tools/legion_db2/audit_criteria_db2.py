#!/usr/bin/env python3
"""Check raw Criteria.db2 records against this core's supported bounds.

    python tools/legion_db2/audit_criteria_db2.py --dbc server/data/dbc/enUS

Exit status: 0 = compatible, 1 = incompatible records, 2 = missing/unreadable data.
Only the raw WDC1 file is checked; SQL hotfix overlays are applied by worldserver.
"""

import argparse
import json
import re
import sys
from pathlib import Path

try:
    from .wdc1 import DBC_DIR, Wdc1Table, _attach_none_offsets, load_metas
except ImportError:  # direct invocation: python tools/legion_db2/audit_criteria_db2.py
    from wdc1 import DBC_DIR, Wdc1Table, _attach_none_offsets, load_metas

ROOT = Path(__file__).resolve().parents[2]
ENUM_HEADER = ROOT / "core/src/server/game/DataStores/DBCEnums.h"


def read_limits():
    """Use the limits compiled into this core instead of hard-coded guesses."""
    text = ENUM_HEADER.read_text(encoding="utf-8")
    total = re.search(r"^#define\s+CRITERIA_TYPE_TOTAL\s+(\d+)\s*$", text, re.M)
    timed = re.search(r"enum\s+CriteriaTimedTypes\s*:\s*uint8\s*\{(.*?)\}", text, re.S)
    if not total or not timed or "CRITERIA_TIMED_TYPE_MAX" not in timed.group(1):
        raise ValueError("Cannot read criteria bounds from DBCEnums.h")
    before_max = timed.group(1).split("CRITERIA_TIMED_TYPE_MAX", 1)[0]
    values = re.findall(r"^\s*CRITERIA_TIMED_TYPE_[A-Z0-9_]+\s*=\s*(\d+)", before_max, re.M)
    if not values:
        raise ValueError("Cannot determine CRITERIA_TIMED_TYPE_MAX")
    return int(total.group(1)), max(map(int, values)) + 1


def audit_rows(rows, type_limit, timed_limit, sample_limit=20):
    """Return a bounded report for dictionaries with ID/Type/StartTimer/StartEvent."""
    result = {
        "checked": 0,
        "type_limit": type_limit,
        "timed_limit": timed_limit,
        "max_type_seen": 0,
        "unsupported_types": 0,
        "invalid_timed_events": 0,
        "type_samples": [],
        "timed_samples": [],
    }
    for row in rows:
        result["checked"] += 1
        kind = int(row["Type"])
        result["max_type_seen"] = max(result["max_type_seen"], kind)
        if kind >= type_limit:
            result["unsupported_types"] += 1
            if len(result["type_samples"]) < sample_limit:
                result["type_samples"].append({"id": int(row["ID"]), "type": kind})
        elif int(row["StartTimer"]) and int(row["StartEvent"]) >= timed_limit:
            result["invalid_timed_events"] += 1
            if len(result["timed_samples"]) < sample_limit:
                result["timed_samples"].append({
                    "id": int(row["ID"]), "start_event": int(row["StartEvent"])
                })
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dbc", type=Path, default=DBC_DIR, help="directory containing Criteria.db2")
    parser.add_argument("--json", action="store_true", help="print machine-readable JSON")
    args = parser.parse_args(argv)
    path = args.dbc / "Criteria.db2"
    if not path.is_file():
        print(f"Missing {path}; extract dbc from a clean 7.3.5 build 26124 client.", file=sys.stderr)
        return 2
    try:
        type_limit, timed_limit = read_limits()
        meta = load_metas(["Criteria"])["Criteria"]
        table = Wdc1Table(path, meta)
        _attach_none_offsets(table)
        header = table.header()
        columns = {name: header.index(name) for name in ("ID", "Type", "StartTimer", "StartEvent")}
        rows = ({name: values[index] for name, index in columns.items()} for _, values in table.rows())
        report = audit_rows(rows, type_limit, timed_limit)
    except (OSError, ValueError, KeyError, IndexError, RuntimeError) as exc:
        print(f"Cannot inspect {path}: {exc}", file=sys.stderr)
        return 2

    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print(f"Criteria.db2: {report['checked']} records; highest type {report['max_type_seen']}; "
              f"supported types 0..{type_limit - 1}, timed events 0..{timed_limit - 1}.")
        print(f"Unsupported types: {report['unsupported_types']}; invalid timed events: {report['invalid_timed_events']}")
        for sample in report["type_samples"]:
            print(f"  Unsupported: criteria {sample['id']}, type {sample['type']}")
        for sample in report["timed_samples"]:
            print(f"  Invalid timer: criteria {sample['id']}, start event {sample['start_event']}")
        if report["unsupported_types"] or report["invalid_timed_events"]:
            print("Replace mixed/newer dbc with a clean 26124 extraction; skipping types cannot implement their mechanics.")
    return 1 if report["unsupported_types"] or report["invalid_timed_events"] else 0


if __name__ == "__main__":
    sys.exit(main())
