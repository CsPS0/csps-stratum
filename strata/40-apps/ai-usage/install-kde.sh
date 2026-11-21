#!/usr/bin/env bash
# Installs the AI usage panel widget on KDE Plasma 6 (the Arch laptop):
#   - ai_usage.py            -> ~/.local/share/ai-usage/ai_usage.py
#   - plasmoid/org.csps.aiusage -> installed (or upgraded) with kpackagetool6
#   - --add-to-panel         also puts it on the top panel, just left of the system tray
#                            (appletsrc is backed up first)
#
#   ./install-kde.sh [--dry-run] [--add-to-panel]
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dest="${XDG_DATA_HOME:-$HOME/.local/share}/ai-usage"
applet="org.csps.aiusage"
dry=0 panel=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry=1 ;;
    --add-to-panel) panel=1 ;;
    *) echo "usage: $0 [--dry-run] [--add-to-panel]" >&2; exit 2 ;;
  esac
done
do_run() { if [ "$dry" = 1 ]; then echo "would run: $*"; else "$@"; fi; }

for cmd in python3 kpackagetool6; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "missing: $cmd" >&2; exit 1; }
done

do_run mkdir -p "$dest"
do_run install -m 644 "$here/ai_usage.py" "$dest/ai_usage.py"

if kpackagetool6 -t Plasma/Applet -s "$applet" >/dev/null 2>&1; then
  do_run kpackagetool6 -t Plasma/Applet -u "$here/plasmoid/$applet"
else
  do_run kpackagetool6 -t Plasma/Applet -i "$here/plasmoid/$applet"
fi

if [ "$panel" = 1 ]; then
  command -v qdbus6 >/dev/null 2>&1 || { echo "missing: qdbus6" >&2; exit 1; }
  rc="${XDG_CONFIG_HOME:-$HOME/.config}/plasma-org.kde.plasma.desktop-appletsrc"
  do_run cp "$rc" "$rc.$(date +%Y%m%d-%H%M%S).bak"
  # Add once to the top panel (plasmashell appends it at the end) and report the ids.
  js='var p = panels().filter(function (x) { return x.location === "top"; })[0];
var tray = p ? p.widgets("org.kde.plasma.systemtray")[0] : null;
if (p && tray && p.widgets("'"$applet"'").length === 0) {
  print(p.id + " " + p.addWidget("'"$applet"'").id + " " + tray.id);
}'
  if [ "$dry" = 1 ]; then
    echo "would add $applet to the top panel, then restart plasmashell with it in front of the tray"
  else
    read -r cid wid tid <<<"$(qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$js")" || true
    if [ -n "${wid:-}" ]; then
      # plasmashell keeps the order in memory, so move it with plasmashell stopped.
      systemctl --user stop plasma-plasmashell
      python3 - "$rc" "$cid" "$wid" "$tid" <<'PY'
import re, sys
rc, cid, wid, tid = sys.argv[1:]
text = open(rc).read()
def move(m):
    order = [i for i in m.group(2).split(";") if i and i != wid]
    order.insert(order.index(tid) if tid in order else len(order), wid)
    return m.group(1) + ";".join(order)
text = re.sub(rf"(\[Containments\]\[{cid}\]\[General\]\n(?:[^\[\n].*\n)*?AppletOrder=)(.*)", move, text)
open(rc, "w").write(text)
PY
      systemctl --user start plasma-plasmashell
      echo "added to the top panel"
    else
      echo "already on the top panel (or no top panel with a system tray)"
    fi
  fi
fi
if [ "$dry" = 1 ]; then echo "dry run, nothing changed"; else echo "done"; fi
