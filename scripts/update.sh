#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
#  NordGpT — Güncelleme Scripti
#  Kullanım: sudo bash update.sh
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

INSTALL_DIR="/opt/nordgpt"
SERVICE_USER="nordgpt"

G='\033[0;32m' Y='\033[1;33m' C='\033[0;36m' W='\033[1;37m' NC='\033[0m'

info() { echo -e "  ${G}✔${NC}  $*"; }
step() { echo -e "\n  ${C}▶${NC}  ${W}$*${NC}"; }

step "NordGpT güncelleniyor..."

# Git pull
step "Kod güncelleniyor..."
sudo -u "$SERVICE_USER" git -C "$INSTALL_DIR" pull --rebase
info "Kod güncellendi"

# pip update
step "Python bağımlılıkları güncelleniyor..."
sudo -u "$SERVICE_USER" "$INSTALL_DIR/.venv/bin/pip" install --quiet -r "$INSTALL_DIR/requirements.txt"
info "Bağımlılıklar güncellendi"

# Restart
step "Servis yeniden başlatılıyor..."
sudo systemctl restart nordgpt
sleep 2

if sudo systemctl is-active --quiet nordgpt; then
  info "NordGpT yeniden başlatıldı ✓"
  echo ""
  echo -e "  ${G}Güncelleme tamamlandı.${NC}"
else
  echo -e "  ${Y}Servis başlamadı:${NC}"
  sudo journalctl -u nordgpt -n 20 --no-pager
fi
