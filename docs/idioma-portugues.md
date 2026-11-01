# Procedimento: Colocar o sistema em português (Plasma Mobile)

## Equipamento
OnePlus 6T (fajita, sdm845) — Fedora 44 Kinoite / Plasma Mobile

## Objetivo
Garantir que o sistema, a tela de login (greeter do plasmalogin) e os apps
usem português do Brasil (pt_BR.UTF-8).

## Verificação do locale do sistema
```bash
cat /etc/locale.conf
# Deve conter: LANG=pt_BR.UTF-8

locale
# Todos os LC_* devem estar em pt_BR.UTF-8
```

Se não estiver, ajuste (requer root):
```bash
sudo localectl set-locale LANG=pt_BR.UTF-8
```

## Timezone / horas
Verifique:
```bash
timedatectl
# Time zone: America/Sao_Paulo
```

Se necessário:
```bash
sudo timedatectl set-timezone America/Sao_Paulo
sudo timedatectl set-ntp true
```

## Tela de login (greeter do plasmalogin) em português
O greeter roda como usuário `plasmalogin` e pode não herdar o locale do
usuário final. Para corrigir (requer root):

```bash
sudo mkdir -p /var/lib/plasmalogin/.config
sudo tee /var/lib/plasmalogin/.config/plasma-localerc >/dev/null <<'EOF'
[Formats]
LANG=pt_BR.UTF-8
LC_TIME=pt_BR.UTF-8
EOF
sudo chown -R plasmalogin:plasmalogin /var/lib/plasmalogin/.config
sudo systemctl restart plasmalogin
```

## Verificação
- Reinicie ou faça logout.
- A tela de login deve aparecer em português.
- O horário deve estar em America/Sao_Paulo.

## Para desfazer
```bash
sudo rm -f /var/lib/plasmalogin/.config/plasma-localerc
sudo systemctl restart plasmalogin
```
EOF
path">
/var/home/zapados/hub/docs/idioma-portugues.md