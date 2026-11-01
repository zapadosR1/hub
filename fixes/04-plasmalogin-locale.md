# Tela de login (plasmalogin) em inglês e horário incorreto

## Sintoma

A tela de login (greeter do plasmalogin) carregava em inglês e com horário
incorreto.

## Observações

- Locale do sistema: `pt_BR.UTF-8` (verificado em `/etc/locale.conf`).
- Timezone: `America/Sao_Paulo` (verificado via `timedatectl`).
- O greeter roda como usuário `plasmalogin` e pode não herdar a configuração
  de locale/timezone do usuário final.

## Ações sugeridas (requerem root)

1. Garantir que `/etc/locale.conf` e `/etc/localtime` estejam corretos (já estão).
2. Criar configuração para o usuário `plasmalogin`:
   ```bash
   sudo mkdir -p /var/lib/plasmalogin/.config
   sudo tee /var/lib/plasmalogin/.config/plasma-localerc >/dev/null <<'EOF'
   [Formats]
   LANG=pt_BR.UTF-8
   LC_TIME=pt_BR.UTF-8
   EOF
   sudo chown -R plasmalogin:plasmalogin /var/lib/plasmalogin/.config
   ```
3. Reiniciar o serviço: `sudo systemctl restart plasmalogin`.

## Status

Documentado para referência da comunidade. Ajustes de root não foram aplicados
nesta sessão (ambiente sem privilégios de root).
