#!/bin/bash
sleep 10


# ==========================================
# Script de Montagem de Servidores HostGator
# ==========================================

# 1. Configurações de Acesso
SSH_USER="thi60523"
SSH_HOST="cortesafe.com.br"
SSH_PORT="2222"
SSH_KEY="$HOME/.ssh/id_rsa_celular"

# 2. Caminhos Remotos (No servidor HostGator)
REMOTE_DIR_1="/home1/thi60523/public_html"
REMOTE_DIR_2="/home1/thi60523/tizomer.com"

# 3. Pastas Locais (No celular)
LOCAL_DIR_1="$HOME/servidor"
LOCAL_DIR_2="$HOME/servidor2"

# 4. Opções do SSHFS (O segredo para não pedir Shell)
# Usamos o sftp_server para burlar o bloqueio e o reconnect para não cair
SSHFS_OPTS="-p $SSH_PORT -o IdentityFile=$SSH_KEY -o sftp_server=/usr/libexec/openssh/sftp-server -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,allow_other,auto_unmount"

# ==========================================
# Início da Execução
# ==========================================

# Cria as pastas locais caso não existam
mkdir -p "$LOCAL_DIR_1"
mkdir -p "$LOCAL_DIR_2"

echo "--- Iniciando montagem ---"

# Montando a pasta 1 (public_html)
if mount | grep -q "$LOCAL_DIR_1"; then
    echo "[OK] A pasta $LOCAL_DIR_1 já está montada."
else
    echo "Montando $LOCAL_DIR_1..."
    sshfs $SSHFS_OPTS "$SSH_USER@$SSH_HOST:$REMOTE_DIR_1" "$LOCAL_DIR_1"
    if [ $? -eq 0 ]; then
        echo "[SUCESSO] $LOCAL_DIR_1 montada!"
    else
        echo "[ERRO] Falha ao montar $LOCAL_DIR_1."
    fi
fi

# Montando a pasta 2 (tizomer.com)
if mount | grep -q "$LOCAL_DIR_2"; then
    echo "[OK] A pasta $LOCAL_DIR_2 já está montada."
else
    echo "Montando $LOCAL_DIR_2..."
    sshfs $SSHFS_OPTS "$SSH_USER@$SSH_HOST:$REMOTE_DIR_2" "$LOCAL_DIR_2"
    if [ $? -eq 0 ]; then
        echo "[SUCESSO] $LOCAL_DIR_2 montada!"
    else
        echo "[ERRO] Falha ao montar $LOCAL_DIR_2."
    fi
fi

echo "--- Finalizado ---"
