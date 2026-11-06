#!/bin/bash
# "Gizli Dosyalar.app" paketini build/ klasörüne derler. Xcode gerekmez (Command Line Tools yeter).
set -euo pipefail
cd "$(dirname "$0")"

AD="GizliDosyalar"
APP="build/Gizli Dosyalar.app"
GECICI="build/tmp"

# Çalışan eski kopyayı kapat; yoksa `open` yeni derlemeyi değil eski süreci öne getirir.
pkill -x "$AD" 2>/dev/null || true

rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$GECICI"

echo "→ Derleniyor (arm64 + x86_64)…"
for mimari in arm64 x86_64; do
    swiftc -O -target "$mimari-apple-macos14.0" -parse-as-library -o "$GECICI/$AD-$mimari" Sources/GizliDosyalar.swift
done
lipo -create -output "$APP/Contents/MacOS/$AD" "$GECICI/$AD-arm64" "$GECICI/$AD-x86_64"
cp Info.plist "$APP/Contents/Info.plist"

echo "→ İkon çiziliyor…"
IKONSET="$GECICI/AppIcon.iconset"
mkdir -p "$IKONSET"
swift Scripts/ikon.swift "$GECICI/ikon-1024.png"
for b in 16 32 128 256 512; do
    sips -z $b $b "$GECICI/ikon-1024.png" --out "$IKONSET/icon_${b}x${b}.png" >/dev/null
    sips -z $((b * 2)) $((b * 2)) "$GECICI/ikon-1024.png" --out "$IKONSET/icon_${b}x${b}@2x.png" >/dev/null
done
iconutil -c icns "$IKONSET" -o "$APP/Contents/Resources/AppIcon.icns"

echo "→ İmzalanıyor (ad-hoc)…"
codesign --force --sign - "$APP"

echo "→ DMG paketleniyor…"
bash Scripts/dmg.sh

echo "→ İndirme arşivi hazırlanıyor…"
ditto -c -k --keepParent "$APP" "build/GizliDosyalar.zip"

rm -rf "$GECICI"
echo "✓ Uygulama: $APP"
echo "✓ DMG:      build/GizliDosyalar.dmg"
echo "✓ Arşiv:    build/GizliDosyalar.zip"
