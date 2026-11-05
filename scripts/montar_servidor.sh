#!/bin/bash
SSH_USER="thi60523"
SSH_HOST="cortesafe.com.br"
SSH_PORT="2222"
SSH_KEY="$HOME/.ssh/id_rsa_celular"
REMOTE_DIR_1="/home1/thi60523/public_html"
REMOTE_DIR_2="/home1/thi60523/tizomer.com"
LOCAL_DIR_1="$HOME/servidor"
LOCAL_DIR_2="$HOME/servidor2"
SSHFS_OPTS="-p $SSH_PORT -o IdentityFile=$SSH_KEY -o sftp_server=/usr/libexec/openssh/sftp-server -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,allow_other,auto_unmount"
LOG="$HOME/servidor-mount.log"

mkdir -p "$LOCAL_DIR_1" "$LOCAL_DIR_2"

# Aguarda rede (máx 15s)
for i in $(seq 1 3); do
    getent hosts "$SSH_HOST" >/dev/null 2>&1 && break
    sleep 5
done

montar() {
    local remote="$1" localdir="$2"
    mountpoint -q "$localdir" 2>/dev/null && return 0
    sshfs $SSHFS_OPTS "$SSH_USER@$SSH_HOST:$remote" "$localdir" 2>/tmp/sshfs_err &
}

montar "$REMOTE_DIR_1" "$LOCAL_DIR_1"
montar "$REMOTE_DIR_2" "$LOCAL_DIR_2"
echo "$(date '+%F %T') Montagem iniciada em background." >> "$LOG"
