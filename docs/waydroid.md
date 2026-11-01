# Procedimento: Configurar o Waydroid (Android em contêiner) — emergência

## Equipamento
OnePlus 6T (fajita, sdm845) — Fedora 44 Kinoite / Plasma Mobile

## Objetivo
Ter um contêiner Android disponível para usar apps de emergência (WhatsApp,
Telegram, mapas offline, etc.) quando necessário.

## Pré-requisitos
- Kernel com suporte a `binder` (verificar: `grep binder /proc/filesystems`).
- Waydroid instalado (`waydroid --version`).
- Espaço em disco (~1 GB para a imagem).

## Instalação (requer root)
```bash
sudo rpm-ostree install waydroid
sudo systemctl reboot
```

## Inicializar o contêiner (GAPPS)
Após o reboot:
```bash
sudo waydroid init -c https://ota.waydro.id/system -v https://ota.waydro.id/vendor -s GAPPS
```
Isso baixa a imagem Android com Google Play (~1 GB, pode demorar).

## Iniciar o serviço
```bash
sudo systemctl enable --now waydroid-container
```

## Lançar o Waydroid
```bash
waydroid show-full-ui
```
Ou use o ícone "Waydroid" na gaveta de apps do Plasma Mobile.

## Verificar status
```bash
waydroid status
# Deve mostrar Session: RUNNING
```

## Instalar apps
Via APK:
```bash
waydroid app install /caminho/para/app.apk
```
Via Google Play (imagem GAPPS): abra a Play Store dentro do Waydroid.

## Solução de problemas
| Problema | Solução |
|---|---|
| `binder` não disponível | Verificar kernel com `CONFIG_ANDROID_BINDERFS` |
| Waydroid não inicia | `sudo waydroid container restart` |
| Apps não aparecem | `waydroid app list` e reiniciar o Plasma shell |
| Lentidão | Feche apps não usados |

## Nota para o OnePlus 6T
No OnePlus 6T com kernel sdm845 customizado, o suporte a binder pode variar.
Se o `waydroid init` falhar com erro de binder, pode ser necessário um kernel
com `CONFIG_ANDROID_BINDERFS` habilitado.
EOF
path">
/var/home/zapados/hub/docs/waydroid.md