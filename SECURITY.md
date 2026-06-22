# Security Policy

AltGesture is designed as a local-only macOS utility.

## Data Handling

- No network requests are made by the app.
- No analytics or telemetry are collected.
- Window titles and diagnostic events are written only to the local log file:
  `~/Library/Logs/AltGesture.log`.
- Screen Recording permission is optional and used only to generate local
  thumbnails. Thumbnails are disabled by default.
- Right-button gesture configuration is read from local Application Support
  files only.

## Permissions

The app may request:

- Accessibility, for reading/restoring/minimizing/focusing/moving windows.
- Input Monitoring, for right-button mouse gestures, mouse chords, double-Option,
  and Option release events.
- Screen Recording, optionally, for window thumbnails.
- Automation, conditionally, for shortcuts that are sent through System Events.

## Reporting Issues

For private security concerns, contact the repository owner directly. For
ordinary bugs or feature requests, open a GitHub issue.
