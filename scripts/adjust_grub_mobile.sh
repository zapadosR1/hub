#!/bin/bash
# Ajusta GRUB para lembrar a última entrada e dar timeout confortável (requer root)
set -u
if [ "$(id -u)" -ne 0 ]; then
    echo "Rode com sudo: sudo bash $0"
    exit 1
fi

cat > /etc/default/grub <<'EOF'
# Gerado por adjust_grub_mobile.sh
GRUB_TIMEOUT=30
GRUB_TIMEOUT_STYLE=menu
GRUB_RECORDFAIL_TIMEOUT=30
GRUB_DEFAULT=saved
GRUB_SAVEDEFAULT=true
GRUB_DISABLE_SUBMENU=true
GRUB_ENABLE_BLSCFG=true
GRUB_DISABLE_OS_PROBER=true
EOF

BK="/boot/grub2/grub.cfg.bak-$(date +%Y%m%d-%H%M%S)"
if ! cp -a /boot/grub2/grub.cfg "$BK" 2>/dev/null; then
    echo "Não foi possível criar backup do grub.cfg; abortando."
    exit 1
fi

GRUB_TMP="$(mktemp /tmp/grub.cfg.XXXXXX)"
GRUB_ERR="$(mktemp /tmp/grub.err.XXXXXX)"
GRUB_OK=0
if grub2-mkconfig -o "$GRUB_TMP" >/dev/null 2>"$GRUB_ERR" && \
   grub2-script-check "$GRUB_TMP" >/dev/null 2>&1; then
    cat "$GRUB_TMP" > /boot/grub2/grub.cfg && GRUB_OK=1
fi

if [ "$GRUB_OK" -ne 1 ]; then
    echo "Falha ao regenerar grub.cfg; restaurando backup."
    cat "$BK" > /boot/grub2/grub.cfg
    [ -s "$GRUB_ERR" ] && sed -n '1,8p' "$GRUB_ERR"
    rm -f "$GRUB_TMP" "$GRUB_ERR"
    exit 1
fi

rm -f "$GRUB_TMP" "$GRUB_ERR"
echo "GRUB ajustado: timeout=30s, GRUB_DEFAULT=saved, GRUB_SAVEDEFAULT=true."
echo "Backup: $BK"