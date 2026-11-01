# Configuração do hub com compartilhamento GitHub

## Objetivo

Criar a pasta `~/hub` como repositório Git sincronizado automaticamente com
um repositório GitHub, para compartilhar procedimentos e ajudar a comunidade.

## Estrutura criada

- `~/hub/procedures/` — documentação coletada.
- `~/hub/scripts/` — scripts de montagem e sincronização.
- `~/hub/fixes/` — documentação das correções.
- `~/hub/config/` — configurações relevantes.

## Sincronização automática

- Script: `~/hub/scripts/sync_hub.sh`
- Usa a variável de ambiente `GITHUB_TOKEN` (PAT com permissão `repo`).
- Timer systemd (user): `hub-sync.timer` (a cada 5 minutos).

## Configuração do token

Adicione ao `~/.bashrc` ou `~/.profile`:

```bash
export GITHUB_TOKEN=ghp_SEU_TOKEN
```

## Primeiro push

```bash
export GITHUB_TOKEN=ghp_SEU_TOKEN
~/hub/scripts/sync_hub.sh
```

O script cria o repositório remoto `zapadosR1/hub` via API do GitHub (se não
existir) e envia o conteúdo.
EOF
path: /var/home/zapados/hub/fixes/02-hub-github.md