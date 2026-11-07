#!/bin/bash
# Wrapper: aguarda internet (modem 5G) antes de montar SSHFS
# Uso chamado pelo systemd montar-servidor.service

SSH_HOST="cortesafe.com.br"
SSH_PORT="2222"
# Não bloqueia o boot esperando a rede. Se não houver internet em 10s,
# o serviço sai e o watchdog/timer tenta novamente depois.
MAX_WAIT=10
WAITED=0

echo "Aguardando conectividade com $SSH_HOST:$SSH_PORT (max ${MAX_WAIT}s)..."

while [ $WAITED -lt $MAX_WAIT ]; do
    # Testa DNS + TCP
    if getent hosts "$SSH_HOST" >/dev/null 2>&1; then
        if timeout 5 bash -c "echo > /dev/tcp/$SSH_HOST/$SSH_PORT" 2>/dev/null; then
            echo "Conectividade OK apos ${WAITED}s"
            exec /bin/bash /var/home/zapados/hub/scripts/montar_servidor.sh
        fi
    fi
    sleep 5
    WAITED=$((WAITED + 5))
done

echo "ERRO: sem conectividade apos ${MAX_WAIT}s"
exit 1
