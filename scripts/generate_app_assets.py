#!/usr/bin/env python3
"""Generate the Proximeet demo app's asset catalog and privacy manifest.

Provenance
----------
Every file written by this script is produced procedurally by the code below
(Python standard library only: zlib, struct, json, plistlib). No external image,
font, icon set, stock asset, Figma export or legacy Proximeet/Halo artwork is
read, copied or traced. The app icon is an original abstract composition, "four
woven intent bands with bead-blasted aluminium clasps", drawn from the palette
in docs/design/PROXIMEET_SOCIAL_OBJECTS_DESIGN.md (Carbon stage; Social, Dating,
Business and Activity intent colours; aluminium greys). It is INTERIM artwork
for the demo milestone, not final brand art and not the photoreal material
target described in the design specification.

Outputs (relative to the repository root)
-----------------------------------------
  Proximeet/Resources/Assets.xcassets/Contents.json
  Proximeet/Resources/Assets.xcassets/AccentColor.colorset/Contents.json
  Proximeet/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json
  Proximeet/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
  Proximeet/Resources/PrivacyInfo.xcprivacy

The PNG is 1024x1024, 8-bit RGB (colour type 2, no alpha channel), with an sRGB
chunk and no timestamp or text chunks. Pixel data are a pure function of this
file. The compressed bytes are identical across runs with the same zlib build;
`--check` additionally accepts a PNG whose decoded pixels match exactly (so a
different zlib build does not produce a false failure).

The privacy manifest declares no tracking, no tracking domains, no collected
data types and no required-reason API use: the demo is offline and in-memory
and stores nothing.

Usage
-----
  python3 scripts/generate_app_assets.py           # write or update the files
  python3 scripts/generate_app_assets.py --check   # exit 1 if on-disk files differ
"""
from __future__ import annotations

import argparse
import json
import math
import plistlib
import struct
import sys
import zlib
from pathlib import Path
from typing import Callable

ROOT = Path(__file__).resolve().parent.parent
RESOURCES = "Proximeet/Resources"
CATALOG = f"{RESOURCES}/Assets.xcassets"
ICON_PATH = f"{CATALOG}/AppIcon.appiconset/AppIcon-1024.png"

RGB = tuple[int, int, int]


def rgb(hex_string: str) -> RGB:
    value = hex_string.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16))


# Palette (docs/design/PROXIMEET_SOCIAL_OBJECTS_DESIGN.md).
CARBON = rgb("#080A0B")
ALLOY_SHADOW = rgb("#25292D")
PORCELAIN_HEX = "#F5F6F2"
INTENT_COLORS = (
    ("Social", rgb("#35D7FF")),
    ("Dating", rgb("#FF56B8")),
    ("Business", rgb("#FFD542")),
    ("Activity", rgb("#70F455")),
)
CLASP_STOPS = (
    (0.0, rgb("#4A5459")),
    (0.45, rgb("#CCD2D5")),
    (1.0, rgb("#68747A")),
)

# Geometry (pixels). The artwork stays inside a 160 px safe margin so the iOS
# icon corner mask never clips it.
SIZE = 1024
MARGIN = 160
BAND_HEIGHT = 140
BAND_GAP = 48  # 4 * 140 + 3 * 48 == 704 == SIZE - 2 * MARGIN
BAND_LEFT = MARGIN
BAND_RIGHT = SIZE - MARGIN
BAND_RADIUS = 44
THREAD_PITCH = 24
THREAD_WIDTH = 3
THREAD_SHADE = 0.88  # ~12% darkening for the warp threads
SELVEDGE_ROWS = 5
STITCH_INSET = 18
CLASP_LEFT = 712
CLASP_RIGHT = 832
CLASP_OVERHANG = 10
CLASP_RADIUS = 18
CLASP_STEP = 8  # rows per gradient step: the "horizontal banding" of the metal
NOTCH_LEFT = CLASP_LEFT + 74
NOTCH_RIGHT = CLASP_LEFT + 88
NOTCH_INSET = 46
NOTCH_RADIUS = 7
SUPERSAMPLE = 4  # vertical sub-rows used for edge anti-aliasing

