#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release --scratch-path .build/universal-arm64 --triple arm64-apple-macosx13.0
swift build -c release --scratch-path .build/universal-x86_64 --triple x86_64-apple-macosx13.0
APP="$PWD/.build/AUDIAL.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swift scripts/make-icon.swift "$PWD/.build/Audial.iconset"
iconutil -c icns "$PWD/.build/Audial.iconset" -o "$APP/Contents/Resources/Audial.icns"
lipo -create .build/universal-arm64/arm64-apple-macosx/release/Dialito .build/universal-x86_64/x86_64-apple-macosx/release/Dialito -output "$APP/Contents/MacOS/Dialito"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>AUDIAL</string>
<key>CFBundleDisplayName</key><string>AUDIAL</string>
<key>CFBundleIdentifier</key><string>app.dialito.controller</string>
<key>CFBundleIconFile</key><string>Audial</string>
<key>CFBundleExecutable</key><string>Dialito</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.2.0</string>
<key>CFBundleVersion</key><string>3</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSAppleEventsUsageDescription</key><string>AUDIAL reads your current song and controls playback in Apple Music.</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
SIGNING_IDENTITY="${DIALITO_SIGNING_IDENTITY:-DIALITO Local Development}"
# Never silently fall back to ad-hoc signing: it invalidates Accessibility grants.
if ! security find-identity -v -p codesigning | /usr/bin/grep -Fq "\"$SIGNING_IDENTITY\""; then
    echo "Missing signing identity: $SIGNING_IDENTITY. Run scripts/setup-signing.py after authorizing local signing setup." >&2
    exit 1
fi
codesign --force --sign "$SIGNING_IDENTITY" --timestamp=none "$APP"
codesign --verify --strict "$APP"
echo "Built $APP"
