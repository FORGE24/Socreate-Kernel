#!/usr/bin/env python3
"""Generate Socreate OS branding PNG assets from official SVG logos."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

BRAND_DARK = (26, 49, 44)       # #1a312c
BRAND_LIGHT = (137, 215, 183)   # #89d7b7
SLATE_DARK = (15, 23, 42)
SLATE_LIGHT = (248, 250, 252)

ICON_SIZES = (16, 22, 24, 32, 36, 48, 96, 256)
BOOT_SIZES = (128, 256)
FAVICON_SIZE = 32


def rsvg(svg: Path, png: Path, width: int, height: int | None = None) -> None:
    png.parent.mkdir(parents=True, exist_ok=True)
    cmd = ["rsvg-convert", "-w", str(width)]
    if height is not None:
        cmd.extend(["-h", str(height)])
    cmd.extend(["-o", str(png), str(svg)])
    subprocess.run(cmd, check=True)


def write_gradient_png(path: Path, width: int, height: int, top: tuple[int, int, int], bottom: tuple[int, int, int]) -> None:
    import struct
    import zlib

    raw = bytearray()
    for y in range(height):
        t = y / max(1, height - 1)
        row = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        raw.append(0)
        raw.extend(row * width)

    def chunk(tag: bytes, data: bytes) -> bytes:
        import struct
        import zlib
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", ihdr)
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


def write_assets(srcdir: Path, outdir: Path) -> None:
    icon_svg = srcdir / "socreate_logo.svg"
    banner_dark_svg = srcdir / "socreate_logo_darkbackground.svg"
    banner_light_svg = srcdir / "socreate_logo_lightbackground.svg"

    for size in ICON_SIZES:
        rsvg(icon_svg, outdir / "icons" / f"{size}x{size}" / "socreate-logo-icon.png", size)
        rsvg(icon_svg, outdir / "icons" / f"{size}x{size}" / "start-here.png", size)

    for size in BOOT_SIZES:
        rsvg(icon_svg, outdir / "bootloader" / f"bootlogo_{size}.png", size)

    rsvg(icon_svg, outdir / "favicon.png", FAVICON_SIZE)
    rsvg(icon_svg, outdir / "pixmaps" / "socreate-logo.png", 256)
    rsvg(icon_svg, outdir / "pixmaps" / "socreate-logo-small.png", 48)
    rsvg(icon_svg, outdir / "anaconda" / "sidebar-logo.png", 160)
    rsvg(icon_svg, outdir / "plymouth" / "watermark.png", 256)

    write_gradient_png(outdir / "anaconda" / "sidebar-bg.png", 240, 800, BRAND_DARK, (30, 58, 52))
    write_gradient_png(outdir / "anaconda" / "topbar-bg.png", 1024, 64, BRAND_LIGHT, BRAND_DARK)

    if banner_dark_svg.exists():
        rsvg(banner_dark_svg, outdir / "pixmaps" / "socreate-logo-banner-dark.png", 640, 256)
    if banner_light_svg.exists():
        rsvg(banner_light_svg, outdir / "pixmaps" / "socreate-logo-banner-light.png", 640, 256)


def main() -> None:
    srcdir = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    outdir = Path(sys.argv[2] if len(sys.argv) > 2 else "generated")
    write_assets(srcdir.resolve(), outdir.resolve())
    print(f"Generated Socreate logos under {outdir}")


if __name__ == "__main__":
    main()
