# Hub de procedimentos — OnePlus 6T / Fedora 44 Kinoite (Plasma Mobile)

Este repositório reúne procedimentos, scripts e documentação usados para
configurar e corrigir um **OnePlus 6T (fajita, sdm845)** rodando
**Fedora 44 Kinoite / Plasma Mobile**.

## Estrutura

- `procedures/` — diagnósticos e anotações coletadas.
- `scripts/` — scripts de montagem (SSHFS) e sincronização com o GitHub.
- `fixes/` — documentação das correções aplicadas (boot, Wi-Fi, SSHFS, hub).
- `config/` — configurações relevantes (autostart, systemd user).

## Sincronização automática com o GitHub

1. Defina o token (PAT com permissão `repo`):
   ```bash
   export GITHUB_TOKEN=ghp_...
   ```
   Para persistir, adicione a linha acima em `~/.bashrc` ou `~/.profile`,
   ou em `~/.config/hub/env`.

2. Rode o script de sincronização:
   ```bash
   ~/hub/scripts/sync_hub.sh
   ```

3. Para sincronização automática, habilite o timer do systemd (user):
   ```bash
   systemctl --user enable --now hub-sync.timer
   ```

## Montagem automática dos servidores (SSHFS)

O script `~/montar_servidor.sh` monta `~/servidor` (public_html) e
`~/servidor2` (tizomer.com). Ele é executado no login via autostart e agora
aguarda a rede e tenta novamente em caso de falha.

## Comunidade

Contribuições e relatos de problemas são bem-vindos. Abra uma issue ou PR no
repositório GitHub.