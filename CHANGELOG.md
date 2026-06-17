# Changelog

## 0.1.0

- Added `Option-Tab` and `Option-Shift-Tab` window switching.
- Added `Option-·` as a reverse-switching shortcut.
- Added minimized-window discovery and restore support through Accessibility.
- Added MRU-style window ordering.
- Added app/window thumbnails with screen-recording permission fallback.
- Added double `Option` current-window minimization.
- Prioritized the freshly minimized window as the next `Option-Tab` default so
  tapping and releasing immediately restores the window you just minimized.
- Added window layout shortcuts:
  - `Option-←` / `Option-→`
  - `Option-1` / `Option-2`
  - `Option-↑` / `Option-↓`
  - `Option-3`
- Added optional experimental `Option-Z/A/S/X/C/V/W/Q` commands.
- Made Option-letter command shortcuts wait for the Option key to be released before
  dispatching the matching Command shortcut, improving reliability in apps that
  treat Option-letter combinations specially.
- Added menu switches for common settings and login-at-startup support.
