# Correção: Bluetooth + Display (commit DPU) — proteções persistentes

## Contexto
OnePlus 6T (fajita, sdm845), Pocket Blue (Fedora 44 Plasma Mobile).
Kernel `6.16.7-0.sdm845.fc44.aarch64`.

Sintomas:
- Bluetooth não ligava: `bluetoothctl power on` → `Failed to set power on: org.bluez.Error.Failed`;
  kernel mostrava `Opcode 0x0c03 failed: -110` (HCI Reset timeout) após o firmware ser carregado.
- Sistema lento: kworker em estado D em `dpu_encoder_helper_wait_event_`, rajadas de
  `[dpu error] enc33 intf1 ctl start interrupt wait failed` e `dpu_kms_wait_for_commit_done ... -22`.

## Causa raiz
- **BT**: o chip WCN3990 às vezes não responde ao reset HCI após o download do firmware.
  O firmware estava correto (md5 `4fce...`/`e31b...`); o problema é de estado do chip
  (warm reboot deixa o chip em estado ruim; cold boot resolve).
- **Display**: o caminho de overlay/direct scanout do KWin disparava commits que o DPU
  do sdm845 não concluía (`ctl start interrupt wait failed`).

## Correções aplicadas

### Bluetooth
1. Firmware bom guardado em `/etc/bt-firmware` e copiado para `/var/lib/firmware-extract/qca`
   e antecipadamente para `/usr/lib/firmware/qca` (overlay gravável), eliminando corrida
   com a montagem de `/var`.
2. `droid-juicer` mascarado (não sobrescreve mais o firmware).
3. `bt-guard`: serviço que garante o firmware, liga o BT no boot, após suspensão e a
   cada 10 minutos. Log em `/var/log/bt-guard.log`.
4. `bt-firmware-early.service`: copia o firmware para `/usr` antes do probe do serdev.

### Display
1. Variáveis do KWin em `~/.config/plasma-workspace/env/msm-display.sh`:
   - `KWIN_USE_OVERLAYS=0`
   - `KWIN_DRM_NO_DIRECT_SCANOUT=1`
   - `KWIN_FORCE_SW_CURSOR=1`
2. `dpu-watchdog`: detecta kworker travado em `dpu_*` por 2 amostras seguidas,
   registra em `/var/log/dpu-watchdog.log` e (opcional) reinicia a sessão.

### Instalador
- `instalar-protecoes.sh`: aplica tudo acima e salva o diagnóstico do BT deste boot.
- `verificar-protecoes.sh`: checa estado (BT, firmware, serviços, erros DPU, kworker).

## Arquivos
- `scripts/instalar-protecoes.sh`
- `scripts/verificar-protecoes.sh`

## Resultado
- BT subiu e permaneceu `Powered: yes`.
- 0 erros DPU nos 10 minutos após a correção.
- Nenhum processo em estado D (travado).

## Observações
- O chip WCN3990 pode precisar de corte de energia real (desligamento completo) após
  um warm reboot que o deixe em estado ruim.
- O `console=ttyMSM0,115200` é o workaround do postmarketOS para a corrida de init do
  painel (drm/msm issue 46); opcional via `rpm-ostree kargs`.
EOF
echo "criado"