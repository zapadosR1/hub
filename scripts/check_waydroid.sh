#!/bin/bash
# Verifica pré-requisitos do Waydroid neste aparelho
echo "=== Verificação Waydroid ==="
grep -q binder /proc/filesystems && echo "OK: binder disponível" || echo "FALTA: binder ausente"
command -v waydroid >/dev/null && echo "OK: waydroid instalado" || echo "FALTA: waydroid não instalado"
[ -d /var/lib/waydroid ] && echo "OK: dados waydroid presentes" || echo "INFO: dados waydroid ausentes"
systemctl is-active waydroid-container >/dev/null 2>&1 && echo "OK: container ativo" || echo "INFO: container inativo"
echo "=== Fim ==="