#!/bin/bash
# =============================================================================
# Watchdog da montagem do HostGator (v3) — [hub]
# Substitui a versão antiga (remontava ~/servidor e ~/servidor2 a cada 2 min).
# Agora verifica a conexão ÚNICA (~/servidor-gator).
# Instalado por: /var/home/zapados/montar-servidor-watchdog.sh
# =============================================================================
set -u

USER_HOME="/var/home/zapados"
LOG="$USER_HOME/servidor-mount.log"
LOCK="$USER_HOME/.cache/montar-servidor-watchdog.lock"
MOUNT_DIR="$USER_HOME/servidor-gator"

mkdir -p "$USER_HOME/.cache"
exec 9>"$LOCK"
if ! flock -n 9; then
  exit 0
fi

log() { echo "$(date '+%F %T') [WATCHDOG] $*" >> "$LOG"; }

saudavel() {
  mountpoint -q "$MOUNT_DIR" 2>/dev/null \
    && timeout 8 ls "$MOUNT_DIR/public_html" >/dev/null 2>&1 \
    && timeout 8 ls "$MOUNT_DIR/tizomer.com" >/dev/null 2>&1
}

if saudavel; then
  exit 0
fi

log "$MOUNT_DIR não responde; recuperando..."

# Se a unidade systemd existir, deixa o systemd recuperar (padrão estável)
if systemctl --user cat servidor-gator.service >/dev/null 2>&1; then
  systemctl --user restart servidor-gator.service >/dev/null 2>&1
  sleep 12
  if saudavel; then
    log "$MOUNT_DIR recuperada via systemd."
    exit 0
  fi
  log "systemd não recuperou; tentando script direto..."
fi

# Fallback: script direto (mesma conexão única)
"$USER_HOME/hub/scripts/montar_servidor.sh" >> "$LOG" 2>&1

if saudavel; then
  log "$MOUNT_DIR remontada com sucesso."
else
  log "Falha ao recuperar $MOUNT_DIR."
fi
