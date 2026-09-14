"""Minimal MPQ v1 writer, enough to build a WoW 1.12 patch archive.

Verified by round-tripping output through mpyq (an independent implementation) and
byte-comparing, which is what this module's users should keep doing.

Files are stored UNCOMPRESSED with MPQ_FILE_SINGLE_UNIT. That flag matters: without
it a reader expects the file split into sectors preceded by a sector offset table,
and an uncompressed file has no such table, so readers that assume one get garbage.
Single-unit removes the ambiguity and is a flag Blizzard's own archives use.
"""

import struct

FLAG_EXISTS = 0x80000000
FLAG_SINGLE_UNIT = 0x01000000
HEADER_SIZE = 32

_crypt = [0] * 0x500


def _init_crypt():
    seed = 0x00100001
    for i in range(0x100):
        for j in range(5):
            seed = (seed * 125 + 3) % 0x2AAAAB
            a = (seed & 0xFFFF) << 0x10
            seed = (seed * 125 + 3) % 0x2AAAAB
            b = seed & 0xFFFF
            _crypt[i + j * 0x100] = (a | b) & 0xFFFFFFFF


_init_crypt()


def hash_string(s, hash_type):
    """Standard MPQ string hash.

    hash_type is passed ALREADY SCALED (0, 0x100, 0x200, 0x300) and indexes the crypt
    table directly. Shifting it again runs off the end of the table.
    """
    seed1, seed2 = 0x7FED7FED, 0xEEEEEEEE
    for ch in s.upper():
        c = ord(ch)
        seed1 = (_crypt[hash_type + c] ^ (seed1 + seed2)) & 0xFFFFFFFF
        seed2 = (c + seed1 + seed2 + (seed2 << 5) + 3) & 0xFFFFFFFF
    return seed1


def encrypt(data, key):
    out = bytearray(data)
    seed2 = 0xEEEEEEEE
    for i in range(0, len(out) - 3, 4):
        seed2 = (seed2 + _crypt[0x400 + (key & 0xFF)]) & 0xFFFFFFFF
        raw = struct.unpack_from("<I", out, i)[0]
        struct.pack_into("<I", out, i, (raw ^ ((key + seed2) & 0xFFFFFFFF)) & 0xFFFFFFFF)
        key = (((~key << 0x15) + 0x11111111) | (key >> 0x0B)) & 0xFFFFFFFF
        seed2 = (raw + seed2 + (seed2 << 5) + 3) & 0xFFFFFFFF
    return bytes(out)


def build(files):
    """files: list of (archive_path, bytes). Returns the archive as bytes."""
    hash_size = 16
    while hash_size < len(files) * 2:
        hash_size *= 2

    blocks, blobs, pos = [], [], HEADER_SIZE
    for _, data in files:
        blocks.append((pos, len(data), len(data), FLAG_EXISTS | FLAG_SINGLE_UNIT))
        blobs.append(data)
        pos += len(data)

    hash_pos = pos
    block_pos = hash_pos + hash_size * 16
    archive_size = block_pos + len(files) * 16

    ht = bytearray(b"\xFF" * (hash_size * 16))
    for idx, (name, _) in enumerate(files):
        start = hash_string(name, 0) & (hash_size - 1)
        for probe in range(hash_size):
            slot = (start + probe) % hash_size
            if struct.unpack_from("<I", ht, slot * 16 + 12)[0] == 0xFFFFFFFF:
                struct.pack_into("<IIHHI", ht, slot * 16,
                                 hash_string(name, 0x100), hash_string(name, 0x200),
                                 0, 0, idx)
                break
        else:
            raise RuntimeError("hash table full")

    bt = bytearray()
    for fpos, csize, fsize, flags in blocks:
        bt += struct.pack("<IIII", fpos, csize, fsize, flags)

    out = bytearray()
    out += struct.pack("<4sIIHHIIII", b"MPQ\x1A", HEADER_SIZE, archive_size, 0, 3,
                       hash_pos, block_pos, hash_size, len(files))
    for blob in blobs:
        out += blob
    out += encrypt(bytes(ht), hash_string("(hash table)", 0x300))
    out += encrypt(bytes(bt), hash_string("(block table)", 0x300))
    return bytes(out)


def verify(path, expected):
    """Read the archive back with mpyq and byte-compare. expected: {name: bytes}."""
    import mpyq
    archive = mpyq.MPQArchive(path, listfile=False)
    for name, want in expected.items():
        got = archive.read_file(name)
        if got is None:
            raise RuntimeError("VERIFY FAILED: %s missing from archive" % name)
        if got != want:
            raise RuntimeError("VERIFY FAILED: %s is %d bytes, expected %d"
                               % (name, len(got), len(want)))
    return True
