#!/usr/bin/env bash
# Build multi-size Windows .ico files from the monochrome icon set.
# Runs on a Linux host that has the set installed (the Arch laptop).
# Usage: build-icons.sh <icons.map> <output-dir>
set -euo pipefail

map="${1:?usage: build-icons.sh <icons.map> <output-dir>}"
out="${2:?usage: build-icons.sh <icons.map> <output-dir>}"
set_dir="${ICON_SET_DIR:-/usr/share/icons/yet-another-monochrome-icon-set}/apps/scalable"

for cmd in rsvg-convert magick; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "missing: $cmd" >&2; exit 1; }
done
mkdir -p "$out"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

while IFS='|' read -r name icon; do
  [[ -z "$name" || "$name" == \#* ]] && continue
  [[ "$icon" == logo-* ]] && continue   # made from the app's own icon, see README
  svg="$set_dir/$icon.svg"
  if [[ ! -f "$svg" ]]; then
    echo "skip: $name ($icon.svg not found)" >&2
    continue
  fi
  pngs=()
  for size in 16 20 24 32 40 48 64 96 128 256; do
    rsvg-convert -w "$size" -h "$size" "$svg" -o "$work/$size.png"
    pngs+=("$work/$size.png")
  done
  magick "${pngs[@]}" "$out/$icon.ico"
  echo "built: $icon.ico ($name)"
done < "$map"
