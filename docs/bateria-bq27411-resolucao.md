# Guia: Resolvendo a bateria (bq27411) no OnePlus 6T (sdm845) com Fedora / Pocket Blue

> Artigo baseado na experiência real de correção no OnePlus 6T (fajita) rodando
> Fedora 44 Kinoite / Plasma Mobile (Pocket Blue), kernel `6.16.7-0.sdm845.fc44.aarch64`.

---

## 1. Sintoma

O fuel gauge reportava leituras absurdas:
- Tensão: `0.039 V` (deveria ser ~3.9 V)
- Temperatura: `-247.4 °C`
- Carga: `100 %` fixo (não variava)
- Corrente: valores incoerentes

## 2. Diagnóstico

### 2.1 Confirmar o chip físico

O DTB entregue pelo u-boot declarava `compatible = "ti,bq27541"`, mas o chip
físico é um **bq27411** (ou bq27421 — o mapa de registradores é idêntico).

Leitura I2C direta no endereço `0x55`:
- `DEVICE_TYPE 0x0421` → bq27411 / bq27421
- bq27541 tem `DEVICE_TYPE 0x0541`

O driver usava o mapa de registradores do bq27541 (errado), por isso as leituras
absurdas.

### 2.2 Verificar o DTB

```bash
# No ESP (u-boot entrega este DTB)
strings /boot/efi/dtb/qcom/sdm845-oneplus-fajita.dtb | grep bq27
```

Se aparecer `ti,bq27541`, o DTB está errado.

## 3. Solução

### 3.1 Patch no DTB do ESP

```bash
sudo cp /boot/efi/dtb/qcom/sdm845-oneplus-fajita.dtb \
       /boot/efi/dtb/qcom/sdm845-oneplus-fajita.dtb.orig
# substituir ti,bq27541 -> ti,bq27411 (via dtc ou sed binário)
```

Backup do original em `/boot/efi/dtb/qcom/sdm845-oneplus-fajita.dtb.orig`.

> **Atenção**: o kernel recebe o DTB do u-boot, não do GRUB. Patch no ESP pode não
> ter efeito imediato em warm boot. A solução definitiva é o módulo corrigido (abaixo).

### 3.2 Módulo kernel corrigido (solução definitiva)

O driver `bq27xxx_battery_i2c` mapeia `bq27541` → `BQ27541` (driver_data `0x11`).
Trocar para `BQ27411` (driver_data `0x16`).

Arquivo original:
```
/lib/modules/6.16.7-0.sdm845.fc44.aarch64/kernel/drivers/power/supply/bq27xxx_battery_i2c.ko.xz
```

Arquivo corrigido: `/etc/bq27xxx_battery_i2c_fix.ko`

Serviço de fallback (caso o DTB volte para bq27541 no boot):
`/etc/systemd/system/bq27411-fallback.service` (ativo).

Comandos:
```bash
sudo rmmod bq27xxx_battery_i2c
sudo insmod /etc/bq27xxx_battery_i2c_fix.ko
sudo systemctl enable bq27411-fallback.service
```

### 3.3 Cold boot

O DTB corrigido (`ti,bq27411`) foi confirmado funcionando em **boot frio**
(quando a bateria acabou e o celular ligou do zero). Se o DTB voltar a
`ti,bq27541` após um warm reboot, o serviço de fallback troca o módulo.

## 4. Resultado

Após a correção:
- Tensão: `3.965 V` (antes: `0.039 V`)
- Temperatura: `31.2 °C` (antes: `-247.4 °C`)
- Carga: `42 %` (antes: `100 %` fixo)
- Corrente: `1.23 A` carregando

## 5. Verificação

```bash
# Tensão, temperatura e carga
cat /sys/class/power_supply/bq27411-0/voltage_now
cat /sys/class/power_supply/bq27411-0/temp
cat /sys/class/power_supply/bq27411-0/capacity
```

## 6. Backups

- `/boot/efi/dtb/qcom/sdm845-oneplus-fajita.dtb.orig` (DTB original)
- `~/Documentos/Projeto Padrão/bq27xxx_battery_i2c.ko` (módulo original)
- `~/Documentos/Projeto Padrão/bq27xxx_battery_i2c_fix.ko` (módulo corrigido)
- Rollback deployment disponível: `aa3572357b76e14e6b4fbe8cc449196c4eba3ba425566853c1b8e3643b56488e.0`

## 7. Observações

- O módulo corrigido não tem assinatura (sem secure boot).
- Se o kernel for atualizado, o módulo precisa ser recompilado para a nova versão.
- O DTB no ESP é lido pelo u-boot; o GRUB não o sobrescreve.

---
*Gerado a partir da experiência de correção no OnePlus 6T com Fedora 44 / Pocket Blue.*
EOF
echo "criado"