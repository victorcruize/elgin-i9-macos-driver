#!/bin/sh
# Probes TCP 9100 without sending print data. stdout contains only the chosen IP.
set -eu
LIST_ONLY=0
[ "${1:-}" != --list ] || LIST_ONLY=1
valid_ip() {
    printf '%s\n' "$1" | awk -F. 'NF != 4 {exit 1} {for(i=1;i<=4;i++) if($i !~ /^[0-9]+$/ || $i>255 || length($i)>3) exit 1}'
}
manual() {
    printf 'IP da impressora (vazio para cancelar): ' >&2
    read -r chosen || exit 1
    valid_ip "$chosen" || { echo 'IPv4 invalido ou busca cancelada.' >&2; exit 1; }
    printf '%s\n' "$chosen"
    exit 0
}
if [ "$LIST_ONLY" -eq 0 ]; then
printf '1) Buscar impressoras na rede local\n2) Informar IP manualmente\nEscolha [1]: ' >&2
read -r mode || exit 1
case "$mode" in ''|1) ;; 2) manual;; *) echo 'Opcao invalida.' >&2; exit 1;; esac
fi
iface="$(route -n get default 2>/dev/null | awk '/interface:/ {print $2; exit}')"
local_ip="$(ipconfig getifaddr "$iface" 2>/dev/null || true)"
if ! valid_ip "$local_ip"; then
    echo 'Nao foi possivel detectar a rede IPv4. Informe o IP manualmente.' >&2
    if [ "$LIST_ONLY" -eq 1 ]; then exit 1; fi
    manual
fi
# Restrict the probe to the directly connected local /24 and actual netmask.
mask="$(ipconfig getoption "$iface" subnet_mask 2>/dev/null || true)"
if ! valid_ip "$mask"; then
    echo 'Nao foi possivel detectar a mascara. Informe o IP manualmente.' >&2
    if [ "$LIST_ONLY" -eq 1 ]; then exit 1; fi
    manual
fi
prefix="${local_ip%.*}"
if [ "$LIST_ONLY" -eq 0 ]; then
printf 'Buscar %s.1 a %s.254 na interface %s? [s/N]: ' "$prefix" "$prefix" "$iface" >&2
read -r confirm || exit 1
case "$confirm" in s|S|sim|SIM) ;; *) manual;; esac
fi
TASK_TMP="$(mktemp -d)"
trap 'rm -rf "$TASK_TMP"' EXIT
trap 'exit 130' INT TERM HUP
printf 'Buscando porta TCP 9100 (sem enviar dados de impressao)...\n' >&2
# Only scan addresses within the interface subnet, excluding its network/broadcast.
awk -v ip="$local_ip" -v mask="$mask" -v prefix="$prefix" 'BEGIN {
    split(ip,a,"."); split(mask,m,".");
    for(n=1;n<=254;n++) {
        split(prefix "." n,b,"."); ok=1; network=1; broadcast=1;
        for(j=1;j<=4;j++) {
            block=256-m[j];
            if(int(a[j]/block)!=int(b[j]/block)) ok=0;
            if(b[j]%block!=0) network=0;
            if(b[j]%block!=block-1) broadcast=0;
        }
        if(ok && !network && !broadcast && prefix "." n != ip) print n;
    }
}' > "$TASK_TMP/hosts"
batch=0
while IFS= read -r host; do
    (
        if nc -G 1 -z "$prefix.$host" 9100 >/dev/null 2>&1; then
            printf '%s\n' "$prefix.$host" > "$TASK_TMP/$host.found"
        fi
    ) &
    batch=$((batch + 1))
    if [ "$batch" -eq 16 ]; then wait; batch=0; fi
done < "$TASK_TMP/hosts"
wait
: > "$TASK_TMP/results"
for host in $(cat "$TASK_TMP/hosts"); do
    if [ -f "$TASK_TMP/$host.found" ]; then cat "$TASK_TMP/$host.found" >> "$TASK_TMP/results"; fi
done
if [ "$LIST_ONLY" -eq 1 ]; then cat "$TASK_TMP/results"; exit 0; fi
count="$(wc -l < "$TASK_TMP/results" | tr -d ' ')"
if [ "$count" -eq 0 ]; then
    echo 'Nenhum candidato encontrado. Confira cabo, IP, firewall ou outra interface/VLAN.' >&2
    if [ "$LIST_ONLY" -eq 1 ]; then exit 1; fi
    manual
fi
echo 'Candidatos (a porta aberta NAO confirma que sejam Elgin i9):' >&2
awk '{printf "%d) %s\n", NR, $0}' "$TASK_TMP/results" >&2
printf 'Numero do IP confirmado da sua i9, ou m para digitar manualmente: ' >&2
read -r pick || exit 1
case "$pick" in m|M) manual;; ''|*[!0-9]*|????*) echo 'Selecao invalida.' >&2; exit 1;; esac
if [ "$pick" -lt 1 ] || [ "$pick" -gt "$count" ]; then echo 'Selecao invalida.' >&2; exit 1; fi
sed -n "${pick}p" "$TASK_TMP/results"
