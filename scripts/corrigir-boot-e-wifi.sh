#!/bin/bash
# ============================================================================
#  corrigir-boot-e-wifi.sh
#  OnePlus 6T (sdm845) - Fedora 44 Kinoite / Plasma Mobile
#
#  Uso:
#      sudo bash /var/home/zapados/corrigir-boot-e-wifi.sh
#
#  O que este script corrige:
#
#   1) rmtfs.service
#      O "Qualcomm remotefs service" ignorava o SIGTERM e o systemd esperava
#      45 s a cada desligamento. Pior: ao receber SIGTERM ele escreve no sysfs
#      para desligar o modem e provoca um Oops do kernel em rpmsg_dev_remove,
#      que deixa o processo preso. É a mensagem:
#         "A stop job is running for Qualcomm remotefs service (rmtfs.service)"
#      Correção: SIGKILL imediato (não executa o desligamento que causa o Oops)
#      + timeout de 5 s.
#
#   2) ath10k-shutdown.service
#      O "rmmod ath10k_snoc ath10k_core" pode travar quando o firmware do
#      Wi-Fi está em crash. Correção: limite de 20 s e SIGKILL.
#
#   3) droid-juicer.service
#      Roda em TODO boot, mostra na tela "Extracting binary firmware..."
#      e falha com panic "Text file busy". O firmware já foi extraído para
#      /usr/lib/firmware/updates, mas o marcador status.json nunca foi criado.
#      Correção: cria /var/lib/droid-juicer/status.json (o serviço passa a
#      ser ignorado, como deveria desde a primeira execução).
#
#   4) SSHFS (/var/home/zapados/servidor e servidor2)
#      Os dois mounts SSHFS impedem o desligamento de desmontar /var/home.
#      É a mensagem:
#         "Unmounting var-home.mount - /var/home..."
#      Correção: adiciona "auto_unmount" ao script de montagem e cria uma
#      unidade que desmonta os SSHFS antes de /var/home no shutdown.
#      A unidade precisa de Conflicts=shutdown.target (DefaultDependencies=no
#      não adiciona isso sozinho) e precisa estar ATIVA.
#
#   5) Wi-Fi (ath10k_snoc / WCN3990)
#      O firmware crasha ("Asserted in wlan_vdev.c:_wlan_vdev_down") quando
#      o rádio troca de AP ou recebe mudança de largura de banda do roteador.
#      Correção: fixa o BSSID no AP estável (canal 1, -49 dBm).
#      Obs.: a correção definitiva é no roteador (2.4 GHz fixo em 20 MHz,
#      desligar band steering / roaming agressivo).
#
#   6) bootloader-update.service
#      Falha em todo boot ("Failed to find all esp devices") porque o
#      bootupd não se aplica a este aparelho (u-boot + ostree).
#      Correção: mascara o serviço (reversível).
#
#   7) Console USB (ttyGS0)
#      Habilita o login serial em /dev/ttyGS0 (USB ACM) para poder entrar no
#      aparelho sem tela/teclado. O gadget ACM+NCM já é criado pelo
#      usb-network.service, que também é habilitado aqui.
#
#   8) Menu do GRUB visível por 10 segundos
#      Sem isso o GRUB boota o padrão quase instantaneamente e não há como
#      escolher uma entrada de emergência em um aparelho sem teclado.
#
#   9) Entradas de emergência no menu do GRUB
#      Cria duas entradas BLS (`emergency-b-rescue` e `emergency-a-shell`)
#      derivadas do deployment em execução:
#        - rescue.target, sem gráfico, com SSH + console USB
#        - multi-user.target, sem gráfico, com SSH + console USB
#      Elas aparecem depois das entradas ostree no menu. São regravadas a
#      cada execução deste script; rode-o de novo depois de cada
#      `rpm-ostree upgrade` (se ficarem velhas, o boot apenas cai no menu).
#
#  PARA DESFAZER TUDO:
#      sudo rm -rf /etc/systemd/system/rmtfs.service.d \
#                  /etc/systemd/system/ath10k-shutdown.service.d \
#                  /etc/systemd/system/sshfs-umount.service \
#                  /etc/systemd/system/serial-getty@ttyGS0.service.d \
#                  /var/lib/droid-juicer/status.json \
#                  /boot/loader/entries/emergency-*.conf
#      sudo systemctl unmask bootloader-update.service
#      sudo systemctl disable serial-getty@ttyGS0.service
#      sudo nmcli connection modify Dallonder 802-11-wireless.bssid ""
#      sudo systemctl daemon-reload
#      # e restaurar /var/home/zapados/montar_servidor.sh.bak
#      # e remover /etc/default/grub + restaurar /boot/grub2/grub.cfg.bak-*
# ============================================================================

