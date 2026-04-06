#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
#  NordGpT — Server Setup Script
#  Çalıştır: bash server-setup.sh
#  Desteklenen: Ubuntu 20.04+ / Debian 11+ / RHEL 8+ / Fedora 37+
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

REPO="https://github.com/davudows/NordGpT.git"
INSTALL_DIR="/opt/nordgpt"
SERVICE_USER="nordgpt"
PORT="${NORDGPT_PORT:-7860}"

R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m' C='\033[0;36m' W='\033[1;37m' NC='\033[0m' DIM='\033[2m'

info()  { echo -e "  ${G}✔${NC}  $*"; }
warn()  { echo -e "  ${Y}⚠${NC}  $*"; }
error() { echo -e "  ${R}✖${NC}  $*"; exit 1; }
step()  { echo -e "\n  ${C}▶${NC}  ${W}$*${NC}"; }

banner() {
cat << 'EOF'

  NordGpT — Server Setup
  ═══════════════════════

EOF
}

# ── OS Detection ───────────────────────────────────────────────────────────────
detect_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS_ID="$ID"
    OS_VER="${VERSION_ID:-0}"
  else
    error "Desteklenmeyen işletim sistemi"
  fi

  case "$OS_ID" in
    ubuntu|debian|linuxmint|pop) PKG="apt"    ;;
    fedora)                       PKG="dnf"    ;;
    rhel|centos|rocky|almalinux)  PKG="dnf"    ;;
    arch|manjaro)                 PKG="pacman" ;;
    *)                            PKG="apt"; warn "Bilinmeyen distro: $OS_ID, apt varsayıldı" ;;
  esac

  info "OS: $OS_ID $OS_VER | Paket yöneticisi: $PKG"
}

# ── System Dependencies ────────────────────────────────────────────────────────
install_deps() {
  step "Sistem bağımlılıkları kuruluyor..."
  case "$PKG" in
    apt)
      export DEBIAN_FRONTEND=noninteractive
      sudo apt-get update -qq
      sudo apt-get install -y -qq \
        python3 python3-pip python3-venv \
        git curl wget build-essential \
        ufw lsof
      ;;
    dnf)
      sudo dnf install -y \
        python3 python3-pip git curl wget \
        gcc ufw lsof
      ;;
    pacman)
      sudo pacman -Sy --noconfirm python python-pip git curl wget ufw
      ;;
  esac

  # Python version check
  PY_VER=$(python3 --version 2>&1 | grep -oP '\d+\.\d+' | head -1)
  MAJOR=$(echo "$PY_VER" | cut -d. -f1)
  MINOR=$(echo "$PY_VER" | cut -d. -f2)
  if (( MAJOR < 3 || (MAJOR == 3 && MINOR < 10) )); then
    warn "Python $PY_VER bulundu. Python 3.10+ önerilir, kuruluyor..."
    case "$PKG" in
      apt)
        sudo apt-get install -y software-properties-common
        sudo add-apt-repository -y ppa:deadsnakes/ppa
        sudo apt-get update -qq
        sudo apt-get install -y python3.11 python3.11-venv python3.11-distutils
        PYTHON_BIN="python3.11"
        ;;
      *) PYTHON_BIN="python3" ;;
    esac
  else
    PYTHON_BIN="python3"
  fi

  info "Python: $(${PYTHON_BIN} --version)"
}

# ── Ollama ─────────────────────────────────────────────────────────────────────
install_ollama() {
  step "Ollama kuruluyor..."
  if command -v ollama &>/dev/null; then
    info "Ollama zaten kurulu: $(ollama --version 2>/dev/null | head -1)"
    return 0
  fi
  curl -fsSL https://ollama.com/install.sh | sh
  info "Ollama kuruldu"
}

setup_ollama_service() {
  step "Ollama servisi yapılandırılıyor..."

  # Ollama servisini sadece localhost'a bağla (güvenlik)
  if [[ -d /etc/systemd/system ]]; then
    sudo mkdir -p /etc/systemd/system/ollama.service.d
    sudo tee /etc/systemd/system/ollama.service.d/override.conf > /dev/null <<EOF
[Service]
Environment="OLLAMA_HOST=127.0.0.1:11434"
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable --now ollama
    info "Ollama systemd servisi aktif (sadece localhost)"
  else
    nohup ollama serve >/var/log/ollama.log 2>&1 &
    info "Ollama arka planda başlatıldı"
  fi

  # Hazır olmasını bekle
  echo -n "  ⏳ Bekleniyor"
  for i in {1..20}; do
    sleep 1; echo -n "."
    curl -sf http://127.0.0.1:11434/api/tags &>/dev/null && { echo ""; info "Ollama hazır"; return 0; }
  done
  echo ""
  warn "Ollama henüz hazır değil, devam ediliyor..."
}

# ── Service User ───────────────────────────────────────────────────────────────
create_service_user() {
  step "Servis kullanıcısı oluşturuluyor: $SERVICE_USER"
  if id "$SERVICE_USER" &>/dev/null; then
    info "Kullanıcı zaten mevcut: $SERVICE_USER"
    return 0
  fi
  sudo useradd --system --shell /bin/false --home "$INSTALL_DIR" \
    --create-home --comment "NordGpT Service" "$SERVICE_USER"
  info "Kullanıcı oluşturuldu: $SERVICE_USER"
}

