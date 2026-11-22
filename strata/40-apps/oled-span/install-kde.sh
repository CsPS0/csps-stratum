#!/usr/bin/env bash
# Install the OLED Span wallpaper plugin for KDE Plasma 6 (per user), and optionally switch every
# desktop to it.
#   install-kde.sh [--dry-run] [--apply]
# Needs qsb (qt6-shadertools) and kpackagetool6. --apply needs a running Plasma session.
set -euo pipefail

dry=0 apply=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry=1 ;;
    --apply) apply=1 ;;
    *) echo "usage: $0 [--dry-run] [--apply]" >&2; exit 2 ;;
  esac
done

src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/kde"
id="com.csps.oledspan"
target="${XDG_DATA_HOME:-$HOME/.local/share}/plasma/wallpapers/$id"

qsb="$(command -v qsb || command -v qsb-qt6 || true)"
[ -z "$qsb" ] && [ -x /usr/lib/qt6/bin/qsb ] && qsb=/usr/lib/qt6/bin/qsb
for tool in "$qsb" kpackagetool6; do
  if [ -z "$tool" ] || ! command -v "$tool" >/dev/null 2>&1; then
    echo "missing: ${tool:-qsb} (install qt6-shadertools and plasma-framework)" >&2
    exit 1
  fi
done

run() { if [ "$dry" = 1 ]; then echo "would run: $*"; else "$@"; fi; }

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
cp -r "$src/." "$stage/"
# GLSL 150 and 330 for desktop OpenGL, 300 es for GLES; fwidth needs at least these.
"$qsb" --glsl "150,330,300 es" -o "$stage/contents/shaders/oledspan.frag.qsb" "$stage/contents/shaders/oledspan.frag"
echo "shader compiled"

upgraded=0
if [ -d "$target" ]; then
  run kpackagetool6 --type Plasma/Wallpaper --upgrade "$stage"
  upgraded=1
else
  run kpackagetool6 --type Plasma/Wallpaper --install "$stage"
fi

if [ "$apply" = 1 ]; then
  script="desktops().forEach(function (d) { d.wallpaperPlugin = '$id'; });"
  run qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$script"
  # plasmashell keeps the old QML of an upgraded plugin until it restarts
  [ "$upgraded" = 1 ] && run systemctl --user restart plasma-plasmashell.service
elif [ "$upgraded" = 1 ]; then
  echo "upgraded: restart plasmashell (systemctl --user restart plasma-plasmashell) to load the new version"
fi
if [ "$dry" = 1 ]; then echo "dry run: nothing installed"; else echo "installed $id"; fi
