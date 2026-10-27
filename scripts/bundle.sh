#!/bin/sh
# Builds build/Rec.app. Set CODESIGN_IDENTITY to sign with a real certificate,
# which keeps privacy permissions across rebuilds (ad-hoc signing resets them).
set -e
cd "$(dirname "$0")/.."

CONFIG=${CONFIG:-release}
IDENTITY=${CODESIGN_IDENTITY:--}
APP=build/Rec.app

swift build -c "$CONFIG"
BIN=$(swift build -c "$CONFIG" --show-bin-path)

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Rec" "$APP/Contents/MacOS/Rec"
install -m 644 Resources/Info.plist "$APP/Contents/Info.plist"
ICONSET=build/Rec.iconset
mkdir -p "$ICONSET"
for SIZE in 16 32 128 256 512; do
    sips -z "$SIZE" "$SIZE" Resources/Icon/AppIcon.png --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
    DOUBLE=$((SIZE * 2))
    sips -z "$DOUBLE" "$DOUBLE" Resources/Icon/AppIcon.png --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/Rec.icns"
codesign --force --options runtime --sign "$IDENTITY" "$APP"
echo "Built $APP"
