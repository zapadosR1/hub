#!/usr/bin/env bash
# Mostra o estado das protecoes depois de reiniciar.
# Uso:  sudo bash "verificar-protecoes.sh"

set -u

DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$DIR/verificacao-$(date +%Y%m%d-%H%M).txt"
exec > >(tee "$OUT") 2>&1

echo "=============================================================="
echo " Estado das protecoes - $(date '+%F %T')"
echo "=============================================================="

echo
echo "== Adaptador Bluetooth =="
timeout 10 bluetoothctl show 2>&1 | head -14

echo
echo "== Firmware em uso =="
md5sum /var/lib/firmware-extract/qca/crbtfw21.tlv \
       /var/lib/firmware-extract/qca/oneplus6/crnv21.bin 2>&1
echo "(esperado: 4fceacf111c621d93666aaeafc1eaf56  e  e31b6b4fc3eb807dac73b0838dfa3265)"

echo
echo "== Servicos =="
for u in bt-firmware-early.service bt-guard.service bt-guard-check.timer dpu-watchdog.timer; do
    printf '%-26s enabled=%-10s active=%s\n' "$u" \
        "$(systemctl is-enabled "$u" 2>&1)" \
        "$(systemctl is-active "$u" 2>&1)"
done
echo "droid-juicer: $(systemctl is-enabled droid-juicer.service 2>&1)"

echo
echo "== Ultimas linhas do bt-guard =="
tail -20 /var/log/bt-guard.log 2>/dev/null || echo "(sem log ainda)"

echo
echo "== Ultimas linhas do dpu-watchdog =="
tail -20 /var/log/dpu-watchdog.log 2>/dev/null || echo "(sem log ainda)"

echo
echo "== Processos em estado D (travados) =="
ps -eo pid,stat,wchan:48,comm 2>/dev/null | awk 'NR == 1 || $2 ~ /^D/'

echo
echo "== Erros DPU nos ultimos 10 minutos =="
journalctl -k --since '-10 min' --no-pager 2>/dev/null | grep -c 'dpu error'

echo
echo "== Variaveis do KWin (sessao) =="
for f in /var/home/*/.config/plasma-workspace/env/msm-display.sh; do
    [ -f "$f" ] && { echo "--- $f"; cat "$f"; }
done

echo
echo "=============================================================="
