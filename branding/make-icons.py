#!/usr/bin/env python3
"""Generate ALL application icons + installer artwork from ONE source image.

Single source of truth: ../branding/icon-source.png  (1024x1024, square, transparent OK)
Outputs (into ../build/):
  - icon.png, icon-256-rounded.png, icon.ico, installerHeaderIcon.ico, icon.icns
  - icon-mac-cartoon.png, icon-mac-cartoon-256.png, icon-mac-cartoon.ico
  - installerSidebar.bmp, uninstallerSidebar.bmp

This script is intentionally self-contained (does NOT call upstream build/make-icon.py)
so that upstream changes to icon tooling never affect our branding. To rebrand, just
replace branding/icon-source.png and re-run `node branding/apply.mjs`.
"""
from __future__ import annotations
import sys
from io import BytesIO
from pathlib import Path
from PIL import Image, ImageDraw

REPO_ROOT = Path(__file__).resolve().parent.parent
BUILD_DIR = REPO_ROOT / "build"
SRC = REPO_ROOT / "branding" / "icon-source.png"

MASTER_SIZE = 1024
CORNER_RATIO = 0.22
SS = 4  # supersample factor for clean corner anti-aliasing

ICO_SIZES = [16, 24, 32, 48, 64, 128, 256]
ICNS_ENTRIES = [
    ("icp4", 16), ("ic11", 32), ("icp5", 32), ("ic12", 64), ("icp6", 64),
    ("ic07", 128), ("ic13", 256), ("ic08", 256), ("ic14", 512),
    ("ic09", 512), ("ic10", 1024),
]

# NSIS modern UI sidebar bitmap size
SIDEBAR_W, SIDEBAR_H = 164, 314
SIDEBAR_BG = (30, 32, 40, 255)


def rounded_mask(size: int, radius: int) -> Image.Image:
    big = Image.new("L", (size * SS, size * SS), 0)
    ImageDraw.Draw(big).rounded_rectangle(
        (0, 0, size * SS - 1, size * SS - 1), radius=radius * SS, fill=255)
    return big.resize((size, size), Image.LANCZOS)


def top_highlight(size: int, mask: Image.Image) -> Image.Image:
    hl = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(hl)
    half = size // 2
    for i in range(half):
        alpha = int(30 * (1 - i / half) ** 2)
        d.rectangle((0, i, size, i + 1), fill=(255, 255, 255, alpha))
    clipped = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    clipped.paste(hl, (0, 0), mask=mask)
    return clipped


def inner_border(size: int, radius: int) -> Image.Image:
    b = Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))
    ImageDraw.Draw(b).rounded_rectangle(
        (SS, SS, size * SS - SS - 1, size * SS - SS - 1),
        radius=(radius - 1) * SS, outline=(255, 255, 255, 55), width=SS * 2)
    return b.resize((size, size), Image.LANCZOS)


def render_icon(size: int, with_polish: bool) -> Image.Image:
    base = Image.open(SRC).convert("RGBA").resize((size, size), Image.LANCZOS)
    radius = max(2, int(size * CORNER_RATIO))
    mask = rounded_mask(size, radius)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(base, (0, 0), mask=mask)
    if with_polish:
        out = Image.alpha_composite(out, top_highlight(size, mask))
        out = Image.alpha_composite(out, inner_border(size, radius))
    return out


def png_bytes(image: Image.Image) -> bytes:
    buf = BytesIO()
    image.save(buf, "PNG", optimize=True)
    return buf.getvalue()


def write_icns(path: Path):
    chunks = []
    for kind, size in ICNS_ENTRIES:
        image = render_icon(size, with_polish=(size >= 48))
        data = png_bytes(image)
        chunks.append(kind.encode("ascii") + (len(data) + 8).to_bytes(4, "big") + data)
    body = b"".join(chunks)
    path.write_bytes(b"icns" + (len(body) + 8).to_bytes(4, "big") + body)


def write_sidebar(path: Path):
    """NSIS sidebar: brand background with a centered, scaled-down icon."""
    canvas = Image.new("RGBA", (SIDEBAR_W, SIDEBAR_H), SIDEBAR_BG)
    icon = render_icon(int(SIDEBAR_W * 0.62), with_polish=True)
    ox = (SIDEBAR_W - icon.width) // 2
    oy = int(SIDEBAR_H * 0.16)
    canvas.paste(icon, (ox, oy), icon)
    canvas.convert("RGB").save(path, "BMP")


def main():
    if not SRC.exists():
        sys.exit(f"[make-icons] missing source: {SRC}\n"
                 "Put a 1024x1024 square PNG at branding/icon-source.png")
    BUILD_DIR.mkdir(exist_ok=True)

    big = render_icon(512, with_polish=True)
    big.save(BUILD_DIR / "icon.png", "PNG", optimize=True)
    print("wrote build/icon.png (512x512)")

    ref = render_icon(256, with_polish=True)
    ref.save(BUILD_DIR / "icon-256-rounded.png", "PNG", optimize=True)
    print("wrote build/icon-256-rounded.png (256x256)")

    icons = [render_icon(s, with_polish=(s >= 48)) for s in ICO_SIZES]
    icons[-1].save(BUILD_DIR / "icon.ico", format="ICO",
                   sizes=[(s, s) for s in ICO_SIZES], append_images=icons[:-1])
    print(f"wrote build/icon.ico sizes={ICO_SIZES}")
    icons[-1].save(BUILD_DIR / "installerHeaderIcon.ico", format="ICO",
                   sizes=[(s, s) for s in ICO_SIZES], append_images=icons[:-1])
    print("wrote build/installerHeaderIcon.ico")

    write_icns(BUILD_DIR / "icon.icns")
    print("wrote build/icon.icns")

    # macOS cartoon variant (same rounded style, larger master)
    cart = render_icon(1024, with_polish=True)
    cart.save(BUILD_DIR / "icon-mac-cartoon.png", "PNG", optimize=True)
    print("wrote build/icon-mac-cartoon.png (1024x1024)")
    cart256 = render_icon(256, with_polish=True)
    cart256.save(BUILD_DIR / "icon-mac-cartoon-256.png", "PNG", optimize=True)
    print("wrote build/icon-mac-cartoon-256.png (256x256)")
    cart256.save(BUILD_DIR / "icon-mac-cartoon.ico", format="ICO",
                 sizes=[(s, s) for s in ICO_SIZES], append_images=icons[:-1])
    print("wrote build/icon-mac-cartoon.ico")

    write_sidebar(BUILD_DIR / "installerSidebar.bmp")
    print("wrote build/installerSidebar.bmp")
    write_sidebar(BUILD_DIR / "uninstallerSidebar.bmp")
    print("wrote build/uninstallerSidebar.bmp")

    print("[make-icons] all branding artwork regenerated from", SRC.name)


if __name__ == "__main__":
    main()
