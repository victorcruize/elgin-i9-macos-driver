#!/bin/sh
set -eu
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
[ "$(uname -s)" = Darwin ] || { echo "Este instalador requer macOS."; exit 1; }
IP="${1:-}"
if [ -z "$IP" ]; then IP="$(/bin/sh "$HERE/discover.sh")"; fi
case "$IP" in ''|*[!0-9.]*|.*|*.) echo "Informe um endereco IPv4 valido."; exit 1;; esac
printf '%s\n' "$IP" | awk -F. 'NF != 4 {exit 1} {for(i=1;i<=4;i++) if($i == "" || $i>255 || length($i)>3) exit 1}' || { echo "IPv4 invalido."; exit 1; }
xcrun --find clang >/dev/null 2>&1 || { echo "Instale as ferramentas Apple com: xcode-select --install"; exit 1; }
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT HUP INT TERM
clang -O2 -Wall -Wextra -o "$BUILD/rastertoelgini9" "$HERE/rastertoelgini9.c" -lcups -lm
DIR=/Library/Printers/Elgin/i9
sudo -v
sudo install -d -o root -g wheel -m 755 "$DIR"
sudo install -o root -g wheel -m 755 "$BUILD/rastertoelgini9" "$DIR/rastertoelgini9"
sudo install -o root -g wheel -m 644 "$HERE/ElginI9.ppd" "$DIR/ElginI9.ppd"
sudo lpadmin -p ELGIN_I9 -E -v "socket://$IP:9100" -P "$DIR/ElginI9.ppd" -D "Elgin i9" -o printer-is-shared=false
echo "Elgin i9 instalada em $IP:9100. Feche e reabra o aplicativo antes de imprimir."
