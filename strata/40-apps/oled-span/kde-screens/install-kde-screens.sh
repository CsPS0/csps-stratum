#!/usr/bin/env bash
# Puts OLED Span on the laptop's lock screen and login splash (KDE Plasma 6, no sudo needed):
#   --lock    the lock screen shows the live OLED Span wallpaper (needs the plugin from ../install-kde.sh)
#   --splash  the splash after login: the contours still (../stills/) with a thin grey spinner
# Both back up their config file first. The login screen (SDDM) and boot splash (Plymouth) need sudo;
# see README.md in this folder.
# Usage:
#   ./install-kde-screens.sh [--dry-run] [--lock] [--splash]
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
still="$here/../stills/contours-1920x1080.png"
config="${XDG_CONFIG_HOME:-$HOME/.config}"
dry=0 lock=0 splash=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry=1 ;;
    --lock) lock=1 ;;
    --splash) splash=1 ;;
    *) echo "usage: $0 [--dry-run] [--lock] [--splash]" >&2; exit 2 ;;
  esac
done
[ "$lock" = 1 ] || [ "$splash" = 1 ] || { echo "nothing to do: pass --lock and/or --splash" >&2; exit 2; }

run() { if [ "$dry" = 1 ]; then echo "would run: $*"; else "$@"; fi; }
stamp="$(date +%Y%m%d-%H%M%S)"
backup() {
  [ -e "$1" ] || return 0
  run cp -a "$1" "$1.$stamp.bak"
  [ "$dry" = 1 ] || echo "backup: $1.$stamp.bak"
}
for cmd in kwriteconfig6 kpackagetool6; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "missing: $cmd" >&2; exit 1; }
done

if [ "$lock" = 1 ]; then
  kpackagetool6 -t Plasma/Wallpaper -s com.csps.oledspan >/dev/null 2>&1 \
    || { echo "missing: the OLED Span wallpaper plugin (run ../install-kde.sh --apply first)" >&2; exit 1; }
  backup "$config/kscreenlockerrc"
  run kwriteconfig6 --file kscreenlockerrc --group Greeter --key WallpaperPlugin com.csps.oledspan
  # No top bar on the lock screen, and nothing to pause for.
  for kv in Fps=15 TopDim=false PauseMaximized=false PauseFullscreen=false; do
    run kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group com.csps.oledspan \
      --group General --key "${kv%%=*}" "${kv#*=}"
  done
fi

if [ "$splash" = 1 ]; then
  [ -f "$still" ] || { echo "missing: $still (python3 ../render-still.py ../stills/contours-1920x1080.png)" >&2; exit 1; }
  id=org.csps.oledspan.splash
  if [ "$dry" = 1 ]; then
    echo "would install the splash package $id with $(basename "$still")"
  else
    stage="$(mktemp -d)"
    trap 'rm -rf "$stage"' EXIT
    cp -r "$here/splash/$id" "$stage/"
    mkdir -p "$stage/$id/contents/splash/images"
    cp "$still" "$stage/$id/contents/splash/images/contours.png"
    # (kpackagetool6 -s answers yes for any look-and-feel id, so look for the folder instead)
    if [ -d "${XDG_DATA_HOME:-$HOME/.local/share}/plasma/look-and-feel/$id" ]; then
      kpackagetool6 -t Plasma/LookAndFeel -u "$stage/$id"
    else
      kpackagetool6 -t Plasma/LookAndFeel -i "$stage/$id"
    fi
  fi
  backup "$config/ksplashrc"
  run kwriteconfig6 --file ksplashrc --group KSplash --key Engine KSplashQML
  run kwriteconfig6 --file ksplashrc --group KSplash --key Theme "$id"
fi

[ "$dry" = 1 ] && echo "dry run, nothing changed"
echo "done"
