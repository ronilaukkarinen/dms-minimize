# dms-minimize

macOS-style window minimize for [Hyprland](https://github.com/hyprwm/hyprland) + [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell). Minimized windows appear as separate dimmed icons in the DMS dock. Click to restore.

<img width="725" height="182" alt="image" src="https://github.com/user-attachments/assets/18c29ecd-c29e-4605-ab72-1beeb17ad529" />

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

- [Hyprland](https://github.com/hyprwm/hyprland) with [hyprbars](https://code.hyprland.org/hyprwm/hyprland-plugins/src/branch/hyprbars/hyprbars) plugin
- DMS (DankMaterialShell)
- jq

## Upstream hyprbars `m_bCancelledDown` leak (patch below)

The minimize flow used by dms-minimize triggers an upstream bug in `hyprwm/hyprland-plugins`. Until it lands upstream, you need to apply the patch in [`docs/hyprbars-cancelled-down-fix.patch`](./docs/hyprbars-cancelled-down-fix.patch) yourself. Without it, clicking the hyprbars yellow minimize button and then later unminimizing leaves the next click anywhere in the window stuck as a drag / selection.

### Symptoms

- Click the hyprbars yellow minimize button on a window
- Window goes to `special:minimized`
- Click the dimmed icon in the DMS dock - window comes back
- Click anywhere in the window - the click acts as a drag or starts a selection
- Holds across reboots / time of day; not a timing race
- Triggering minimize via `Super+M` (or any keybind path) does NOT cause the bug

### Root cause

1. PRESS on bar minimize button: `handleDownEvent` sets `info.cancelled = true; m_bCancelledDown = true;` and dispatches the minimize command.
2. The command moves the window to `special:minimized`, a workspace that is not visible on any monitor.
3. RELEASE arrives. `CHyprBar::onMouseButton` runs `inputIsValid()` which returns false because `m_pWindow->m_workspace->isVisible()` is now false. `handleUpEvent` is never called.
4. `m_bCancelledDown` stays stuck at `true` indefinitely.
5. User unminimizes via dock click. Window comes back, workspace is visible again.
6. User clicks anywhere in the window. `handleDownEvent` runs; the click is outside the bar rect so it returns early without resetting the flag.
7. The matching RELEASE invokes `handleUpEvent`, which sees the stale `m_bCancelledDown == true` and sets `info.cancelled = true`.
8. `CInputManager::onMouseButton` returns early before calling `sendPointerButton`. The client sees PRESS without a matching RELEASE, treats the button as held, and the next motion event becomes a drag / selection.

`Super+M` (keybind path) never touches `m_bCancelledDown`, which is why it does not trigger the bug.

### The fix

Reset `m_bCancelledDown = false` at the top of `handleDownEvent`, before any other logic, so stale state from a previous orphaned press cannot survive into the next click cycle. Nine added lines, no removed lines.

### Build and install

```bash
mkdir -p /tmp/hyprbars-fix && cd /tmp/hyprbars-fix
git clone https://github.com/hyprwm/hyprland-plugins.git
cd hyprland-plugins
# Pin to a known-good commit. If your Hyprland version differs, check out
# the commit hyprpm built last (look at hyprpm.toml or the upstream tags).
git checkout 6acc0738f298f5efe40a99db2c12449112d65633
git apply /path/to/dms-minimize/docs/hyprbars-cancelled-down-fix.patch
cd hyprbars
make
```

You now have a patched `hyprbars.so`. Install it into hyprpm's cache and reload the plugin without restarting Hyprland:

```bash
sudo cp /var/cache/hyprpm/$USER/hyprland-plugins/hyprbars.so \
        /var/cache/hyprpm/$USER/hyprland-plugins/hyprbars.so.pre-fix-backup
hyprpm disable hyprbars
sudo cp hyprbars.so /var/cache/hyprpm/$USER/hyprland-plugins/hyprbars.so
hyprpm enable hyprbars
hyprctl version | head -1   # sanity check Hyprland is still alive
```

After `hyprpm enable`, titlebars reappear immediately on existing windows. No relogin needed.

### Rollback

```bash
hyprpm disable hyprbars
sudo cp /var/cache/hyprpm/$USER/hyprland-plugins/hyprbars.so.pre-fix-backup \
        /var/cache/hyprpm/$USER/hyprland-plugins/hyprbars.so
hyprpm enable hyprbars
```

If Hyprland crashes during reload (this fix did not, but a previous broken attempt did):

1. `Ctrl+Alt+F3` to a text TTY, log in
2. `sudo cp /var/cache/hyprpm/$USER/hyprland-plugins/hyprbars.so.pre-fix-backup /var/cache/hyprpm/$USER/hyprland-plugins/hyprbars.so`
3. `exit`, `Ctrl+Alt+F1` to your display manager, log in.

### Caveat

The patched `.so` is built against a specific hyprbars commit and a specific Hyprland ABI. If `hyprpm update` rebuilds hyprbars (typically after a Hyprland upgrade), your patched `.so` is overwritten by the upstream build and you'll need to re-apply.

The proper long-term fix is to land this change upstream. An issue and PR to `hyprwm/hyprland-plugins` are planned.

### Tested versions

- Hyprland 0.54.3
- hyprbars commit `6acc0738f298f5efe40a99db2c12449112d65633`
