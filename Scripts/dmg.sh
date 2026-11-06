#!/bin/bash
# "Gizli Dosyalar.app"ı sürükle-bırak kurulumlu bir .dmg'ye paketler.
# Xcode gerekmez; yalnızca Command Line Tools araçları kullanılır
# (hdiutil, osascript, sips, tiffutil, ve isteğe bağlı Rez/DeRez/SetFile).
# Uygulama önce ./build.sh ile derlenmiş olmalıdır.
set -euo pipefail
cd "$(dirname "$0")/.."

AD="Gizli Dosyalar"                 # birim (disk) ve .app adı
APP="build/$AD.app"
DMG="build/GizliDosyalar.dmg"
ICNS="$APP/Contents/Resources/AppIcon.icns"
HAM="build/tmp.dmg"                 # geçici okuma-yazma imajı
SAHNE="build/dmg-sahne"            # DMG'ye konacak içerik

[ -d "$APP" ] || { echo "✗ Önce ./build.sh çalıştırın — bulunamadı: $APP" >&2; exit 1; }

# Bu araçlar macOS sürümüne göre ya PATH'te ya da yalnızca 'xcrun' ile çağrılabilir.
arac() { if command -v "$1" >/dev/null 2>&1; then "$@"; else xcrun "$@"; fi; }

echo "→ DMG içeriği hazırlanıyor…"
rm -rf "$SAHNE" "$HAM" "$DMG"
mkdir -p "$SAHNE/.background"
cp -R "$APP" "$SAHNE/"
ln -s /Applications "$SAHNE/Applications"           # sürükle-bırak hedefi

# Birim (disk) simgesi: uygulamanın kendi ikonu. Aşağıda SetFile ile etkinleştirilir.
[ -f "$ICNS" ] && cp "$ICNS" "$SAHNE/.VolumeIcon.icns"

# Arka plan: Retina için 1x + 2x'i tek TIFF'te birleştir (en iyi çaba; başarısızsa düz zemin).
ARKA=""
if swift Scripts/dmg-arkaplan.swift "$SAHNE/.background/arkaplan.png"    1 \
   && swift Scripts/dmg-arkaplan.swift "$SAHNE/.background/arkaplan@2x.png" 2; then
    if arac tiffutil -cathidpicheck \
            "$SAHNE/.background/arkaplan.png" "$SAHNE/.background/arkaplan@2x.png" \
            -out "$SAHNE/.background/arkaplan.tiff" >/dev/null 2>&1; then
        ARKA="arkaplan.tiff"
    else
        ARKA="arkaplan.png"
    fi
fi

echo "→ Okuma-yazma imajı oluşturuluyor…"
BOYUT_MB=$(( $(du -sk "$SAHNE" | cut -f1) / 1024 + 20 ))   # içerik + düzen için pay
hdiutil create -volname "$AD" -srcfolder "$SAHNE" -fs HFS+ \
    -format UDRW -size "${BOYUT_MB}m" -ov "$HAM" >/dev/null

echo "→ Pencere düzeni ayarlanıyor…"
BAG="/Volumes/$AD"
# Aynı adlı bir disk zaten bağlıysa (ör. test için açılıp çıkarılmamış eski DMG) yeni imaj
# "$AD 1" adıyla bağlanır ve düzen sessizce yanlış (salt okunur) diske uygulanır.
if [ -d "$BAG" ]; then
    echo "✗ \"$BAG\" zaten bağlı. Önce çıkarın: hdiutil detach \"$BAG\"" >&2
    rm -f "$HAM"; rm -rf "$SAHNE"; exit 1
fi
AYGIT=$(hdiutil attach -readwrite -noverify -noautoopen "$HAM" \
        | grep '^/dev/' | head -1 | awk '{print $1}') || true

arac SetFile -a C "$BAG" 2>/dev/null || true          # birim simgesini etkinleştir

# Finder düzeni: grafik oturum (örn. başsız CI) yoksa sessizce atlanır, imaj yine çalışır.
osascript <<OSA >/dev/null 2>&1 || true
tell application "Finder"
  tell disk "$AD"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {300, 150, 840, 550}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 128
    if "$ARKA" is not "" then set background picture of opts to file ".background:$ARKA"
    set position of item "$AD.app" of container window to {150, 200}
    set position of item "Applications" of container window to {390, 200}
    update without registering applications
    delay 1
    close
  end tell
end tell
OSA

# Finder düzen sırasında .VolumeIcon.icns'i silebiliyor; birim simgesi için geri koy.
if [ -f "$ICNS" ] && [ ! -f "$BAG/.VolumeIcon.icns" ]; then
    cp "$ICNS" "$BAG/.VolumeIcon.icns" 2>/dev/null || true
fi

sync
arac SetFile -a C "$BAG" 2>/dev/null || true
chmod -Rf go-w "$BAG" 2>/dev/null || true

echo "→ Sıkıştırılmış DMG yazılıyor…"
hdiutil detach "$AYGIT" >/dev/null 2>&1 || { sleep 2; hdiutil detach "$AYGIT" -force >/dev/null 2>&1 || true; }
hdiutil convert "$HAM" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
rm -f "$HAM"
rm -rf "$SAHNE"

# .dmg dosyasının kendi Finder simgesi (en iyi çaba; Rez/DeRez/SetFile gerektirir).
if [ -f "$ICNS" ]; then
    GECICI=$(mktemp -d)
    cp "$ICNS" "$GECICI/ikon.icns"
    if arac sips -i "$GECICI/ikon.icns" >/dev/null 2>&1 \
       && arac DeRez -only icns "$GECICI/ikon.icns" > "$GECICI/ikon.rsrc" 2>/dev/null \
       && arac Rez -append "$GECICI/ikon.rsrc" -o "$DMG" 2>/dev/null; then
        arac SetFile -a C "$DMG" 2>/dev/null || true
    fi
    rm -rf "$GECICI"
fi

echo "✓ DMG hazır: $DMG"