set -u

# ---- opções (pode mudar antes de rodar) ------------------------------------
FIX_WIFI_BSSID="${FIX_WIFI_BSSID:-1}"              # 1 = fixa BSSID, 0 = não mexe
MASK_BOOTLOADER_UPDATE="${MASK_BOOTLOADER_UPDATE:-1}"  # 1 = mascara, 0 = deixa
CONEXAO="Dallonder"
BSSID_ALVO="f0:9f:c2:34:7c:f4"                     # AP canal 1, sinal -49 dBm
USUARIO="${SUDO_USER:-zapados}"
HOME_USUARIO="/var/home/${USUARIO}"
SCRIPT_SSHFS="${HOME_USUARIO}/montar_servidor.sh"
BLS_DIR="/boot/loader/entries"

# ---- helpers ---------------------------------------------------------------
info()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()    { printf '    \033[1;32m[OK]\033[0m %s\n' "$*"; }
warn()  { printf '    \033[1;33m[AVISO]\033[0m %s\n' "$*"; }
erro()  { printf '    \033[1;31m[ERRO]\033[0m %s\n' "$*"; }

if [ "$(id -u)" -ne 0 ]; then
    echo "Este script precisa de root. Rode:"
    echo "    sudo bash $0"
    exit 1
fi

echo "============================================================"
echo " Correção de boot + Wi-Fi - OnePlus 6T / Fedora 44"
echo "============================================================"

# ---- 1) rmtfs: parada imediata --------------------------------------------
info "1/9  rmtfs.service (travamento de 45 s no desligamento)"
mkdir -p /etc/systemd/system/rmtfs.service.d
cat > /etc/systemd/system/rmtfs.service.d/10-fast-stop.conf <<'EOF'
# Não esperar o SIGTERM: o rmtfs ignora e o systemd ficava 45 s parado
# em "A stop job is running for Qualcomm remotefs service".
[Service]
TimeoutStopSec=5
KillSignal=SIGKILL
SendSIGKILL=yes
EOF
ok "drop-in criado em /etc/systemd/system/rmtfs.service.d/10-fast-stop.conf"

# ---- 2) ath10k-shutdown: limite no rmmod ----------------------------------
info "2/9  ath10k-shutdown.service (rmmod pode travar com firmware em crash)"
mkdir -p /etc/systemd/system/ath10k-shutdown.service.d
cat > /etc/systemd/system/ath10k-shutdown.service.d/10-timeout.conf <<'EOF'
[Service]
TimeoutStopSec=20
KillSignal=SIGKILL
EOF
ok "drop-in criado em /etc/systemd/system/ath10k-shutdown.service.d/10-timeout.conf"

# ---- 3) droid-juicer: marcador de "já extraído" ---------------------------
info "3/9  droid-juicer.service (\"Extracting binary firmware...\" a cada boot)"
mkdir -p /var/lib/droid-juicer
if [ -f /var/lib/droid-juicer/status.json ] && \
   grep -q '"files"' /var/lib/droid-juicer/status.json; then
    ok "status.json válido já existe, nada a fazer"
else
    # JSON válido para o struct Status { files, folders }. O serviço só checa
    # se o arquivo existe (ConditionPathExists=!), mas um JSON inválido
    # quebraria um futuro "droid-juicer --cleanup".
    printf '{"files": [], "folders": []}\n' > /var/lib/droid-juicer/status.json
    chmod 644 /var/lib/droid-juicer/status.json
    ok "criado /var/lib/droid-juicer/status.json válido (serviço será ignorado)"
