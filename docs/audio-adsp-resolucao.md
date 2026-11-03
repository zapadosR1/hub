# Guia: Resolvendo o áudio (ADSP) no OnePlus 6T (sdm845) com Fedora / Pocket Blue

> Artigo baseado na experiência real de correção no OnePlus 6T (fajita) rodando
> Fedora 44 Kinoite / Plasma Mobile (Pocket Blue), kernel `6.16.7-0.sdm845.fc44.aarch64`.

---

## 1. Sintoma

- `aplay -l` → "no soundcards found"
- Nenhuma placa de som detectada.
- O áudio do celular não funciona (alto-falante, fone, microfone).

## 2. Diagnóstico

### 2.1 ADSP não sobe no boot

O ADSP (remoteproc1) não inicia porque o firmware `adsp.mbn` é pedido
**antes** de `/var` (onde fica `/usr/lib/firmware/updates`) montar. O pedido
de firmware falha silenciosamente e o ADSP não sobe.

Verificar:

```bash
cat /sys/class/remoteproc/remoteproc1/state
# se "offline", o ADSP não subiu
dmesg | grep -i adsp
# procurar "firmware load failed" ou "unable to load"
```

### 2.2 Firmware presente?

```bash
ls -la /var/lib/firmware-extract/ 2>/dev/null
ls /usr/lib/firmware/qcom/ 2>/dev/null | grep adsp
```

O firmware `adsp.mbn` (e os módulos `.so`) devem estar em `/var/lib/firmware-extract`
ou `/usr/lib/firmware`.

## 3. Solução

### 3.1 Script de inicialização do ADSP

Crie `/usr/local/bin/adsp-start.sh`:

```bash
#!/bin/bash
# Aguarda o firmware adsp.mbn aparecer (ate 20s) e inicia o ADSP.
FW=/var/lib/firmware-extract/adsp.mbn
for i in $(seq 1 20); do
    [ -f "$FW" ] && break
    sleep 1
done
[ -f "$FW" ] || { echo "adsp.mbn nao encontrado"; exit 1; }
echo start > /sys/class/remoteproc/remoteproc1/state
```

### 3.2 Serviço systemd

Crie `/etc/systemd/system/adsp-start.service`:

```ini
[Unit]
Description=adsp-start (inicia o ADSP apos firmware disponivel)
After=var-lib-firmware-extract.mount local-fs.target
Wants=var-lib-firmware-extract.mount

[Service]
Type=oneshot
ExecStart=/bin/bash /usr/local/bin/adsp-start.sh
RemainAfterExit=yes
TimeoutStartSec=30

[Install]
WantedBy=multi-user.target
```

Habilite:

```bash
sudo chmod 755 /usr/local/bin/adsp-start.sh
sudo systemctl daemon-reload
sudo systemctl enable --now adsp-start.service
```

### 3.3 Verificar se o ADSP subiu

```bash
cat /sys/class/remoteproc/remoteproc1/state
# deve mostrar "running"
```

### 3.4 Reiniciar PipeWire

```bash
systemctl --user restart pipewire wireplumber pipewire-pulse
```

### 3.5 Definir alto-falante como saída padrão

```bash
pactl set-default alsa_output.platform-sound.HiFi__Speaker__sink
```

Para persistir, adicione ao autostart ou a um script de sessão.

## 4. Resultado

- ADSP sobe no boot (remoteproc1 = running).
- Placas de som detectadas (`aplay -l` lista os devices).
- Áudio pelo alto-falante do celular funcionando.

## 5. Verificação

```bash
aplay -l
pactl list sinks short
cat /sys/class/remoteproc/remoteproc1/state
```

## 6. Observações

- O ADSP é um coprocessador de áudio (Qualcomm Hexagon). Sem ele, o ALSA não tem
  devices.
- O firmware `adsp.mbn` fica em `/var/lib/firmware-extract` (extraído pelo droid-juicer
  ou copiado manualmente).
- Se o droid-juicer estiver mascarado (por causa do Bluetooth), garanta que o firmware
  do ADSP já está em `/var/lib/firmware-extract` (foi extraído antes do mascaramento).
- O serviço `adsp-start` depende de `var-lib-firmware-extract.mount` para garantir que
  `/var` esteja pronto antes de procurar o firmware.

## 7. Áudio e Bluetooth compartilham o chip WCN3990

O WCN3990 é um chip combo (Wi-Fi + Bluetooth). O áudio do celular usa o ADSP
(separado), mas o Bluetooth de áudio (A2DP) depende do BT funcionando. Se o BT
não subir, o A2DP não funciona mesmo com o ADSP OK.

---
*Gerado a partir da experiência de correção no OnePlus 6T com Fedora 44 / Pocket Blue.*
EOF
echo "criado"