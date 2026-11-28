#!/usr/bin/env bash
# Installs the laptop's Windows-style top bar (KDE Plasma 6):
#   - the widgets in plasmoids/ (kpackagetool6) and cava-levels.py -> ~/.local/share/kde-bar/
#   - --style   the OLED-Monochrome Plasma style: a copy of WhiteSur-dark-mono with a black,
#               rounded, bordered panel background (plasma-style/panel-background.svg), then applied
#   - --layout  rebuilds the top panel in the Windows order (backs up the Plasma config first)
# Usage:
#   ./install-kde-bar.sh [--dry-run] [--style] [--layout]
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
data="${XDG_DATA_HOME:-$HOME/.local/share}"
config="${XDG_CONFIG_HOME:-$HOME/.config}"
dry=0 style=0 layout=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry=1 ;;
    --style) style=1 ;;
    --layout) layout=1 ;;
    *) echo "usage: $0 [--dry-run] [--style] [--layout]" >&2; exit 2 ;;
  esac
done

run() { if [ "$dry" = 1 ]; then echo "would run: $*"; else "$@"; fi; }
stamp="$(date +%Y%m%d-%H%M%S)"
backup() {
  [ -e "$1" ] || return 0
  run cp -a "$1" "$1.$stamp.bak"
  [ "$dry" = 1 ] || echo "backup: $1.$stamp.bak"
}

for cmd in python3 kpackagetool6; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "missing: $cmd" >&2; exit 1; }
done
command -v cava >/dev/null 2>&1 || echo "note: cava is not installed, so the visualizer stays flat (sudo pacman -S cava)"

