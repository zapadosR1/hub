# Plano de emergência — OnePlus 6T (fajita)

Fedora 44 Kinoite / Plasma Mobile · u-boot + GRUB (EFI) + ostree

Este documento assume que o aparelho é um **telefone**: sem teclado, sem
monitor externo e, muitas vezes, sem rede. Todas as instruções usam apenas os
botões físicos, um cabo USB-C e/ou outro computador.

---

## 0. O que já está preparado

| Recurso | Como funciona |
|---|---|
| Menu do GRUB | aparece por **10 s** em todo boot |
| Entradas do GRUB | deployment atual, rollback, `rescue` e `shell sem gráfico` |
| Menu do u-boot | segure **Volume Down** ao ligar |
| SSH pela rede local/Tailscale | `100.93.235.98` |
| SSH pelo cabo USB | `172.16.42.1` (interface `usb0`, NCM) |
| Console serial pelo cabo USB | `/dev/ttyGS0` no aparelho = `/dev/ttyACM0` no PC |
| eMMC para o PC | "Enable USB mass storage" no menu do u-boot |
| fastboot | "Enable fastboot mode" no menu do u-boot |
| EDL (último recurso) | botões Volume Up + Volume Down + cabo USB |

O script `/var/home/zapados/corrigir-boot-e-wifi.sh` cria/atualiza tudo isso.
**Rode-o de novo depois de cada `rpm-ostree upgrade`** (as entradas de
emergência apontam para o kernel do deployment atual).

### Por que não entra em loop infinito

- u-boot: `bootretry=1` tenta o boot de novo; se o `bootefi` falhar, cai no
  menu (`bootcmd` termina em `pause; run menucmd`).
- Se a seleção do menu for "Quit", o u-boot volta ao menu em ~1 s em vez de
  ficar parado num console sem teclado.
- GRUB: sem `recordfail`, timeout fixo de 10 s, `GRUB_DEFAULT=0` (deployment
  atual). Se o kernel novo não bootar, o u-boot cai no menu dele.
- Sempre existe a entrada de rollback no GRUB e a entrada `rescue`.

---

## 1. Checklist antes de reiniciar

```bash
# menu de 10 s e blscfg presentes
sudo grep -E '^[[:space:]]*set (timeout|timeout_style)=' /boot/grub2/grub.cfg
sudo grep -c blscfg /boot/grub2/grub.cfg

# entradas do menu (as emergency-* são as duas últimas do menu)
sudo ls -l /boot/loader/entries/

# console USB
systemctl is-enabled serial-getty@ttyGS0
ls -l /dev/ttyGS0

# SSH
tailscale ip -4
ip -4 addr show usb0
```

Teste **antes** de reiniciar:

```bash
# no PC, com o cabo USB conectado:
ls /dev/ttyACM*
sudo screen /dev/ttyACM0 115200      # sair: Ctrl+A, K
# alternativa: picocom -b 115200 /dev/ttyACM0

# em outro terminal do PC:
ssh zapados@172.16.42.1
```

Se aparecer `login:` no console serial e o SSH USB funcionar, o resgate está
garantido mesmo que a tela ou o Wi-Fi morram.

---

## 2. O sistema liga, mas está sem tela / sem Wi-Fi

### 2.1 SSH pelo Tailscale (precisa de internet)

```bash
ssh zapados@100.93.235.98
```

### 2.2 SSH pelo cabo USB (não precisa de internet)

Conecte o cabo USB-C ao PC. O aparelho roda um DHCP em `usb0`; o PC deve
receber um IP `172.16.42.x`.

```bash
# no PC
ip -4 addr show                      # procure a interface com 172.16.42.x
ssh zapados@172.16.42.1
```

Se o PC não pegar DHCP:

```bash
sudo ip addr add 172.16.42.2/24 dev <interface>
ssh zapados@172.16.42.1
```

### 2.3 Console serial pelo USB (login na tela do PC)

```bash
# no PC
sudo screen /dev/ttyACM0 115200
# sair do screen: Ctrl+A, K
```

Login com usuário/senha do aparelho (`zapados`). Esse console é um getty normal
em `/dev/ttyGS0`, habilitado pelo script.

