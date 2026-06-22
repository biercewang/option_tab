# Architecture

AltGesture is a small native macOS menu-bar utility.

## Main Components

- `AppDelegate`: wires startup, menu items, hotkeys, timers, permissions, and
  window-switching actions.
- `HotKeyManager`: registers global Carbon hotkeys.
- `OptionDoubleTapMonitor`: watches modifier events for double-Option
  minimization and Option-release confirmation.
- `InputMonitoringPermission`: centralizes Input Monitoring preflight and
  request prompts for mouse and modifier event taps.
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
- `RightGestureController`: owns right-button gesture config migration,
  permission prompts, and listener lifecycle.
- `RightGestureEngine`: listens for right-button gestures and mouse-button
  chords, then dispatches the configured shortcuts.
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
thumbnails, which are disabled by default.

Right-button gestures use a CoreGraphics event tap, so they need Accessibility
and Input Monitoring. Some configured gesture actions use System Events to reach
global shortcuts that do not reliably respond to synthesized CGEvents; those
actions trigger macOS Automation permission for AltGesture.

Known Magnet-style `Control+Option+Arrow` gesture actions migrate to native
`windowAction` values. Supported native action names include `left`, `right`,
`top`, `bottom`, `topLeft`, `topRight`, `bottomLeft`, `bottomRight`, `center`,
`fill`, `restore`, and `toggleFill`.
