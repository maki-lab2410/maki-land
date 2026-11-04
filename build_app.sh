#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "==> Building DynamicIsland in Release mode..."
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
export DARWIN_USER_CACHE_DIR=/tmp/cache
export CLANG_MODULE_CACHE_PATH=/tmp/cache
mkdir -p /tmp/cache

xcrun swift build -c release --disable-sandbox

APP_NAME="makiland"
APP_BUNDLE="$DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> Packaging $APP_NAME.app..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary
cp "$DIR/.build/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

# Copy media-helper script
cp "$DIR/Resources/media-helper.swift" "$RESOURCES_DIR/media-helper.swift"

# Copy app icon (if exists)
if [ -f "$DIR/Resources/AppIcon.icns" ]; then
  cp "$DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
  echo "==> App icon included."
fi

# Create Info.plist
cat <<EOF > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.makiland</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>maki-land</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.7</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSCameraUsageDescription</key>
    <string>maki-land memerlukan izin kamera untuk fitur Cermin Webcam di Notch.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>maki-land memerlukan izin mikrofon untuk fitur perekam memo suara dan pengontrol mic.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>maki-land memerlukan akses untuk membaca informasi lagu dan mengontrol pemutaran musik.</string>
    <key>NSCalendarsFullAccessUsageDescription</key>
    <string>maki-land memerlukan akses kalender untuk menampilkan jadwal harian dari akun iOS/iCloud dan Google Calendar Anda.</string>
    <key>NSCalendarsUsageDescription</key>
    <string>maki-land memerlukan akses kalender untuk menampilkan jadwal harian Anda.</string>
</dict>
</plist>
EOF

echo "==> Performing Ad-Hoc code signing (Lifetime / No expiration)..."
codesign --force --deep -s - "$APP_BUNDLE"

echo "==> Generating disk image (DMG) & ZIP for easy distribution / Google Drive..."
hdiutil create -volname "makiland" -srcfolder "$APP_BUNDLE" -ov -format UDZO "$DIR/makiland-macOS.dmg"
zip -qr "$DIR/makiland-macOS.zip" "$APP_NAME.app"

echo "==> Build successful! Application created at: $APP_BUNDLE"
echo "==> Installer DMG created at: $DIR/makiland-macOS.dmg"
echo "==> Archive ZIP created at: $DIR/makiland-macOS.zip"
