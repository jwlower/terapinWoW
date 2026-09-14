"""BLP2 writer and reader, enough for WoW 1.12 interface icons.

WHY WRITE ONE RATHER THAN FIND A TOOL
  No BLP converter was installed, and the format is small enough to implement exactly. That
  also means the pipeline has no external dependency for anyone who clones the repo.

FORMAT (BLP2, as the 1.12 client uses)
    0   char[4]     'BLP2'
    4   uint32      version                 (1)
    8   uint8       colorEncoding           1 = palettised, 2 = DXT
    9   uint8       alphaDepth              0, 1 or 8
    10  uint8       alphaEncoding           0
    11  uint8       hasMips                 1
    12  uint32      width
    16  uint32      height
    20  uint32[16]  mipOffsets
    84  uint32[16]  mipSizes
    148 BGRA[256]   palette                 (present even when unused)
    1172            pixel data

WHY PALETTISED AND NOT DXT
  The client's own icons are colorEncoding 2 (DXT1). Palettised (1) is also supported and is
  the better choice here: DXT1 compresses 4x4 blocks to two RGB565 endpoints, which smears
  the hard edges and thin borders that icons are made of. A 256-colour palette reproduces a
  64x64 icon almost exactly, and the file is still tiny.

  One palette is shared by every mip level - that is required, since the header has room for
  exactly one.
"""
import struct

HEADER_SIZE = 148
PALETTE_SIZE = 256 * 4
DATA_START = HEADER_SIZE + PALETTE_SIZE

COLOR_PALETTISED = 1
COLOR_DXT = 2


