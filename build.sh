#!/bin/bash
# Builds Caffeine.app. Usage: ./build.sh [--install]  (--install copies to /Applications)
set -euo pipefail
cd "$(dirname "$0")"

APP=build/Caffeine.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents/Info.plist"

swiftc -O -parse-as-library -swift-version 5 \
    -target "$(uname -m)-apple-macosx13.0" \
    -o "$APP/Contents/MacOS/Caffeine" Sources/*.swift

codesign --force --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
    pkill -x Caffeine 2>/dev/null || true
    rm -rf /Applications/Caffeine.app
    cp -R "$APP" /Applications/
    echo "Installed to /Applications/Caffeine.app"
    open /Applications/Caffeine.app
fi
