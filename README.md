# Hub de procedimentos — OnePlus 6T / Fedora 44 Kinoite (Plasma Mobile)

Este repositório reúne procedimentos e documentação para configurar e corrigir
um **OnePlus 6T (fajita, sdm845)** rodando **Fedora 44 Kinoite / Plasma Mobile**.

## Estrutura
- `docs/` — procedimentos (idioma, horas, Waydroid, guia visual).
- `fixes/` — documentação das correções aplicadas (boot, Wi-Fi, SSHFS, locale, etc.).
- `oneplus 6t(fedora kde mobile)/` — procedimentos por subsistema (Wi-Fi, modem, Bluetooth).
- `procedures/` — planos de emergência.
- `scripts/` — scripts de montagem (SSHFS) e sincronização com o GitHub.

## Sincronização automática com o GitHub
1. Defina o token (PAT com permissão `repo`):
   ```bash
   export GITHUB_TOKEN=ghp_...
   ```
2. Rode:
   ```bash
   ~/hub/scripts/sync_hub.sh
   ```

## Montagem automática dos servidores (SSHFS)
O script `~/hub/scripts/montar_servidor.sh` monta `~/servidor` e `~/servidor2`.

## Comunidade
Contribuições e relatos de problemas são bem-vindos.