fi
# conferir se o firmware realmente está lá
if [ -f /usr/lib/firmware/updates/qcom/sdm845/oneplus6/adsp.mbn ] && \
   [ -f /usr/lib/firmware/updates/qcom/sdm845/oneplus6/wlanmdsp.mbn ]; then
    ok "firmware extraído presente em /usr/lib/firmware/updates"
else
    warn "firmware extraído incompleto em /usr/lib/firmware/updates"
fi

# ---- 4) SSHFS: auto_unmount + desmontar antes de /var/home ----------------
info "4/9  SSHFS (travamento em \"Unmounting var-home.mount\")"
if [ -f "$SCRIPT_SSHFS" ]; then
    if grep -q 'auto_unmount' "$SCRIPT_SSHFS"; then
        ok "montar_servidor.sh já tem auto_unmount"
    else
        cp -a "$SCRIPT_SSHFS" "${SCRIPT_SSHFS}.bak"
        # edita preservando dono/inode do arquivo
        sed 's/,allow_other"/,allow_other,auto_unmount"/' "$SCRIPT_SSHFS" > /tmp/.sshfs.tmp
        cat /tmp/.sshfs.tmp > "$SCRIPT_SSHFS"
        rm -f /tmp/.sshfs.tmp
        chown "${USUARIO}:${USUARIO}" "$SCRIPT_SSHFS"
        chmod 755 "$SCRIPT_SSHFS"
        ok "auto_unmount adicionado (backup: ${SCRIPT_SSHFS}.bak)"
    fi
else
    warn "$SCRIPT_SSHFS não encontrado"
fi

cat > /etc/systemd/system/sshfs-umount.service <<'EOF'
[Unit]
Description=Desmonta SSHFS antes de /var/home no desligamento
DefaultDependencies=no
Requires=var-home.mount
# Sem isto a unidade não é parada no shutdown (DefaultDependencies=no não
# adiciona Conflicts=shutdown.target automaticamente).
Conflicts=shutdown.target
# Ordena antes das unidades dos próprios mounts SSHFS, para que o umount -l
# rode primeiro e elas não fiquem presas tentando desmontar.
After=var-home.mount var-home-zapados-servidor.mount var-home-zapados-servidor2.mount
Before=shutdown.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/true
# "-" = falha não é fatal; umount -l resolve o mount preso
ExecStop=-/usr/bin/umount -l /var/home/zapados/servidor
ExecStop=-/usr/bin/umount -l /var/home/zapados/servidor2
ExecStop=-/usr/bin/fusermount3 -u -z /var/home/zapados/servidor
ExecStop=-/usr/bin/fusermount3 -u -z /var/home/zapados/servidor2
TimeoutStopSec=10

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable sshfs-umount.service >/dev/null 2>&1
# Precisa estar ATIVA: unidade inativa não recebe job de stop no shutdown.
systemctl start sshfs-umount.service >/dev/null 2>&1
ok "unidade sshfs-umount.service criada, habilitada e iniciada"

# Rede de segurança: as unidades dos mounts SSHFS têm JobTimeoutUSec=infinity.
# Se o serviço acima não rodar, o próprio systemd faz unmount preguiçoso
# (ForceUnmount) e não espera eternamente (JobTimeoutSec).
for m in var-home-zapados-servidor.mount var-home-zapados-servidor2.mount; do
    mkdir -p "/etc/systemd/system/${m}.d"
    cat > "/etc/systemd/system/${m}.d/10-lazy-unmount.conf" <<'EOF'
[Unit]
JobTimeoutSec=30

[Mount]
ForceUnmount=yes
EOF
done
ok "drop-ins ForceUnmount=yes/JobTimeoutSec=30 nos mounts SSHFS"

# ---- 5) Wi-Fi: fixar BSSID ------------------------------------------------
info "5/9  Wi-Fi (crash do firmware ao trocar de AP)"
if [ "$FIX_WIFI_BSSID" = "1" ]; then
    if nmcli -t -f NAME connection show 2>/dev/null | grep -qx "$CONEXAO"; then
        nmcli connection modify "$CONEXAO" 802-11-wireless.bssid "$BSSID_ALVO" 2>&1 \
            && ok "BSSID de \"$CONEXAO\" fixado em $BSSID_ALVO (aplica na próxima conexão)"
    else
        warn "conexão \"$CONEXAO\" não encontrada no NetworkManager"
    fi
    echo "         Para desfazer: sudo nmcli connection modify $CONEXAO 802-11-wireless.bssid \"\""
