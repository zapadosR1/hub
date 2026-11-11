#!/bin/bash
# =============================================================================
# Montagem ÚNICA e ESTÁVEL do HostGator via SSHFS (v3) — [hub]
# Substitui a versão antiga (2 sshfs em background, que caíam a cada 2 min).
#
# - Uma só conexão SSH para /home1/thi60523 montada em ~/servidor-gator
# - Mapeamento mantido (compatibilidade):
#     ~/servidor  (e ~/servidor1) -> ~/servidor-gator/public_html  = cortesafe.com.br
#     ~/servidor2                 -> ~/servidor-gator/tizomer.com  = tizomer.com
# =============================================================================
set -u

SSH_USER="thi60523"
SSH_HOST="cortesafe.com.br"
SSH_PORT="2222"
SSH_KEY="$HOME/.ssh/id_rsa_celular"
REMOTE_DIR="/home1/thi60523"

MOUNT_DIR="$HOME/servidor-gator"
LOG="/var/home/zapados/servidor-mount.log"

SSHFS_BIN="$(command -v sshfs || echo /usr/bin/sshfs)"
FUSERMOUNT_BIN="$(command -v fusermount3 || command -v fusermount || echo /usr/bin/fusermount3)"

SSHFS_OPTS="-p $SSH_PORT -o IdentityFile=$SSH_KEY -o sftp_server=/usr/libexec/openssh/sftp-server \
-o reconnect,ServerAliveInterval=15,ServerAliveCountMax=4,ConnectTimeout=20 \
-o dir_cache=yes,entry_timeout=120,negative_timeout=60,compression=no \
-o idmap=user,allow_other,auto_unmount"

log() { echo "$(date '+%F %T') [MONTAR] $*" | tee -a "$LOG"; }

# Aguarda DNS (máx 30s) — não bloqueia o boot
for i in $(seq 1 6); do
    getent hosts "$SSH_HOST" >/dev/null 2>&1 && break
    sleep 5
done

criar_symlinks() {
    ln -sfn "$MOUNT_DIR/public_html" "$HOME/servidor"
    ln -sfn "$MOUNT_DIR/public_html" "$HOME/servidor1"
    ln -sfn "$MOUNT_DIR/tizomer.com" "$HOME/servidor2"
    log "Symlinks garantidos: ~/servidor(1)=cortesafe.com.br | ~/servidor2=tizomer.com"
}

saudavel() {
    mountpoint -q "$MOUNT_DIR" && timeout 10 ls "$MOUNT_DIR/public_html" >/dev/null 2>&1
}

if saudavel; then
    criar_symlinks
    exit 0
fi

"$FUSERMOUNT_BIN" -u -z "$MOUNT_DIR" 2>/dev/null || true
mkdir -p "$MOUNT_DIR"

tentativa=0
while [ $tentativa -lt 5 ]; do
    tentativa=$((tentativa+1))
    log "Montando $MOUNT_DIR (tentativa $tentativa/5)..."
    "$SSHFS_BIN" $SSHFS_OPTS "$SSH_USER@$SSH_HOST:$REMOTE_DIR" "$MOUNT_DIR" 2>/tmp/sshfs_err
    if saudavel; then
        log "[SUCESSO] $MOUNT_DIR montada (1 conexão única: cortesafe + tizomer)."
        criar_symlinks
        exit 0
    fi
    log "[ERRO] Falha: $(tail -1 /tmp/sshfs_err 2>/dev/null)"
    sleep 8
done

log "[ERRO] Não foi possível montar após 5 tentativas."
exit 1