assert 4 * BAND_HEIGHT + 3 * BAND_GAP == SIZE - 2 * MARGIN


def clamp_byte(value: float) -> int:
    return max(0, min(255, int(value + 0.5)))


def shade(color: RGB, factor: float) -> bytes:
    return bytes(clamp_byte(channel * factor) for channel in color)


def rounded_span(yc: float, top: int, bottom: int, left: int, right: int,
                 radius: int) -> tuple[float, float] | None:
    """Horizontal extent [xl, xr) of a rounded rectangle at height yc."""
    if yc < top or yc >= bottom:
        return None
    if yc < top + radius:
        dy = top + radius - yc
    elif yc > bottom - radius:
        dy = yc - (bottom - radius)
    else:
        return (float(left), float(right))
    inset = radius - math.sqrt(max(0.0, radius * radius - dy * dy))
    return (left + inset, right - inset)


class Shape:
    """A rounded rectangle plus a fill function returning RGB bytes for [a, b)."""

    def __init__(self, top: int, bottom: int, left: int, right: int, radius: int,
                 fill: Callable[[int, int, int], bytes]) -> None:
        self.top, self.bottom, self.left, self.right = top, bottom, left, right
        self.radius = radius
        self.fill = fill

    def paint(self, row: bytearray, y: int) -> None:
        if y < self.top or y >= self.bottom:
            return
        spans = [
            rounded_span(y + (k + 0.5) / SUPERSAMPLE, self.top, self.bottom,
                         self.left, self.right, self.radius)
            for k in range(SUPERSAMPLE)
        ]
        valid = [span for span in spans if span is not None]
        if not valid:
            return
        lo = math.floor(min(span[0] for span in valid))
        hi = math.ceil(max(span[1] for span in valid))
        full_start = full_end = hi
        if len(valid) == SUPERSAMPLE:
            start = math.ceil(max(span[0] for span in valid))
            end = math.floor(min(span[1] for span in valid))
            if start < end:
                full_start, full_end = start, end
                row[3 * start:3 * end] = self.fill(y, start, end)
        for x in range(lo, hi):
            if full_start <= x < full_end:
                continue
            coverage = sum(
                max(0.0, min(x + 1.0, span[1]) - max(float(x), span[0])) for span in valid
            ) / SUPERSAMPLE
            if coverage <= 0.0:
                continue
            source = self.fill(y, x, x + 1)
            if coverage >= 1.0:
                row[3 * x:3 * x + 3] = source
                continue
            for channel in range(3):
                index = 3 * x + channel
                row[index] = clamp_byte(row[index] * (1.0 - coverage) + source[channel] * coverage)


