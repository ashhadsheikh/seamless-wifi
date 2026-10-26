#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p dist

swift scripts/generate-app-icon.swift
ICONSET="$ROOT/dist/SeamlessWiFi.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
for entry in "16 16" "32 16" "32 32" "64 32" "64 64" "128 64" "128 128" "256 128" "256 256" "512 256" "512 512" "1024 512"; do
  read -r pixels points <<< "$entry"
  if [[ "$pixels" == "$points" ]]; then
    name="icon_${points}x${points}.png"
  else
    name="icon_${points}x${points}@2x.png"
  fi
  sips -z "$pixels" "$pixels" "$ROOT/Resources/SeamlessWiFi.png" --out "$ICONSET/$name" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$ROOT/dist/SeamlessWiFi.icns"

swift build -c release --triple arm64-apple-macosx13.0 --product SeamlessWiFi
swift build -c release --triple x86_64-apple-macosx13.0 --product SeamlessWiFi
APP="$ROOT/dist/Seamless WiFi.app"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp "$ROOT/dist/SeamlessWiFi.icns" "$APP/Contents/Resources/SeamlessWiFi.icns"
lipo -create \
  .build/arm64-apple-macosx/release/SeamlessWiFi \
  .build/x86_64-apple-macosx/release/SeamlessWiFi \
  -output "$APP/Contents/MacOS/SeamlessWiFi"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>SeamlessWiFi</string>
<key>CFBundleIdentifier</key><string>com.seamlesswifi.mac</string>
<key>CFBundleName</key><string>Seamless WiFi</string>
<key>CFBundleDisplayName</key><string>Seamless WiFi</string>
<key>CFBundleIconFile</key><string>SeamlessWiFi</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>0.1.0</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSLocationUsageDescription</key><string>Seamless WiFi uses Wi-Fi network names to show nearby networks and make switching recommendations.</string>
</dict></plist>
PLIST

if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  codesign --force --deep --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$APP"
else
  codesign --force --deep --sign - "$APP"
  echo "Warning: ad-hoc signature only. Set DEVELOPER_ID_APPLICATION for a Gatekeeper-ready release."
fi

xcrun stapler validate "$APP" >/dev/null 2>&1 || true
ZIP="$ROOT/dist/Seamless-WiFi.zip"
DMG="$ROOT/dist/Seamless-WiFi.dmg"
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  if [[ -z "${DEVELOPER_ID_APPLICATION:-}" ]]; then
    echo "NOTARY_PROFILE requires DEVELOPER_ID_APPLICATION." >&2
    exit 2
  fi
  TEMP_ZIP="$ROOT/dist/Seamless-WiFi-notary-upload.zip"
  ditto -c -k --sequesterRsrc --keepParent "$APP" "$TEMP_ZIP"
  xcrun notarytool submit "$TEMP_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
fi

ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
hdiutil create -volname "Seamless WiFi" -srcfolder "$APP" -ov -format UDZO "$DMG" >/dev/null
if [[ -n "${NOTARY_PROFILE:-}" ]]; then xcrun stapler staple "$DMG"; fi

echo "App: $APP"
echo "Zip: $ZIP"
echo "DMG: $DMG"
lipo -info "$APP/Contents/MacOS/SeamlessWiFi"
