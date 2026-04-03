#!/usr/bin/env bash
# Uninstall dms-minimize and revert dock patches

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$HOME/.local/bin"

echo "Uninstalling dms-minimize..."

# Restore any minimized windows first
echo "Restoring minimized windows..."
hyprctl clients -j | jq -r '.[] | select(.workspace.name == "special:minimized") | .address' | while read addr; do
    hyprctl dispatch movetoworkspace "1,address:$addr" > /dev/null 2>&1
done

# Revert dock patches
echo "Reverting DMS dock patches..."
bash "$SCRIPT_DIR/patcher/dms-minimize-patcher.sh" --revert

# Remove scripts
rm -f "$BIN_DIR/hypr-minimize.sh" "$BIN_DIR/hypr-unminimize.sh"
echo "Scripts removed"

# Remove systemd timer
systemctl --user disable --now dms-minimize-patcher.timer 2>/dev/null || true
rm -f "$HOME/.config/systemd/user/dms-minimize-patcher.service"
rm -f "$HOME/.config/systemd/user/dms-minimize-patcher.timer"
systemctl --user daemon-reload

rm -f /tmp/hypr-minimized-state.json

echo ""
echo "Uninstall complete."
echo "Run 'dms restart' to apply."
echo "Remember to revert hyprbar button in hyprland.conf."
