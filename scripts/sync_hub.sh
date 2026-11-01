#!/bin/bash
# Sincroniza ~/hub com o GitHub usando GITHUB_TOKEN (PAT com escopo repo).

set -u

HUB_DIR="$HOME/hub"
REPO_OWNER="zapadosR1"
REPO_NAME="hub"
REMOTE_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}.git"

cd "$HUB_DIR" || { echo "Pasta $HUB_DIR não encontrada"; exit 1; }

if [ ! -d .git ]; then
    git init
    git branch -M main
fi

git config user.name >/dev/null 2>&1 || git config user.name "zapadosR1"
git config user.email >/dev/null 2>&1 || git config user.email "63672297+zapadosR1@users.noreply.github.com"

SSH_KEY="$HOME/.ssh/id_rsa_celular"

if [ -n "${GITHUB_TOKEN:-}" ]; then
    AUTH_URL="https://${GITHUB_TOKEN}@github.com/${REPO_OWNER}/${REPO_NAME}.git"
    if git remote get-url origin >/dev/null 2>&1; then
        git remote set-url origin "$AUTH_URL"
    else
        git remote add origin "$AUTH_URL"
    fi

    HTTP_CODE=$(curl -s -o /tmp/gh_create.json -w "%{http_code}" \
        -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github+json" \
        https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME})
    if [ "$HTTP_CODE" = "404" ]; then
        echo "Criando repositório ${REPO_OWNER}/${REPO_NAME} no GitHub..."
        curl -s -X POST \
            -H "Authorization: Bearer ${GITHUB_TOKEN}" \
            -H "Accept: application/vnd.github+json" \
            https://api.github.com/user/repos \
            -d "{\"name\":\"${REPO_NAME}\",\"private\":false,\"description\":\"Hub de procedimentos - OnePlus 6T / Fedora 44 Kinoite\"}" \
            >/tmp/gh_create_result.json
    fi
elif ssh -T -i "$SSH_KEY" -o BatchMode=yes git@github.com 2>&1 | grep -qi "successfully authenticated"; then
    SSH_URL="git@github.com:${REPO_OWNER}/${REPO_NAME}.git"
    echo "Usando autenticação SSH com a chave $SSH_KEY."
    if git remote get-url origin >/dev/null 2>&1; then
        git remote set-url origin "$SSH_URL"
    else
        git remote add origin "$SSH_URL"
    fi
else
    echo "AVISO: nem GITHUB_TOKEN nem chave SSH autorizada no GitHub."
    echo "Opções:"
    echo "  1) Criar um PAT em https://github.com/settings/tokens e definir GITHUB_TOKEN."
    echo "  2) Adicionar sua chave pública ao GitHub:"
    echo "     $(cat ${SSH_KEY}.pub)"
    echo "     https://github.com/settings/keys"
    if ! git remote get-url origin >/dev/null 2>&1; then
        git remote add origin "https://github.com/${REPO_OWNER}/${REPO_NAME}.git"
    fi
fi

git add -A
if ! git diff --cached --quiet; then
    git commit -m "sync: $(date '+%Y-%m-%d %H:%M:%S')"
fi

if git remote get-url origin >/dev/null 2>&1; then
    git pull --rebase origin main 2>/dev/null || git pull --rebase origin master 2>/dev/null || true
    git push -u origin main 2>/dev/null || git push -u origin master 2>/dev/null || echo "Push falhou (verifique token/permissões)."
else
    echo "Sem remote configurado."
fi

echo "--- Sincronização concluída ---"
