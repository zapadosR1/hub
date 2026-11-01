# Correções de boot e Wi-Fi (referência)

As correções de boot, Wi-Fi (ath10k/WCN3990), desligamento e SSHFS estão
documentadas no repositório `oneplus6t-fedora-wifi` e no arquivo
`PLANO-EMERGENCIA.md` (copiado em `procedures/`).

## Resumo

- BSSID fixo na conexão NetworkManager para evitar crash do firmware.
- rmtfs/ath10k-shutdown com timeout e SIGKILL.
- droid-juicer marcador para não extrair firmware a cada boot.
- auto_unmount + unidade `sshfs-umount.service` para desmontar SSHFS no shutdown.
- GRUB com menu visível por 10 s e entradas de emergência.
- Console USB e SSH pelo cabo USB.

## Script

- `~/corrigir-boot-e-wifi.sh` (também copiado em `scripts/`).