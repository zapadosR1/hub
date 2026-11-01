# Autenticação GitHub no Plasma Mobile (sem PAT)

## Situação

O navegador do Plasma Mobile pode estar logado no GitHub, mas o `git` (linha
de comando) não usa a sessão do navegador. Por isso o `sync_hub.sh` não
consegue enviar commits sem um token ou chave SSH autorizada.

## Solução recomendada: chave SSH

1. Copie a chave pública exibida pelo script:
   ```bash
   cat ~/.ssh/id_rsa_celular.pub
   ```
2. No navegador, acesse https://github.com/settings/keys e clique em
   **New SSH key**, cole a chave e salve.
3. Rode a sincronização:
   ```bash
   ~/hub/scripts/sync_hub.sh
   ```
   O script detecta automaticamente que a chave está autorizada e usa SSH.

## Alternativa: Personal Access Token (PAT)

1. Crie um PAT em https://github.com/settings/tokens (escopo `repo`).
2. Defina:
   ```bash
   echo 'GITHUB_TOKEN=ghp_SEU_TOKEN' >> ~/.config/hub/env
   ```
3. Rode `~/hub/scripts/sync_hub.sh`.

## Nota

A sessão do navegador não é reutilizável pelo git; é necessário cadastrar a
chave SSH ou usar um PAT. Ambos podem ser feitos pelo próprio navegador.