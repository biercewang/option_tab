# Security Policy

TrustedAltTab is designed as a local-only macOS utility.

## Data Handling

- No network requests are made by the app.
- No analytics or telemetry are collected.
- Window titles and diagnostic events are written only to the local log file:
  `~/Library/Logs/TrustedAltTab.log`.
- Screen Recording permission is used only to generate local thumbnails.

## Permissions

The app may request:

- Accessibility, for reading/restoring/minimizing/focusing/moving windows.
- Screen Recording, for window thumbnails.

## Reporting Issues

For private security concerns, contact the repository owner directly. For
ordinary bugs or feature requests, open a GitHub issue.
