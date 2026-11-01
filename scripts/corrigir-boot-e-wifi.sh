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
