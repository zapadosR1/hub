# Waydroid — Guia visual para Plasma Mobile (OnePlus 6T / Fedora 44)

## O que é o Waydroid?

O Waydroid é um **contêiner Android** que roda dentro do Linux.  
Ele permite instalar e usar **apps Android** (APKs) no seu celular, com
integração nativa ao Plasma Mobile (ícones na gaveta de apps, notificações, etc.).

```
┌─────────────────────────────────────┐
│         Plasma Mobile (Linux)        │
│  ┌───────────────────────────────┐  │
│  │     Waydroid (contêiner)      │  │
│  │   ┌─────────────────────┐    │  │
│  │   │   Apps Android      │    │  │
│  │   │  (WhatsApp, etc.)    │    │  │
│  │   └─────────────────────┘    │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

## Pré-requisitos

| Item | Status neste aparelho |
|------|----------------------|
| Kernel com suporte a `binder` | ✅ Disponível (`/proc/filesystems` lista binder) |
| Montagem de binderfs | ⚠️ Requer root |
| Waydroid instalado | ❌ Não instalado |
| Espaço em disco | ✅ ~86 GB livres em `/var/home` |

## Instalação (requer root + reboot)

### Passo 1 — Instalar o Waydroid
```bash
sudo rpm-ostree install waydroid
sudo systemctl reboot
```

### Passo 2 — Inicializar o contêiner Android
Após o reboot:
```bash
sudo waydroid init
```
(Isso baixa a imagem Android, ~1 GB. Pode demorar.)

### Passo 3 — Iniciar o serviço
```bash
sudo systemctl enable --now waydroid-container
```

### Passo 4 — Lançar o Waydroid
```bash
waydroid show-full-ui
```
Ou use o ícone "Waydroid" na gaveta de apps do Plasma Mobile.

## Integração com Plasma Mobile

O Plasma Mobile já tem suporte nativo:
- **Quick Settings**: há um tile "Waydroid" para iniciar/parar.
- **Gaveta de apps**: apps Android instalados aparecem como ícones normais.
- **Notificações**: notificações Android são repassadas ao Plasma.

## Instalar apps Android

```bash
# Via APK
waydroid app install /caminho/para/app.apk

# Via Google Play (se usar imagem com GApps)
# Abra a Play Store dentro do Waydroid
```

## Verificar se está funcionando

```bash
waydroid status
```
Deve mostrar `Session: RUNNING`.

## Solução de problemas

| Problema | Solução |
|----------|---------|
| `binder` não disponível | Verificar se o kernel tem `CONFIG_ANDROID_BINDERFS=y` |
| Waydroid não inicia | `sudo waydroid container restart` |
| Apps não aparecem | `waydroid app list` e reiniciar o Plasma shell |
| Lentidão | Waydroid usa recursos; feche apps não usados |

## Script de verificação de pré-requisitos

```bash
#!/bin/bash
echo "=== Verificação Waydroid ==="
grep -q binder /proc/filesystems && echo "✅ binder disponível" || echo "❌ binder ausente"
command -v waydroid >/dev/null && echo "✅ waydroid instalado" || echo "❌ waydroid não instalado"
[ -d /var/lib/waydroid ] && echo "✅ dados waydroid presentes" || echo "ℹ️  dados waydroid ausentes"
systemctl is-active waydroid-container 2>/dev/null && echo "✅ container ativo" || echo "ℹ️  container inativo"
```

## Nota

No OnePlus 6T com kernel sdm845 customizado, o suporte a binder pode variar.
Se o `waydroid init` falhar com erro de binder, pode ser necessário um kernel
com `CONFIG_ANDROID_BINDERFS` habilitado. Isso exigiria recompilar o kernel
ou usar um kernel alternativo (ex.: do projeto postmarketOS).