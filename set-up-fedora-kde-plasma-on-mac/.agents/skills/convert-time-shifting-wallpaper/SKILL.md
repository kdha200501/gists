---
name: convert-time-shifting-wallpaper
description: >-
  Convert a macOS Apple dynamic (time-shifting) wallpaper — a multi-image HEIC
  such as Mojave.heic, Big Sur, Catalina, Sonoma, or Sequoia — into a KDE
  plasma-workspace dynamic-sequence wallpaper package (frames + dynamic.json,
  with an upstream-compatible light/dark preview pair). Use this skill when the
  user mentions converting/turning an Apple dynamic wallpaper into a KDE or
  Plasma wallpaper, or names a dynamic-wallpaper .heic/.heif file (Mojave.heic, etc.).
---

# Convert Apple Time-Shifting Wallpaper → KDE Plasma

## Overview

Apple dynamic wallpapers (Mojave, Big Sur, Catalina, Sonoma, Sequoia, …) ship as
a single multi-image HEIF file. Each image is stored as a **grid of HEVC tiles**,
and the file carries an XMP `apple_desktop:solar` table that records the **sun
altitude/azimuth** for each sun position. Sun position — not clock time — selects
the image.

Two layouts occur:

- **one image per sun position** (Mojave: 16 images / 16 solar slots), and
- **more slots than images**, where an image is reused at two times of day
  (Big Sur family: 8 images / 10 solar slots).

In both cases the `solar` table's `si` lists one entry per **sun position** (slot),
each naming the image to show at that position (`i`) plus the sun altitude/azimuth.
The builder emits one frame per slot, so a reused image simply appears twice — at
its two anchor positions.

This skill turns that file into a `plasma-workspace` wallpaper package that works
with the custom **day-night-sequence** engine and, on upstream Plasma, gracefully
degrades to a normal light/dark day-night wallpaper.

It uses three scripts bundled in this skill's directory alongside this `SKILL.md`:

- `parse_heif.py` — parses the HEIF structure (grids, tile size) and the solar table.
- `extract_frames.sh` — decodes every tile with `ffmpeg`.
- `build_wallpaper.py` — orders the sun positions, derives each one's timeline
  anchor, stitches the tiles, and writes the KPackage.

> **Why grids:** `ffmpeg` exposes the *tiles*, not the images. A naive extraction
> yields one "frame" per tile (e.g. Mojave: 16 images × 60 tiles = 960; Big Sur:
> 8 × 36 = 288) — these are 512²/1024² picture pieces (row-major), not animation
> steps. `parse_heif.py` tells us how tiles map to full images;
> `build_wallpaper.py` uses that to reassemble each full image.

---

## Prerequisites

- `ffmpeg`/`ffprobe` on `PATH` (for tile extraction).
- Python 3 with `Pillow` (`import PIL`).

Verify before starting:

```bash
command -v ffmpeg >/dev/null && python3 -c "import PIL" && echo "ok"
```

If either is missing, stop and ask the user to install it.

---

## Step 1 — Locate the source wallpaper and an output location

Ask the user for:

1. **Source HEIF file** — the Apple dynamic wallpaper (e.g. `Mojave.heic`).
   Use a path mentioned in the context if one was given.
2. **Package output directory** — where to write the KPackage. Present these
   options:

   - **`<source_dir>/<source-stem>-package`** (default) — a folder next to the
     source file (e.g. `Big Sur-package`), kept as a working copy.
   - **`~/.local/share/wallpapers/<Id>`** — build directly into the user
     wallpaper path so the package is installed as a side effect (it appears in
     Wallpaper settings immediately, see Step 7). Use the KPlugin `Id` computed
     from the display name (e.g. `org.kde.wallpaper.big-sur`).
   - **A directory provided by the end user.**

Use the chosen directory as `<package_dir>` for the rest of the skill.

---

## Step 2 — Locate the bundled scripts

Find the skill directory:

- **Claude Code**: `${CLAUDE_SKILL_DIR}`
- **Other tools**: the directory containing this `SKILL.md`
  (e.g. `~/.claude/skills/convert-time-shifting-wallpaper/`,
  `~/.copilot/skills/convert-time-shifting-wallpaper/`,
  `~/.agents/skills/convert-time-shifting-wallpaper/`)

Refer to it as `<skill>` below. Confirm all three scripts exist there.

---

## Step 3 — Parse the HEIF structure and solar table

```bash
python3 <skill>/parse_heif.py <source.heic> --json layout.json
```

Capture the output. Confirm it reports:

- **Grid items** = full images, each a uniform grid
  (Mojave: 16 images, 10×6 tiles → 5120×2880, 512×512 tiles;
  Big Sur family: 8 images, 6×6 tiles → 6016×6016, 1024×1024 tiles).
- **`XMP apple_desktop plists: [...solar]`** with a per-slot `si` list of
  `altitude`/`azimuth` (`solar.ap`, the `l`/`d` appearance indices, may be present
  or `None`).

> The number of `si` **slots** can exceed the number of grid images — that's the
> reused-image case and is fine. The builder keys off the slot count, not the
> image count.

> The script also prints a `tileSize` per grid into `layout.json`; the builder
> relies on it. If `grids` is empty or the XMP has no `solar` table, the file
> is not a supported Apple dynamic wallpaper — report this and stop.

---

## Step 4 — Extract the tiles

```bash
<skill>/extract_frames.sh <source.heic> frames
```

This writes `frames/frame_0000.png` … one PNG per tile (Mojave: 960 tiles).
The count should equal `number_of_grids × (cols × rows)`.

