# Procedimento: Ajustar horas e timezone (America/Sao_Paulo)

## Equipamento
OnePlus 6T (fajita, sdm845) — Fedora 44 Kinoite / Plasma Mobile

## Objetivo
Garantir que o relógio do sistema e da tela de login estejam corretos
(America/Sao_Paulo) e sincronizados via NTP.

## Verificação
```bash
timedatectl
```
Deve mostrar:
- `Time zone: America/Sao_Paulo`
- `System clock synchronized: yes`
- `NTP service: active`

## Ajuste (requer root)
```bash
sudo timedatectl set-timezone America/Sao_Paulo
sudo timedatectl set-ntp true
```

## RTC (relógio de hardware)
O RTC do aparelho pode estar em 1970; o NTP corrige o relógio do sistema
após a rede. Para forçar sincronização imediata:
```bash
sudo systemctl restart systemd-timesyncd 2>/dev/null || sudo systemctl restart chronyd 2>/dev/null || true
```

## Tela de login (greeter)
Se o horário na tela de login estiver errado, aplique o locale pt_BR ao
usuário plasmalogin (ver `idioma-portugues.md`).

## Verificação final
```bash
date
timedatectl
```
EOF
path">
/var/home/zapados/hub/docs/horario-timezone.md