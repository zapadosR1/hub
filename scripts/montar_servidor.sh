#!/bin/bash
# Montagem dos servidores HostGator via SSHFS (robusta)
# Aguarda a rede e tenta novamente em caso de falha.

sleep 5

SSH_USER="thi60523"
SSH_HOST="cortesafe.com.br"
SSH_PORT="2222"
SSH_KEY="$HOME/.ssh/id_rsa_celular"

REMOTE_DIR_1="/home1/thi60523/public_html"
REMOTE_DIR_2="/home1/thi60523/tizomer.com"

LOCAL_DIR_1="$HOME/servidor"
LOCAL_DIR_2="$HOME/servidor2"

SSHFS_OPTS="-p $SSH_PORT -o IdentityFile=$SSH_KEY -o sftp_server=/usr/libexec/openssh/sftp-server -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,allow_other,auto_unmount"

mkdir -p "$LOCAL_DIR_1" "$LOCAL_DIR_2"

# Aguarda conectividade (até 60s) - usa DNS (ping não existe neste sistema)
for i in $(seq 1 12); do
    if getent hosts "$SSH_HOST" >/dev/null 2>&1; then
        break
    fi
    sleep 5
done

LOG="$HOME/servidor-mount.log"

montar() {
    local remote="$1" localdir="$2" tentativa=0
    if mountpoint -q "$localdir"; then
        echo "[OK] $localdir já montado." | tee -a "$LOG"
        return 0
    fi
    while [ $tentativa -lt 5 ]; do
        tentativa=$((tentativa+1))
        echo "$(date '+%F %T') Montando $localdir (tentativa $tentativa/5)..." | tee -a "$LOG"
        sshfs $SSHFS_OPTS "$SSH_USER@$SSH_HOST:$remote" "$localdir" 2>/tmp/sshfs_err
        if mountpoint -q "$localdir"; then
            echo "$(date '+%F %T') [SUCESSO] $localdir montada!" | tee -a "$LOG"
            return 0
        fi
        echo "$(date '+%F %T') [ERRO] Falha ao montar $localdir: $(cat /tmp/sshfs_err)" | tee -a "$LOG"
        sleep 5
    done
    echo "$(date '+%F %T') [ERRO] Não foi possível montar $localdir após 5 tentativas." | tee -a "$LOG"
    return 1
}

montar "$REMOTE_DIR_1" "$LOCAL_DIR_1"
montar "$REMOTE_DIR_2" "$LOCAL_DIR_2"

echo "--- Finalizado ---"