else
    warn "FIX_WIFI_BSSID=0 - BSSID não alterado"
fi

# ---- 6) bootupd: mascarar serviço inútil ----------------------------------
info "6/9  bootloader-update.service (falha sempre neste aparelho)"
if [ "$MASK_BOOTLOADER_UPDATE" = "1" ]; then
    systemctl mask bootloader-update.service >/dev/null 2>&1
    ok "bootloader-update.service mascarado"
    echo "         Para desfazer: sudo systemctl unmask bootloader-update.service"
else
    warn "MASK_BOOTLOADER_UPDATE=0 - serviço mantido"
fi

# ---- 7) console USB: login em /dev/ttyGS0 ---------------------------------
info "7/9  console USB (login serial em /dev/ttyGS0)"
# O gadget ACM+NCM é criado pelo usb-network.service; sem ele não existe
# /dev/ttyGS0. Habilitar garante que o console volte em todo boot.
if [ "$(systemctl is-enabled usb-network.service 2>&1)" = "enabled" ]; then
    ok "usb-network.service já habilitado"
else
    systemctl enable usb-network.service >/dev/null 2>&1 \
        && ok "usb-network.service habilitado" \
        || warn "não foi possível habilitar usb-network.service"
fi
systemctl start usb-network.service >/dev/null 2>&1 || true

# Se ninguém estiver do outro lado do cabo, o getty pode ficar preso em uma
# leitura do ACM. Isto evita que ele atrase o desligamento.
mkdir -p /etc/systemd/system/serial-getty@ttyGS0.service.d
cat > /etc/systemd/system/serial-getty@ttyGS0.service.d/10-fast-stop.conf <<'EOF'
[Service]
TimeoutStopSec=5
KillSignal=SIGKILL
SendSIGKILL=yes
EOF

systemctl enable serial-getty@ttyGS0.service >/dev/null 2>&1 \
    && ok "serial-getty@ttyGS0.service habilitado" \
    || warn "não foi possível habilitar serial-getty@ttyGS0.service"
if [ -e /dev/ttyGS0 ]; then
    systemctl start serial-getty@ttyGS0.service >/dev/null 2>&1 \
        && ok "serial-getty@ttyGS0.service ativo (teste pelo cabo USB)" \
        || warn "serial-getty@ttyGS0.service não iniciou"
else
    warn "/dev/ttyGS0 não existe agora; o login USB deve subir no próximo boot"
fi

# ---- 8) GRUB: menu visível por 10 s ---------------------------------------
info "8/9  GRUB (menu visível por 10 s)"
# Sem /etc/default/grub o 00_header usa GRUB_TIMEOUT=5. Também interessa
# garantir que o menu apareça (timeout_style=menu) e que o default seja a
# entrada mais nova.
cat > /etc/default/grub <<'EOF'
# Gerado por corrigir-boot-e-wifi.sh
GRUB_TIMEOUT=10
GRUB_TIMEOUT_STYLE=menu
GRUB_RECORDFAIL_TIMEOUT=10
GRUB_DEFAULT=0
GRUB_DISABLE_SUBMENU=true
GRUB_ENABLE_BLSCFG=true
GRUB_DISABLE_OS_PROBER=true
EOF
ok "/etc/default/grub criado (timeout de 10 s, menu sempre visível)"

# Gera em arquivo temporário, valida e só então substitui o grub.cfg real.
GRUB_TMP="$(mktemp /tmp/grub.cfg.XXXXXX)" || GRUB_TMP=""
GRUB_ERR="$(mktemp /tmp/grub.err.XXXXXX)" || GRUB_ERR=""
# UUID da raiz em uso: serve para garantir que o grub.cfg gerado continua
# apontando para o mesmo sistema de arquivos (proteção contra regressão).
ROOT_UUID="$(sed -n 's/.*root=UUID=\([0-9a-fA-F-]*\).*/\1/p' /proc/cmdline | head -n1)"
[ -n "$GRUB_TMP" ] || GRUB_TMP="/dev/null"
[ -n "$GRUB_ERR" ] || GRUB_ERR="/dev/null"
BK="/boot/grub2/grub.cfg.bak-$(date +%Y%m%d-%H%M%S)"
# Sem backup válido não se toca no grub.cfg de jeito nenhum.
BACKUP_OK=0
if cp -a /boot/grub2/grub.cfg "$BK" 2>/dev/null; then
    BACKUP_OK=1
    ok "backup do grub.cfg: $BK"
