## Commits and code style

- Never use Claude watermark in commits (FORBIDDEN: "Co-Authored-By")
- No emojis in commits or code
- One logical change per commit
- Keep commit messages concise (one line), use sentence case
- Use present tense in commits
- Always commit all files (git add -A)
- Always run `git status` after committing to verify nothing is left uncommitted
- Use sentence case for headings (not Title Case)
- Never use bold text as headings, use proper heading levels instead
- Always add an empty line after headings
- Do not ever use separators like ============================================================ or headings like === Something ===

## Claude Code workflow

- ALWAYS use Helsinki timezone (Europe/Helsinki) for all timestamps
- NEVER add Finnish language in anywhere unless the feature requires it
- NEVER unsolicited clean up, replace, or wipe data/words from files
- NEVER cap with artificial limits or truncate as a "solution"
- Always add tasks to the Claude Code to-do list and keep it up to date
- Review your to-do list and prioritize before starting
- Do not ever guess features, always proof them via looking up official docs, GitHub code, issues, if possible
- NEVER just patch the line you see. Before fixing, trace the full chain
- Prefer DRY code - avoid repeating logic, extract shared patterns

## Project structure

- `scripts/hypr-minimize.sh` - Minimize active window to special:minimized workspace, saves position
- `scripts/hypr-unminimize.sh` - Restore a minimized window by Hyprland address (needs 0x prefix)
- `patcher/dms-minimize-patcher.sh` - Patches DMS dock QML files, supports --revert
- `install.sh` - Install scripts, apply patches, set up systemd timer
- `uninstall.sh` - Restore minimized windows, revert patches, clean up

## Technical notes

- Quickshell strips the `0x` prefix from Hyprland addresses - must re-add it when calling hyprctl
- `Hyprland.dispatch()` does not work from DockAppButton context - use `Quickshell.execDetached` with hyprctl instead
- DockAppButton needs `import Quickshell.Hyprland` for the isMinimized property
- Click handling for minimized items uses a MouseArea overlay in DockApps delegate (z:100), not DockAppButton's handleLeftClick
- `dms restart` does a full restart including QML reload - never kill quickshell manually
