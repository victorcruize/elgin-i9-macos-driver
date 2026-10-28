#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
VERSION=1.3.0
TASK_BUILD="$(mktemp -d)"
trap 'rm -rf "$TASK_BUILD"' EXIT
DEST="$ROOT/dist"
mkdir -p "$DEST"
PAYLOAD="$TASK_BUILD/payload/Library/Printers/Elgin/i9"
mkdir -p "$PAYLOAD"
for ARCH in arm64 x86_64; do
    MACOSX_DEPLOYMENT_TARGET=11.0 clang -arch "$ARCH" -O2 -Wall -Wextra -o "$TASK_BUILD/filter-$ARCH" "$ROOT/rastertoelgini9.c" -lcups -lm
done
lipo -create "$TASK_BUILD/filter-arm64" "$TASK_BUILD/filter-x86_64" -output "$PAYLOAD/rastertoelgini9"
chmod 755 "$PAYLOAD/rastertoelgini9"
codesign --force --sign - "$PAYLOAD/rastertoelgini9"
cp "$ROOT/ElginI9.ppd" "$PAYLOAD/ElginI9.ppd"
xattr -c "$PAYLOAD/ElginI9.ppd"
pkgbuild --root "$TASK_BUILD/payload" --ownership recommended --identifier io.github.victorcruize.elgin-i9-driver --version "$VERSION" --install-location / "$TASK_BUILD/ElginI9Driver.pkg"
APP="$TASK_BUILD/Instalar Elgin i9 FULL2.app"
osacompile -o "$APP" "$ROOT/installer/Installer.applescript"
RES="$APP/Contents/Resources"
cp "$TASK_BUILD/ElginI9Driver.pkg" "$ROOT/discover.sh" "$ROOT/installer/configure.sh" "$RES/"
/usr/libexec/PlistBuddy -c 'Add :CFBundleIdentifier string io.github.victorcruize.elgin-i9-installer' "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :NSLocalNetworkUsageDescription string Busca impressoras na rede local pela porta TCP 9100.' "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
STAGE="$TASK_BUILD/dmg"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
printf '%s\n' 'Abra Instalar Elgin i9 FULL2.app. Busque a impressora ou informe o IP e autorize a instalação.' 'Driver comunitário, não oficial. Compatibilidade de distribuição: macOS 11 ou superior, Intel ou Apple Silicon, com CUPS/PPD.' 'Este aplicativo e o pacote não são assinados com Developer ID nem notarizados. O macOS pode bloquear a abertura; consulte Ajustes > Privacidade e Segurança para autorizar somente se confiar na origem.' 'Não é preciso instalar Xcode, Homebrew ou Python. Não há impressão automática.' > "$STAGE/LEIA-ME.txt"
hdiutil create -volname 'Elgin i9 FULL2' -srcfolder "$STAGE" -ov -format UDZO "$DEST/Elgin-i9-FULL2-macOS-$VERSION.dmg"
echo "$DEST/Elgin-i9-FULL2-macOS-$VERSION.dmg"
