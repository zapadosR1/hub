#!/usr/bin/env bash
# Instala protecoes para o Bluetooth e para o display (commit DPU) no OnePlus 6T
# Uso:  sudo bash "instalar-protecoes.sh"
#
# O que faz:
#   1. Salva um diagnostico do BT deste boot em bt-diagnostico-AAAAMMDD-HHMM.txt
#   2. Guarda o firmware bom em /etc/bt-firmware e copia para /var e /usr
#   3. Mascara o droid-juicer (nao sobrescreve mais o firmware)
#   4. Instala o bt-guard (boot, retomada e verificacao a cada 10 min)
#   5. Instala o dpu-watchdog (detecta commit travado e registra/recupera)
#   6. Aplica variaveis do KWin para evitar o caminho que trava o DPU

set -u

DIR="$(cd "$(dirname "$0")" && pwd)"

# Se rodado de outro diretorio, tenta achar os arquivos do projeto
if [ ! -f "$DIR/crbtfw21-fedora.tlv" ]; then
    for d in "/var/home/zapados/Documentos/Projeto Padrão" "$HOME/Documentos/Projeto Padrão"; do
        if [ -f "$d/crbtfw21-fedora.tlv" ]; then
            DIR="$d"
            break
        fi
    done
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "Execute com sudo:  sudo bash \"$0\""
    exit 1
fi

U="${SUDO_USER:-zapados}"
UHOME="$(getent passwd "$U" | cut -d: -f6)"
[ -n "${UHOME:-}" ] || UHOME="/var/home/$U"

for f in crbtfw21-fedora.tlv crnv21-fedora.bin; do
    if [ ! -f "$DIR/$f" ]; then
        echo "ERRO: nao encontrei $DIR/$f"
        exit 1
    fi
done

echo "=================================================================="
echo " Protecoes Bluetooth + Display - OnePlus 6T / PocketBlue"
echo "=================================================================="

# ------------------------------------------------------------------
# 0. Diagnostico do BT deste boot (fica salvo para analise)
# ------------------------------------------------------------------
DIAG="$DIR/bt-diagnostico-$(date +%Y%m%d-%H%M).txt"
{
    echo "== kernel: bluetooth deste boot =="
    journalctl -b -k -o short-iso --no-pager 2>&1 | grep -iE 'hci0|qca|bluetooth|wcn399' || true
    echo
    echo "== bluetoothd deste boot =="
    journalctl -b -u bluetooth -o short-iso --no-pager 2>&1 | tail -40 || true
    echo
    echo "== onde fica /var/lib/firmware-extract =="
    findmnt -T /var/lib/firmware-extract 2>&1 || true
    systemctl list-units --type=mount --all --no-pager 2>&1 | grep -i firmware || true
    echo
    echo "== adaptador agora =="
    timeout 10 bluetoothctl show 2>&1 | head -20 || true
} > "$DIAG" 2>&1
echo
echo "[1/6] Diagnostico do BT salvo em: $DIAG"

# ------------------------------------------------------------------
# 1. Firmware bom: /etc (permanente) -> /var (usado pelo kernel)
# ------------------------------------------------------------------
install -d -m 755 /etc/bt-firmware
install -m 644 "$DIR/crbtfw21-fedora.tlv" /etc/bt-firmware/crbtfw21.tlv
install -m 644 "$DIR/crnv21-fedora.bin"   /etc/bt-firmware/crnv21.bin

install -d -m 755 /var/lib/firmware-extract/qca/oneplus6
install -m 644 /etc/bt-firmware/crbtfw21.tlv /var/lib/firmware-extract/qca/crbtfw21.tlv
install -m 644 /etc/bt-firmware/crnv21.bin   /var/lib/firmware-extract/qca/oneplus6/crnv21.bin

systemctl mask droid-juicer.service >/dev/null 2>&1 || true

