# Notice

AltGesture is an independently implemented macOS utility built with Swift,
AppKit, Carbon HotKey APIs, CoreGraphics, and the macOS Accessibility APIs.

## Relationship To AltTab

This project was created because the user wanted a local, auditable utility
with a workflow similar to AltTab for macOS. AltTab's public project is licensed
under GPL-3.0. This repository does not vendor, copy, translate, or adapt
AltTab source files.

The overlap is behavioral and product-level only:

- show a window switcher with `Option-Tab`
- list visible and minimized windows
- restore or focus a selected window
- provide macOS window-management shortcuts

The implementation in this repository uses native macOS APIs directly and keeps
its own code structure, UI, hotkey registration, window collection, focusing,
and window sizing logic.

If code from AltTab or another GPL project is ever copied into this repository,
the licensing and attribution must be reviewed before publication.