else
    erro "não consegui salvar backup do grub.cfg; arquivo NÃO será alterado"
fi

GRUB_OK=0
if [ "$BACKUP_OK" -eq 1 ] && \
   grub2-mkconfig -o "$GRUB_TMP" >/dev/null 2>"$GRUB_ERR" && \
   grub2-script-check "$GRUB_TMP" >/dev/null 2>&1 && \
   grep -qE '^[[:space:]]*set timeout=10$' "$GRUB_TMP" && \
   grep -q 'blscfg' "$GRUB_TMP" && \
   grep -q 'insmod btrfs' "$GRUB_TMP" && \
   { [ -z "$ROOT_UUID" ] || grep -qiF "$ROOT_UUID" "$GRUB_TMP"; }; then
    # "cat >" preserva o inode/permissões do arquivo original (root:root 0600)
    cat "$GRUB_TMP" > /boot/grub2/grub.cfg \
        && { GRUB_OK=1; ok "grub.cfg regenerado e validado (set timeout=10 + blscfg)"; } \
        || erro "falha ao gravar /boot/grub2/grub.cfg; use o backup $BK"
fi
if [ "$BACKUP_OK" -eq 1 ] && [ "$GRUB_OK" -ne 1 ]; then
    warn "geração/validação do grub.cfg falhou; aplicando só o timeout no arquivo atual"
    [ -s "$GRUB_ERR" ] && sed -n '1,5p' "$GRUB_ERR" | sed 's/^/         /'
    sed -i -E 's/^[[:space:]]*set timeout=.*/set timeout=10/' /boot/grub2/grub.cfg
    sed -i -E 's/^[[:space:]]*set timeout_style=.*/set timeout_style=menu/' /boot/grub2/grub.cfg
    if grub2-script-check /boot/grub2/grub.cfg >/dev/null 2>&1 && \
       grep -qE '^[[:space:]]*set timeout=10$' /boot/grub2/grub.cfg; then
        GRUB_OK=1
        ok "timeout ajustado no grub.cfg existente (sintaxe validada)"
    else
        erro "grub.cfg ficou inválido; restaurando o backup automaticamente"
        if cat "$BK" > /boot/grub2/grub.cfg; then
            erro "backup restaurado: $BK (NÃO reinicie ainda; investigue)"
        else
            erro "FALHA AO RESTAURAR $BK - não reinicie e repare pelo UMS"
        fi
    fi
fi
if [ "$BACKUP_OK" -eq 1 ] && [ "$GRUB_OK" -ne 1 ]; then
    erro "GRUB não foi atualizado com segurança; veja o erro acima"
fi
# Confirmação final: exatamente o que o menu vai usar no próximo boot.
if [ "$GRUB_OK" -eq 1 ]; then
    TMO="$(grep -E '^[[:space:]]*set timeout=' /boot/grub2/grub.cfg | tail -n1 | sed 's/.*set timeout=//')"
    TMS="$(grep -E '^[[:space:]]*set timeout_style=' /boot/grub2/grub.cfg | tail -n1 | sed 's/.*set timeout_style=//')"
    ok "menu do GRUB: timeout=${TMO:-5}s  timeout_style=${TMS:-menu}"
fi
[ "$GRUB_TMP" = "/dev/null" ] || rm -f "$GRUB_TMP"
[ "$GRUB_ERR" = "/dev/null" ] || rm -f "$GRUB_ERR"

# ---- 9) entradas de emergência no menu do GRUB ----------------------------
info "9/9  entradas de emergência (rescue e shell sem gráfico)"
# Descobre qual arquivo BLS corresponde ao deployment em execução, comparando
# o ostree= do /proc/cmdline com o options= das entradas.
CMD_OSTREE="$(tr ' ' '\n' < /proc/cmdline | sed -n 's/^ostree=//p' | head -n1)"
SRC=""
for f in "$BLS_DIR"/ostree-*.conf; do
    [ -e "$f" ] || continue
    linha_opts=" $(sed -n 's/^options //p' "$f" | head -n1) "
    case "$linha_opts" in
        *" ostree=${CMD_OSTREE} "*) SRC="$f"; break ;;
    esac
