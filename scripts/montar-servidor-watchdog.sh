#!/bin/bash
# Verifica e remonta os servidores SSHFS se cairem.
# Instalado por: /var/home/zapados/montar-servidor-watchdog.sh

set -u

USER_HOME="/var/home/zapados"
LOG="$USER_HOME/servidor-mount.log"
SSH_USER="thi60523"
SSH_HOST="cortesafe.com.br"
SSH_PORT="2222"
SSH_KEY="$USER_HOME/.ssh/id_rsa_celular"
SSHFS_OPTS="-p $SSH_PORT -o IdentityFile=$SSH_KEY -o sftp_server=/usr/libexec/openssh/sftp-server -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,allow_other,auto_unmount"

declare -A REMOTES=(
    ["$USER_HOME/servidor"]="/home1/thi60523/public_html"
    ["$USER_HOME/servidor2"]="/home1/thi60523/tizomer.com"
)

for localdir in "${!REMOTES[@]}"; do
    remote="${REMOTES[$localdir]}"
    # considera "morto" se não for mountpoint OU se ls falhar (stale)
    if mountpoint -q "$localdir" 2>/dev/null && ls "$localdir" >/dev/null 2>&1; then
        continue
    fi
    echo "$(date '+%F %T') [WATCHDOG] $localdir não responde; remontando..." | tee -a "$LOG"
    # desmonta (lazy) se ainda estiver montado
    fusermount -u -z "$localdir" 2>/dev/null || umount -l "$localdir" 2>/dev/null || true
    sleep 2
    mkdir -p "$localdir"
    sshfs $SSHFS_OPTS "$SSH_USER@$SSH_HOST:$remote" "$localdir" 2>/tmp/sshfs_err
    if mountpoint -q "$localdir" && ls "$localdir" >/dev/null 2>&1; then
        echo "$(date '+%F %T') [WATCHDOG] $localdir remontada com sucesso." | tee -a "$LOG"
    else
        echo "$(date '+%F %T') [WATCHDOG] Falha ao remontar $localdir: $(cat /tmp/sshfs_err 2>/dev/null)" | tee -a "$LOG"
    fi
done
