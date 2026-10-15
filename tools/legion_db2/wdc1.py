"""Read Legion 7.3.5 WDC1 DB2 files using the server's own field metadata.

Field names, layout hashes and array sizes come from
core/src/server/game/DataStores/DB2Metadata.h and DB2LoadInfo.h, the same
definitions worldserver uses to load these files.
"""

import csv
import re
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
META_H = ROOT / "core" / "src" / "server" / "game" / "DataStores" / "DB2Metadata.h"
LOAD_H = ROOT / "core" / "src" / "server" / "game" / "DataStores" / "DB2LoadInfo.h"
DBC_DIR = ROOT / "server" / "data" / "dbc" / "enUS"

HEADER = struct.Struct("<11IHh9I")
FIELD_ENTRY = struct.Struct("<hH")
COLUMN_META = struct.Struct("<HHI I III")  # bit_off, bit_size, extra, compression, a, b, c
CATALOG = struct.Struct("<IH")
COPY = struct.Struct("<II")
COMMON = struct.Struct("<II")

NONE, IMMEDIATE, COMMON_DATA, PALLET, PALLET_ARRAY = range(5)


def _u64(buf, offset):
    chunk = buf[offset:offset + 8]
    if len(chunk) < 8:
        chunk = chunk + b"\x00" * (8 - len(chunk))
    return int.from_bytes(chunk, "little")


def _packed(buf, offset, bit_width, bit_offset):
    if bit_width == 0:
        return 0
    bits = bit_offset & 7
    raw = _u64(buf, offset)
    shifted = (raw << (64 - bits - bit_width)) & ((1 << 64) - 1)
    return shifted >> (64 - bit_width)


def _sign_extend(value, width):
    if width <= 0 or width >= 64:
        return value
    sign = 1 << (width - 1)
    return (value ^ sign) - sign


def _as_float(bits):
    return struct.unpack("<f", struct.pack("<I", bits & 0xFFFFFFFF))[0]


def _as_signed(bits, nbytes, signed):
    bits &= (1 << (nbytes * 8)) - 1
    if not signed:
        return bits
    sign = 1 << (nbytes * 8 - 1)
    return bits - (1 << (nbytes * 8)) if bits & sign else bits


class TableMeta:
    def __init__(self, name, index_field, field_count, layout_hash, array_sizes, fields, parent_field):
        self.name = name
        self.index_field = index_field
        self.field_count = field_count
        self.layout_hash = layout_hash
        self.array_sizes = array_sizes
        self.fields = fields  # list of (signed, type_char, name) matching LoadInfo order
        self.parent_field = parent_field

    @property
    def has_index(self):
        return self.index_field != -1


LOAD_ALIAS = {
    "GameObjectDisplayInfo": "GameobjectDisplayInfo",
}


def _synthetic_fields(index_field, types, arrays):
    fields = []
    if index_field == -1:
        fields.append((False, "i", "ID"))
    for index, size in enumerate(arrays):
        type_char = types[index]
        for slot in range(size):
            if index == index_field and slot == 0:
                name = "ID"
            elif size == 1:
                name = "F%d" % index
            else:
                name = "F%d_%d" % (index, slot)
            fields.append((False, type_char, name))
    return fields


def load_metas(names):
    meta_text = META_H.read_text(encoding="utf-8", errors="replace")
    load_text = LOAD_H.read_text(encoding="utf-8", errors="replace")
    metas = {}
    for name in names:
        block = re.search(
            r"struct %sMeta\s*\{.*?static char const\* types = \"([^\"]+)\";\s*"
            r"static uint8 const arraySizes\[\d+\] = \{([^}]+)\};\s*"
            r"static DB2Meta instance\((-?\d+), (\d+), (0x[0-9A-Fa-f]+), types, arraySizes, (-?\d+)\)" % name,
            meta_text,
            re.S,
        )
        if not block:
            raise RuntimeError("No DB2 metadata for %s" % name)
        types = block.group(1)
        arrays = [int(x.strip()) for x in block.group(2).split(",") if x.strip()]
        index_field = int(block.group(3))
        field_count = int(block.group(4))
        layout = int(block.group(5), 16)
        parent_field = int(block.group(6))
        if len(arrays) != field_count:
            raise RuntimeError("%s array size count %s != field count %s" % (name, len(arrays), field_count))
        load_name = LOAD_ALIAS.get(name, name)
        load = re.search(
            r"struct %sLoadInfo\s*\{.*?fields\[\] =\s*\{(.*?)\};" % load_name,
            load_text,
            re.S,
        )
        fields = []
        if load:
            for signed, kind, fname in re.findall(
                r"\{\s*(true|false),\s*(FT_[A-Z_]+),\s*\"([^\"]+)\"\s*\}",
                load.group(1),
            ):
                type_char = {
                    "FT_STRING": "s",
                    "FT_STRING_NOT_LOCALIZED": "S",
                    "FT_FLOAT": "f",
                    "FT_INT": "i",
                    "FT_BYTE": "b",
                    "FT_SHORT": "h",
                    "FT_LONG": "l",
                }[kind]
                fields.append((signed == "true", type_char, fname))
        else:
            fields = _synthetic_fields(index_field, types, arrays)
        metas[name] = TableMeta(name, index_field, field_count, layout, arrays, fields, parent_field)
    return metas


