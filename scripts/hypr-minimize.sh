#!/usr/bin/env bash
# Minimize the active Hyprland window to special:minimized workspace
# Saves original workspace and position for proper restore

set -euo pipefail

STATE_FILE="/tmp/hypr-minimized-state.json"

ACTIVE_JSON=$(hyprctl activewindow -j)
ADDR=$(echo "$ACTIVE_JSON" | jq -r '.address')
WS_ID=$(echo "$ACTIVE_JSON" | jq -r '.workspace.id')
FLOATING=$(echo "$ACTIVE_JSON" | jq -r '.floating')
POS_X=$(echo "$ACTIVE_JSON" | jq -r '.at[0]')
POS_Y=$(echo "$ACTIVE_JSON" | jq -r '.at[1]')
SIZE_W=$(echo "$ACTIVE_JSON" | jq -r '.size[0]')
SIZE_H=$(echo "$ACTIVE_JSON" | jq -r '.size[1]')

if [[ "$ADDR" == "null" || -z "$ADDR" ]]; then
    exit 0
fi

if [[ ! -f "$STATE_FILE" ]]; then
    echo '{}' > "$STATE_FILE"
fi

TMP=$(mktemp)
jq --arg addr "$ADDR" --argjson ws "$WS_ID" \
    --argjson floating "$FLOATING" \
    --argjson x "$POS_X" --argjson y "$POS_Y" \
    --argjson w "$SIZE_W" --argjson h "$SIZE_H" \
    '.[$addr] = {"ws": $ws, "floating": $floating, "x": $x, "y": $y, "w": $w, "h": $h}' \
    "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"

hyprctl dispatch movetoworkspacesilent "special:minimized,address:$ADDR"
