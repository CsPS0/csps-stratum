#!/usr/bin/env bash
# Builds the "oled-span" SDDM login theme and makes it the current one:
#   - a copy of the installed Breeze login theme (/usr/share/sddm/themes/breeze)
#   - its clock replaced by OledClock.qml: fixed 24-hour "23:49" and "2026-11-27"
#   - the OLED Span contours picture as background (theme.conf.user)
# Run with sudo. --dry-run previews; --build-to <dir> only builds a copy there (no sudo, for
# `sddm-greeter-qt6 --test-mode --theme <dir>`). Undo: set Current=breeze in
# /etc/sddm.conf.d/kde_settings.conf (a backup is made first).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
still="$here/../../stills/contours-1920x1080.png"
src=/usr/share/sddm/themes/breeze
dest=/usr/share/sddm/themes/oled-span
picture=/usr/share/wallpapers/oled-span-contours.png
conf=/etc/sddm.conf.d/kde_settings.conf
dry=0 build_to=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) dry=1 ;;
    --build-to) build_to="${2:?--build-to needs a folder}"; shift ;;
    *) echo "usage: $0 [--dry-run] [--build-to DIR]" >&2; exit 2 ;;
  esac
  shift
done

[ -d "$src" ] || { echo "missing: $src (the Breeze SDDM theme, package plasma-desktop)" >&2; exit 1; }
[ -f "$still" ] || { echo "missing: $still" >&2; exit 1; }
[ "$(grep -c '^[[:space:]]*Clock {$' "$src/Main.qml")" = 1 ] \
  || { echo "Breeze's Main.qml changed: no single 'Clock {' line to replace; not touching anything" >&2; exit 1; }

# Build the theme in a folder: Breeze, our clock, our picture settings, our name.
build() {
  local out="$1" bg="$2"
  mkdir -p "$out"
  cp -r "$src/." "$out/"
  rm -f "$out"/theme.conf.user*
  cp "$here/OledClock.qml" "$out/OledClock.qml"
  sed -i 's/^\([[:space:]]*\)Clock {$/\1OledClock {/' "$out/Main.qml"
  sed -i -e '/^\(Name\|Description\)\[/d' \
         -e 's/^Name=.*/Name=OLED Span/' \
         -e 's/^Description=.*/Description=Breeze with the OLED Span contours and a 24-hour yyyy-MM-dd clock/' \
         -e 's/^Theme-Id=.*/Theme-Id=oled-span/' "$out/metadata.desktop"
  printf '[General]\ntype=image\nbackground=%s\nshowClock=true\n' "$bg" > "$out/theme.conf.user"
}

if [ -n "$build_to" ]; then
  build "$build_to" "$still"
  echo "built a preview copy in $build_to"
  exit 0
fi

if [ "$dry" = 1 ]; then
  echo "would install $still as $picture"
  echo "would build $dest from $src with OledClock.qml"
  echo "would back up $conf and set Current=oled-span"
  echo "dry run, nothing changed"
  exit 0
fi

[ "$(id -u)" = 0 ] || { echo "run with sudo" >&2; exit 1; }
install -m 644 "$still" "$picture"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
build "$stage/oled-span" "$picture"
rm -rf "$dest"
mv "$stage/oled-span" "$dest"
chmod -R a+rX "$dest"
cp -a "$conf" "$conf.$(date +%Y%m%d-%H%M%S).bak"
sed -i 's/^Current=.*/Current=oled-span/' "$conf"
grep -E '^Current=' "$conf"
echo "done: the login screen uses $dest from the next time it starts"
