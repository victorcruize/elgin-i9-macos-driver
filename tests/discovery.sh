#!/bin/sh
set -eu
PROJECT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
TASK_TMP="$(mktemp -d)"
trap 'rm -rf "$TASK_TMP"' EXIT
cat > "$TASK_TMP/route" <<'MOCK'
#!/bin/sh
echo 'interface: en0'
MOCK
cat > "$TASK_TMP/ipconfig" <<'MOCK'
#!/bin/sh
case "$1" in getifaddr) echo 192.168.0.109;; getoption) echo "${MOCK_MASK:-255.255.255.0}";; esac
MOCK
cat > "$TASK_TMP/nc" <<'MOCK'
#!/bin/sh
case "$*" in *192.168.0.127*|*192.168.0.145*) exit 0;; *) exit 1;; esac
MOCK
chmod +x "$TASK_TMP/route" "$TASK_TMP/ipconfig" "$TASK_TMP/nc"
PATH="$TASK_TMP:$PATH"
export PATH
result="$(printf '1\ns\n2\n' | sh "$PROJECT/discover.sh" 2>/dev/null)"
[ "$result" = 192.168.0.145 ]
result="$(printf '2\n192.168.1.20\n' | sh "$PROJECT/discover.sh" 2>/dev/null)"
[ "$result" = 192.168.1.20 ]
if printf '2\n999.1.1.1\n' | sh "$PROJECT/discover.sh" >/dev/null 2>&1; then exit 1; fi
MOCK_MASK=255.255.255.252
export MOCK_MASK
result="$(printf '1\ns\n192.168.0.110\n' | sh "$PROJECT/discover.sh" 2>/dev/null)"
[ "$result" = 192.168.0.110 ]
echo 'PASS: discovery selection, manual IP, invalid IP, subnet restriction'
