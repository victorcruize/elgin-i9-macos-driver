#!/bin/sh
set -eu
sudo lpadmin -x ELGIN_I9
sudo rm -f /Library/Printers/Elgin/i9/rastertoelgini9 /Library/Printers/Elgin/i9/ElginI9.ppd
echo "Fila e driver removidos."
