# Melhoria de desempenho — OnePlus 6T / Fedora 44 Kinoite (Plasma Mobile)

## Ações aplicadas

1. **Baloo (indexador de arquivos) desativado**
   - Serviço `kde-baloo.service` consumia I/O e CPU indexando arquivos.
   - Comando: `balooctl6 disable`
   - Para reativar: `balooctl6 enable`

2. **Rygel (servidor DLNA/UPnP) desativado no autostart**
   - Autostart removido: `~/.config/autostart/rygel.desktop`
   - O serviço `rygel.service` já estava disabled; o autostart o iniciava no login.

3. **ksshaskpass em loop de crash encerrado**
   - Prompt de credencial do git travava em crash (Qt platform fatal).
   - Comando: `pkill ksshaskpass`
   - Evitar repetir: garantir token SSH/PAT configurado (ver `06-github-auth.md`).

4. **Intervalo de sincronização do hub ajustado**
   - Timer `hub-sync.timer` alterado de 5 min para 15 min para reduzir
     atividade de background.

## Ajustes opcionais (requerem root)

5. **Governor de CPU para `performance`**
   ```bash
   echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
   ```
   Melhora a resposta, mas reduz a autonomia de bateria.

6. **Desativar animações no Plasma Mobile**
   - Configurações → Aparência → Efeitos → desativar animações de janela.

## Erros benignos conhecidos (não afetam o uso)

- `systemd-tmpfiles` e `udev` reportam grupos/usuários ausentes
  (`audio`, `disk`, `kvm`, `utmp`, `tss`, `clock`, `tty`, `kmem`, `input`,
  `video`, `render`). Isso é esperado em sistemas ostree/immutable onde esses
  grupos são gerenciados de forma diferente. Não impactam o desempenho.

## Monitoramento rápido

```bash
# Processos por CPU
ps aux --sort=-%cpu | head

# Memória
free -h

# Temperatura
for z in /sys/class/thermal/thermal_zone*; do echo "$(cat $z/type): $(cat $z/temp)"; done | grep -i cpu
```