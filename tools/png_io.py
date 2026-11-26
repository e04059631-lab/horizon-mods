"""Zero-dependency PNG RGBA reader and writer for Horizon 26.3 resourcepack builder."""

import struct
import zlib
from pathlib import Path


def _paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa = abs(p - a)
    pb = abs(p - b)
    pc = abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def read_png_rgba(path: str | Path) -> tuple[int, int, bytearray]:
    """Reads any standard 8-bit PNG (Gray, RGB, Palette+tRNS, Gray+Alpha, RGBA) into RGBA8 bytearray."""
    data = Path(path).read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"Not a PNG file: {path}")

    pos = 8
    width = height = bit_depth = color_type = interlace = 0
    palette: list[tuple[int, int, int]] = []
    trns = b""
    idat_chunks: list[bytes] = []

    while pos < len(data):
        length = struct.unpack(">I", data[pos : pos + 4])[0]
        ctype = data[pos + 4 : pos + 8]
        chunk_data = data[pos + 8 : pos + 8 + length]
        pos += 12 + length

        if ctype == b"IHDR":
            width, height, bit_depth, color_type, _, _, interlace = struct.unpack(">IIBBBBB", chunk_data)
            if interlace != 0:
                raise ValueError(f"Interlaced PNG unsupported: {path}")
        elif ctype == b"PLTE":
            palette = [
                (chunk_data[i], chunk_data[i + 1], chunk_data[i + 2])
                for i in range(0, len(chunk_data), 3)
            ]
        elif ctype == b"tRNS":
            trns = chunk_data
        elif ctype == b"IDAT":
            idat_chunks.append(chunk_data)
        elif ctype == b"IEND":
            break

    raw = zlib.decompress(b"".join(idat_chunks))

    # Determine bits/bytes per pixel for filter reconstruction
    channels_map = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}
    ch = channels_map[color_type]
    bits_per_pixel = ch * bit_depth
    bpp = max(1, (bits_per_pixel + 7) // 8)
    stride = (width * bits_per_pixel + 7) // 8

    recon = bytearray(height * stride)
    in_pos = 0
    for y in range(height):
        ftype = raw[in_pos]
        in_pos += 1
        row_out = y * stride
        prev_row = (y - 1) * stride
        for x in range(stride):
            val = raw[in_pos + x]
            left = recon[row_out + x - bpp] if x >= bpp else 0
            up = recon[prev_row + x] if y > 0 else 0
            up_left = recon[prev_row + x - bpp] if (y > 0 and x >= bpp) else 0
            if ftype == 0:
                r = val
            elif ftype == 1:
                r = (val + left) & 0xFF
            elif ftype == 2:
                r = (val + up) & 0xFF
            elif ftype == 3:
                r = (val + ((left + up) >> 1)) & 0xFF
            elif ftype == 4:
                r = (val + _paeth(left, up, up_left)) & 0xFF
            else:
                raise ValueError(f"Unknown PNG filter {ftype} in {path}")
            recon[row_out + x] = r
        in_pos += stride

    out = bytearray(width * height * 4)
    for y in range(height):
        row = recon[y * stride : (y + 1) * stride]
        for x in range(width):
            dst = (y * width + x) * 4
            if bit_depth < 8:
                # Unpack 1/2/4-bit grayscale or palette indices
                per_byte = 8 // bit_depth
                byte_val = row[x // per_byte]
                shift = (per_byte - 1 - (x % per_byte)) * bit_depth
                idx = (byte_val >> shift) & ((1 << bit_depth) - 1)
                if color_type == 3:
                    r, g, b = palette[idx]
                    a = trns[idx] if idx < len(trns) else 255
                else:
                    g = (idx * 255) // ((1 << bit_depth) - 1)
                    r = b = g
                    a = 255
            elif bit_depth == 8:
                if color_type == 6:
                    s = x * 4
                    r, g, b, a = row[s], row[s + 1], row[s + 2], row[s + 3]
                elif color_type == 2:
                    s = x * 3
                    r, g, b = row[s], row[s + 1], row[s + 2]
                    a = 255
                    if len(trns) >= 6:
                        tr, tg, tb = trns[1], trns[3], trns[5]
                        if (r, g, b) == (tr, tg, tb):
                            a = 0
                elif color_type == 3:
                    idx = row[x]
                    r, g, b = palette[idx]
                    a = trns[idx] if idx < len(trns) else 255
                elif color_type == 4:
                    s = x * 2
                    r = g = b = row[s]
                    a = row[s + 1]
                elif color_type == 0:
                    r = g = b = row[x]
                    a = 255
                    if len(trns) >= 2 and r == trns[1]:
                        a = 0
                else:
                    raise ValueError(f"Unsupported color_type {color_type}")
            elif bit_depth == 16:
                if color_type == 6:
                    s = x * 8
                    r, g, b, a = row[s], row[s + 2], row[s + 4], row[s + 6]
                elif color_type == 2:
                    s = x * 6
                    r, g, b, a = row[s], row[s + 2], row[s + 4], 255
                else:
                    r = g = b = row[x * 2]
                    a = 255
            else:
                raise ValueError(f"Unsupported bit_depth {bit_depth}")
            out[dst] = r
            out[dst + 1] = g
            out[dst + 2] = b
            out[dst + 3] = a

    return width, height, out


def _chunk(ctype: bytes, payload: bytes) -> bytes:
    crc = zlib.crc32(ctype + payload) & 0xFFFFFFFF
    return struct.pack(">I", len(payload)) + ctype + payload + struct.pack(">I", crc)


def write_png_rgba(path: str | Path, width: int, height: int, rgba: bytes | bytearray) -> None:
    """Writes an RGBA8 buffer to a standard PNG file."""
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    stride = width * 4
    raw = bytearray(height * (1 + stride))
    for y in range(height):
        out_row = y * (1 + stride)
        raw[out_row] = 0  # Filter None (optimal & fast for small textures)
        src = y * stride
        raw[out_row + 1 : out_row + 1 + stride] = rgba[src : src + stride]
    compressed = zlib.compress(bytes(raw), level=9)
    png_bytes = (
        b"\x89PNG\r\n\x1a\n"
        + _chunk(b"IHDR", ihdr)
        + _chunk(b"IDAT", compressed)
        + _chunk(b"IEND", b"")
    )
    p.write_bytes(png_bytes)
