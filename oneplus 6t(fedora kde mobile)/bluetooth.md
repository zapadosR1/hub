# Procedimento: Correção do Bluetooth (qca / wcn3990 / firmware)

## Equipamento
OnePlus 6T (fajita, sdm845) — Fedora 44 Kinoite / Plasma Mobile

## Sintomas observados
- Bluetooth não funcionava ou falhava ao inicializar.
- Firmware do Bluetooth (qca) não era encontrado ou não carregava.
- Necessidade de extrair firmware do Android (crnv21.tlv, crbtfw21.tlv).
- Problemas com o chip de bateria (bq27541) que afetava o subsistema de
  energia do Bluetooth.

## Causa raiz
1. Firmware do Bluetooth (Qualcomm qca) não estava presente em
   `/usr/lib/firmware/`.
2. O `droid-juicer` não havia extraído os arquivos do firmware Android
   (crnv21.bin, crbtfw21.tlv).
3. O marcador `status.json` não existia, então o serviço tentava extrair a
   cada boot e falhava com "Text file busy".
4. Possível problema no DTB (device tree) afetando o subsistema Bluetooth.

## O que encontramos
- Chip Bluetooth: Qualcomm qca (wcn3990).
- Firmware necessário: `crnv21.bin`, `crbtfw21.tlv`, `crbtfw21.tlv.bak`.
- Localização esperada: `/usr/lib/firmware/qca/` e
  `/usr/lib/firmware/updates/qcom/sdm845/oneplus6/`.
- Serviço `droid-juicer` responsável pela extração do firmware Android.
- Chip de bateria: `bq27541` (monitorado via I2C).

## Arquivos de diagnóstico coletados
- `btmon.txt` — captura do btmon (monitoramento Bluetooth).
- `firmware-bt.txt` — verificação de firmware Bluetooth.
- `estado-bt.txt` — estado do Bluetooth no sistema.
- `chip-bateria.txt` / `chip-mapa.txt` — mapeamento do chip de bateria.
- `dtb-fonte.txt` / `patch-dtb.txt` — análise e patch do device tree.
- `bateria.txt`, `bateria2.txt`, `bateria-final.txt` — diagnóstico de bateria.
- `onde-bq27541.txt` — localização do chip bq27541.
- `limpeza-e-bt.txt` — limpeza e verificação de Bluetooth.
- `bt-arquivos.txt` — arquivos relacionados ao Bluetooth.
- `teste-bt.txt`, `teste-hciconfig.txt` — testes de Bluetooth.
- `audio-check.txt`, `audio-dmesg.txt` — áudio (compartilha subsistema).

## Comandos de diagnóstico
```bash
# Verificar interface Bluetooth
bluetoothctl show
hciconfig -a
hcitool dev

# Verificar firmware
ls -la /usr/lib/firmware/qca/
ls -la /usr/lib/firmware/updates/qcom/sdm845/oneplus6/

# Verificar módulos
lsmod | grep -E 'hci_uart|btqca|bluetooth'

# Monitoramento em tempo real
btmon

# Verificar dmesg para Bluetooth
dmesg | grep -iE 'bluetooth|hci0|qca|wcn399'

# Verificar chip de bateria (bq27541)
cat /sys/class/power_supply/bq27411-0/uevent 2>/dev/null
find / -name "*bq27541*" 2>/dev/null

# Verificar device tree
find /proc/device-tree -iname "*bluetooth*" 2>/dev/null
find /proc/device-tree -iname "*qca*" 2>/dev/null
```

## Correção 1: droid-juicer (marcador de firmware já extraído)
O firmware já foi extraído, mas o marcador `status.json` nunca foi criado,
causando falha a cada boot ("Text file busy").

```bash
mkdir -p /var/lib/droid-juicer
printf '{"files": [], "folders": []}\n' > /var/lib/droid-juicer/status.json
chmod 644 /var/lib/droid-juicer/status.json
```

## Correção 2: Verificar firmware presente
```bash
# Confirmar que os arquivos estão no lugar
ls -l /usr/lib/firmware/qca/crnv21.bin
ls -l /usr/lib/firmware/qca/crbtfw21.tlv
ls -l /usr/lib/firmware/updates/qcom/sdm845/oneplus6/
```

## Correção 3: Device Tree (DTB)
O device tree pode precisar de patch para habilitar o Bluetooth corretamente.
Arquivos de referência:
- `fdt-uboot.dtb` — device tree do u-boot.
- `patch-dtb.txt` — análise do patch necessário.
- `custom-cfg.txt`, `custom2.txt` — configurações customizadas.

```bash
# Verificar device tree atual
cat /proc/device-tree/model
find /proc/device-tree -name "compatible" -exec sh -c 'echo "$1: $(cat $1)"' _ {} \; 2>/dev/null | grep -i qca
```

## Correção 4: Módulos do kernel
```bash
# Carregar módulos necessários (se não carregados)
sudo modprobe bluetooth
sudo modprobe hci_uart
sudo modprobe btqca

# Verificar
lsmod | grep -E 'bluetooth|hci_uart|btqca'
```

## Correção 5: Serviço Bluetooth
```bash
# Habilitar e iniciar o serviço
sudo systemctl enable bluetooth.service
sudo systemctl start bluetooth.service

# Verificar status
systemctl status bluetooth.service
```

## Verificação final
```bash
# Interface deve aparecer
bluetoothctl show

# Deve listar dispositivos
hcitool dev

# Sem erros no dmesg
dmesg | grep -iE 'bluetooth|hci0' | tail -10

# Temperatura do modem (afeta Bluetooth)
cat /sys/class/thermal/thermal_zone16/temp
```

## Para desfazer
```bash
sudo systemctl disable bluetooth.service
sudo systemctl stop bluetooth.service
sudo rm -f /var/lib/droid-juicer/status.json
```

## Resumo
O Bluetooth no OnePlus 6T depende do firmware qca extraído do Android via
droid-juicer. A criação do marcador `status.json` evita a re-extração a cada
boot. O device tree pode precisar de ajustes para habilitar o subsistema
corretamente. A bateria (bq27541) e o áudio compartilham o mesmo subsistema
de energia, por isso foram diagnosticados em conjunto.