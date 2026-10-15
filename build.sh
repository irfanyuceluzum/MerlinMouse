#!/bin/bash
# MerlinMouse.app paketini derler ve imzalar.
# Bir "Apple Development" sertifikası varsa onunla imzalar: Erişilebilirlik izni
# yeniden derlemelerde korunur. Yoksa yerel (ad-hoc) imza kullanılır ve her
# derlemeden sonra izni kapatıp açmak gerekir. Elle seçmek için: SIGN_ID="..." ./build.sh
# İmzadan sonra uygulama /Applications/MerlinMouse.app konumuna kurulur;
# yalnız build/ altına üretmek için: INSTALL=0 ./build.sh
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP=build/MerlinMouse.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/MerlinMouse "$APP/Contents/MacOS/MerlinMouse"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

SIGN_ID="${SIGN_ID:-$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Apple Development/ { print $2; exit }')}"
if [ -n "$SIGN_ID" ]; then
    codesign --force --sign "$SIGN_ID" "$APP"
    echo "İmza: $SIGN_ID"
else
    codesign --force --sign - "$APP"
    echo "İmza: yerel (ad-hoc) — derlemeden sonra Erişilebilirlik iznini kapatıp aç."
fi

echo "Hazır: $(pwd)/$APP"

if [ "${INSTALL:-1}" != "0" ]; then
    rm -rf /Applications/MerlinMouse.app
    ditto "$APP" /Applications/MerlinMouse.app
    echo "Kuruldu: /Applications/MerlinMouse.app"
fi
