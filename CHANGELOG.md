# Changelog

## 0.1.0

- Added `Option-Tab` and `Option-Shift-Tab` window switching.
- Added `Option-·` as a reverse-switching shortcut.
- Added minimized-window discovery and restore support through Accessibility.
- Added MRU-style window ordering.
- Added app/window thumbnails with screen-recording permission fallback.
- Added double `Option` current-window minimization.
- Made double `Option` restore the most recently minimized window when all
  windows are already minimized.
- Reduced restore-time visual jitter by focusing only the selected window's app
  instead of activating every window in that app.
- Kept the switcher overlay visible for a brief moment while minimized windows
  restore, reducing flashes from the desktop or previously active app.
- Made the `Option-·` reverse-switch shortcut dismiss the switcher overlay
  immediately after selection.
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
- Merged right-button mouse gestures into AltGesture, including config
  migration from RightKeyGesture and menu controls for reload/restart.
- Renamed the merged app to AltGesture with its own bundle id, icon, log file,
  config directory, and login item.
- Made thumbnails opt-in by default to keep Screen Recording permission optional.
- Added native Magnet-style window layouts and migrated known Magnet arrow
  gestures to built-in window actions.
- Restored the upper-right `Option+Control+M` gesture as native fill/restore
  toggle behavior.
- Preserved ordinary right-click behavior by replaying context clicks when no
  gesture or mouse chord is recognized.
- Added mouse-driven window switching: hold the right button, scroll to cycle
  through the same switcher, and release the right button to confirm.
- Added a triple right-click privacy shield that covers all screens with black
  panels, hides the pointer, and toggles off with another triple right-click.
- Strengthened privacy shield cursor hiding with CoreGraphics cursor detach and
  transparent cursor enforcement so the pointer stays hidden while active.
- Added menu switches for common settings and login-at-startup support.
