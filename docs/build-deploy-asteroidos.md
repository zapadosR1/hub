# Build e Deploy — Apps AsteroidOS (TicWatch 3 Pro GPS)

## Pré-requisitos
- SDK OpenEmbedded em `~/oecore-x86_64`
- Código-fonte em `~/sdkwork/asteroid-<app>`
- Relógio acessível via SSH: `root@192.168.0.42`

## 1. Compilar um app
```bash
cd ~/sdkwork/asteroid-<app>/build
source ~/oecore-x86_64/environment-setup-armv7vehf-neon-oe-linux-gnueabi
ninja
```
O artefato gerado é `build/src/libasteroid-<app>.so`.

## 2. Backup antes do deploy
```bash
~/backup_watch_apps.sh
```
Ou manualmente:
```bash
ssh root@192.168.0.42 'mkdir -p /root/backup-apps/$(date +%Y%m%d-%H%M%S); cp /usr/lib/libasteroid-*.so /root/backup-apps/$(date +%Y%m%d-%H%M%S)/'
```

## 3. Deploy do .so
```bash
scp ~/sdkwork/asteroid-<app>/build/src/libasteroid-<app>.so root@192.168.0.42:/tmp/
ssh root@192.168.0.42 'mv /tmp/libasteroid-<app>.so /usr/lib/ && chmod 755 /usr/lib/libasteroid-<app>.so'
```
Alternativa (se /tmp sem permissão):
```bash
ssh root@192.168.0.42 'cat > /usr/lib/libasteroid-<app>.so' < ~/sdkwork/asteroid-<app>/build/src/libasteroid-<app>.so
ssh root@192.168.0.42 'chmod 755 /usr/lib/libasteroid-<app>.so'
```

## 4. Testar
Abra o app no relógio. Para capturar screenshot:
```bash
ssh ceres@192.168.0.42 'screenshottool /tmp/shot.png 0'
scp ceres@192.168.0.42:/tmp/shot.png ~/shot.png
```

## Apps disponíveis em ~/sdkwork
- asteroid-gps
- asteroid-maptest
- asteroid-sensors
- asteroid-wifi
- asteroid-store
- asteroid-print
- asteroid-shell

## Observações
- Ajustar layout para tela redonda: usar `effW = Math.min(parent.width, parent.height) * 0.8` e centralizar com `anchors.horizontalCenter`.
- Sensores devem ser ativados apenas sob demanda (`active: sh.running`).
- Teclado: usar `keyH`/`gap` que caibam no Enter (ex.: keyH=50, gap=3, height 320).
