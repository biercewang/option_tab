#!/usr/bin/env bash
set -euo pipefail

BUNDLE_ID="local.trusted-alt-tab"
APP_PATH="${APP_PATH:-$HOME/Applications/TrustedAltTab.app}"

pkill -x TrustedAltTab 2>/dev/null || true
tccutil reset Accessibility "$BUNDLE_ID" || true
tccutil reset ScreenCapture "$BUNDLE_ID" || true

open "$APP_PATH"
open 'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility'