### 2.4 Consertar o Wi-Fi

Se o firmware cair de novo:

```bash
journalctl -b -k | grep -c 'firmware crashed'
nmcli -f GENERAL.STATE,ACTIVE 2>/dev/null; nmcli device status
sudo nmcli connection up Dallonder
```

A correção definitiva é no roteador: **2.4 GHz fixo em 20 MHz**, desligar band
steering e roaming agressivo. O BSSID está fixado em `f0:9f:c2:34:7c:f4`.

---

## 3. O sistema não chega ao login (boot loop / kernel travado)

Primeiro: **desligue à força** segurando **Power por ~10 s**.

### 3.1 Menu do GRUB (10 segundos)

Ligue normalmente e não aperte nada. Em até 10 s o menu aparece.

Navegação no telefone: **Volume Up/Down = cima/baixo**, **Power = Enter**.

Com 2 deployments instalados a ordem é:

| Índice | Entrada | Para que serve |
|---|---|---|
| 0 | deployment atual (mais novo) | boot normal |
| 1 | deployment anterior (rollback) | volta para o kernel/sistema antigo |
| 2 | `EMERGENCIA: rescue` | texto, SSH + USB, quase nada iniciado |
| 3 | `EMERGENCIA: shell sem grafico` | multi-user sem Plasma, SSH + USB |

As entradas `emergency-*` são sempre as **duas últimas** do menu, não importa
quantos deployments existam. Se houver mais deployments, o índice do rollback
muda: confira com `sudo ls /boot/loader/entries` e `ostree admin status`.

**Jeito mais confiável (pelo SSH, antes de reiniciar):**

```bash
# próxima inicialização apenas
sudo grub2-reboot 2          # 2 = rescue; 3 = shell sem gráfico; 1 = rollback

# ou permanente (cuidado: continua assim em todo boot)
sudo grub2-set-default 2

# voltar ao normal
sudo grub2-set-default 0
```

`grub2-reboot`/`grub2-set-default` usam o índice **numérico** do menu. Confira
o que está gravado:

```bash
sudo grub2-editenv /boot/grub2/grubenv list
```

Depois de entrar numa entrada de emergência:

- SSH USB: `ssh zapados@172.16.42.1` (funciona em rescue e em shell)
- Console USB: `screen /dev/ttyACM0 115200`
- Tailscale só sobe no `shell sem grafico` (multi-user), **não** no rescue
- No rescue, o `sulogin` aparece na tela do aparelho (tty0, sem teclado); o
  acesso prático é o getty em `/dev/ttyGS0` pelo cabo USB e o SSH

Para consertar o sistema a partir daí:

```bash
rpm-ostree status
sudo rpm-ostree rollback         # se o problema for o deployment novo
sudo rpm-ostree cleanup -p       # se precisar liberar espaço
sudo systemctl reboot
```

### 3.2 Menu do u-boot (quando o GRUB nem aparece)

1. Desligue à força (Power ~10 s).
2. Segure **Volume Down** e aperte **Power**, mantendo Volume Down até o menu
   aparecer.
3. Navegue com **Volume Up/Down** e confirme com **Power**.

O menu tem atalhos numéricos no teclado (1–9, 0 = Quit), úteis quando se usa o
console serial.

| Item | O que faz |
|---|---|
| `1. Boot` | tenta o boot normal (GRUB) |
| `2. Enable serial console gadget` | liga o console no cabo USB (precisa do PC já conectado e com terminal aberto) |
| `3. Enable USB mass storage` | exporta o eMMC inteiro para o PC |
| `4. Enable fastboot mode` | entra em fastboot |
| `5. Drop to shell` | desliga o retry e leva ao prompt do u-boot |
| `6. Reset device` | reinicia |
| `7. Dump clocks` | diagnóstico |
| `8. Dump environment` | mostra o ambiente do u-boot |
| `9. Board info` | diagnóstico |
| `a. Dump bootargs` | mostra o `bootargs` da DT |
| `0. Quit` | sai do menu |

#### Como chegar ao prompt do u-boot (`=>`)

O telefone não tem teclado, então o prompt só serve junto com o console USB:

1. Conecte o cabo USB ao PC e abra o terminal **antes**:
   `sudo screen /dev/ttyACM0 115200`