def band_fill_factory(index: int, color: RGB, top: int) -> Callable[[int, int, int], bytes]:
    """Woven band: warp threads, selvedge, a dashed stitch line and clasp contact shadow."""
    cache: dict[int, bytes] = {}
    offset = (index % 2) * (THREAD_PITCH // 2)

    def row_bytes(y: int) -> bytes:
        local = y - top
        t = (local + 0.5) / BAND_HEIGHT
        roundness = 1.0 - 0.10 * (2.0 * t - 1.0) ** 2  # fabric curving away at the edges
        selvedge = local < SELVEDGE_ROWS or local >= BAND_HEIGHT - SELVEDGE_ROWS
        stitch = local in (STITCH_INSET, STITCH_INSET + 1) or local in (
            BAND_HEIGHT - STITCH_INSET - 2, BAND_HEIGHT - STITCH_INSET - 1)
        out = bytearray(3 * SIZE)
        for x in range(BAND_LEFT, BAND_RIGHT):
            factor = roundness
            if selvedge:
                factor *= 0.86
            if (x - BAND_LEFT + offset) % THREAD_PITCH < THREAD_WIDTH:
                factor *= THREAD_SHADE
            if stitch and BAND_LEFT + 40 <= x < CLASP_LEFT - 16 and (x - BAND_LEFT) % 18 < 10:
                factor *= 0.78
            if CLASP_LEFT - 12 <= x < CLASP_LEFT:
                factor *= 0.62 + 0.33 * (CLASP_LEFT - 1 - x) / 11.0
            elif CLASP_RIGHT <= x < CLASP_RIGHT + 8:
                factor *= 0.70 + 0.30 * (x - CLASP_RIGHT) / 7.0
            out[3 * x:3 * x + 3] = shade(color, factor)
        return bytes(out)

    def fill(y: int, a: int, b: int) -> bytes:
        if y not in cache:
            cache[y] = row_bytes(y)
        return cache[y][3 * a:3 * b]

    return fill


def clasp_fill_factory(top: int, bottom: int) -> Callable[[int, int, int], bytes]:
    """Bead-blasted aluminium: banded vertical gradient plus a fixed-hash stipple."""
    height = bottom - top

    def base_color(y: int) -> RGB:
        stepped = ((y - top) // CLASP_STEP) * CLASP_STEP + CLASP_STEP / 2.0
        t = max(0.0, min(1.0, stepped / (height - 1)))
        for (t0, c0), (t1, c1) in zip(CLASP_STOPS, CLASP_STOPS[1:]):
            if t <= t1:
                u = (t - t0) / (t1 - t0)
                return tuple(clamp_byte(c0[i] + (c1[i] - c0[i]) * u) for i in range(3))  # type: ignore[return-value]
        return CLASP_STOPS[-1][1]

    def fill(y: int, a: int, b: int) -> bytes:
        base = base_color(y)
        out = bytearray()
        for x in range(a, b):
            grain = (((x * 73856093) ^ (y * 19349663)) & 0xFF) % 7 - 3
            out += bytes(max(0, min(255, channel + grain)) for channel in base)
        return bytes(out)

    return fill


def flat_fill(color: RGB) -> Callable[[int, int, int], bytes]:
    pixel = bytes(color)
    return lambda y, a, b: pixel * (b - a)


def build_shapes() -> list[Shape]:
    shapes: list[Shape] = []
    for index, (_name, color) in enumerate(INTENT_COLORS):
        top = MARGIN + index * (BAND_HEIGHT + BAND_GAP)
        bottom = top + BAND_HEIGHT
        shapes.append(Shape(top, bottom, BAND_LEFT, BAND_RIGHT, BAND_RADIUS,
                            band_fill_factory(index, color, top)))
        clasp_top, clasp_bottom = top - CLASP_OVERHANG, bottom + CLASP_OVERHANG
        shapes.append(Shape(clasp_top, clasp_bottom, CLASP_LEFT, CLASP_RIGHT, CLASP_RADIUS,
                            clasp_fill_factory(clasp_top, clasp_bottom)))
        shapes.append(Shape(clasp_top + NOTCH_INSET, clasp_bottom - NOTCH_INSET, NOTCH_LEFT,
                            NOTCH_RIGHT, NOTCH_RADIUS, flat_fill(ALLOY_SHADOW)))
    return shapes


def render_icon_pixels() -> bytes:
    """Raw PNG scanlines (filter byte 0 + RGB triples) for the 1024x1024 icon."""
    shapes = build_shapes()
    background = bytes(CARBON) * SIZE
    scanlines = []
    for y in range(SIZE):
        row = bytearray(background)
        for shape in shapes:
            shape.paint(row, y)
        scanlines.append(b"\x00" + bytes(row))
    return b"".join(scanlines)


def png_chunk(tag: bytes, data: bytes) -> bytes:
    crc = zlib.crc32(tag + data) & 0xFFFFFFFF
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)


def encode_png(raw: bytes) -> bytes:
    header = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0)  # 8-bit RGB, no alpha
    return (
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", header)
        + png_chunk(b"sRGB", b"\x00")
        + png_chunk(b"IDAT", zlib.compress(raw, 9))
        + png_chunk(b"IEND", b"")
    )


