#!/bin/bash

# Optimizes PNG images in a ROMs directory for handheld consoles (640x480).
# Resizes per image type, compresses to PNG8, and only replaces when smaller.
#
# Accepts either:
#   - a root roms directory   <root>/<platform>/images/*.png
#   - a single platform dir   <platform>/images/*.png
#
# Usage:
#   optimize-roms-images.sh <directory> [--backup <backup-directory>] [--dry-run]
#
# Examples:
#   optimize-roms-images.sh /Volumes/share/roms
#   optimize-roms-images.sh /Volumes/share/roms/snes
#   optimize-roms-images.sh /Volumes/share/roms --backup /tmp/roms-backup
#   optimize-roms-images.sh /Volumes/share/roms --dry-run

set -eufo pipefail

# Prevent macOS from copying xattr/ACL to exFAT
export COPYFILE_DISABLE=1

# ---- defaults ----
BACKUP_DIR=""
DRY_RUN=0

# ---- argument parsing ----
usage() {
  echo "Usage: $(basename "$0") <roms-directory> [--backup <backup-directory>] [--dry-run]"
  echo
  echo "Options:"
  echo "  --backup <dir>  Back up original files before replacing (off by default)"
  echo "  --dry-run       Show what would be done without modifying any file"
  exit 1
}

if [[ $# -lt 1 ]]; then
  usage
fi

ROOT="$1"
shift

while [[ $# -gt 0 ]]; do
  case "$1" in
    --backup)
      [[ $# -lt 2 ]] && { echo "Error: --backup requires a directory argument"; usage; }
      BACKUP_DIR="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    *)
      echo "Error: unknown option: $1"
      usage
      ;;
  esac
done

# ---- checks ----
if ! command -v magick >/dev/null 2>&1; then
  echo "Error: ImageMagick ('magick') not found. Install via: brew install imagemagick"
  exit 1
fi

if [[ ! -d "$ROOT" ]]; then
  echo "Error: directory not found: $ROOT"
  exit 1
fi

# ---- helpers ----
bytes() { stat -f%z "$1"; }

# Return the max resize geometry for a given filename (never upscale with ">").
#   -image.png   : miximage displayed on console (full screen)  -> 640x480
#   -thumb.png   : small thumbnail                              -> 320x240
#   -marquee.png : banner / logo strip                          -> 480x200
#   anything else: safe fallback                                -> 640x480
get_resize() {
  local name_lower
  name_lower="$(basename "$1" | tr '[:upper:]' '[:lower:]')"
  case "$name_lower" in
    *-image.png)   echo "640x480>" ;;
    *-thumb.png)   echo "320x240>" ;;
    *-marquee.png) echo "480x200>" ;;
    *)             echo "640x480>" ;;
  esac
}

# ---- setup ----
if [[ -n "$BACKUP_DIR" && "$DRY_RUN" -eq 0 ]]; then
  mkdir -p "$BACKUP_DIR"
  echo "Backup directory: $BACKUP_DIR"
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "** DRY RUN — no files will be modified **"
fi

# Detect mode: platform dir (has images/ directly) or root dir (has platform subdirs)
if [[ -d "$ROOT/images" ]]; then
  FIND_ARGS=(-mindepth 2 -maxdepth 2)
  echo "Mode: single platform directory"
else
  FIND_ARGS=(-mindepth 3 -maxdepth 3)
  echo "Mode: root roms directory (scanning all platforms)"
fi

echo "Scanning: $ROOT"
echo

# ---- run ----
total_before=0
total_after=0
converted=0
skipped=0

tmp_png=""
cleanup() { [[ -n "$tmp_png" && -f "$tmp_png" ]] && rm -f "$tmp_png"; }
trap cleanup EXIT

while IFS= read -r -d '' f; do
  orig_size="$(bytes "$f")"
  total_before=$((total_before + orig_size))

  resize="$(get_resize "$f")"
  dir="$(dirname "$f")"
  tmp_png="$(mktemp "${dir}/.optim.XXXXXX")"

  # PNG 8-bit palette + alpha, max compression, strip metadata
  # -colorspace sRGB normalises broken ICC profiles (e.g. Photoshop iCCP warnings)
  magick "$f" \
    -colorspace sRGB \
    -alpha on \
    -strip \
    -resize "$resize" \
    -colors 256 \
    -depth 8 \
    -define png:compression-level=9 \
    -define png:compression-strategy=1 \
    -define png:compression-filter=5 \
    "PNG8:$tmp_png"

  new_size="$(bytes "$tmp_png")"

  if [[ "$new_size" -lt "$orig_size" ]]; then
    if [[ "$DRY_RUN" -eq 0 ]]; then
      # Optional backup
      if [[ -n "$BACKUP_DIR" ]]; then
        rel="${f#"$ROOT"/}"
        mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
        cp -pX "$f" "$BACKUP_DIR/$rel"
      fi
      touch -r "$f" "$tmp_png"
      mv -f "$tmp_png" "$f"
    else
      rm -f "$tmp_png"
    fi
    converted=$((converted + 1))
    total_after=$((total_after + new_size))
    echo "OK   : $f  ${orig_size} -> ${new_size} bytes"
  else
    skipped=$((skipped + 1))
    total_after=$((total_after + orig_size))
    rm -f "$tmp_png"
    echo "SKIP : $f  (no gain)"
  fi
  tmp_png=""
done < <(find "$ROOT" "${FIND_ARGS[@]}" -type f -path "*/images/*.png" -not -name "._*" -print0)

# ---- summary ----
echo
echo "Converted : $converted"
echo "Skipped   : $skipped"
echo "Total     : $total_before -> $total_after bytes"
echo "Saved     : $((total_before - total_after)) bytes"
if [[ -n "$BACKUP_DIR" && "$DRY_RUN" -eq 0 ]]; then
  echo "Backup    : $BACKUP_DIR"
fi
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "(dry-run — no files were modified)"
fi