2. No menu do u-boot escolha `2. Enable serial console gadget`.
   O menu fecha e reabre (o u-boot remapeia o `bootcmd` para reabrir o menu).
3. Escolha `5. Drop to shell`. O menu fecha e, desta vez, o u-boot para no
   prompt `=>` — que agora também aparece no terminal do PC.
   (Se o menu reabrir, escolha `0. Quit`; com o retry desligado o prompt fica.)

Comandos úteis no prompt:

```text
printenv                     # ver o ambiente
run bootcmd                  # tentar o boot normal de novo
run setup_rootdev            # reconfigurar o dispositivo raiz
run setup_blkmap             # recriar o blkmap
ums 0 ${rootdev}             # exportar o eMMC para o PC (sair: apertar botão)
fastboot usb 0               # entrar em fastboot
reset                        # reiniciar
bdinfo                       # informações da placa
```

### 3.3 Prompt do GRUB (ler arquivos e boot manual)

O GRUB tem um console próprio (`grub>`), mas ele **só serve como leitura**: o
GRUB lê btrfs/ext4, porém não grava nesses sistemas de arquivos. Para
*consertar* arquivos use o UMS (seção 4) ou as entradas de emergência.

Como chegar nele no telefone (não há tecla para digitar `c` nos 3 botões):

1. Cabo USB conectado no PC, terminal aberto: `sudo screen /dev/ttyACM0 115200`.
2. Volume Down + Power → menu do u-boot → `2. Enable serial console gadget`.
3. No menu do u-boot escolha `1. Boot` (o GRUB herda o teclado do console USB).
4. No menu do GRUB tecle **`c`** no terminal do PC.

Comandos úteis (o UUID da raiz é `0c26887f-665f-43fa-bb63-5578670b0c35`):

```text
search --no-floppy --fs-uuid --set=root 0c26887f-665f-43fa-bb63-5578670b0c35
ls /
ls /boot/loader/entries
cat /boot/loader/entries/ostree-2.conf     # ver kernel/initrd/options do boot atual
cat /boot/grub2/grub.cfg | grep timeout    # conferir o timeout
```

Boot manual (quando o menu está quebrado), copiando os caminhos que aparecem no
`cat` acima:

```text
linux /boot/ostree/default-<HASH>/vmlinuz-<VERSAO> root=UUID=0c26887f-665f-43fa-bb63-5578670b0c35 rootflags=subvol=/root rw boot=UUID=0c26887f-665f-43fa-bb63-5578670b0c35 ostree=/ostree/boot.1/default/<HASH>/0 console=tty0
initrd /boot/ostree/default-<HASH>/initramfs-<VERSAO>.img
boot
```

Para sair do `grub>`: `reboot` (reinicia) ou `normal` (volta ao menu).

> Sem PC por perto, o caminho para "acessar o sistema de arquivos" é a entrada
> `EMERGENCIA: shell sem grafico` (índice 3): o Linux sobe, monta tudo e você
> entra por SSH/USB com permissão de root via `sudo`.

---

## 4. Reparar o `/boot` pelo PC (USB mass storage)

Use quando o GRUB/menu quebrou ou quando for preciso restaurar um backup.

1. Desligue à força.
2. Volume Down + Power → menu do u-boot → `3. Enable USB mass storage`.
3. No PC:

```bash
lsblk -o NAME,SIZE,FSTYPE,PARTLABEL
# o eMMC aparece como /dev/sdX; a partição "userdata" tem ~110G e é btrfs
sudo mount -o subvol=boot /dev/sdX17 /mnt
ls /mnt                       # loader/  grub2/  ostree/  efi/
```

4. Conserte o que precisar:

```bash
# ver/restaurar o grub.cfg (o script cria backups com data)
ls -l /mnt/grub2/grub.cfg*
sudo cp -a /mnt/grub2/grub.cfg.bak-AAAAmmdd-HHMMSS /mnt/grub2/grub.cfg

# remover as entradas de emergência (se forem a causa)
sudo rm -f /mnt/loader/entries/emergency-*.conf

# conferir timeout e blscfg
sudo grep -E 'set timeout' /mnt/grub2/grub.cfg
```

