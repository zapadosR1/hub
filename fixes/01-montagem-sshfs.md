# Correção: montagem automática do servidor (SSHFS)

## Problema

A pasta `~/servidor` (remoto `public_html`) nem sempre montava no login,
enquanto `~/servidor2` (remoto `tizomer.com`) montava corretamente. O script
`montar_servidor.sh` era executado via autostart, mas podia rodar antes da rede
estar disponível, causando falha silenciosa na primeira tentativa.

## Causa

- O script usava `sleep 10` fixo e uma única tentativa de `sshfs`.
- Não havia verificação de conectividade antes da montagem.
- Não havia retentativa em caso de falha.

## Correção aplicada

O script `montar_servidor.sh` foi ajustado para:

1. Aguardar até 60 segundos pela rede (ping ao host remoto).
2. Tentar montar cada pasta até 5 vezes, com espera entre tentativas.
3. Só considerar montado quando `mountpoint` confirmar.

## Arquivo

- `~/montar_servidor.sh`
- `~/hub/scripts/montar_servidor.sh` (cópia de referência)

## Verificação

```bash
mount | grep servidor
ls ~/servidor ~/servidor2
```