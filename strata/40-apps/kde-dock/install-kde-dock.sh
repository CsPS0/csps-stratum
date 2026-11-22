#!/usr/bin/env bash
# Installs the dock widget (plasmoid/org.csps.dock) on KDE Plasma 6 and, on request, swaps it in for
# KDE's icon-only task manager on the bottom panel, keeping the pinned apps.
#
#   ./install-kde-dock.sh [--dry-run]              install or update the widget only
#   ./install-kde-dock.sh [--dry-run] --replace    also swap it into the bottom panel
#   ./install-kde-dock.sh [--dry-run] --restore    put KDE's task manager back (same pinned apps)
#
# --replace and --restore back up ~/.config/plasma-org.kde.plasma.desktop-appletsrc first.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
applet="org.csps.dock"
dry=0 mode=install
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry=1 ;;
    --replace) mode=replace ;;
    --restore) mode=restore ;;
    *) echo "usage: $0 [--dry-run] [--replace|--restore]" >&2; exit 2 ;;
  esac
done
do_run() { if [ "$dry" = 1 ]; then echo "would run: $*"; else "$@"; fi; }

for cmd in kpackagetool6 qdbus6; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "missing: $cmd" >&2; exit 1; }
done

if kpackagetool6 -t Plasma/Applet -s "$applet" >/dev/null 2>&1; then
  do_run kpackagetool6 -t Plasma/Applet -u "$here/plasmoid/$applet"
else
  do_run kpackagetool6 -t Plasma/Applet -i "$here/plasmoid/$applet"
fi

swap() { # swap <from-plugin> <to-plugin>
  local js='var p = panels().filter(function (x) { return x.location === "bottom"; })[0];
var old = p ? p.widgets("'"$1"'")[0] : null;
if (!old) { print("no '"$1"' on the bottom panel, nothing changed"); } else {
  old.currentConfigGroup = ["General"];
  var launchers = old.readConfig("launchers", []);
  var w = p.addWidget("'"$2"'");
  w.currentConfigGroup = ["General"];
  w.writeConfig("launchers", launchers);
  old.remove();
  print("swapped in '"$2"' with " + String(launchers).split(",").filter(String).length + " pinned apps");
}'
  local rc="${XDG_CONFIG_HOME:-$HOME/.config}/plasma-org.kde.plasma.desktop-appletsrc"
  do_run cp "$rc" "$rc.$(date +%Y%m%d-%H%M%S).bak"
  if [ "$dry" = 1 ]; then
    echo "would swap $1 for $2 on the bottom panel, keeping the pinned apps"
  else
    qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$js"
  fi
}

case "$mode" in
  replace) swap org.kde.plasma.icontasks "$applet" ;;
  restore) swap "$applet" org.kde.plasma.icontasks ;;
esac
if [ "$dry" = 1 ]; then echo "dry run, nothing changed"; else echo "done"; fi
