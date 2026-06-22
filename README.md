# AltGesture

English | [中文](README.zh-CN.md)

AltGesture is a local, auditable macOS window switcher, lightweight window
manager, and right-button mouse gesture utility. It is built with Swift, AppKit,
Carbon HotKey APIs, CoreGraphics, and macOS Accessibility APIs.

The main workflow is similar to a window-based Alt-Tab experience: hold
`Option`, press `Tab` to open the window list, keep pressing `Tab` or reverse
with `Shift-Tab` / `Option-·`, then release `Option` to focus the selected
window.

## Features

- `Option-Tab` / `Option-Shift-Tab` window switching.
- `Option-·` as an easier reverse-switching shortcut.
- MRU-style ordering, with recently used windows first.
- Visible and minimized-to-Dock windows in the same list.
- Optional window thumbnails; disabled by default to minimize permission prompts.
- App-icon fallback when thumbnails are disabled or unavailable.
- Double `Option` to minimize the visually frontmost window, or restore the
  most recently minimized window when all windows are minimized.
- Window layout shortcuts for the visually frontmost window.
- Optional experimental `Option-Z/A/S/X/C/V/W/Q` command forwarding.
- Configurable right-button mouse gestures and right-button mouse chords.
- Menu-bar settings and user-level login-at-startup support.
- Local-only operation: no networking, telemetry, analytics, or updater.

## Shortcuts

| Shortcut | Action |
| --- | --- |
| `Option-Tab` | Open or advance the window switcher |
| `Option-Shift-Tab` | Reverse in the window switcher |
| `Option-·` | Reverse in the window switcher |
| double `Option` | Minimize the visually frontmost window, or restore the most recently minimized window when none are visible |
| `Option-←` | Move the visually frontmost window to the left half |
| `Option-→` | Move the visually frontmost window to the right half |
| `Option-1` | Move the visually frontmost window to the left half |
| `Option-2` | Move the visually frontmost window to the right half |
| `Option-↑` | Fill the current screen's usable area without macOS full screen |
| `Option-↓` | Restore the window to the pre-layout frame |
| `Option-3` | Toggle fill/restore |
| `Option-Z` | Optional: behave like `Command-Z` |
| `Option-A` | Optional: behave like `Command-A` |
| `Option-S` | Optional: behave like `Command-S` |
| `Option-X` | Optional: behave like `Command-X` |
| `Option-C` | Optional: behave like `Command-C` |
| `Option-V` | Optional: behave like `Command-V` |
| `Option-W` | Optional: behave like `Command-W` |
| `Option-Q` | Optional: behave like `Command-Q` |

These Option-letter command shortcuts are disabled by default. Enable them from
the menu bar item only if you want AltGesture to intercept those shortcuts.

Right-button gestures are enabled by default. Hold the right mouse button and
drag, or hold the right button while pressing another mouse button, to trigger
the shortcuts from the gesture config. On first launch, the app migrates the
first available old config from:

```text
~/Library/Application Support/TrustedAltTab/right-gestures.json
~/Library/Application Support/RightKeyGesture/gestures.json
```

The merged config is stored at:

```text
~/Library/Application Support/AltGesture/right-gestures.json
```

## Menu Items

- Enable or disable `Option-Tab`.
- Show or hide thumbnails.
- Include or exclude minimized Dock windows.
- Include or exclude hidden app windows.
- Enable or disable double-`Option` minimization.
- Enable or disable experimental Option-letter command shortcuts.
- Enable, restart, or reload right-button gestures.
- Open the right-button gesture config file.
- Enable or disable login-at-startup.
- Open Accessibility, Input Monitoring, Automation, and Screen Recording
  permission settings.
- Show the window list manually.

Login-at-startup is implemented with a user LaunchAgent:

```bash
~/Library/LaunchAgents/local.alt-gesture.login.plist
```

## Permissions

AltGesture may request:

- Accessibility: read, restore, focus, minimize, move, and resize windows.
- Input Monitoring: listen for right-button mouse gestures, mouse chords,
  double-Option, and Option release.
- Screen Recording: optional, only for local window thumbnails; thumbnails are
  off by default to avoid requesting this permission.
- Automation: conditional, only for gesture actions that send shortcuts through
  System Events.

Hotkey registration itself uses Carbon and does not require Accessibility.
See [docs/PERMISSIONS.zh-CN.md](docs/PERMISSIONS.zh-CN.md) for the minimal
permission profile.

## Build

Requirements:

- macOS 13 or later.
- Xcode command line tools with Swift 5.9 or newer.

Build and install the app bundle:

```bash
./scripts/build-app.sh
open ~/Applications/AltGesture.app
```

The build script creates:

- `dist/AltGesture.app`
- `~/Applications/AltGesture.app`

It signs with the first available local Apple Development identity. If none is
available, it falls back to ad-hoc signing.

## Permission Reset

If macOS will not show the permission prompt again:

```bash
./scripts/reset-permissions.sh
```

Then reopen:

```bash
open ~/Applications/AltGesture.app
```

## Diagnostics

Logs are written locally:

```bash
~/Library/Logs/AltGesture.log
```

## Project Structure

```text
Sources/AltGesture/
  AppDelegate.swift
  HotKeyManager.swift
  OptionDoubleTapMonitor.swift
  WindowProvider.swift
  DisplayedWindowResolver.swift
  SwitcherOverlay.swift
  WindowRowView.swift
  WindowFocuser.swift
  CurrentWindowMinimizer.swift
  WindowSnapper.swift
  WindowCommandPerformer.swift
  InputMonitoringPermission.swift
  RightGestureConfig.swift
  RightGestureEngine.swift
  LoginItemManager.swift
scripts/
  build-app.sh
  generate-app-icon.py
  reset-permissions.sh
docs/
  ARCHITECTURE.md
  PERMISSIONS.zh-CN.md
Resources/
  AppIcon.icns
```

## Relationship To AltTab

This project is functionally inspired by the user experience of AltTab for
macOS, but it does not copy, vendor, translate, or adapt AltTab source code.
AltTab's public source is licensed under GPL-3.0. AltGesture is an
independent implementation built directly on macOS APIs.

See [NOTICE.md](NOTICE.md) for the attribution and license-boundary note.

## License

MIT. See [LICENSE](LICENSE).