def decoded_png_data(data: bytes) -> bytes | None:
    """Concatenated, decompressed IDAT payload (for pixel-level comparison)."""
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        return None
    position, idat = 8, b""
    while position + 8 <= len(data):
        length, tag = struct.unpack(">I4s", data[position:position + 8])
        if tag == b"IDAT":
            idat += data[position + 8:position + 8 + length]
        position += 12 + length
    try:
        return zlib.decompress(idat)
    except zlib.error:
        return None


def xcode_json(value: object) -> bytes:
    return (json.dumps(value, indent=2, separators=(",", " : "), sort_keys=True) + "\n").encode()


XCODE_INFO = {"author": "xcode", "version": 1}


def accent_color_contents() -> dict:
    red, green, blue = PORCELAIN_HEX[1:3], PORCELAIN_HEX[3:5], PORCELAIN_HEX[5:7]
    return {
        "colors": [
            {
                "color": {
                    "color-space": "srgb",
                    "components": {
                        "alpha": "1.000",
                        "blue": f"0x{blue}",
                        "green": f"0x{green}",
                        "red": f"0x{red}",
                    },
                },
                "idiom": "universal",
            }
        ],
        "info": XCODE_INFO,
    }


def privacy_manifest() -> bytes:
    manifest = {
        "NSPrivacyTracking": False,
        "NSPrivacyTrackingDomains": [],
        "NSPrivacyCollectedDataTypes": [],
        "NSPrivacyAccessedAPITypes": [],
    }
    return plistlib.dumps(manifest, fmt=plistlib.FMT_XML, sort_keys=True)


def render() -> dict[str, bytes]:
    """Relative path -> exact file bytes."""
    return {
        f"{CATALOG}/Contents.json": xcode_json({"info": XCODE_INFO}),
        f"{CATALOG}/AccentColor.colorset/Contents.json": xcode_json(accent_color_contents()),
        f"{CATALOG}/AppIcon.appiconset/Contents.json": xcode_json({
            "images": [
                {
                    "filename": "AppIcon-1024.png",
                    "idiom": "universal",
                    "platform": "ios",
                    "size": "1024x1024",
                }
            ],
            "info": XCODE_INFO,
        }),
        ICON_PATH: encode_png(render_icon_pixels()),
        f"{RESOURCES}/PrivacyInfo.xcprivacy": privacy_manifest(),
    }


def differing_files(root: Path, expected: dict[str, bytes]) -> list[str]:
    problems = []
    for relative, content in expected.items():
        path = root / relative
        if not path.is_file():
            problems.append(f"{relative}: missing")
            continue
        actual = path.read_bytes()
        if actual == content:
            continue
        if relative.endswith(".png"):
            ours, theirs = decoded_png_data(content), decoded_png_data(actual)
            if ours is not None and ours == theirs:
                print(f"note: {relative}: compressed bytes differ but decoded pixels match")
                continue
        problems.append(f"{relative}: content differs")
    return problems


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--check", action="store_true",
                        help="compare on-disk files with a fresh render; write nothing")
    args = parser.parse_args(argv)
    expected = render()
    if args.check:
        problems = differing_files(ROOT, expected)
        for problem in problems:
            print(f"DIFFERS {problem}")
        print("generate_app_assets --check: " + ("FAILED" if problems else "up to date"))
        return 1 if problems else 0
    for relative, content in expected.items():
        path = ROOT / relative
        if path.is_file() and path.read_bytes() == content:
            print(f"unchanged {relative}")
            continue
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
        print(f"wrote     {relative} ({len(content)} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