# ── Clone / Update Repo ────────────────────────────────────────────────────────
deploy_app() {
  step "Uygulama deploy ediliyor: $INSTALL_DIR"

  if [[ -d "$INSTALL_DIR/.git" ]]; then
    info "Mevcut kurulum güncelleniyor..."
    sudo -u "$SERVICE_USER" git -C "$INSTALL_DIR" pull --rebase
  else
    sudo git clone "$REPO" "$INSTALL_DIR"
    sudo chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
  fi

  # Executable
  sudo chmod +x "$INSTALL_DIR/nordgpt.sh"

  # Python venv
  sudo -u "$SERVICE_USER" ${PYTHON_BIN:-python3} -m venv "$INSTALL_DIR/.venv"
  sudo -u "$SERVICE_USER" "$INSTALL_DIR/.venv/bin/pip" install --quiet --upgrade pip
  sudo -u "$SERVICE_USER" "$INSTALL_DIR/.venv/bin/pip" install --quiet -r "$INSTALL_DIR/requirements.txt"

  # Data directories
  sudo -u "$SERVICE_USER" mkdir -p "$INSTALL_DIR/data/chats"

  info "Uygulama hazır: $INSTALL_DIR"
}

# ── Systemd Service ────────────────────────────────────────────────────────────
install_service() {
  step "Systemd servisi kuruluyor..."

  sudo tee /etc/systemd/system/nordgpt.service > /dev/null <<EOF
[Unit]
Description=NordGpT Local AI Chat Interface
Documentation=https://github.com/davudows/NordGpT
After=network.target ollama.service
Wants=ollama.service

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_USER}
WorkingDirectory=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/.venv/bin/python -m uvicorn app:app \\
    --host 0.0.0.0 \\
    --port ${PORT} \\
    --log-level warning \\
    --no-access-log
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=nordgpt

# Security hardening
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ReadWritePaths=${INSTALL_DIR}/data
ProtectHome=yes

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable nordgpt
  info "Servis kuruldu: nordgpt.service"
}

# ── Firewall ───────────────────────────────────────────────────────────────────
setup_firewall() {
  step "Firewall yapılandırılıyor (ufw)..."

  if ! command -v ufw &>/dev/null; then
    warn "ufw bulunamadı, firewall atlanıyor"
    return 0
  fi

  sudo ufw --force enable 2>/dev/null || true
  sudo ufw allow ssh          # SSH kaybetme!
  sudo ufw allow "${PORT}/tcp" comment "NordGpT"
  sudo ufw status verbose

  info "Port $PORT açıldı"
}

# ── Run Wizard ─────────────────────────────────────────────────────────────────
run_nordgpt_wizard() {
  step "NordGpT kurulum sihirbazı başlatılıyor..."
  echo -e "  ${DIM}Admin hesabı ve model seçimi için wizard çalışacak.${NC}"
  echo -e "  ${DIM}Sihirbazı tamamladıktan sonra servis başlatılacak.${NC}"
  echo ""
  cd "$INSTALL_DIR"
  sudo -u "$SERVICE_USER" bash nordgpt.sh reset 2>/dev/null || true
  # Run just the wizard parts (model + admin) without starting the server
  sudo -u "$SERVICE_USER" bash -c "
    source '$INSTALL_DIR/.venv/bin/activate'
    cd '$INSTALL_DIR'
    bash nordgpt.sh reset
  " || warn "Wizard tamamlanamadı, web arayüzünden devam edin"
}

# ── Start ──────────────────────────────────────────────────────────────────────
start_service() {
  step "NordGpT servisi başlatılıyor..."
  sudo systemctl start nordgpt
  sleep 2

  if sudo systemctl is-active --quiet nordgpt; then
    info "NordGpT çalışıyor"
  else
    warn "Servis başlamadı, logları kontrol edin:"
    echo "  sudo journalctl -u nordgpt -n 30 --no-pager"
  fi
}

# ── Summary ────────────────────────────────────────────────────────────────────
print_summary() {
  SERVER_IP=$(hostname -I | awk '{print $1}')
  echo ""
  echo -e "  ${G}╔══════════════════════════════════════════════╗${NC}"
  echo -e "  ${G}║  🚀 NordGpT Kurulumu Tamamlandı!             ║${NC}"
  echo -e "  ${G}║                                              ║${NC}"
  echo -e "  ${G}║  ${W}http://${SERVER_IP}:${PORT}${G}                 ║${NC}"
  echo -e "  ${G}║                                              ║${NC}"
  echo -e "  ${G}║  Yararlı komutlar:                           ║${NC}"
  echo -e "  ${G}║  ${DIM}sudo systemctl status nordgpt${G}              ║${NC}"
  echo -e "  ${G}║  ${DIM}sudo journalctl -u nordgpt -f${G}              ║${NC}"
  echo -e "  ${G}║  ${DIM}sudo systemctl restart nordgpt${G}             ║${NC}"
  echo -e "  ${G}╚══════════════════════════════════════════════╝${NC}"
  echo ""
}

# ── Main ───────────────────────────────────────────────────────────────────────
main() {
  # Root check
  if [[ "$EUID" -ne 0 ]] && ! sudo -n true 2>/dev/null; then
    error "Bu script sudo yetkisi gerektirir. 'sudo bash server-setup.sh' ile çalıştırın."
  fi

  banner
  detect_os
  install_deps
  install_ollama
  setup_ollama_service
  create_service_user
  deploy_app
  install_service
  setup_firewall

  echo ""
  echo -e "  ${Y}Şimdi admin hesabı ve ilk model kurulumu yapılacak.${NC}"
  echo -e "  ${Y}NordGpT setup wizard'ı başlatılıyor...${NC}"
  echo ""

  # Wizard'ı servis kullanıcısı olarak interaktif çalıştır
  cd "$INSTALL_DIR"
  sudo -u "$SERVICE_USER" bash nordgpt.sh

  start_service
  print_summary
}

main "$@"