class Wdc1Table:
    def __init__(self, path, meta):
        self.path = Path(path)
        self.meta = meta
        data = self.path.read_bytes()
        if data[:4] != b"WDC1":
            raise RuntimeError("%s is not WDC1" % self.path.name)
        hdr = HEADER.unpack_from(data, 0)
        self.record_count = hdr[1]
        self.field_count = hdr[2]
        self.record_size = hdr[3]
        self.string_table_size = hdr[4]
        self.layout_hash = hdr[6]
        self.min_id = hdr[7]
        self.max_id = hdr[8]
        self.copy_table_size = hdr[10]
        self.flags = hdr[11]
        self.total_field_count = hdr[13]
        self.packed_data_offset = hdr[14]
        self.parent_lookup_count = hdr[15]
        self.id_table_size = hdr[17]
        self.column_meta_size = hdr[18]
        self.sparse = bool(self.flags & 1)
        if self.layout_hash != meta.layout_hash:
            raise RuntimeError(
                "%s layout hash %08X != server meta %08X" % (self.path.name, self.layout_hash, meta.layout_hash)
            )
        expected = meta.field_count
        if meta.parent_field >= self.field_count:
            expected = self.field_count + 1
        if self.field_count != meta.field_count and expected != meta.field_count:
            raise RuntimeError("%s field count %s != meta %s" % (self.path.name, self.field_count, meta.field_count))

        pos = HEADER.size
        self.field_entries = [FIELD_ENTRY.unpack_from(data, pos + i * 4) for i in range(self.field_count)]
        pos += 4 * self.field_count

        if self.sparse:
            catalog_count = self.max_id - self.min_id + 1
            data_end = pos
            # CatalogDataOffset is absolute. Recover it from the header field index 16.
            catalog_offset = hdr[16]
            self.records_blob = data[pos:catalog_offset]
            self.data_start = pos
            pos = catalog_offset
            self.catalog = []
            for _ in range(catalog_count):
                self.catalog.append(CATALOG.unpack_from(data, pos))
                pos += CATALOG.size
            self.string_table = b""
            self.id_table = []
            self.copies = []
            self.columns = []
            self.parents = {}
        else:
            blob_size = self.record_size * self.record_count + self.string_table_size
            blob = data[pos:pos + blob_size]
            pos += blob_size
            self.records_blob = blob[: self.record_size * self.record_count]
            self.string_table = blob[self.record_size * self.record_count :]
            self.id_table = []
            if not meta.has_index and self.id_table_size:
                count = self.id_table_size // 4
                self.id_table = list(struct.unpack_from("<%dI" % count, data, pos))
                pos += self.id_table_size
            copy_count = self.copy_table_size // 8
            self.copies = [COPY.unpack_from(data, pos + i * 8) for i in range(copy_count)]
            pos += self.copy_table_size
            self.columns = []
            for i in range(self.total_field_count):
                bit_off, bit_size, extra, comp, a, b, c = COLUMN_META.unpack_from(data, pos + i * COLUMN_META.size)
                signed = bool(data[pos + i * COLUMN_META.size + 20]) if comp == IMMEDIATE else False
                self.columns.append({
                    "comp": comp,
                    "extra": extra,
                    "bit_offset": a if comp in (IMMEDIATE, PALLET, PALLET_ARRAY) else bit_off,
                    "bit_width": b if comp in (IMMEDIATE, PALLET, PALLET_ARRAY) else 0,
                    "array_size": c if comp == PALLET_ARRAY else 0,
                    "signed": signed,
                    "common_default": a if comp == COMMON_DATA else 0,
                })
            pos += self.column_meta_size
            self.pallets = {}
            self.pallet_arrays = {}
            self.common = {}
            for i, col in enumerate(self.columns):
                if col["comp"] != PALLET or not col["extra"]:
                    continue
                n = col["extra"] // 4
                self.pallets[i] = list(struct.unpack_from("<%dI" % n, data, pos))
                pos += col["extra"]
            for i, col in enumerate(self.columns):
                if col["comp"] != PALLET_ARRAY or not col["extra"]:
                    continue
                n = col["extra"] // 4
                self.pallet_arrays[i] = list(struct.unpack_from("<%dI" % n, data, pos))
                pos += col["extra"]
            for i, col in enumerate(self.columns):
                if col["comp"] != COMMON_DATA or not col["extra"]:
                    continue
                n = col["extra"] // 8
                values = {}
                for rec, val in struct.iter_unpack("<II", data[pos:pos + col["extra"]]):
                    values[rec] = val
                self.common[i] = values
                pos += n * 8
        self.parents = {}
        if self.parent_lookup_count:
            num_entries = struct.unpack_from("<I", data, pos)[0]
            pos += 12
            for _i in range(num_entries):
                parent_id, record_index = struct.unpack_from("<II", data, pos)
                pos += 8
                self.parents[record_index] = parent_id

    def _record_bytes(self, index):
        start = index * self.record_size
        return self.records_blob[start:start + self.record_size]

    def _field_offset(self, col):
        comp = col["comp"]
        if comp == NONE:
            return col["bit_offset"] // 8 if "raw_bit_offset" in col else 0

    def _regular_offset(self, index):
        col = self.columns[index]
        if col["comp"] == NONE:
            return self._column_bit_offset(index) // 8
        if col["comp"] in (IMMEDIATE, PALLET, PALLET_ARRAY):
            return col["bit_offset"] // 8 + self.packed_data_offset
        return None

    def _column_bit_offset(self, index):
        # NONE compression stores the byte offset in the column header BitOffset, not the union.
        raw = COLUMN_NONE_OFFSETS[id(self)][index]
        return raw

    def _value_at(self, record, record_index, field, array_index, type_char, signed):
        col = self.columns[field]
        comp = col["comp"]
        if comp == NONE:
            off = (col["header_bit_offset"] // 8) + _type_size(type_char) * array_index
            return _read_plain(record, off, type_char, signed, self.string_table)
        if comp == IMMEDIATE:
            off = col["bit_offset"] // 8 + self.packed_data_offset
            bits = _packed(record, off, col["bit_width"], col["bit_offset"])
            if col["signed"]:
                bits = _sign_extend(bits, col["bit_width"])
            if type_char == "f":
                return _as_float(bits)
            return int(bits)
        if comp == COMMON_DATA:
            rid = self._row_id(record, record_index)
            raw = self.common.get(field, {}).get(rid, col["common_default"])
            if type_char == "f":
                return _as_float(raw)
            width = {"b": 1, "h": 2, "i": 4, "l": 8}.get(type_char, 4)
            return _as_signed(raw, width, signed)
        if comp == PALLET:
            off = col["bit_offset"] // 8 + self.packed_data_offset
            idx = _packed(record, off, col["bit_width"], col["bit_offset"])
            raw = self.pallets[field][idx]
            if type_char == "f":
                return _as_float(raw)
            width = {"b": 1, "h": 2, "i": 4, "l": 8}.get(type_char, 4)
            return _as_signed(raw, width, signed)
        if comp == PALLET_ARRAY:
            off = col["bit_offset"] // 8 + self.packed_data_offset
            idx = _packed(record, off, col["bit_width"], col["bit_offset"])
            raw = self.pallet_arrays[field][idx * col["array_size"] + array_index]
            if type_char == "f":
                return _as_float(raw)
            width = {"b": 1, "h": 2, "i": 4, "l": 8}.get(type_char, 4)
            return _as_signed(raw, width, signed)
        raise RuntimeError("Unhandled compression %s in %s" % (comp, self.path.name))

    def _row_id(self, record, record_index):
        if self.meta.has_index:
            signed, type_char, _name = self._index_field_meta()
            return self._value_at(record, record_index, self.meta.index_field, 0, type_char, signed)
        return self.id_table[record_index]

    def _index_field_meta(self):
        # Walk load-info fields the same way the server maps names onto file fields.
        slot = 0 if self.meta.has_index else 1
        seen = 0
        for field, size in enumerate(self.meta.array_sizes):
            for _arr in range(size):
                if field == self.meta.index_field and _arr == 0:
                    return self.meta.fields[slot]
                slot += 1
                seen += 1
        raise RuntimeError("Index field missing in %s" % self.meta.name)

    def rows(self):
        if self.sparse:
            return list(self._sparse_rows())
        out = []
        for i in range(self.record_count):
            record = self._record_bytes(i)
            rid = self._row_id(record, i)
            out.append((rid, self._expand(record, i)))
        by_id = {rid: values for rid, values in out}
        id_at = self._id_column()
        for new_id, source_id in self.copies:
            if source_id in by_id:
                cloned = list(by_id[source_id])
                cloned[id_at] = new_id
                out.append((new_id, cloned))
                by_id[new_id] = cloned
        return out

    def _expand(self, record, record_index):
        values = []
        slot = 0
        if not self.meta.has_index:
            values.append(self._row_id(record, record_index))
            slot = 1
        for field, size in enumerate(self.meta.array_sizes):
            for arr in range(size):
                signed, type_char, _name = self.meta.fields[slot]
                if field == self.meta.parent_field and field >= self.field_count:
                    values.append(self.parents.get(record_index, 0))
                else:
                    values.append(self._value_at(record, record_index, field, arr, type_char, signed))
                slot += 1
        return values

    def header(self):
        return [name for _signed, _kind, name in self.meta.fields]

    def _sparse_rows(self):
        for index, (file_off, rec_size) in enumerate(self.catalog):
            if not file_off or not rec_size:
                continue
            raw = self.records_blob[file_off - self.data_start: file_off - self.data_start + rec_size]
            offsets = _sparse_offsets(raw, self.meta, self.field_entries)
            values = []
            slot = 0
            flat = 0
            if not self.meta.has_index:
                values.append(self.min_id + index)
                slot = 1
            for field, size in enumerate(self.meta.array_sizes):
                for _arr in range(size):
                    signed, type_char, _name = self.meta.fields[slot]
                    values.append(_sparse_value(raw, offsets[flat], self.field_entries[field], type_char, signed))
                    slot += 1
                    flat += 1
            if self.meta.has_index:
                rid = values[self._id_column()]
            else:
                rid = self.min_id + index
            yield rid, values

    def _id_column(self):
        for i, (_s, _t, name) in enumerate(self.meta.fields):
            if name == "ID":
                return i
        return 0


# Filled while parsing NONE-compression header bit offsets. Kept off the column
# dict so Immediate union fields are not confused with the header BitOffset.
COLUMN_NONE_OFFSETS = {}


def _type_size(type_char):
    return {"b": 1, "h": 2, "i": 4, "l": 8, "f": 4, "s": 4, "S": 4}[type_char]


def _read_plain(record, offset, type_char, signed, string_table):
    if type_char in ("s", "S"):
        str_off = struct.unpack_from("<I", record, offset)[0]
        end = string_table.find(b"\x00", str_off)
        return string_table[str_off:end].decode("utf-8", errors="replace")
    size = _type_size(type_char)
    raw = record[offset:offset + size]
    if type_char == "f":
        return struct.unpack("<f", raw)[0]
    bits = int.from_bytes(raw, "little")
    return _as_signed(bits, size, signed)


def _sparse_offsets(raw, meta, field_entries):
    offsets = []
    pos = 0
    slot = 0 if meta.has_index else 1
    for field, size in enumerate(meta.array_sizes):
        unused = field_entries[field][0]
        width = 4 - (unused // 8)
        for _arr in range(size):
            offsets.append(pos)
            type_char = meta.fields[slot][1]
            if type_char in ("s", "S"):
                end = raw.find(b"\x00", pos)
                pos = end + 1
            elif type_char == "f":
                pos += 4
            else:
                pos += width
            slot += 1
    return offsets


def _sparse_value(raw, offset, field_entry, type_char, signed):
    if type_char in ("s", "S"):
        end = raw.find(b"\x00", offset)
        return raw[offset:end].decode("utf-8", errors="replace")
    if type_char == "f":
        return struct.unpack_from("<f", raw, offset)[0]
    unused = field_entry[0]
    width = 4 - (unused // 8)
    bits = int.from_bytes(raw[offset:offset + width], "little")
    return _as_signed(bits, width, signed)


def open_table(name, metas=None):
    metas = metas or load_metas([name])
    path = DBC_DIR / ("%s.db2" % name)
    table = Wdc1Table(path, metas[name])
    _attach_none_offsets(table)
    return table


def _attach_none_offsets(table):
    if table.sparse:
        return
    # Re-read header bit offsets; COLUMN_META union overwrites them in the dict.
    data = table.path.read_bytes()
    pos = HEADER.size + 4 * table.field_count
    if not table.sparse:
        pos += table.record_size * table.record_count + table.string_table_size
        if not table.meta.has_index and table.id_table_size:
            pos += table.id_table_size
        pos += table.copy_table_size
    for i, col in enumerate(table.columns):
        bit_off = struct.unpack_from("<H", data, pos + i * COLUMN_META.size)[0]
        col["header_bit_offset"] = bit_off


def write_csv(table, dest):
    dest = Path(dest)
    dest.parent.mkdir(parents=True, exist_ok=True)
    with dest.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(table.header())
        for _rid, values in table.rows():
            writer.writerow(_cell(v) for v in values)


def _cell(value):
    if isinstance(value, float):
        return ("%.6g" % value)
    return value
