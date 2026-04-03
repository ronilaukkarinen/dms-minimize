#!/usr/bin/env bash
#
# DMS Minimize Patcher
# Patches DMS dock for macOS-style minimize:
# - Minimized windows appear as separate dimmed icons in the dock
# - Clicking a minimized icon restores the window to foreground
#

set -euo pipefail

DOCK_BUTTON="/usr/share/quickshell/dms/Modules/Dock/DockAppButton.qml"
DOCK_APPS="/usr/share/quickshell/dms/Modules/Dock/DockApps.qml"
PATCH_MARKER="DMS-MINIMIZE-PATCH"
LOG_FILE="$HOME/.local/share/dms-minimize-patcher.log"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

is_patched() {
    grep -q "$PATCH_MARKER" "$1" 2>/dev/null
}

revert() {
    for f in "$DOCK_BUTTON" "$DOCK_APPS"; do
        local backup="${f}.minimize-backup"
        if [[ -f "$backup" ]]; then
            sudo cp "$backup" "$f"
            log "Reverted $(basename "$f")"
        fi
    done
    log "Revert complete. Run 'dms restart' to apply."
}

[[ "${1:-}" == "--revert" ]] && { revert; exit 0; }

for f in "$DOCK_BUTTON" "$DOCK_APPS"; do
    [[ -f "$f" ]] || { log "ERROR: $f not found"; exit 1; }
done

CHANGES=false

# ── Patch DockAppButton.qml ─────────────────────────────────────────
# Adds: Hyprland import, isMinimized property, visual dimming
if is_patched "$DOCK_BUTTON"; then
    log "DockAppButton.qml already patched."
else
    log "Patching DockAppButton.qml..."
    sudo cp "$DOCK_BUTTON" "${DOCK_BUTTON}.minimize-backup"

    sudo python3 - "$DOCK_BUTTON" "$PATCH_MARKER" << 'PYEOF'
import sys
f, marker = sys.argv[1], sys.argv[2]
with open(f) as fh: c = fh.read()

ok = True

# 1. Add Hyprland import
if 'import Quickshell.Hyprland' not in c:
    c = c.replace('import Quickshell.Wayland', 'import Quickshell.Hyprland\nimport Quickshell.Wayland')

# 2. Add isMinimized property
target = '    property string tooltipText: {'
prop = f'    // {marker}\n    property bool isMinimized: appData ? (appData.isMinimized === true) : false\n\n    property string tooltipText: {{'
if target in c:
    c = c.replace(target, prop)
else:
    print("FAIL: tooltipText not found", file=sys.stderr)
    ok = False

# 3. Dim visualContent
old = '    Item {\n        id: visualContent\n        anchors.fill: parent'
new = f'    Item {{\n        id: visualContent\n        anchors.fill: parent\n        opacity: root.isMinimized ? 0.35 : 1.0 // {marker}'
if old in c:
    c = c.replace(old, new)
else:
    print("FAIL: visualContent not found", file=sys.stderr)
    ok = False

if ok:
    with open(f, 'w') as fh: fh.write(c)
    print("OK")
else:
    sys.exit(1)
PYEOF

    if [[ $? -eq 0 ]]; then
        log "SUCCESS: DockAppButton.qml"
        CHANGES=true
    else
        log "FAIL: DockAppButton.qml, reverting"
        sudo cp "${DOCK_BUTTON}.minimize-backup" "$DOCK_BUTTON"
    fi
fi

# ── Patch DockApps.qml ──────────────────────────────────────────────
# Adds: minimized items in updateModel, click overlay MouseArea
if is_patched "$DOCK_APPS"; then
    log "DockApps.qml already patched."
else
    log "Patching DockApps.qml..."
    sudo cp "$DOCK_APPS" "${DOCK_APPS}.minimize-backup"

    sudo python3 - "$DOCK_APPS" "$PATCH_MARKER" << 'PYEOF'
import sys
f, marker = sys.argv[1], sys.argv[2]
with open(f) as fh: c = fh.read()

ok = True

# 1. Replace updateModel to append minimized windows
old_update = '''                function updateModel() {
                    const baseResult = buildBaseItems();
                    dockItems = applyOverflow(baseResult);
                }'''