> **Colour note:** tiles are decoded to sRGB by ffmpeg *without* applying the
> embedded Apple `appl` (P3-class) ICC profile. For colour-critical work, map
> through the profile when converting; for wallpapers this is usually fine.

---

## Step 5 — Build the package

```bash
python3 <skill>/build_wallpaper.py \
    --layout layout.json \
    --frames frames \
    --out <package_dir> \
    --name <Display Name>
```

- `--name` defaults to the layout file stem; set it to the wallpaper name
  (e.g. `Mojave`, `Big Sur`, `Sonoma`). The KPlugin `Id` defaults to
  `org.kde.wallpaper.<name-slugified>` (e.g. `org.kde.wallpaper.big-sur`) —
  pass `--id` to override.
- The script prints the **chronological order** of the sun positions and each
  slot's `(anchor, t)`. A reused image appears twice (once per slot); the builder
  drops a slot only if it would land on an identical `(anchor, t)` pair, which the
  engine forbids.

The builder derives each slot from its sun altitude: `civilDawn`/`sunrise`
(altitudes −6°/−0.83°) bound the twilights, the peak altitude is `noon`, the
minimum is `midnight`; the rising branch is azimuth < 180 (morning), the setting
branch the rest (evening).

---

## Step 6 — Verify the package

Inspect the output tree:

```bash
find <package_dir> -type f | sort
```

Expected:

```
<package_dir>/
├── metadata.json
├── dynamic.json
├── frames/00.jpg ... NN.jpg          (one per stitched image)
├── contents/images/<WxH>.jpg         (light preview = noon)
└── contents/images_dark/<WxH>.jpg    (dark preview = midnight)
```

Sanity checks:

- `dynamic.json` lists one `{file, anchor, t}` per **sun slot**, in chronological
  order. There can be more entries than images (a reused image appears twice).
- `frames/` contains one JPEG per stitched image (the grid count); a reused image's
  entry in `dynamic.json` points at the same frame file.
- `contents/images/` and `contents/images_dark/` each contain exactly one
  resolution-named JPEG (`<W>x<H>.jpg`). **Do not** create a loose
  `contents/images/preview.jpg` — plasma-workspace's
  `findPreferredImageInPackage` only matches a *resolution-named* file, so a
  stray `preview.jpg` is ignored and the settings preview renders as an icon.

---

## Step 7 — Install and test (optional)

Offer the user the option to install the package so it can be picked up by
Plasma. The install location is one directory under the wallpaper search path,
named after the **KPlugin `Id`** (not the source file name).

If `<package_dir>` was already `~/.local/share/wallpapers/<Id>` (Step 1),
the package is installed — skip to the reload at the end of this step.

Otherwise, determine the `Id` and the install root:

```bash
ID=$(python3 -c "import json;print(json.load(open('<package_dir>/metadata.json'))['KPlugin']['Id'])")
# The user wallpaper path (verify which exists; a setup may use one or the other):
ls ~/.local/share/wallpapers/ ~/.local/share/plasma/wallpapers/
```

Then ask the user: **"Move the package to `~/.local/share/wallpapers/<Id>` so it
appears in Wallpaper settings?"** If they confirm:

```bash
mkdir -p ~/.local/share/wallpapers
rsync -a --delete <package_dir>/ ~/.local/share/wallpapers/<ID>/

# Reload so Plasma picks it up (Wayland shown; use kwin_x11 on X11):
kquitall6 kwin_wayland kwin_x11 &
sleep 3; kwin_wayland &
```

> `rsync --delete` keeps the install in sync with the latest build and clears
> stale frames. Installing under the `Id` (not `mojave`/a single shared dir) is
> essential — each package has its own `metadata.json`/`dynamic.json`/`frames/`,
> and dumping several packages into one directory makes them overwrite each other.

Then open **System Settings → Wallpaper**, select the wallpaper, and set
*Switch dynamic wallpapers* to **Based on the day-night cycle**. The settings
preview should show the **split light/dark** view (noon over midnight).

---

## Output format reference

```json
// dynamic.json
{
  "format": "org.kde.plasma.wallpaper.dynamic-sequence/1",
  "frames": [
    { "file": "frames/14.jpg", "anchor": "midnight",   "t": 0.000 },
    { "file": "frames/02.jpg", "anchor": "civilDawn",  "t": 0.339 },
    { "file": "frames/03.jpg", "anchor": "sunrise",    "t": 0.041 },
    { "file": "frames/07.jpg", "anchor": "noon",       "t": 0.000 },
    { "file": "frames/11.jpg", "anchor": "civilDusk",  "t": 0.005 }
  ]
}
```

Anchors in day order: `midnight → civilDawn → sunrise → noon → sunset →
civilDusk → (next midnight)`. A frame is placed at `anchor + t × (segment to
the next anchor)`.

---

## Troubleshooting

- **`expected … solar slots` / `has no 'tileSize'`** — the file is not a
  standard Apple dynamic wallpaper, or `parse_heif.py` is stale. Re-run step 3
  with the bundled script.
- **`solar slot references image …`** — the `si` table names an image index that
  doesn't exist; the file is malformed. Report it and stop.
- **`non-uniform grid layout`** — mixed image resolutions in one file; not
  supported. Report the offending grid.
- **Settings preview is an icon** — the preview file is not named `<W>x<H>.jpg`.
  Re-run step 5 and confirm no stray `preview.jpg`.
- **Frames appear as loose wallpapers** — install a full package directory (with
  `metadata.json`), not scattered files; recent plasma forks skip package roots
  in the loose-image finder.
