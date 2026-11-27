#!/usr/bin/env bash
# Installs the no-blur lock screen patch and its pacman hook, then applies the patch once.
#   sudo ./install-lockscreen-noblur.sh            install and patch
#   ./install-lockscreen-noblur.sh --dry-run       show what it would do
#   sudo ./install-lockscreen-noblur.sh --undo     put Breeze's blur back, remove the hook and script
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bin=/usr/local/bin/oled-lockscreen-noblur
hook=/etc/pacman.d/hooks/oled-lockscreen-noblur.hook
mode=install
case "${1:-}" in
  "") ;;
  --dry-run) mode=dry ;;
  --undo) mode=undo ;;
  *) echo "usage: $0 [--dry-run|--undo]" >&2; exit 2 ;;
esac

if [ "$mode" = dry ]; then
  echo "would install $here/oled-lockscreen-noblur as $bin"
  echo "would install $here/oled-lockscreen-noblur.hook as $hook"
  echo "would run $bin (patches LockScreenUi.qml, backup in /var/lib/csps-stratum/)"
  echo "dry run, nothing changed"
  exit 0
fi

[ "$(id -u)" = 0 ] || { echo "run with sudo" >&2; exit 1; }

if [ "$mode" = undo ]; then
  if [ -x "$bin" ]; then "$bin" --undo; else bash "$here/oled-lockscreen-noblur" --undo; fi
  rm -f "$hook" "$bin"
  echo "removed $hook and $bin"
  exit 0
fi

install -D -m 755 "$here/oled-lockscreen-noblur" "$bin"
install -D -m 644 "$here/oled-lockscreen-noblur.hook" "$hook"
"$bin"
echo "done: lock the screen (Meta+L) and move the mouse to check"
