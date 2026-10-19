#!/usr/bin/env python3
"""Build a KDE dynamic-sequence wallpaper package from an Apple dynamic wallpaper.

Reads the `layout.json` produced by `parse_heif.py` (grid structure + the
`apple_desktop:solar` XMP table) and the tiles extracted by `extract_frames.sh`,
then produces a KPackage directory that works with the plasma-workspace
day-night-sequence engine and degrades gracefully to a plain light/dark
wallpaper on upstream Plasma.

Pipeline (given `Mojave.heic`):
    python3 parse_heif.py Mojave.heic --json layout.json
    ./extract_frames.sh Mojave.heic frames
    python3 build_wallpaper.py --layout layout.json --frames frames \
        --out <package_dir> --name Mojave

Two Apple layouts are supported:
  * one image per sun position (Mojave: 16 images / 16 slots)
  * more slots than images, where an image is reused at two times of day
    (Big Sur family: 8 images / 10 slots). In both cases the `si` solar table
    lists one entry per *slot*; each slot names the image to show (`i`) and the
    sun altitude/azimuth for that moment.

The output emits one frame per slot (so a reused image simply appears twice, at
its two anchor positions). `dynamic.json` must never contain two frames with an
identical `(anchor, t)` pair — the engine rejects that — so the builder drops
exact slot duplicates.

Steps performed here:
    1. Read grid geometry (cols/rows/tile size/full WxH) and the solar table.
    2. Order the slots chronologically by sun azimuth (midnight -> ... -> midnight).
    3. Derive each slot's (anchor, t) from its sun altitude:
         civilDawn/sunrise (altitudes CIVIL/HORIZON) bound the twilights,
         the peak altitude is noon, the minimum is midnight;
         the rising branch (morning) is azimuth < 180, the setting (evening) the rest.
    4. Stitch the tiles into full-resolution images and convert to JPEG.
    5. Write `frames/NN.jpg`, `dynamic.json`, `metadata.json`, and the
       upstream-compatible day/night preview pair where the light image is the
       peak-altitude (noon) image and the dark image is the minimum (midnight)
       image, named `<W>x<H>.jpg` so findPreferredImageInPackage finds them.

Usage:
    build_wallpaper.py --layout layout.json --frames frames --out <dir>
                       [--name Name] [--id ID] [--quality Q]
"""
import argparse
import json
import re
import sys
from pathlib import Path

from PIL import Image

CIVIL = -6.0        # civil dawn/dusk threshold (deg)
HORIZON = -0.83     # sunrise/sunset threshold (deg, includes refraction)


def slugify(name):
    slug = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")
    return slug or "wallpaper"


def parse_args():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--layout", required=True, help="layout.json from parse_heif.py")
    p.add_argument("--frames", required=True, help="directory of frame_NNNN.png tiles")
    p.add_argument("--out", required=True, help="output package directory")
    p.add_argument("--name", default=None, help="display name (default: layout file stem)")
    p.add_argument("--id", dest="pkg_id", default=None,
                   help="KPlugin Id (default: org.kde.wallpaper.<name-lowercased>)")
    p.add_argument("--quality", type=int, default=90, help="JPEG quality (default: 90)")
    return p.parse_args()


