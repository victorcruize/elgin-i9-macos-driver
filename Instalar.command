#!/bin/sh
cd "$(dirname "$0")" || exit 1
/bin/sh ./install.sh
RESULT=$?
printf '\nPressione Enter para fechar. '
read -r IGNORE
exit "$RESULT"
