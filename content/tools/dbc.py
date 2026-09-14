"""Minimal WDBC (DBC) reader/writer for WoW 1.12 client files.

Format:
    header  4s  magic 'WDBC'
            I   record count
            I   field count
            I   record size (bytes)
            I   string block size
    records record_count * record_size bytes, each field_count uint32s
    strings string block; a string field holds a BYTE OFFSET into this block,
            offset 0 is the empty string

Strings are the only subtle part: a record's "name" field is not text, it is an
offset into the trailing string block. Appending a record therefore means appending
its strings to that block and storing the resulting offsets.
"""

import struct

HEADER = struct.Struct("<4sIIII")
MAGIC = b"WDBC"


class Dbc(object):
    def __init__(self, data):
        magic, nrec, nfield, recsize, sblock = HEADER.unpack_from(data, 0)
        if magic != MAGIC:
            raise ValueError("not a WDBC file (magic %r)" % magic)
        expected = HEADER.size + nrec * recsize + sblock
        if len(data) != expected:
            raise ValueError("size %d != header-implied %d" % (len(data), expected))
        if recsize != nfield * 4:
            raise ValueError("record size %d is not field count %d * 4 - "
                             "this file has non-uint32 fields" % (recsize, nfield))

        self.field_count = nfield
        self.record_size = recsize
        off = HEADER.size
        self.records = [
            list(struct.unpack_from("<%dI" % nfield, data, off + i * recsize))
            for i in range(nrec)
        ]
        self.strings = bytearray(data[off + nrec * recsize:])

    # ---------------------------------------------------------------- strings
    def get_string(self, offset):
        if offset == 0 or offset >= len(self.strings):
            return ""
        end = self.strings.find(b"\x00", offset)
        return self.strings[offset:end].decode("utf-8", "replace")

    def add_string(self, text):
        """Append a string, returning its offset. Empty text reuses offset 0."""
        if not text:
            return 0
        raw = text.encode("utf-8") + b"\x00"
        # reuse an identical existing string where possible, keeping the block small
        found = self.strings.find(raw)
        if found != -1 and (found == 0 or self.strings[found - 1] == 0):
            return found
        offset = len(self.strings)
        self.strings += raw
        return offset

    # ---------------------------------------------------------------- records
    def index_by_id(self):
        """Map field 0 (the id) to its record index."""
        return dict((r[0], i) for i, r in enumerate(self.records))

    def new_record(self, template_index=None):
        """A blank record, or a copy of an existing one to inherit sane defaults."""
        if template_index is None:
            return [0] * self.field_count
        return list(self.records[template_index])

    def pack(self):
        out = bytearray()
        out += HEADER.pack(MAGIC, len(self.records), self.field_count,
                           self.record_size, len(self.strings))
        fmt = struct.Struct("<%dI" % self.field_count)
        for r in self.records:
            if len(r) != self.field_count:
                raise ValueError("record has %d fields, expected %d"
                                 % (len(r), self.field_count))
            out += fmt.pack(*r)
        out += self.strings
        return bytes(out)


def load(path):
    with open(path, "rb") as f:
        return Dbc(f.read())
