# Guia: Resolvendo o Bluetooth no OnePlus 6T (sdm845) com Fedora / Pocket Blue

> Artigo baseado na experiência real de correção no OnePlus 6T (fajita) rodando
> Fedora 44 Kinoite / Plasma Mobile (Pocket Blue), kernel `6.16.7-0.sdm845.fc44.aarch64`.

---

## 1. Sintoma

- `bluetoothctl power on` retorna:
  ```
  Failed to set power on: org.bluez.Error.Failed
  ```
- O adaptador existe (`hci0`), `rfkill` soft/hard = 0, driver `hci_uart_qca` carregado.
- `bluetoothctl show` lista o controller, mas `Powered: no`.
- O kernel diz:
  ```
  Bluetooth: hci0: QCA setup on UART is completed
  Bluetooth: hci0: Opcode 0x0c03 failed: -110
  Bluetooth: hci0: Failed to read MSFT supported features (-110)
  ```

## 2. Diagnóstico

### 2.1 Firmware

O firmware **não** é o problema na maioria dos casos. Confirme:

```bash
md5sum /var/lib/firmware-extract/qca/crbtfw21.tlv
md5sum /var/lib/firmware-extract/qca/oneplus6/crnv21.bin
```

Valores conhecidos como bons (funcionaram em 31/out):
- `crbtfw21.tlv` → `4fceacf111c621d93666aaeafc1eaf56`
- `crnv21.bin` → `e31b6b4fc3eb807dac73b0838dfa3265`

Se diferente, restaure a partir de um backup confiável (ex.: `/etc/bt-firmware`).

### 2.2 droid-juicer

O `droid-juicer` extrai firmware do Android e **sobrescreve** o firmware bom com a
versão do vendor. Mascare-o:

```bash
sudo systemctl mask droid-juicer.service
```

### 2.3 Corrida com `/var`

O firmware é buscado em `/var/lib/firmware-extract` (via symlink `/usr/lib/firmware/updates`).
Se o probe do serdev acontecer antes de `/var` estar pronto, o firmware não é encontrado
e o chip não inicializa. Copie o firmware também para `/usr/lib/firmware/qca` (overlay
gravável) via serviço de early-boot:

```bash
sudo cp /etc/bt-firmware/crbtfw21.tlv /usr/lib/firmware/qca/crbtfw21.tlv
sudo cp /etc/bt-firmware/crnv21.bin  /usr/lib/firmware/qca/oneplus6/crnv21.bin
```

### 2.4 Causa real: estado do chip WCN3990

O firmware carrega e o setup completa, mas o chip **não responde ao HCI Reset**
(`0x0c03 failed: -110`). Isso acontece quando o chip está em estado ruim de um
boot anterior (warm reboot). Um **cold boot** (desligamento total, esperar ~1 min,
ligar) resolve quase sempre.

Evidência: o boot que funcionou (31/out) aconteceu depois da bateria morrer
(desligamento total); os boots que falharam eram warm reboots.

## 3. Solução persistente

### 3.1 Guarda do firmware

```bash
sudo mkdir -p /etc/bt-firmware
sudo cp crbtfw21-fedora.tlv /etc/bt-firmware/crbtfw21.tlv
sudo cp crnv21-fedora.bin   /etc/bt-firmware/crnv21.bin
```

### 3.2 Serviço de early-boot (copia para `/usr`)

Crie `/etc/systemd/system/bt-firmware-early.service`:

```ini
[Unit]
Description=bt-firmware-early (copia firmware do BT para /usr)
DefaultDependencies=no
After=local-fs.target systemd-journald.socket
Before=sysinit.target shutdown.target
Conflicts=shutdown.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash /usr/local/bin/bt-firmware-early.sh

[Install]
WantedBy=sysinit.target
```

Script `/usr/local/bin/bt-firmware-early.sh`:

```bash
#!/bin/bash
SRC=/etc/bt-firmware
DST=/usr/lib/firmware/qca
[ -f "$SRC/crbtfw21.tlv" ] || exit 0
[ -f "$SRC/crnv21.bin" ]   || exit 0
mkdir -p "$DST/oneplus6" 2>/dev/null
cp -f "$SRC/crbtfw21.tlv" "$DST/crbtfw21.tlv"
cp -f "$SRC/crbtfw21.tlv" "$DST/oneplus6/crbtfw21.tlv"
cp -f "$SRC/crnv21.bin"   "$DST/crnv21.bin"
cp -f "$SRC/crnv21.bin"   "$DST/oneplus6/crnv21.bin"
exit 0
```

### 3.3 bt-guard (liga o BT automaticamente)

Script `/usr/local/bin/bt-guard.sh`:

```bash
#!/bin/bash
MODE="${1:-boot}"
TLV=/var/lib/firmware-extract/qca/crbtfw21.tlv
NVM=/var/lib/firmware-extract/qca/oneplus6/crnv21.bin
GOOD_TLV=4fceacf111c621d93666aaeafc1eaf56
GOOD_NVM=e31b6b4fc3eb807dac73b0838dfa3265

[ -f /etc/bt-guard/keep-on ] || exit 0

md5() { md5sum "$1" 2>/dev/null | awk '{print $1}'; }

# Restaura firmware se necessário
[ "$(md5 "$TLV")" != "$GOOD_TLV" ] && cp /etc/bt-firmware/crbtfw21.tlv "$TLV"
[ "$(md5 "$NVM")" != "$GOOD_NVM" ] && cp /etc/bt-firmware/crnv21.bin "$NVM"

systemctl is-active --quiet bluetooth.service || systemctl start bluetooth.service

TRIES=6; [ "$MODE" = "quick" ] && TRIES=1
i=0
while [ $i -lt $TRIES ]; do
    i=$((i+1))
    bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && exit 0
    bluetoothctl power on >/dev/null 2>&1
    [ $i -lt $TRIES ] && sleep 3
done

# Registra falha
{
    echo "=== $(date) modo=$MODE ==="
    bluetoothctl show 2>&1 | head -12
    journalctl -b -k 2>/dev/null | grep -iE 'hci0|qca|bluetooth' | tail -40
} >> /var/log/bt-guard.log
exit 1
```

Serviços:
- `bt-guard.service` (oneshot, boot) — `ExecStart=/bin/bash /usr/local/bin/bt-guard.sh boot`
- `bt-guard-check.timer` — a cada 10 min chama `bt-guard.sh quick`
- `/usr/lib/systemd/system-sleep/bt-guard` — reaplica após suspensão

### 3.4 Se o BT ainda não subir

1. Desligue o telefone completamente (não reinicie).
2. Espere ~1 minuto e ligue.
3. O chip WCN3990 recebe corte de energia real e inicializa limpo.

## 4. Verificação

```bash
bluetoothctl show | grep -E "Powered|PowerState"
md5sum /var/lib/firmware-extract/qca/crbtfw21.tlv /var/lib/firmware-extract/qca/oneplus6/crnv21.bin
systemctl is-enabled droid-juicer.service   # deve ser "masked"
```

## 5. Referências
- Firmware bom: `crbtfw21.tlv` md5 `4fceacf111c621d93666aaeafc1eaf56`,
  `crnv21.bin` md5 `e31b6b4fc3eb807dac73b0838dfa3265`.
- `droid-juicer` mascara o firmware com a versão do vendor (erro "Text file busy").
- WCN3990 é um chip combo (Wi-Fi + BT); warm reboot pode deixá-lo em estado ruim.

---
*Gerado a partir da experiência de correção no OnePlus 6T com Fedora 44 / Pocket Blue.*
EOF
echo "criado"