new_update = f'''                function updateModel() {{ // {marker}
                    const baseResult = buildBaseItems();
                    var items = applyOverflow(baseResult);

                    if (typeof Hyprland !== "undefined" && Hyprland.toplevels) {{
                        var hyprItems = Array.from(Hyprland.toplevels.values);
                        var minimized = [];
                        for (var i = 0; i < hyprItems.length; i++) {{
                            var t = hyprItems[i];
                            var wsName = t.lastIpcObject ? (t.lastIpcObject.workspace ? t.lastIpcObject.workspace.name : "") : "";
                            if (wsName === "special:minimized" && t.wayland) {{
                                minimized.push({{
                                    uniqueKey: "minimized_" + t.address,
                                    type: "window",
                                    appId: t.wayland.appId || "unknown",
                                    toplevel: t.wayland,
                                    isPinned: false,
                                    isRunning: true,
                                    isMinimized: true,
                                    appAddress: t.address,
                                    isCoreApp: false,
                                    coreAppData: null,
                                    isInOverflow: false
                                }});
                            }}
                        }}
                        if (minimized.length > 0) {{
                            var minimizedTls = new Set(minimized.map(function(m) {{ return m.toplevel; }}));
                            for (var j = 0; j < items.length; j++) {{
                                var item = items[j];
                                if (item.type === "grouped" && item.allWindows) {{
                                    item.allWindows = item.allWindows.filter(function(w) {{ return !minimizedTls.has(w.toplevel); }});
                                    item.windowCount = item.allWindows.length;
                                    if (item.allWindows.length > 0) {{
                                        item.toplevel = item.allWindows[0].toplevel;
                                    }} else {{
                                        item.toplevel = null;
                                    }}
                                }} else if (item.type === "window" && minimizedTls.has(item.toplevel)) {{
                                    items[j] = null;
                                }}
                            }}
                            items = items.filter(function(x) {{ return x !== null; }});
                            items.push({{
                                uniqueKey: "separator_minimized",
                                type: "separator",
                                appId: "__SEPARATOR__",
                                toplevel: null,
                                isPinned: false,
                                isRunning: false
                            }});
                            for (var k = 0; k < minimized.length; k++) {{
                                items.push(minimized[k]);
                            }}
                        }}
                    }}

                    dockItems = items;
                }}'''

if old_update in c:
    c = c.replace(old_update, new_update)
else:
    print("FAIL: updateModel not found", file=sys.stderr)
    ok = False

# 2. Add click overlay MouseArea after DockAppButton
old_delegate_end = '''                        windowTitle: {
                            const title = itemData?.toplevel?.title || "(Unnamed)";
                            return title.length > 50 ? title.substring(0, 47) + "..." : title;
                        }
                    }
                }
            }'''

new_delegate_end = f'''                        windowTitle: {{
                            const title = itemData?.toplevel?.title || "(Unnamed)";
                            return title.length > 50 ? title.substring(0, 47) + "..." : title;
                        }}
                    }}

                    // {marker}: click overlay for minimized items
                    MouseArea {{
                        anchors.fill: parent
                        visible: itemData.isMinimized === true
                        enabled: itemData.isMinimized === true
                        z: 100
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {{
                            var addr = "0x" + (itemData.appAddress || "");
                            Quickshell.execDetached(["bash", "-c", "hyprctl dispatch movetoworkspace $(hyprctl activeworkspace -j | jq -r .id),address:" + addr + " && hyprctl dispatch focuswindow address:" + addr + " && hyprctl dispatch alterzorder top,address:" + addr]);
                        }}
                    }}
                }}
            }}'''

if old_delegate_end in c:
    c = c.replace(old_delegate_end, new_delegate_end)
else:
    print("FAIL: delegate end not found", file=sys.stderr)
    ok = False

if ok:
    with open(f, 'w') as fh: fh.write(c)
    print("OK")
else:
    sys.exit(1)
PYEOF

    if [[ $? -eq 0 ]]; then
        log "SUCCESS: DockApps.qml"
        CHANGES=true
    else
        log "FAIL: DockApps.qml, reverting"
        sudo cp "${DOCK_APPS}.minimize-backup" "$DOCK_APPS"
    fi
fi

if [[ "$CHANGES" == true ]]; then
    log "Restarting DMS..."
    dms restart 2>&1 | tee -a "$LOG_FILE" || log "WARNING: Run 'dms restart' manually"
else
    log "No changes needed."
fi
