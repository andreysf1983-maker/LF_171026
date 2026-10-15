"""Self-contained fixture tests for the Criteria.db2 compatibility preflight."""

import contextlib
import io
import json
import struct
import tempfile
import unittest
from pathlib import Path

from audit_criteria_db2 import audit_rows, main, read_limits
from wdc1 import COLUMN_META, FIELD_ENTRY, HEADER, load_metas


def make_criteria_db2(path, rows):
    """Encode the 11 fields of a minimal uncompressed WDC1 Criteria table."""
    meta = load_metas(["Criteria"])["Criteria"]
    fields = ["Asset", "StartAsset", "FailAsset", "ModifierTreeId", "StartTimer",
              "EligibilityWorldStateID", "Type", "StartEvent", "FailEvent", "Flags",
              "EligibilityWorldStateValue"]
    formats = ["I", "i", "i", "I", "H", "h", "B", "B", "B", "B", "b"]
    record_format = "<" + "".join(formats)
    offsets = [struct.calcsize("<" + "".join(formats[:i])) for i in range(len(fields))]
    header = [0] * 22
    header[0] = int.from_bytes(b"WDC1", "little")
    header[1] = len(rows)
    header[2] = len(fields)
    header[3] = struct.calcsize(record_format)
    header[6] = meta.layout_hash
    header[7] = min(row["ID"] for row in rows)
    header[8] = max(row["ID"] for row in rows)
    header[12] = -1  # record ID is in the separate ID table
    header[13] = len(fields)
    header[17] = len(rows) * 4
    header[18] = len(fields) * COLUMN_META.size
    binary = bytearray(HEADER.pack(*header))
    binary.extend(b"".join(FIELD_ENTRY.pack(0, 0) for _ in fields))
    for row in rows:
        binary.extend(struct.pack(record_format, *(row.get(key, 0) for key in fields)))
    binary.extend(struct.pack("<" + "I" * len(rows), *(row["ID"] for row in rows)))
    for offset, fmt in zip(offsets, formats):
        binary.extend(COLUMN_META.pack(offset * 8, struct.calcsize(fmt) * 8, 0, 0, 0, 0, 0))
    path.write_bytes(binary)


class CriteriaPreflightTests(unittest.TestCase):
    def test_current_limits(self):
        self.assertEqual((213, 15), read_limits())

    def test_boundary_and_bounded_samples(self):
        rows = [{"ID": 1, "Type": 212, "StartTimer": 1, "StartEvent": 14},
                {"ID": 2, "Type": 213, "StartTimer": 0, "StartEvent": 0},
                {"ID": 3, "Type": 255, "StartTimer": 0, "StartEvent": 0},
                {"ID": 4, "Type": 212, "StartTimer": 1, "StartEvent": 15},
                {"ID": 5, "Type": 212, "StartTimer": 0, "StartEvent": 255}]
        result = audit_rows(rows, 213, 15, sample_limit=1)
        self.assertEqual((5, 2, 1), (result["checked"], result["unsupported_types"], result["invalid_timed_events"]))
        self.assertEqual([{"id": 2, "type": 213}], result["type_samples"])
        self.assertEqual([{"id": 4, "start_event": 15}], result["timed_samples"])

    def test_real_wdc1_decoder_and_cli_status(self):
        with tempfile.TemporaryDirectory() as directory:
            dbc = Path(directory)
            path = dbc / "Criteria.db2"
            make_criteria_db2(path, [{"ID": 100, "Type": 212, "StartTimer": 1, "StartEvent": 14}])
            with contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(0, main(["--dbc", directory, "--json"]))
            self.assertEqual(0, json.loads(output.getvalue())["unsupported_types"])

            make_criteria_db2(path, [{"ID": 101, "Type": 213},
                                     {"ID": 102, "Type": 212, "StartTimer": 1, "StartEvent": 15}])
            with contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(1, main(["--dbc", directory, "--json"]))
            report = json.loads(output.getvalue())
            self.assertEqual((1, 1), (report["unsupported_types"], report["invalid_timed_events"]))
            self.assertEqual([{"id": 101, "type": 213}], report["type_samples"])

    def test_missing_db2_exits_with_error(self):
        with tempfile.TemporaryDirectory() as directory, contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(2, main(["--dbc", directory]))


if __name__ == "__main__":
    unittest.main()
