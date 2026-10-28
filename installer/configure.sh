#!/bin/sh
set -eu
VALIDATE=0
if [ "${1:-}" = --validate ]; then VALIDATE=1; shift; fi
IP="${1:-}"
printf '%s\n' "$IP" | awk -F. 'NF != 4 {exit 1} {for(i=1;i<=4;i++) if($i !~ /^[0-9]+$/ || $i>255 || length($i)>3) exit 1}' || { echo 'IPv4 invalido'; exit 1; }
[ "$VALIDATE" -ne 1 ] || exit 0
[ "$(id -u)" -eq 0 ] || { echo 'Permissao de administrador necessaria'; exit 1; }
/usr/sbin/lpadmin -p ELGIN_I9 -E -v "socket://$IP:9100" -P /Library/Printers/Elgin/i9/ElginI9.ppd -D 'Elgin i9 FULL2' -o printer-is-shared=false
