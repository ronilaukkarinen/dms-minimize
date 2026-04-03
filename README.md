# dms-minimize

macOS-style window minimize for Hyprland + DMS (DankMaterialShell).

Minimized windows appear as separate dimmed icons in the DMS dock. Click to restore.

## How it works

- Hyprbar minimize button hides the window to `special:minimized` workspace
- DMS dock shows each minimized window as a separate dimmed icon after a separator
- Clicking a dimmed icon restores the window to the current workspace and brings it to foreground
- Window position is saved and restored for floating windows

## Install

```bash
./install.sh
```

Then update your `hyprland.conf` hyprbar button:

```conf
hyprbars-button = rgb(f6d014), 12,  , hyprctl dispatch exec ~/.local/bin/hypr-minimize.sh
```

## Uninstall

```bash
./uninstall.sh
dms restart
```

## Re-patching after DMS updates

A systemd timer automatically re-applies patches every 6 hours and on boot. You can also run manually:

```bash
./patcher/dms-minimize-patcher.sh
```

To revert patches:

```bash
./patcher/dms-minimize-patcher.sh --revert
dms restart
```

## Requirements

- Hyprland with hyprbar plugin
- DMS (DankMaterialShell)
- jq
