#!/bin/bash
# Aplica locale/timezone pt_BR ao greeter do plasmalogin (requer root)
set -e
if [ "$(id -u)" -ne 0 ]; then
    echo "Rode com sudo: sudo bash $0"
    exit 1
fi
mkdir -p /var/lib/plasmalogin/.config
cat > /var/lib/plasmalogin/.config/plasma-localerc <<'EOF'
[Formats]
LANG=pt_BR.UTF-8
LC_TIME=pt_BR.UTF-8
EOF
chown -R plasmalogin:plasmalogin /var/lib/plasmalogin/.config
systemctl restart plasmalogin
echo "Locale do greeter aplicado (pt_BR)."
