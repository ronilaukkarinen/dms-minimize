#!/usr/bin/env bash
# Restore a minimized window by address
# Restores original workspace, position, and focus

set -euo pipefail

STATE_FILE="/tmp/hypr-minimized-state.json"
ADDR="$1"

CURRENT_WS=$(hyprctl activeworkspace -j | jq -r '.id')
RESTORE_WS="$CURRENT_WS"
FLOATING=false
POS_X="" POS_Y="" SIZE_W="" SIZE_H=""

if [[ -f "$STATE_FILE" ]]; then
    STATE=$(jq -r --arg addr "$ADDR" '.[$addr] // empty' "$STATE_FILE")
    if [[ -n "$STATE" ]]; then
        RESTORE_WS=$(echo "$STATE" | jq -r '.ws // empty')
        FLOATING=$(echo "$STATE" | jq -r '.floating // false')
        POS_X=$(echo "$STATE" | jq -r '.x // empty')
        POS_Y=$(echo "$STATE" | jq -r '.y // empty')
        SIZE_W=$(echo "$STATE" | jq -r '.w // empty')
        SIZE_H=$(echo "$STATE" | jq -r '.h // empty')
        [[ -z "$RESTORE_WS" ]] && RESTORE_WS="$CURRENT_WS"
    fi
    TMP=$(mktemp)
    jq --arg addr "$ADDR" 'del(.[$addr])' "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"
fi

hyprctl dispatch movetoworkspace "$RESTORE_WS,address:$ADDR" > /dev/null 2>&1

# Restore position for floating windows
if [[ "$FLOATING" == "true" && -n "$POS_X" && -n "$POS_Y" ]]; then
    hyprctl dispatch movewindowpixel "exact $POS_X $POS_Y,address:$ADDR" > /dev/null 2>&1
    if [[ -n "$SIZE_W" && -n "$SIZE_H" ]]; then
        hyprctl dispatch resizewindowpixel "exact $SIZE_W $SIZE_H,address:$ADDR" > /dev/null 2>&1
    fi
fi

hyprctl dispatch focuswindow "address:$ADDR" > /dev/null 2>&1
