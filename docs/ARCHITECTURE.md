# Architecture

TrustedAltTab is a small native macOS menu-bar utility.

## Main Components

- `AppDelegate`: wires startup, menu items, hotkeys, timers, permissions, and
  window-switching actions.
- `HotKeyManager`: registers global Carbon hotkeys.
- `OptionDoubleTapMonitor`: watches modifier events for double-Option
  minimization and Option-release confirmation.
- `WindowProvider`: collects visible windows through CoreGraphics and
  minimized/hidden windows through Accessibility.
- `DisplayedWindowResolver`: resolves the visually frontmost window and maps it
  to an Accessibility window when needed.
- `SwitcherOverlay`: draws the non-activating AppKit switcher panel.
- `WindowRowView`: renders a row in the switcher.
- `WindowFocuser`: activates/restores the selected window.
- `CurrentWindowMinimizer`: minimizes the visually frontmost window.
- `WindowSnapper`: implements left/right/fill/restore layout shortcuts.
- `WindowCommandPerformer`: optional experimental `Option-W/Q` support.
- `LoginItemManager`: writes/removes the user LaunchAgent for login startup.

## Window Discovery

Visible windows come from `CGWindowListCopyWindowInfo` with
`.optionOnScreenOnly`. Minimized windows are not present there, so they are
cached from `AXUIElement` window lists when Accessibility permission is
available.

## Permissions

The switcher hotkeys use Carbon and do not require Accessibility. Accessibility
is required for precise focusing, minimized-window restore, minimize, move,
resize, and optional command forwarding. Screen Recording is only used for
thumbnails.
