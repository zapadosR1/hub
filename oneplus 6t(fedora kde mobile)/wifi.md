# Procedimento: Correção do Wi-Fi (ath10k / WCN3990)

## Equipamento
OnePlus 6T (fajita, sdm845) — Fedora 44 Kinoite / Plasma Mobile

## Sintomas observados
- Wi-Fi conectava normalmente e depois de minutos/horas parava de responder.
- `journalctl -k` mostrava:
  ```
  ath10k_snoc ... firmware crashed!
  ath10k_snoc ... Asserted in wlan_vdev.c:_wlan_vdev_down
  ```
- Às vezes a rede caía e só voltava reconectando ou reiniciando.
- Em alguns casos o desligamento travava em jobs do systemd.

## Causa raiz
O firmware do Wi-Fi (ath10k_snoc / WCN3990) travava quando o rádio trocava
de access point ou recebia mudança de largura de banda do roteador (band
steering / roaming agressivo).

## O que encontramos
- Interface Wi-Fi: `ath10k_snoc` (WCN3990).
- Conexão NetworkManager: `Dallonder`.
- AP estável: canal 1, sinal -49 dBm, BSSID `f0:9f:c2:34:7c:f4`.
- Firmware extraído em `/usr/lib/firmware/updates/qcom/sdm845/oneplus6/`.

## Comandos usados para diagnóstico
```bash
# Verificar crash do firmware
journalctl -b -k | grep -i "firmware crashed"

# Status da rede
nmcli device status
nmcli -f GENERAL.STATE,ACTIVE device show

# Detalhes da conexão
nmcli connection show "Dallonder"
nmcli -g 802-11-wireless.bssid connection show "Dallonder"

# Verificar firmware presente
ls -l /usr/lib/firmware/updates/qcom/sdm845/oneplus6/
```

## Correção aplicada
Fixar o BSSID na conexão do NetworkManager para evitar troca de AP:

```bash
sudo nmcli connection modify "Dallonder" 802-11-wireless.bssid "f0:9f:c2:34:7c:f4"
```

### Correção complementar no roteador
- Travar o 2.4 GHz em **20 MHz**.
- Desligar band steering / roaming agressivo.

## Ajustes no systemd (desligamento)
Para evitar travamento no desligamento quando o firmware está em crash:

```bash
# rmtfs: parada imediata
mkdir -p /etc/systemd/system/rmtfs.service.d
cat > /etc/systemd/system/rmtfs.service.d/10-fast-stop.conf <<'EOF'
[Service]
TimeoutStopSec=5
KillSignal=SIGKILL
SendSIGKILL=yes
EOF

# ath10k-shutdown: limite no rmmod
mkdir -p /etc/systemd/system/ath10k-shutdown.service.d
cat > /etc/systemd/system/ath10k-shutdown.service.d/10-timeout.conf <<'EOF'
[Service]
TimeoutStopSec=20
KillSignal=SIGKILL
EOF
```

## droid-juicer (firmware já extraído)
Criar marcador para o serviço não re-extrair firmware a cada boot:
```bash
mkdir -p /var/lib/droid-juicer
printf '{"files": [], "folders": []}\n' > /var/lib/droid-juicer/status.json
chmod 644 /var/lib/droid-juicer/status.json
```

## Verificação
```bash
# Confirmar BSSID fixado
nmcli -g 802-11-wireless.bssid connection show "Dallonder"

# Confirmar ausência de crash após uso
journalctl -b -k | grep -c 'firmware crashed'

# Verificar firmware presente
ls /usr/lib/firmware/updates/qcom/sdm845/oneplus6/
```

## Para desfazer
```bash
sudo nmcli connection modify "Dallonder" 802-11-wireless.bssid ""
```

## Resumo em uma linha
Fixe o BSSID do access point estável na conexão do NetworkManager e, no
roteador, trave o 2.4 GHz em 20 MHz desligando band steering/roaming agressivo.