def main():
    args = parse_args()
    layout_path = Path(args.layout)
    frames_dir = Path(args.frames)
    out = Path(args.out)

    name = args.name or layout_path.stem
    pkg_id = args.pkg_id or f"org.kde.wallpaper.{slugify(name)}"

    # --- 1. structure + solar table -----------------------------------------
    layout = json.loads(layout_path.read_text())
    grids = layout["grids"]
    n_img = len(grids)
    if n_img < 2:
        sys.exit(f"expected at least 2 grid images, got {n_img}")
    g0 = grids[0]
    cols, rows, W, H = g0["cols"], g0["rows"], g0["width"], g0["height"]
    for g in grids:
        if (g["cols"], g["rows"], g["width"], g["height"]) != (cols, rows, W, H):
            sys.exit(f"non-uniform grid layout: {g} vs {g0}")
    tile = g0.get("tileSize")
    if not tile:
        sys.exit("layout.json has no 'tileSize'; regenerate with the bundled parse_heif.py")
    tw, th = tile
    tiles = cols * rows

    solar = layout["xmp"]["solar"]
    slots = solar["si"]  # one per sun position; an image may be reused across slots
    m = len(slots)
    if m < 2:
        sys.exit(f"expected at least 2 solar slots, got {m}")
    for s in slots:
        if not (0 <= s["i"] < n_img):
            sys.exit(f"solar slot references image {s['i']} but there are only {n_img} images")
    PK = max(e["a"] for e in slots)
    MK = min(e["a"] for e in slots)
    pk_img = next(e["i"] for e in slots if e["a"] == PK)
    mk_img = next(e["i"] for e in slots if e["a"] == MK)
    print(f"ok: {n_img} images, {m} solar slots ({cols}x{rows} {tw}x{th} tiles -> {W}x{H}); "
          f"noon=img {pk_img} ({PK:.1f}deg), midnight=img {mk_img} ({MK:.1f}deg)")

    # --- 2. chronological order of the slots (walk azimuth from midnight) ---
    def fwd(a, b):
        return (a - b) % 360

    slots_index = list(range(m))
    start = min(slots_index, key=lambda i: (slots[i]["a"], slots[i]["z"]))
    order = [start]
    for _ in range(m - 1):
        prev_z = slots[order[-1]]["z"]
        order.append(min((i for i in slots_index if i not in order),
                         key=lambda i: fwd(slots[i]["z"], prev_z)))
    print("chronological:", " -> ".join(f"img{slots[i]['i']}" for i in order))

    # --- 3. anchor + t per slot ---------------------------------------------
    # A frame at (anchor, t) sits at anchor + t * (next anchor - anchor):
    #   civilDawn(-6) -> sunrise(-0.83) -> noon(peak) -> sunset(-0.83)
    #   -> civilDusk(-6) -> midnight(min) -> civilDawn
    def anchor_t(s):
        a, z = s["a"], s["z"]
        if z < 180:  # sun rising (morning)
            if a <= CIVIL:
                return "midnight", (a - MK) / (CIVIL - MK)
            if a <= HORIZON:
                return "civilDawn", (a - CIVIL) / (HORIZON - CIVIL)
            return "sunrise", (a - HORIZON) / (PK - HORIZON)
        else:        # sun setting (evening)
            if a >= HORIZON:
                return "noon", (PK - a) / (PK - HORIZON)
            if a >= CIVIL:
                return "sunset", (HORIZON - a) / (HORIZON - CIVIL)
            return "civilDusk", (CIVIL - a) / (CIVIL - MK)

    frames = []
    seen = set()
    for si in order:
        s = slots[si]
        anchor, t = anchor_t(s)
        t = round(min(1.0, max(0.0, t)), 3)
        file = f"frames/{s['i']:02d}.jpg"
        key = (file, anchor, t)  # engine forbids duplicate (anchor, t) -> drop slot dupes
        if key in seen:
            continue
        seen.add(key)
        frames.append({"file": file, "anchor": anchor, "t": t})
        print(f"  img {s['i']:2d}: alt {s['a']:6.2f}  az {s['z']:6.1f}  -> {anchor:9s} t={t:.3f}")

    # --- 4. stitch tiles, convert, write package -----------------------------
    (out / "frames").mkdir(parents=True, exist_ok=True)

    stitched = {}
    for g in range(n_img):
        canvas = Image.new("RGB", (cols * tw, rows * th))
        for k in range(tiles):
            tile_img = Image.open(frames_dir / f"frame_{g * tiles + k:04d}.png").convert("RGB")
            canvas.paste(tile_img, ((k % cols) * tw, (k // cols) * th))
        img = canvas.crop((0, 0, W, H))
        img.save(out / "frames" / f"{g:02d}.jpg", quality=args.quality)
        stitched[g] = img
        print(f"  stitched img {g:2d} -> frames/{g:02d}.jpg ({W}x{H})")

    # Upstream-compatible day/night preview pair (light = peak/noon, dark = min/midnight).
    for dark, img in ((False, pk_img), (True, mk_img)):
        dest = out / "contents" / ("images_dark" if dark else "images")
        dest.mkdir(parents=True, exist_ok=True)
        stitched[img].save(dest / f"{W}x{H}.jpg", quality=args.quality)

    (out / "metadata.json").write_text(json.dumps({
        "KPlugin": {
            "Authors": [{"Name": "Apple Inc.", "Email": ""}],
            "Id": pkg_id,
            "License": "All Rights Reserved",
            "Name": name,
        }
    }, indent=4) + "\n")
    (out / "dynamic.json").write_text(json.dumps({
        "format": "org.kde.plasma.wallpaper.dynamic-sequence/1",
        "frames": frames,
    }, indent=4) + "\n")
    print(f"wrote {out}  ({len(frames)} frames from {n_img} images, id={pkg_id}, "
          f"preview light=noon dark=midnight)")


if __name__ == "__main__":
    main()