echo "[2/6] Firmware guardado em /etc/bt-firmware e aplicado em /var"
echo "        droid-juicer: $(systemctl is-enabled droid-juicer.service 2>&1)"

# ------------------------------------------------------------------
# 2. Copia do firmware para /usr antes do probe do kernel
#    (o /usr e overlay gravavel; resolve corrida com /var)
# ------------------------------------------------------------------
cat > /usr/local/bin/bt-firmware-early.sh <<'EOF'
#!/usr/bin/env bash
# Copia o firmware do BT para /usr/lib/firmware antes do probe do serdev.
# /usr e overlay: some no reboot, por isso roda a cada boot.
set -u
SRC=/etc/bt-firmware
DST=/usr/lib/firmware/qca
[ -f "$SRC/crbtfw21.tlv" ] || exit 0
[ -f "$SRC/crnv21.bin" ]   || exit 0
mkdir -p "$DST/oneplus6" 2>/dev/null || true
cp -f "$SRC/crbtfw21.tlv" "$DST/crbtfw21.tlv"            2>/dev/null || true
cp -f "$SRC/crbtfw21.tlv" "$DST/oneplus6/crbtfw21.tlv"   2>/dev/null || true
cp -f "$SRC/crnv21.bin"   "$DST/crnv21.bin"              2>/dev/null || true
cp -f "$SRC/crnv21.bin"   "$DST/oneplus6/crnv21.bin"     2>/dev/null || true
exit 0
EOF
chmod 755 /usr/local/bin/bt-firmware-early.sh

cat > /etc/systemd/system/bt-firmware-early.service <<'EOF'
[Unit]
Description=bt-firmware-early (copia firmware do BT para /usr)
DefaultDependencies=no
After=local-fs.target systemd-journald.socket
Before=sysinit.target shutdown.target
Conflicts=shutdown.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/bt-firmware-early.sh

[Install]
WantedBy=sysinit.target
EOF
/usr/local/bin/bt-firmware-early.sh 2>/dev/null || true

echo "[3/6] Servico bt-firmware-early criado"

# ------------------------------------------------------------------
# 3. bt-guard: garante firmware e liga o adaptador
# ------------------------------------------------------------------
cat > /usr/local/bin/bt-guard.sh <<'EOF'
#!/usr/bin/env bash
set -u

MODE="${1:-boot}"
TLV=/var/lib/firmware-extract/qca/crbtfw21.tlv
NVM=/var/lib/firmware-extract/qca/oneplus6/crnv21.bin
GOOD_TLV=4fceacf111c621d93666aaeafc1eaf56
GOOD_NVM=e31b6b4fc3eb807dac73b0838dfa3265
LOG=/var/log/bt-guard.log
STAMP=/run/bt-guard.lastlog

[ -f /etc/bt-guard/keep-on ] || exit 0

log() { logger -t bt-guard "$*" 2>/dev/null; echo "$*"; }

md5() { md5sum "$1" 2>/dev/null | awk '{print $1}'; }

# firmware correto?
if [ "$(md5 "$TLV")" != "$GOOD_TLV" ]; then
    install -m 644 /etc/bt-firmware/crbtfw21.tlv "$TLV" 2>/dev/null && log "crbtfw21.tlv restaurado"
fi
if [ "$(md5 "$NVM")" != "$GOOD_NVM" ]; then
    install -m 644 /etc/bt-firmware/crnv21.bin "$NVM" 2>/dev/null && log "crnv21.bin restaurado"
fi

systemctl is-active --quiet bluetooth.service || systemctl start bluetooth.service

if [ "$MODE" = "quick" ]; then TRIES=1; else TRIES=6; fi
i=0
while [ "$i" -lt "$TRIES" ]; do
    i=$((i + 1))
    if bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; then
        [ "$MODE" != "quick" ] && log "Bluetooth ligado (tentativa $i)"
        exit 0
    fi
    bluetoothctl power on >/dev/null 2>&1
    [ "$i" -lt "$TRIES" ] && sleep 3
