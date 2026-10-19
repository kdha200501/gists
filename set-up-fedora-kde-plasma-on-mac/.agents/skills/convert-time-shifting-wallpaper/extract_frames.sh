#!/usr/bin/env bash
# Extract every image frame from a multi-image HEIF (Apple dynamic wallpaper).
#
# NOTE: ffmpeg exposes the HEVC *tiles*, not the assembled images. Each full
# wallpaper image is a grid of tiles (e.g. Mojave = 16 images x 60 tiles = 960),
# so the number of frames written is larger than the number of wallpapers.
# `parse_heif.py` reports the grid geometry used to reassemble them.
#
# Usage: ./extract_frames.sh [source.heic [output_dir]]
set -euo pipefail

SRC="${1:-Mojave.heic}"
OUT="${2:-frames}"
mkdir -p "$OUT"

ffmpeg -hide_banner -v error -i "$SRC" \
    -vsync 0 -map 0 -start_number 0 \
    "$OUT/frame_%04d.png" -y

N=$(ls "$OUT"/frame_*.png 2>/dev/null | wc -l)
echo "Wrote $N tile frames: $OUT/frame_0000.png .. frame_$(printf '%04d' $((N-1))).png"