done

if [ -z "$CMD_OSTREE" ]; then
    erro "não encontrei ostree= em /proc/cmdline; emergência NÃO criada"
elif [ -z "$SRC" ]; then
    erro "nenhuma entrada BLS casa com ostree=$CMD_OSTREE; emergência NÃO criada"
else
    ok "entrada do deployment atual: $SRC"
    OPTS="$(sed -n 's/^options //p' "$SRC" | head -n1)"
    LINUX_BLS="$(sed -n 's/^linux //p' "$SRC" | head -n1)"
    INITRD_BLS="$(sed -n 's/^initrd //p' "$SRC" | head -n1)"
    FDTDIR_BLS="$(sed -n 's/^fdtdir //p' "$SRC" | head -n1)"

    if [ -z "$LINUX_BLS" ] || [ -z "$INITRD_BLS" ]; then
        erro "entrada de origem sem linux/initrd; emergência NÃO criada"
    else
        # rescue: só o essencial + SSH/USB. NÃO adicionamos "console=ttyGS0"
        # de propósito: o kernel pode bloquear writes no ACM quando nenhum
        # host USB está conectado, o que travaria o boot escolhido no menu.
        # O acesso ao texto vem do getty em /dev/ttyGS0 (login normal).
        {
            echo "title Fedora Linux 44 (plasma-mobile) - EMERGENCIA: rescue (texto/USB)"
            echo "version 900"
            echo "options ${OPTS} systemd.unit=rescue.target systemd.wants=usb-network.service systemd.wants=sshd.service systemd.wants=serial-getty@ttyGS0.service"
            echo "linux ${LINUX_BLS}"
            echo "initrd ${INITRD_BLS}"
            [ -n "$FDTDIR_BLS" ] && echo "fdtdir ${FDTDIR_BLS}"
        } > "$BLS_DIR/emergency-b-rescue.conf"
        chmod 644 "$BLS_DIR/emergency-b-rescue.conf"

        # shell sem gráfico: multi-user (getty.target + sshd + USB)
        {
            echo "title Fedora Linux 44 (plasma-mobile) - EMERGENCIA: shell sem grafico (USB/SSH)"
            echo "version 901"
            echo "options ${OPTS} systemd.unit=multi-user.target systemd.wants=usb-network.service systemd.wants=sshd.service"
            echo "linux ${LINUX_BLS}"
            echo "initrd ${INITRD_BLS}"
            [ -n "$FDTDIR_BLS" ] && echo "fdtdir ${FDTDIR_BLS}"
        } > "$BLS_DIR/emergency-a-shell.conf"
        chmod 644 "$BLS_DIR/emergency-a-shell.conf"

        ok "criadas: $BLS_DIR/emergency-b-rescue.conf (indice 2 no menu)"
        ok "criadas: $BLS_DIR/emergency-a-shell.conf  (indice 3 no menu)"
    fi
fi

# ---- recarregar e limpar falhas antigas -----------------------------------
info "Aplicando (daemon-reload)"
systemctl daemon-reload
systemctl reset-failed droid-juicer.service bootloader-update.service \
    serial-getty@ttyGS0.service 2>/dev/null || true
sync
ok "systemd recarregado (arquivos de /boot sincronizados)"

# ---- verificação ----------------------------------------------------------
info "Verificação do estado"
printf '  rmtfs.service        : TimeoutStopSec=%s  KillSignal=%s\n' \
    "$(systemctl show rmtfs.service -p TimeoutStopUSec --value)" \
    "$(systemctl show rmtfs.service -p KillSignal --value)"
printf '  ath10k-shutdown      : TimeoutStopSec=%s\n' \
    "$(systemctl show ath10k-shutdown.service -p TimeoutStopUSec --value)"
printf '  droid-juicer         : status.json %s\n' \
    "$([ -f /var/lib/droid-juicer/status.json ] && echo presente || echo AUSENTE)"