done

# no modo quick, grava no maximo 1 vez por hora
if [ "$MODE" = "quick" ] && [ -f "$STAMP" ]; then
    idade=$(( $(date +%s) - $(stat -c %Y "$STAMP") ))
    [ "$idade" -lt 3600 ] && exit 1
fi
touch "$STAMP" 2>/dev/null || true

log "Bluetooth NAO ligou (modo $MODE)"

{
    echo "=== $(date '+%F %T') modo=$MODE ==="
    bluetoothctl show 2>&1 | head -12
    journalctl -b -k -o short-iso --no-pager 2>/dev/null | grep -iE 'hci0|qca|bluetooth' | tail -40
} >> "$LOG"

exit 1
EOF
chmod 755 /usr/local/bin/bt-guard.sh

cat > /etc/systemd/system/bt-guard.service <<'EOF'
[Unit]
Description=bt-guard: firmware e power-on do Bluetooth
Wants=bluetooth.service
After=bluetooth.service
ConditionPathExists=/etc/bt-guard/keep-on

[Service]
Type=oneshot
ExecStart=/usr/local/bin/bt-guard.sh boot
TimeoutStartSec=90

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/bt-guard-check.service <<'EOF'
[Unit]
Description=bt-guard: verificacao periodica do Bluetooth
After=bt-guard.service
ConditionPathExists=/etc/bt-guard/keep-on

[Service]
Type=oneshot
ExecStart=/usr/local/bin/bt-guard.sh quick
EOF

cat > /etc/systemd/system/bt-guard-check.timer <<'EOF'
[Unit]
Description=bt-guard: verificacao a cada 10 minutos

[Timer]
OnBootSec=5min
OnUnitActiveSec=10min
AccuracySec=30s

[Install]
WantedBy=timers.target
EOF

cat > /usr/lib/systemd/system-sleep/bt-guard <<'EOF'
#!/bin/sh
# Reaplica o bt-guard depois de voltar da suspensao
[ "$1" = "post" ] && systemctl start --no-block bt-guard.service
exit 0
EOF
chmod 755 /usr/lib/systemd/system-sleep/bt-guard

install -d -m 755 /etc/bt-guard
touch /etc/bt-guard/keep-on

echo "[4/6] bt-guard instalado (boot, retomada e timer de 10 min)"

# ------------------------------------------------------------------
# 4. dpu-watchdog: detecta commit travado no display
# ------------------------------------------------------------------
cat > /usr/local/bin/dpu-watchdog.sh <<'EOF'
#!/usr/bin/env bash
set -u

LOG=/var/log/dpu-watchdog.log
STATE=/run/dpu-watchdog.state
RSTAMP=/run/dpu-watchdog.restart
ESTAMPA=/run/dpu-watchdog.errstamp
THRESHOLD=100

[ -f "$LOG" ] && [ "$(stat -c %s "$LOG" 2>/dev/null || echo 0)" -gt 1048576 ] && mv -f "$LOG" "$LOG.1"

travado="$(ps -eo pid,stat,wchan:48,comm 2>/dev/null | awk '$2 ~ /^D/ && $3 ~ /dpu_/ {print $1}')"
erros="$(journalctl -k --since '-2 min' --no-pager 2>/dev/null | grep -c 'dpu error')"

if [ -z "$travado" ]; then
    rm -f "$STATE"
    # sem kworker travado: so registra rajadas de erro, no maximo a cada 5 min
    if [ "$erros" -lt "$THRESHOLD" ]; then
        exit 0
    fi
    if [ -f "$ESTAMPA" ] && [ $(( $(date +%s) - $(stat -c %Y "$ESTAMPA") )) -lt 300 ]; then
        exit 0
    fi
    touch "$ESTAMPA" 2>/dev/null || true
fi

anterior="$(cat "$STATE" 2>/dev/null || true)"
echo "$travado" > "$STATE" 2>/dev/null || true

