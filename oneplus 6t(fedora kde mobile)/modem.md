# Procedimento: Correção do modem (rmtfs / q6-modem / SSHFS no desligamento)

## Equipamento
OnePlus 6T (fajita, sdm845) — Fedora 44 Kinoite / Plasma Mobile

## Sintomas observados
- Desligamento travava em "A stop job is running for Qualcomm remotefs service".
- Mensagem de Oops do kernel em `rpmsg_dev_remove` ao desligar o modem.
- Processo do rmtfs ficava preso (ignorava SIGTERM).
- SSHFS (~/servidor e ~/servidor2) impediam desmontar /var/home no shutdown.

## Causa raiz
1. `rmtfs.service` (Qualcomm remotefs) ignorava SIGTERM e escrevia no sysfs
   para desligar o modem, causando Oops do kernel.
2. `ath10k-shutdown.service` podia travar no `rmmod` com firmware em crash.
3. Mounts SSHFS não tinham `auto_unmount` e não eram desmontados antes de
   `/var/home`, causando espera infinita.

## O que encontramos
- Serviço: `rmtfs.service` (Qualcomm remotefs).
- Serviço: `ath10k-shutdown.service`.
- Mounts: `var-home-zapados-servidor.mount`, `var-home-zapados-servidor2.mount`.
- Unidade de desmontagem: `sshfs-umount.service` (criada).
- Firmware modem: `/usr/lib/firmware/updates/qcom/sdm845/oneplus6/`.

## Comandos de diagnóstico
```bash
# Verificar serviços travados no desligamento
journalctl -b -1 --no-pager | tail -25

# Status dos serviços
systemctl status rmtfs.service
systemctl status ath10k-shutdown.service
systemctl status sshfs-umount.service

# Mounts SSHFS
mount | grep servidor
findmnt /var/home/zapados/servidor

# Temperatura do modem
cat /sys/class/thermal/thermal_zone16/temp   # q6-modem-thermal
cat /sys/class/thermal/thermal_zone22/temp   # modem-thermal
```

## Correção 1: rmtfs (parada imediata)
```bash
mkdir -p /etc/systemd/system/rmtfs.service.d
cat > /etc/systemd/system/rmtfs.service.d/10-fast-stop.conf <<'EOF'
# Não esperar o SIGTERM: o rmtfs ignora e o systemd ficava 45 s parado
[Service]
TimeoutStopSec=5
KillSignal=SIGKILL
SendSIGKILL=yes
EOF
```

## Correção 2: ath10k-shutdown (limite no rmmod)
```bash
mkdir -p /etc/systemd/system/ath10k-shutdown.service.d
cat > /etc/systemd/system/ath10k-shutdown.service.d/10-timeout.conf <<'EOF'
[Service]
TimeoutStopSec=20
KillSignal=SIGKILL
EOF
```

## Correção 3: SSHFS auto_unmount + desmontar antes de /var/home

### Adicionar auto_unmount ao script de montagem
```bash
# Editar montar_servidor.sh: adicionar auto_unmount nas opções
sed -i 's/,allow_other"/,allow_other,auto_unmount"/' ~/montar_servidor.sh
```

### Criar unidade de desmontagem
```bash
cat > /etc/systemd/system/sshfs-umount.service <<'EOF'
[Unit]
Description=Desmonta SSHFS antes de /var/home no desligamento
DefaultDependencies=no
Requires=var-home.mount
Conflicts=shutdown.target
After=var-home.mount var-home-zapados-servidor.mount var-home-zapados-servidor2.mount
Before=shutdown.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/true
ExecStop=-/usr/bin/umount -l /var/home/zapados/servidor
ExecStop=-/usr/bin/umount -l /var/home/zapados/servidor2
ExecStop=-/usr/bin/fusermount3 -u -z /var/home/zapados/servidor
ExecStop=-/usr/bin/fusermount3 -u -z /var/home/zapados/servidor2
TimeoutStopSec=10

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable sshfs-umount.service
systemctl start sshfs-umount.service
```

### Drop-ins ForceUnmount nos mounts SSHFS
```bash
for m in var-home-zapados-servidor.mount var-home-zapados-servidor2.mount; do
    mkdir -p "/etc/systemd/system/${m}.d"
    cat > "/etc/systemd/system/${m}.d/10-lazy-unmount.conf" <<'EOF'
[Unit]
JobTimeoutSec=30

[Mount]
ForceUnmount=yes
EOF
done
```

## Correção 4: droid-juicer (marcador de firmware já extraído)
```bash
mkdir -p /var/lib/droid-juicer
printf '{"files": [], "folders": []}\n' > /var/lib/droid-juicer/status.json
chmod 644 /var/lib/droid-juicer/status.json
```

## Verificação
```bash
# Unidade ativa
systemctl is-enabled sshfs-umount.service
systemctl is-active sshfs-umount.service

# Mounts com auto_unmount
mount | grep servidor

# Sem travamento no desligamento (verificar após reboot)
journalctl -b -1 --no-pager | tail -25
```

## Para desfazer
```bash
sudo rm -rf /etc/systemd/system/rmtfs.service.d \
            /etc/systemd/system/ath10k-shutdown.service.d \
            /etc/systemd/system/sshfs-umount.service \
            /etc/systemd/system/var-home-zapados-servidor.mount.d \
            /etc/systemd/system/var-home-zapados-servidor2.mount.d
sudo systemctl daemon-reload
# Restaurar montar_servidor.sh.bak
```