printf '  sshfs-umount         : %s / %s\n' \
    "$(systemctl is-enabled sshfs-umount.service 2>&1)" \
    "$(systemctl is-active sshfs-umount.service 2>&1)"
printf '  bootloader-update    : %s\n' "$(systemctl is-enabled bootloader-update.service 2>&1)"
if [ "$FIX_WIFI_BSSID" = "1" ]; then
    printf '  Wi-Fi BSSID          : %s\n' \
        "$(nmcli -g 802-11-wireless.bssid connection show "$CONEXAO" 2>/dev/null || echo '-')"
fi

echo
printf '  usb-network          : %s\n' "$(systemctl is-active usb-network.service 2>&1)"
printf '  serial-getty@ttyGS0  : %s / %s\n' \
    "$(systemctl is-enabled serial-getty@ttyGS0.service 2>&1)" \
    "$(systemctl is-active serial-getty@ttyGS0.service 2>&1)"
printf '  /dev/ttyGS0          : %s\n' "$([ -e /dev/ttyGS0 ] && echo presente || echo AUSENTE)"
printf '  SSH USB (usb0)       : %s\n' \
    "$(ip -4 -o addr show usb0 2>/dev/null | awk '{print $4}' || echo '-')"
printf '  Tailscale            : %s\n' "$(tailscale ip -4 2>/dev/null | head -n1 || echo '-')"

echo
printf '  GRUB timeout         : %s\n' \
    "$(grep -E '^[[:space:]]*set timeout=' /boot/grub2/grub.cfg 2>/dev/null | head -n1 | sed 's/^ *//')"
printf '  GRUB timeout_style   : %s\n' \
    "$(grep -E '^[[:space:]]*set timeout_style=' /boot/grub2/grub.cfg 2>/dev/null | head -n1 | sed 's/^ *//')"
printf '  GRUB blscfg          : %s referência(s)\n' \
    "$(grep -c 'blscfg' /boot/grub2/grub.cfg 2>/dev/null)"
printf '  GRUB env             :\n'
grub2-editenv /boot/grub2/grubenv list 2>/dev/null | sed 's/^/         /'
printf '  Stub EFI (/boot/efi/EFI/fedora/grub.cfg):\n'
sed -n '1,10p' /boot/efi/EFI/fedora/grub.cfg 2>/dev/null | sed 's/^/         /'
printf '  Entradas BLS (ordem do menu é a inversa da listagem):\n'
ls -1 "$BLS_DIR"/*.conf 2>/dev/null | sed 's/^/         /'
printf '  Deployment atual (ostree=): %s\n' "${CMD_OSTREE:--}"
printf '  Origem das entradas      : %s\n' "${SRC:--}"

echo
echo "============================================================"
echo " FIXADO. NÃO reinicie ainda: teste o console USB primeiro."
echo
echo " 1. Conecte o cabo USB-C no computador e abra um terminal:"
echo "        ls /dev/ttyACM*"
echo "        sudo screen /dev/ttyACM0 115200     # ou: picocom -b 115200 /dev/ttyACM0"
echo "    Deve aparecer um prompt 'login:'. Entre com o usuário/senha do"
echo "    aparelho. Se aparecer, o resgate por USB está funcionando."
echo
echo " 2. Teste também o SSH pelo USB (outro terminal):"
echo "        ssh zapados@172.16.42.1"
echo
echo " 3. Saia do screen com Ctrl+A, K (ou Ctrl+A, D para desconectar)."
echo
echo " 4. Só então reinicie:"
echo "        systemctl reboot"
echo
echo " Durante o boot:"
echo "   - segure Volume Down ao ligar  -> menu do u-boot (emergência)"
echo "   - sem tocar em nada            -> menu do GRUB por 10 s"
echo "   - Volume Up/Down movem, Power seleciona"
echo
echo " Depois do boot, verifique o desligamento anterior:"
echo "     journalctl -b -1 --no-pager | tail -25"
echo "   (não deve mais aparecer 'stop-sigterm timed out' nem parar"
echo "    em 'Unmounting var-home.mount')"
echo
echo " Depois de cada 'rpm-ostree upgrade', rode este script de novo para"
echo " atualizar as entradas de emergência (elas apontam para o kernel"
echo " do deployment atual)."
echo "============================================================"
