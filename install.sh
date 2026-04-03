#!/usr/bin/env bash
# Install dms-minimize scripts and apply dock patches

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$HOME/.local/bin"

echo "Installing dms-minimize..."

# Install scripts
mkdir -p "$BIN_DIR"
cp "$SCRIPT_DIR/scripts/hypr-minimize.sh" "$BIN_DIR/"
cp "$SCRIPT_DIR/scripts/hypr-unminimize.sh" "$BIN_DIR/"
chmod +x "$BIN_DIR/hypr-minimize.sh" "$BIN_DIR/hypr-unminimize.sh"
echo "Scripts installed to $BIN_DIR"

# Apply dock patches
echo "Applying DMS dock patches..."
bash "$SCRIPT_DIR/patcher/dms-minimize-patcher.sh"

# Systemd timer to re-apply after DMS updates
SYSTEMD_DIR="$HOME/.config/systemd/user"
mkdir -p "$SYSTEMD_DIR"

cat > "$SYSTEMD_DIR/dms-minimize-patcher.service" << EOF
[Unit]
Description=DMS Minimize Dock Patcher
After=dms.service

[Service]
Type=oneshot
ExecStart=$SCRIPT_DIR/patcher/dms-minimize-patcher.sh
EOF

cat > "$SYSTEMD_DIR/dms-minimize-patcher.timer" << EOF
[Unit]
Description=Re-apply DMS minimize patches periodically

[Timer]
OnBootSec=30s
OnUnitActiveSec=6h

[Install]
WantedBy=timers.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now dms-minimize-patcher.timer

echo ""
echo "Installation complete!"
echo ""
echo "Hyprland config - replace your current minimize hyprbar button with:"
echo '  hyprbars-button = rgb(f6d014), 12,  , hyprctl dispatch exec ~/.local/bin/hypr-minimize.sh'
