#!/usr/bin/env python3
"""Generate tennis-ball AppIcon PNGs for iOS and watchOS.

The repository keeps app icon generation as source code so PRs can stay text-only
(GitHub's mobile PR flow does not support binary PNG changes reliably). CI runs
this script before XcodeGen/build so the archived TestFlight app contains the
updated tennis-ball icons.
"""
from __future__ import annotations

import json
import math
import os
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IOS_ICONSET = ROOT / "iOS/PadelApp/Assets.xcassets/AppIcon.appiconset"
WATCH_ICONSET = ROOT / "WatchApp/PadelWatch/Assets.xcassets/AppIcon.appiconset"
CANVAS = 1024


def blend(a: tuple[int, int, int, int], b: tuple[int, int, int, int], t: float) -> tuple[int, int, int, int]:
    t = max(0.0, min(1.0, t))
    return tuple(max(0, min(255, round(a[i] * (1 - t) + b[i] * t))) for i in range(4))  # type: ignore[return-value]


def icon_pixel(x: float, y: float) -> tuple[int, int, int, int]:
    nx = (x - 512) / 384
    ny = (y - 512) / 384
    distance = math.hypot(nx, ny)
    background = blend(
        (31, 105, 70, 255),
        (8, 45, 33, 255),
        math.hypot((x - 512) / 512, (y - 512) / 512) * 0.85,
    )

    if distance > 1:
        return background

    highlight = max(0, 1 - math.hypot(nx + 0.38, ny + 0.46) / 1.15)
    shade = max(0, nx * 0.45 + ny * 0.65)
    color = blend((198, 221, 38, 255), (237, 243, 86, 255), 0.55 * highlight)
    color = blend(color, (111, 164, 30, 255), 0.34 * shade)

    left_seam = abs(math.hypot(x + 205, y - 512) - 560)
    right_seam = abs(math.hypot(x - 1229, y - 512) - 560)
    seam_width = 28
    seam_edge = 999.0
    if left_seam < seam_width and x < 535:
        seam_edge = min(seam_edge, left_seam)
    if right_seam < seam_width and x > 489:
        seam_edge = min(seam_edge, right_seam)
    if seam_edge != 999.0:
        color = blend((249, 248, 223, 255), color, max(0, min(1, seam_edge / seam_width)) * 0.25)

    color = blend(color, (71, 130, 25, 255), max(0, distance - 0.86) * 1.6)
    if distance > 0.985:
        color = blend(color, background, (distance - 0.985) / 0.015)
    return color


def write_png(path: Path, width: int, height: int, rows: list[bytearray]) -> None:
    raw = b"".join(b"\0" + bytes(row) for row in rows)

    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )


def render_icon(size: int) -> list[bytearray]:
    rows: list[bytearray] = []
    scale = CANVAS / size
    for y in range(size):
        row = bytearray()
        for x in range(size):
            source_x = (x + 0.5) * scale
            source_y = (y + 0.5) * scale
            row.extend(icon_pixel(source_x, source_y))
        rows.append(row)
    return rows


def clean_generated_icons(iconset: Path) -> None:
    for png in iconset.glob("icon-*.png"):
        png.unlink()


def image_side(image: dict[str, str]) -> int:
    scale = float(image.get("scale", "1x").removesuffix("x"))
    return round(float(image["size"].split("x", maxsplit=1)[0]) * scale)


def write_iconset(iconset: Path, images: list[dict[str, str]]) -> None:
    iconset.mkdir(parents=True, exist_ok=True)
    clean_generated_icons(iconset)
    rendered_sizes: set[int] = set()
    for image in images:
        side = image_side(image)
        image["filename"] = f"icon-{side}.png"
        if side not in rendered_sizes:
            write_png(iconset / image["filename"], side, side, render_icon(side))
            rendered_sizes.add(side)

    contents = {"images": images, "info": {"author": "xcode", "version": 1}}
    (iconset / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")


def ios_images() -> list[dict[str, str]]:
    images: list[dict[str, str]] = []
    for size in ("20x20", "29x29", "40x40", "60x60"):
        for scale in ("2x", "3x"):
            images.append({"idiom": "iphone", "size": size, "scale": scale})
    images.append({"idiom": "ios-marketing", "size": "1024x1024", "scale": "1x"})
    return images


def watch_images() -> list[dict[str, str]]:
    return [
        {"idiom": "watch", "role": "notificationCenter", "subtype": "38mm", "size": "24x24", "scale": "2x"},
        {"idiom": "watch", "role": "notificationCenter", "subtype": "42mm", "size": "27.5x27.5", "scale": "2x"},
        {"idiom": "watch", "role": "companionSettings", "size": "29x29", "scale": "2x"},
        {"idiom": "watch", "role": "companionSettings", "size": "29x29", "scale": "3x"},
        {"idiom": "watch", "role": "appLauncher", "subtype": "38mm", "size": "40x40", "scale": "2x"},
        {"idiom": "watch", "role": "appLauncher", "subtype": "40mm", "size": "44x44", "scale": "2x"},
        {"idiom": "watch", "role": "appLauncher", "subtype": "41mm", "size": "46x46", "scale": "2x"},
        {"idiom": "watch", "role": "appLauncher", "subtype": "44mm", "size": "50x50", "scale": "2x"},
        {"idiom": "watch", "role": "appLauncher", "subtype": "45mm", "size": "51x51", "scale": "2x"},
        {"idiom": "watch", "role": "appLauncher", "subtype": "49mm", "size": "54x54", "scale": "2x"},
        {"idiom": "watch", "role": "quickLook", "subtype": "38mm", "size": "86x86", "scale": "2x"},
        {"idiom": "watch", "role": "quickLook", "subtype": "42mm", "size": "98x98", "scale": "2x"},
        {"idiom": "watch", "role": "quickLook", "subtype": "44mm", "size": "108x108", "scale": "2x"},
        {"idiom": "watch", "role": "quickLook", "subtype": "45mm", "size": "117x117", "scale": "2x"},
        {"idiom": "watch-marketing", "size": "1024x1024", "scale": "1x"},
    ]


def main() -> None:
    write_iconset(IOS_ICONSET, ios_images())
    write_iconset(WATCH_ICONSET, watch_images())


if __name__ == "__main__":
    main()