# ---------------------------------------------------------------- widgets
run mkdir -p "$data/kde-bar"
run install -m 644 "$here/cava-levels.py" "$data/kde-bar/cava-levels.py"
for pkg in "$here"/plasmoids/*/; do
  [ -f "$pkg/metadata.json" ] || continue
  id="$(basename "$pkg")"
  if kpackagetool6 -t Plasma/Applet -s "$id" >/dev/null 2>&1; then
    run kpackagetool6 -t Plasma/Applet -u "$pkg"
  else
    run kpackagetool6 -t Plasma/Applet -i "$pkg"
  fi
done

# ---------------------------------------------------------------- Plasma style
if [ "$style" = 1 ]; then
  # WhiteSur-dark-mono is a greyscale copy of WhiteSur-dark made by hand on the original laptop (no
  # package ships it). Elsewhere, use WhiteSur-dark (WhiteSur KDE's install script, or AUR
  # whitesur-plasma-theme-git) without its own colours, so the style follows the colour scheme.
  dest="$data/plasma/desktoptheme/OLED-Monochrome"
  drop_colors=0
  if [ -d /usr/share/plasma/desktoptheme/WhiteSur-dark-mono ]; then
    base=/usr/share/plasma/desktoptheme/WhiteSur-dark-mono
  elif [ -d /usr/share/plasma/desktoptheme/WhiteSur-dark ]; then
    base=/usr/share/plasma/desktoptheme/WhiteSur-dark
    drop_colors=1
  else
    echo "missing: WhiteSur-dark (install the WhiteSur KDE theme first: https://github.com/vinceliuice/WhiteSur-kde)" >&2
    exit 1
  fi
  if [ "$dry" = 1 ]; then
    echo "would copy $base to $dest, rename it OLED-Monochrome and use plasma-style/panel-background.svg"
    [ "$drop_colors" = 1 ] && echo "would leave out its colours, so it follows the OLED Monochrome colour scheme"
  else
    stage="$(mktemp -d)"
    trap 'rm -rf "$stage"' EXIT
    cp -r "$base/." "$stage/"
    [ "$drop_colors" = 1 ] && rm -f "$stage/colors"
    rm -f "$stage/widgets/panel-background.svgz"
    cp "$here/plasma-style/panel-background.svg" "$stage/widgets/panel-background.svg"
    python3 - "$stage" <<'PY'
import json, re, sys, os
d = sys.argv[1]
p = os.path.join(d, "metadata.json")
m = json.load(open(p))
k = m["KPlugin"]
for key in [x for x in k if x.startswith(("Name", "Description"))]:
    del k[key]
k.update(Id="OLED-Monochrome", Name="OLED Monochrome",
         Description="WhiteSur-dark Mono with a black, rounded, bordered panel (csps-stratum)")
json.dump(m, open(p, "w"), indent=4)
p = os.path.join(d, "metadata.desktop")
if os.path.exists(p):
    t = open(p).read()
    t = re.sub(r"(?m)^(Name|Comment)(\[[^]]*\])?=.*\n", "", t)
    t = re.sub(r"(?m)^X-KDE-PluginInfo-Name=.*$", "X-KDE-PluginInfo-Name=OLED-Monochrome", t)
    t = t.replace("[Desktop Entry]\n", "[Desktop Entry]\nName=OLED Monochrome\n", 1)
    open(p, "w").write(t)
PY
    mkdir -p "$(dirname "$dest")"
    rm -rf "$dest"
    mv "$stage" "$dest"
    trap - EXIT
    # Plasma caches rendered theme pieces by theme name; drop ours so a changed SVG shows.
    rm -f "${XDG_CACHE_HOME:-$HOME/.cache}"/plasma_theme_OLED-Monochrome*.kcache
    echo "installed $dest"
  fi
  backup "$config/plasmarc"
  run plasma-apply-desktoptheme OLED-Monochrome
fi

# ---------------------------------------------------------------- top panel layout
if [ "$layout" = 1 ]; then
  command -v qdbus6 >/dev/null 2>&1 || { echo "missing: qdbus6" >&2; exit 1; }
  rc="$config/plasma-org.kde.plasma.desktop-appletsrc"
  # The Windows order. Spacers are the two flexible spacers already on the panel (they centre the
  # clock); anything else on the panel stays, after the tray. No launcher on the bar, as on Windows:
  # Meta opens KRunner instead, like the Windows key opens the search-only Start menu.
  order="org.csps.appname org.kde.plasma.appmenu org.csps.media org.csps.stats
org.kde.plasma.panelspacer org.csps.clock org.csps.nextevent org.csps.quickapps
org.kde.plasma.panelspacer org.csps.aiusage org.kde.plasma.systemtray org.csps.power"
  # KDE's clock follows the locale, which writes "0:41" in Hungarian; org.csps.clock has a fixed
  # "2026-11-28  00:41", like Windows.
  remove="org.kde.plasma.kicker org.kde.plasma.kickoff org.kde.plasma.pager org.kde.plasma.mediacontroller org.kde.plasma.quicklaunch org.kde.plasma.digitalclock"
  add="org.csps.appname org.csps.media org.csps.stats org.csps.clock org.csps.nextevent org.csps.quickapps org.csps.power"
  meta="org.kde.krunner,/App,,toggleDisplay"
  backup "$rc"
  backup "$config/kwinrc"
  if [ "$dry" = 1 ]; then
    echo "would remove from the top panel: $remove"
    echo "would add to the top panel: $add"
    echo "would set Meta to open KRunner ($meta)"
    echo "would stop plasmashell, set the order to: $(echo $order)"
  else
    kwriteconfig6 --file kwinrc --group ModifierOnlyShortcuts --key Meta "$meta"
    qdbus6 org.kde.KWin /KWin reconfigure
    js='var p = panels().filter(function (x) { return x.location === "top"; })[0];
if (p) {
  "'"$remove"'".split(" ").forEach(function (pl) { p.widgets(pl).forEach(function (w) { w.remove(); }); });
  "'"$add"'".split(" ").forEach(function (pl) { if (p.widgets(pl).length === 0) p.addWidget(pl); });
  print(p.id);
}'
    cid="$(qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$js")"
    [ -n "$cid" ] || { echo "no top panel found" >&2; exit 1; }
    # plasmashell keeps the order in memory and writes it on exit, so reorder while it is stopped.
    systemctl --user stop plasma-plasmashell
    python3 - "$rc" "$cid" "$order" <<'PY'
import re, sys
rc, cid, order = sys.argv[1], sys.argv[2], sys.argv[3].split()
text = open(rc).read()
plugin = {}
for m in re.finditer(r"^\[Containments\]\[%s\]\[Applets\]\[(\d+)\]\n((?:[^\[\n].*\n?)*)" % re.escape(cid), text, re.M):
    p = re.search(r"^plugin=(.*)$", m.group(2), re.M)
    if p:
        plugin[m.group(1)] = p.group(1).strip()
cur = re.search(r"^(\[Containments\]\[%s\]\[General\]\n(?:[^\[\n].*\n)*?)AppletOrder=(.*)$" % re.escape(cid), text, re.M)
existing = cur.group(2).split(";") if cur else sorted(plugin, key=int)
existing = [i for i in existing if i in plugin] + [i for i in sorted(plugin, key=int) if i not in existing]
left, new = list(existing), []
for name in order:
    hit = next((i for i in left if plugin[i] == name), None)
    if hit:
        new.append(hit)
        left.remove(hit)
# Widgets not in the list stay on the panel, right after the tray (or at the end).
tray = next((k for k, i in enumerate(new) if plugin[i] == "org.kde.plasma.systemtray"), len(new) - 1)
new[tray + 1:tray + 1] = left
line = "AppletOrder=" + ";".join(new)
if cur:
    text = text[:cur.start(2) - len("AppletOrder=")] + line + text[cur.end(2):]
else:
    text = re.sub(r"^(\[Containments\]\[%s\]\[General\]\n)" % re.escape(cid), r"\1" + line + "\n", text, flags=re.M) \
        if re.search(r"^\[Containments\]\[%s\]\[General\]$" % re.escape(cid), text, re.M) \
        else text + "\n[Containments][%s][General]\n%s\n" % (cid, line)
open(rc, "w").write(text)
print("order:", " ".join(plugin[i] for i in new))
PY
    systemctl --user start plasma-plasmashell
  fi
fi

[ "$dry" = 1 ] && echo "dry run, nothing changed"
echo "done"