5. Desmonte com segurança e saia do UMS:

```bash
sync
sudo umount /mnt
```

6. No telefone, aperte qualquer botão para sair do modo UMS e escolha
   `1. Boot` (ou `6. Reset device`).

> O `.conf` de emergência e o `/etc/default/grub` são recriados pelo
> `corrigir-boot-e-wifi.sh`; se possível, rode-o depois de voltar ao sistema.

---

## 5. fastboot

Útil para ver o log do u-boot e reiniciar.

No telefone: menu do u-boot → `4. Enable fastboot mode`.
No PC (pacote `android-tools`):

```bash
sudo fastboot devices
sudo fastboot oem console      # despeja o console gravado pelo u-boot
sudo fastboot reboot
```

O fastboot deste u-boot só escreve em MMC (`FASTBOOT_FLASH_MMC_DEV=0`).
**Não** use `fastboot flash` sem saber exatamente o que está fazendo.

---

## 6. EDL / Qualcomm 9008 (último recurso)

Só use se o u-boot também estiver morto (nem o menu aparece) e o PC enxergar o
aparelho como Qualcomm 9008.

1. Aparelho desligado.
2. Segure **Volume Up + Volume Down** e conecte o cabo USB.
3. No PC:

```bash
lsusb | grep -i 9008          # deve mostrar 05c6:9008
```

Recuperar em EDL exige as ferramentas MSM/`edl` e o loader Firehose correto
para o sdm845. É um procedimento de alto risco (pode apagar dados e, se
interrompido, deixar o aparelho inutilizável). **Não faça isso sem antes
esgotar as opções acima.**

---

## 7. Manutenção depois de atualizações

```bash
# depois de todo rpm-ostree upgrade, antes de reiniciar:
sudo bash /var/home/zapados/corrigir-boot-e-wifi.sh
```

O script:

- reaplica os drop-ins de shutdown (rmtfs, ath10k, SSHFS);
- mantém o menu do GRUB em 10 s;
- recria `emergency-b-rescue.conf` e `emergency-a-shell.conf` apontando para o
  deployment **em execução** (kernel/initramfs/DTB/`ostree=` corretos);
- reimprime o estado para conferência.

Se as entradas de emergência ficarem velhas (script não rodado após upgrade),
o pior que acontece é a entrada falhar e o boot voltar ao menu do GRUB — não
há loop.

---

## 8. Diagnóstico rápido

| Sintoma | Primeira ação |
|---|---|
| Wi-Fi cai / firmware crashed | SSH USB; `journalctl -b -k \| grep firmware`; roteador em 20 MHz |
| Desliga e trava em stop job | `journalctl -b -1 \| tail -30`; rodar o script de novo |
| Tela preta, mas ligado | `ping 100.93.235.98`; SSH USB `172.16.42.1`; console `/dev/ttyACM0` |
| GRUB não aparece | Volume Down no boot → menu do u-boot → `1. Boot` |
| GRUB aparece mas o kernel não sobe | escolher rollback (índice 1) ou `rescue` (2) |
| Nada funciona no menu | UMS (item 3) e reparar `/boot` pelo PC |
| u-boot não aparece / 9008 no PC | EDL (seção 6), último recurso |

---

## 9. Checklist pós-reboot

1. O menu do GRUB aparece e fica ~10 s na tela.
2. Volume Up/Down movem a seleção; Power confirma.
3. O boot normal (índice 0) chega ao Plasma Mobile.
4. Console USB: `sudo screen /dev/ttyACM0 115200` mostra `login:`.
5. SSH USB: `ssh zapados@172.16.42.1`.
6. SSH Tailscale: `ssh zapados@100.93.235.98`.
7. Desligamento limpo:

```bash
journalctl -b -1 --no-pager | tail -30
# não deve haver "stop-sigterm timed out" nem parada em
# "Unmounting var-home.mount"
```

8. Teste controlado de uma entrada de emergência (opcional, exige 2 reboots):

```bash
sudo grub2-reboot 2          # próximo boot = rescue
sudo systemctl reboot
# confirme o SSH/USB no rescue e depois:
sudo grub2-set-default 0
sudo systemctl reboot
```
