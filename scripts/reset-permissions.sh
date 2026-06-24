#!/usr/bin/env bash
set -euo pipefail

BUNDLE_ID="local.alt-gesture"
APP_PATH="${APP_PATH:-$HOME/Applications/AltGesture.app}"

pkill -x AltGesture 2>/dev/null || true
pkill -x TrustedAltTab 2>/dev/null || true
pkill -x RightKeyGesture 2>/dev/null || true
tccutil reset Accessibility "$BUNDLE_ID" || true
tccutil reset ListenEvent "$BUNDLE_ID" || true
tccutil reset AppleEvents "$BUNDLE_ID" || true
tccutil reset ScreenCapture "$BUNDLE_ID" || true

open "$APP_PATH"
open 'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility'
