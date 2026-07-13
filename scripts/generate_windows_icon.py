#!/usr/bin/env python3
"""Generate the Windows ICO from the canonical VAGINA application artwork.

Uses only the Python standard library. The canonical 1536 px source is evenly
box-filtered to standard Windows icon sizes and embedded as PNG-compressed ICO
entries.
"""

from __future__ import annotations

import binascii
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/icons/ios/iTunesArtwork@3x.png"
OUTPUT = ROOT / "windows/runner/resources/app_icon.ico"
SIZES = (16, 24, 32, 48, 64, 128, 256)
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def read_rgba_png(path: Path) -> tuple[int, int, list[bytes]]:
    data = path.read_bytes()
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError(f"Canonical artwork is not PNG: {path}")

    position = len(PNG_SIGNATURE)
    width = height = bit_depth = color_type = None
    compressed = bytearray()
    while position < len(data):
        length = struct.unpack_from(">I", data, position)[0]
        chunk_type = data[position + 4 : position + 8]
        chunk_data = data[position + 8 : position + 8 + length]
        position += length + 12
        if chunk_type == b"IHDR":
            width, height, bit_depth, color_type, compression, filtering, interlace = struct.unpack(
                ">IIBBBBB", chunk_data
            )
            if (bit_depth, color_type, compression, filtering, interlace) != (8, 6, 0, 0, 0):
                raise ValueError("Canonical PNG must be non-interlaced 8-bit RGBA")
        elif chunk_type == b"IDAT":
            compressed.extend(chunk_data)
        elif chunk_type == b"IEND":
            break

    if width is None or height is None:
        raise ValueError("Canonical PNG has no IHDR")

    raw = zlib.decompress(compressed)
    stride = width * 4
    rows: list[bytes] = []
    previous = bytearray(stride)
    offset = 0
    for _ in range(height):
        filter_type = raw[offset]
        offset += 1
        scanline = bytearray(raw[offset : offset + stride])
        offset += stride
        for index in range(stride):
            left = scanline[index - 4] if index >= 4 else 0
            above = previous[index]
            upper_left = previous[index - 4] if index >= 4 else 0
            if filter_type == 1:
                scanline[index] = (scanline[index] + left) & 0xFF
            elif filter_type == 2:
                scanline[index] = (scanline[index] + above) & 0xFF
            elif filter_type == 3:
                scanline[index] = (scanline[index] + ((left + above) // 2)) & 0xFF
            elif filter_type == 4:
                estimate = left + above - upper_left
                distances = (
                    abs(estimate - left),
                    abs(estimate - above),
                    abs(estimate - upper_left),
                )
                predictor = (left, above, upper_left)[distances.index(min(distances))]
                scanline[index] = (scanline[index] + predictor) & 0xFF
            elif filter_type != 0:
                raise ValueError(f"Unsupported PNG filter: {filter_type}")
        rows.append(bytes(scanline))
        previous = scanline
    return width, height, rows


def resize_box(rows: list[bytes], source_size: int, target_size: int) -> bytes:
    if source_size % target_size:
        raise ValueError(f"{source_size} is not evenly divisible by {target_size}")
    scale = source_size // target_size
    sample_count = scale * scale
    result = bytearray(target_size * target_size * 4)
    for target_y in range(target_size):
        for target_x in range(target_size):
            totals = [0, 0, 0, 0]
            for source_y in range(target_y * scale, (target_y + 1) * scale):
                row = rows[source_y]
                for source_x in range(target_x * scale, (target_x + 1) * scale):
                    offset = source_x * 4
                    for channel in range(4):
                        totals[channel] += row[offset + channel]
            output_offset = (target_y * target_size + target_x) * 4
            for channel in range(4):
                result[output_offset + channel] = (totals[channel] + sample_count // 2) // sample_count
    return bytes(result)


def png_chunk(chunk_type: bytes, payload: bytes) -> bytes:
    return (
        struct.pack(">I", len(payload))
        + chunk_type
        + payload
        + struct.pack(">I", binascii.crc32(chunk_type + payload) & 0xFFFFFFFF)
    )


def encode_rgba_png(size: int, pixels: bytes) -> bytes:
    stride = size * 4
    scanlines = b"".join(
        b"\x00" + pixels[offset : offset + stride]
        for offset in range(0, len(pixels), stride)
    )
    header = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)
    return (
        PNG_SIGNATURE
        + png_chunk(b"IHDR", header)
        + png_chunk(b"IDAT", zlib.compress(scanlines, level=9))
        + png_chunk(b"IEND", b"")
    )


def build_ico(images: list[tuple[int, bytes]]) -> bytes:
    directory_size = 6 + len(images) * 16
    offset = directory_size
    entries = bytearray()
    payloads = bytearray()
    for size, payload in images:
        dimension = 0 if size == 256 else size
        entries.extend(
            struct.pack(
                "<BBBBHHII",
                dimension,
                dimension,
                0,
                0,
                1,
                32,
                len(payload),
                offset,
            )
        )
        payloads.extend(payload)
        offset += len(payload)
    return struct.pack("<HHH", 0, 1, len(images)) + entries + payloads


def main() -> None:
    width, height, rows = read_rgba_png(SOURCE)
    if width != height or width != 1536:
        raise ValueError(f"Canonical artwork must be 1536x1536, got {width}x{height}")
    images = [
        (size, encode_rgba_png(size, resize_box(rows, width, size)))
        for size in SIZES
    ]
    OUTPUT.write_bytes(build_ico(images))
    print(f"Generated {OUTPUT.relative_to(ROOT)} from {SOURCE.relative_to(ROOT)}")
    print("ICO sizes: " + ", ".join(f"{size}x{size}" for size in SIZES))


if __name__ == "__main__":
    main()
