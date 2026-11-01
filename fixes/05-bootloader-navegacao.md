# Navegação no boot (u-boot / GRUB) com botões físicos

## Realidade do aparelho

No OnePlus 6T (fajita) com Fedora 44 Kinoite/Plasma Mobile:

- O **u-boot** é o primeiro bootloader. Segurar **Volume Down** ao ligar
  abre o menu do u-boot, que pode ser navegado com os botões de volume
  (cima/baixo) e selecionado com **Power**.
- O **GRUB** (EFI) é carregado pelo u-boot. O menu do GRUB aparece por
  10 s e é navegado por **teclado** (setas/Enter). Os botões de volume/power
  **não** são mapeados para o GRUB neste dispositivo (não há módulo serial
  nem driver de botões no GRUB do bootupd).
- Não existe módulo GRUB de serial/USB ACM instalado neste sistema
  (bootupd fornece um binário EFI estático), então não é possível controlar
  o GRUB pelo cabo USB.

## Alternativas práticas

1. **Teclado USB-C/OTG**: conectar um teclado USB ao aparelho permite
   navegar no GRUB normalmente (setas + Enter).
2. **Depender do u-boot**: usar o menu do u-boot (Volume Down) para escolher
   a entrada, quando disponível.
3. **Evitar a necessidade de navegar**: configurar o GRUB para lembrar a
   última entrada usada e dar um timeout confortável.

## Configuração recomendada (requer root)

Aplicar `GRUB_DEFAULT=saved`, `GRUB_SAVEDEFAULT=true` e timeout de 30 s:

```bash
sudo bash ~/hub/scripts/adjust_grub_mobile.sh
```

O script regenera o `grub.cfg` com validação e backup, como em
`corrigir-boot-e-wifi.sh`.

## Recuperação automática (já configurada)

Este sistema já possui mecanismo de recuperação automática, sem necessidade
de teclado:

- `grub-boot-success.timer` (user) marca `boot_success=1` após 2 minutos
  de sessão ativa.
- `08_fallback_counting` no GRUB: se `boot_success=0` após um upgrade,
  decrementa `boot_counter`; ao chegar a 0, boota o deployment anterior
  (rollback) automaticamente.
- `12_menu_auto_hide` esconde o menu quando o último boot foi OK, mas o
  fallback ainda funciona mesmo com menu oculto.

Ou seja: se um update quebrar o boot, o sistema tenta algumas vezes e
depois volta sozinho para a versão anterior. Não é necessário intervenção
manual para evitar loop infinito.

## Mostrar sempre o menu (opcional, requer root)

Se quiser o menu sempre visível (para usar teclado USB), desative o
auto-hide:

```bash
sudo grub2-editenv /boot/grub2/grubenv set menu_auto_hide=0
```

## Nota

Mapear volume/power para o GRUB exigiria um bootloader personalizado
(u-boot/GRUB com drivers de GPIO) e não é suportado pelo bootupd/ostree
deste sistema. Esta limitação é documentada para a comunidade.