{
    echo "=== $(date '+%F %T') erros_2min=$erros travado=[$travado] anterior=[$anterior] ==="
    ps -eo pid,stat,wchan:48,comm 2>/dev/null | awk '$2 ~ /^D/'
    journalctl -k --since '-2 min' --no-pager 2>/dev/null | grep -i 'dpu error' | tail -8
} >> "$LOG"

# So age se o MESMO kworker aparecer travado em duas amostras seguidas.
if [ -n "$anterior" ] && [ "$travado" = "$anterior" ]; then
    if [ -f /etc/dpu-guard/auto-restart ]; then
        if [ ! -f "$RSTAMP" ] || [ $(( $(date +%s) - $(stat -c %Y "$RSTAMP") )) -gt 600 ]; then
            touch "$RSTAMP" 2>/dev/null || true
            logger -t dpu-watchdog "commit DPU travado; reiniciando a sessao grafica"
            systemctl restart plasmalogin >/dev/null 2>&1 || \
            systemctl restart sddm      >/dev/null 2>&1 || true
        fi
    fi
fi
EOF
chmod 755 /usr/local/bin/dpu-watchdog.sh

cat > /etc/systemd/system/dpu-watchdog.service <<'EOF'
[Unit]
Description=dpu-watchdog: detecta commit travado do display

[Service]
Type=oneshot
ExecStart=/usr/local/bin/dpu-watchdog.sh
EOF

cat > /etc/systemd/system/dpu-watchdog.timer <<'EOF'
[Unit]
Description=dpu-watchdog a cada minuto

[Timer]
OnBootSec=3min
OnUnitActiveSec=1min
AccuracySec=5s

[Install]
WantedBy=timers.target
EOF

install -d -m 755 /etc/dpu-guard

echo "[5/6] dpu-watchdog instalado (registra em /var/log/dpu-watchdog.log)"

# ------------------------------------------------------------------
# 5. KWin: evitar o caminho de planes que trava o DPU
# ------------------------------------------------------------------
ENVDIR="$UHOME/.config/plasma-workspace/env"
install -d -m 755 "$ENVDIR"
cat > "$ENVDIR/msm-display.sh" <<'EOF'
# Workarounds para o DPU do SDM845 (OnePlus 6T) no KWin.
# Carregado no inicio da sessao Plasma.
export KWIN_USE_OVERLAYS=0
export KWIN_DRM_NO_DIRECT_SCANOUT=1
export KWIN_FORCE_SW_CURSOR=1
EOF
chown -R "$U:$U" "$ENVDIR" 2>/dev/null || true

echo "[6/6] Variaveis do KWin gravadas em $ENVDIR/msm-display.sh"

# ------------------------------------------------------------------
systemctl daemon-reload
systemctl enable --now bt-firmware-early.service >/dev/null 2>&1 || true
systemctl enable bt-guard.service bt-guard-check.timer dpu-watchdog.timer >/dev/null 2>&1 || true
systemctl start bt-guard-check.timer dpu-watchdog.timer >/dev/null 2>&1 || true

echo
echo "=================================================================="
echo " Pronto."
echo
echo " - O firmware foi aplicado; o droid-juicer esta mascarado."
echo " - O bt-guard vai tentar ligar o BT no boot e a cada 10 min."
echo " - O dpu-watchdog registra travamentos em /var/log/dpu-watchdog.log."
echo " - As variaveis do KWin valem no proximo login/sessao."
echo
echo " Para o watchdog reiniciar a sessao sozinho quando travar:"
echo "     sudo touch /etc/dpu-guard/auto-restart"
echo
echo " Para desligar o bt-guard (deixar o BT desligado de proposito):"
echo "     sudo rm /etc/bt-guard/keep-on"
echo
echo " Reinicie para aplicar tudo:  sudo systemctl reboot"
echo
echo " Diagnostico do BT deste boot: $DIAG"
echo "=================================================================="