def _mip_sizes(width, height):
    """Successive halvings down to 1x1, which is what hasMips=1 implies."""
    out = []
    w, h = width, height
    while True:
        out.append((w, h))
        if w == 1 and h == 1:
            break
        w = max(1, w // 2)
        h = max(1, h // 2)
    return out


def _rgb565(r, g, b):
    return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)


def _unpack565(c):
    r = (c >> 11) & 0x1F
    g = (c >> 5) & 0x3F
    b = c & 0x1F
    return (r << 3) | (r >> 2), (g << 2) | (g >> 4), (b << 3) | (b >> 2)


def _encode_dxt1_block(block):
    """One 4x4 RGB block -> 8 DXT1 bytes.

    Endpoints are the bounding box of the block's colours, which is the classic cheap
    encoder: not optimal, but well within tolerance for 64x64 icon art and utterly
    predictable. color0 > color1 selects the opaque 4-colour mode.
    """
    import numpy as np

    mn = block.min(axis=0)
    mx = block.max(axis=0)
    c0 = _rgb565(int(mx[0]), int(mx[1]), int(mx[2]))
    c1 = _rgb565(int(mn[0]), int(mn[1]), int(mn[2]))

    if c0 == c1:
        # Flat block. Index 0 selects color0 in both modes, so this is safe either way.
        return struct.pack("<HHI", c0, c1, 0)
    if c0 < c1:
        c0, c1 = c1, c0

    # int32 throughout, NOT int16.
    #
    # The squared distance between black and white is 3 * 255^2 = 195075, which overflows a
    # signed 16-bit maximum of 32767 and wraps NEGATIVE - so argmin then selects the
    # farthest colour as the nearest. It corrupted precisely the high-contrast blocks: the
    # edges and highlights that icons are made of, which rendered as bright speckle.
    e0 = np.array(_unpack565(c0), dtype=np.int32)
    e1 = np.array(_unpack565(c1), dtype=np.int32)
    palette = np.stack([e0, e1,
                        (2 * e0 + e1) // 3,
                        (e0 + 2 * e1) // 3]).astype(np.int32)

    d = block.astype(np.int32)[:, None, :] - palette[None, :, :]
    idx = (d * d).sum(axis=2).argmin(axis=1)

    bits = 0
    for i in range(16):
        bits |= int(idx[i]) << (2 * i)
    return struct.pack("<HHI", c0, c1, bits)


def _encode_dxt1(image):
    """PIL RGB image -> DXT1 bytes, padding partial blocks by edge repetition."""
    import numpy as np

    w, h = image.size
    arr = np.asarray(image.convert("RGB"), dtype=np.uint8)
    out = bytearray()
    for by in range(0, max(h, 1), 4):
        for bx in range(0, max(w, 1), 4):
            block = np.zeros((16, 3), dtype=np.uint8)
            for y in range(4):
                for x in range(4):
                    # Mip levels below 4x4 still occupy one full block; clamping to the
                    # edge is what every encoder does and what the client expects.
                    sy = min(by + y, h - 1)
                    sx = min(bx + x, w - 1)
                    block[y * 4 + x] = arr[sy, sx]
            out += _encode_dxt1_block(block)
    return bytes(out)


def write_dxt1(image):
    """Encode a PIL image as DXT1 BLP2 - the format this client actually reads.

    WHY NOT PALETTISED
      Every icon sampled from the client is colorEncoding 2 (DXT); not one is palettised.
      A palettised file is therefore decoded AS DXT, which renders as a collage of garbage
      rather than failing cleanly. Matching the client's own encoding removes the question.

      The size arithmetic corroborates it: 64x64 DXT1 with 7 mips is 2744 bytes of data,
      plus the 148-byte header and the 1024-byte palette block (present but unused) = 3916,
      which is exactly the size of every 64x64 icon in the client.
    """
    from PIL import Image

    if image.mode != "RGB":
        image = image.convert("RGB")
    width, height = image.size

    mips, offsets, sizes = [], [0] * 16, [0] * 16
    offset = DATA_START
    for i, (w, h) in enumerate(_mip_sizes(width, height)):
        if i >= 16:
            break
        level = image if (w, h) == (width, height) else image.resize((w, h), Image.LANCZOS)
        data = _encode_dxt1(level)
        mips.append(data)
        offsets[i] = offset
        sizes[i] = len(data)
        offset += len(data)

    head = bytearray()
    head += b"BLP2"
    head += struct.pack("<I", 1)
    head += struct.pack("<BBBB", COLOR_DXT, 0, 0, 1)    # alphaDepth 0 = opaque DXT1
    head += struct.pack("<II", width, height)
    head += struct.pack("<16I", *offsets)
    head += struct.pack("<16I", *sizes)
    assert len(head) == HEADER_SIZE, len(head)

    # The palette block is unused by DXT but is still part of the layout.
    return bytes(head) + bytes(PALETTE_SIZE) + b"".join(mips)


def write(image, alpha_depth=8):
    """Encode a PIL RGBA image as palettised BLP2 bytes.

    RETAINED FOR REFERENCE - use write_dxt1 for anything the client must render. See the
    note there: this client reads only DXT, and a palettised file renders as garbage.

    The image must already be the size you want (64x64 for interface icons).
    """
    from PIL import Image

    if image.mode != "RGBA":
        image = image.convert("RGBA")
    width, height = image.size

    # One palette for every mip. Build it from the full-size image: the smaller levels are
    # derived from it, so its colours cover them.
    rgb = image.convert("RGB")
    quantised = rgb.quantize(colors=256, method=Image.MEDIANCUT)
    pal = quantised.getpalette()[:768]
    while len(pal) < 768:
        pal.append(0)

    palette_bytes = bytearray()
    for i in range(256):
        r, g, b = pal[i * 3], pal[i * 3 + 1], pal[i * 3 + 2]
        palette_bytes += bytes((b, g, r, 0))        # BGRA, alpha unused in the palette

    # A reference image carrying that palette, so every mip maps onto the same colours.
    ref = Image.new("P", (1, 1))
    ref.putpalette(pal)

    mips, offsets, sizes = [], [0] * 16, [0] * 16
    offset = DATA_START
    for i, (w, h) in enumerate(_mip_sizes(width, height)):
        if i >= 16:
            break
        level = image if (w, h) == (width, height) else image.resize((w, h), Image.LANCZOS)
        idx = level.convert("RGB").quantize(palette=ref, dither=Image.NONE)
        data = bytearray(idx.tobytes())
        if alpha_depth == 8:
            data += bytes(level.getchannel("A").tobytes())
        mips.append(bytes(data))
        offsets[i] = offset
        sizes[i] = len(data)
        offset += len(data)

    head = bytearray()
    head += b"BLP2"
    head += struct.pack("<I", 1)
    head += struct.pack("<BBBB", COLOR_PALETTISED, alpha_depth, 0, 1)
    head += struct.pack("<II", width, height)
    head += struct.pack("<16I", *offsets)
    head += struct.pack("<16I", *sizes)
    assert len(head) == HEADER_SIZE, len(head)

    return bytes(head) + bytes(palette_bytes) + b"".join(mips)


def read_header(data):
    """Parse a BLP2 header - used to verify what we wrote, and to inspect client icons."""
    if data[:4] != b"BLP2":
        raise ValueError("not BLP2: %r" % data[:4])
    version = struct.unpack("<I", data[4:8])[0]
    enc, alpha_depth, alpha_enc, has_mips = struct.unpack("<4B", data[8:12])
    width, height = struct.unpack("<II", data[12:20])
    offsets = struct.unpack("<16I", data[20:84])
    sizes = struct.unpack("<16I", data[84:148])
    return {
        "version": version, "colorEncoding": enc, "alphaDepth": alpha_depth,
        "alphaEncoding": alpha_enc, "hasMips": has_mips,
        "width": width, "height": height,
        "mips": [(o, s) for o, s in zip(offsets, sizes) if s],
    }


def decode_top_mip(data):
    """Decode mip 0 of a PALETTISED BLP2 back to a PIL RGBA image, for verification."""
    from PIL import Image

    h = read_header(data)
    if h["colorEncoding"] != COLOR_PALETTISED:
        raise ValueError("decode only supports palettised BLP2, got %d" % h["colorEncoding"])
    w, ht = h["width"], h["height"]
    palette = data[HEADER_SIZE:HEADER_SIZE + PALETTE_SIZE]
    off, _size = h["mips"][0]
    idx = data[off:off + w * ht]

    out = Image.new("RGBA", (w, ht))
    px = out.load()
    has_alpha = h["alphaDepth"] == 8
    alpha = data[off + w * ht: off + 2 * w * ht] if has_alpha else None
    for y in range(ht):
        for x in range(w):
            i = idx[y * w + x]
            b, g, r = palette[i * 4], palette[i * 4 + 1], palette[i * 4 + 2]
            a = alpha[y * w + x] if has_alpha else 255
            px[x, y] = (r, g, b, a)
    return out
