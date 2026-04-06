#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
#  NordGpT — Local AI Chat Interface Launcher
#  Supports: macOS · Ubuntu · Debian · Arch · Fedora
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/.nordgpt.conf"
VENV_DIR="$SCRIPT_DIR/.venv"
PORT="${NORDGPT_PORT:-7860}"
OLLAMA_URL="http://localhost:11434"

# ── Colors ─────────────────────────────────────────────────────────────────────
R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m' B='\033[0;34m'
C='\033[0;36m' W='\033[1;37m' DIM='\033[2m' NC='\033[0m'

banner() {
cat << 'EOF'

  ███╗   ██╗ ██████╗ ██████╗ ██████╗  ██████╗ ██████╗ ████████╗
  ████╗  ██║██╔═══██╗██╔══██╗██╔══██╗██╔════╝ ██╔══██╗╚══██╔══╝
  ██╔██╗ ██║██║   ██║██████╔╝██║  ██║██║  ███╗██████╔╝   ██║
  ██║╚██╗██║██║   ██║██╔══██╗██║  ██║██║   ██║██╔═══╝    ██║
  ██║ ╚████║╚██████╔╝██║  ██║██████╔╝╚██████╔╝██║        ██║
  ╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝╚═════╝  ╚═════╝ ╚═╝        ╚═╝

EOF
  echo -e "  ${C}Yerel AI Chat Arayüzü${NC}  ${DIM}|${NC}  ${DIM}Gizlilik önce gelir — internet gerekmez${NC}"
  echo ""
}

info()   { echo -e "  ${G}✔${NC}  $*"; }
warn()   { echo -e "  ${Y}⚠${NC}  $*"; }
error()  { echo -e "  ${R}✖${NC}  $*"; }
step()   { echo -e "\n  ${B}▶${NC}  ${W}$*${NC}"; }
prompt() { echo -en "\n  ${C}?${NC}  $*  "; }
divider(){ echo -e "  ${DIM}────────────────────────────────────────────${NC}"; }

# ── OS Detection ───────────────────────────────────────────────────────────────
detect_os() {
  OS="" ; PKG=""
  if [[ "$OSTYPE" == darwin* ]]; then
    OS="macos"; PKG="brew"
  elif [[ -f /etc/os-release ]]; then
    . /etc/os-release
    case "$ID" in
      ubuntu|debian|linuxmint|pop)  OS="debian"; PKG="apt"    ;;
      arch|manjaro|endeavouros)      OS="arch";   PKG="pacman" ;;
      fedora|rhel|centos|rocky)      OS="fedora"; PKG="dnf"    ;;
      *)                             OS="unknown"               ;;
    esac
  else
    OS="unknown"
  fi
}

# ── Hardware Detection ─────────────────────────────────────────────────────────
detect_hardware() {
  RAM_GB=0; CPU_CORES=0; GPU_VRAM_GB=0; GPU_NAME="Yok"; HW_TIER="low"

  CPU_CORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

  if [[ "$OS" == "macos" ]]; then
    RAM_BYTES=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
    RAM_GB=$(( RAM_BYTES / 1024 / 1024 / 1024 ))
  elif [[ -f /proc/meminfo ]]; then
    RAM_KB=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    RAM_GB=$(( RAM_KB / 1024 / 1024 ))
  fi

  if command -v nvidia-smi &>/dev/null; then
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || echo "")
    GPU_MEM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 || echo "0")
    GPU_VRAM_GB=$(( ${GPU_MEM:-0} / 1024 ))
  elif command -v rocm-smi &>/dev/null; then
    GPU_NAME="AMD GPU (ROCm)"
  fi

  if [[ "$OS" == "macos" ]] && system_profiler SPDisplaysDataType 2>/dev/null | grep -q "Apple M"; then
    GPU_NAME="Apple Silicon (Unified Memory)"
    GPU_VRAM_GB=$RAM_GB
  fi

  EFFECTIVE=$(( GPU_VRAM_GB > 0 ? GPU_VRAM_GB : RAM_GB ))
  if   (( EFFECTIVE >= 32 )); then HW_TIER="high"
  elif (( EFFECTIVE >= 16 )); then HW_TIER="medium"
  else                              HW_TIER="low"
  fi
}

print_hardware() {
  echo ""
  echo -e "  ${W}── Donanım ──────────────────────────────────${NC}"
  printf "  ${DIM}%-8s${NC} %s GB\n"   "RAM:"  "$RAM_GB"
  printf "  ${DIM}%-8s${NC} %s çekirdek\n" "CPU:"  "$CPU_CORES"
  printf "  ${DIM}%-8s${NC} %s\n"      "GPU:"  "$GPU_NAME"
  [[ $GPU_VRAM_GB -gt 0 ]] && printf "  ${DIM}%-8s${NC} %s GB\n" "VRAM:" "$GPU_VRAM_GB"
  case "$HW_TIER" in
    high)   echo -e "  ${DIM}Seviye:${NC} ${G}🔥 Yüksek${NC}  — 70B+ modeller çalışabilir" ;;
    medium) echo -e "  ${DIM}Seviye:${NC} ${Y}⚡ Orta${NC}   — 7-13B modeller önerilir" ;;
    low)    echo -e "  ${DIM}Seviye:${NC} ${R}🌱 Düşük${NC}  — Mini modeller gerekli" ;;
  esac
  divider
}

# ── Existing Installation Check ────────────────────────────────────────────────
check_existing() {
  OLLAMA_INSTALLED=false
  OLLAMA_RUNNING=false
  INSTALLED_MODELS=()
  NORDGPT_CONFIGURED=false
  PREV_LANGUAGE="tr"
  PREV_CATEGORY="general"
  PREV_MODEL=""
  PREV_TIER="low"

  command -v ollama &>/dev/null && OLLAMA_INSTALLED=true

  if $OLLAMA_INSTALLED; then
    if curl -sf --max-time 3 "$OLLAMA_URL/api/tags" &>/dev/null; then
      OLLAMA_RUNNING=true
      while IFS= read -r line; do
        [[ "$line" =~ ^NAME ]] && continue
        [[ -z "$line" ]] && continue
        m=$(awk '{print $1}' <<< "$line")
        [[ -n "$m" ]] && INSTALLED_MODELS+=("$m")
      done < <(ollama list 2>/dev/null || true)
    fi
  fi

  if [[ -f "$CONFIG_FILE" ]]; then
    NORDGPT_CONFIGURED=true
    while IFS='=' read -r key val; do
      [[ "$key" =~ ^#  ]] && continue
      [[ -z "$key"     ]] && continue
      val="${val//\"/}"
      case "$key" in
        LANGUAGE)      PREV_LANGUAGE="$val"  ;;
        CATEGORY)      PREV_CATEGORY="$val"  ;;
        DEFAULT_MODEL) PREV_MODEL="$val"     ;;
        HW_TIER)       PREV_TIER="$val"      ;;
      esac
    done < "$CONFIG_FILE"
  fi
}

print_status() {
  echo ""
  echo -e "  ${W}── Mevcut Kurulum Durumu ────────────────────${NC}"

  # Ollama
  if $OLLAMA_INSTALLED; then
    local ver; ver=$(ollama --version 2>/dev/null | head -1 | tr -d '\n') || ver="?"
    echo -e "  ${G}✔${NC}  Ollama kurulu  ${DIM}($ver)${NC}"
  else
    echo -e "  ${R}✗${NC}  Ollama kurulu değil — kurulacak"
  fi

  # Running
  if $OLLAMA_RUNNING; then
    echo -e "  ${G}✔${NC}  Ollama servisi çalışıyor"
  else
    if $OLLAMA_INSTALLED; then
      echo -e "  ${Y}⚠${NC}  Ollama çalışmıyor — başlatılacak"
    fi
  fi

  # Models
  if [[ ${#INSTALLED_MODELS[@]} -gt 0 ]]; then
    echo -e "  ${G}✔${NC}  ${#INSTALLED_MODELS[@]} yüklü model:"
    for m in "${INSTALLED_MODELS[@]}"; do
      echo -e "       ${DIM}• $m${NC}"
    done
  else
    echo -e "  ${Y}⚠${NC}  Yüklü model bulunamadı"
  fi

  # NordGpT config
  if $NORDGPT_CONFIGURED; then
    echo -e "  ${G}✔${NC}  NordGpT yapılandırması mevcut:"
    echo -e "       ${DIM}• Dil: $PREV_LANGUAGE  |  Sektör: $PREV_CATEGORY  |  Model: $PREV_MODEL${NC}"
  else
    echo -e "  ${Y}⚠${NC}  NordGpT yapılandırması yok"
  fi

  divider
}

# ── Language Selection ─────────────────────────────────────────────────────────
select_language() {
  echo ""
  echo -e "  ${W}Arayüz dilini seçin / Select interface language:${NC}"
  echo ""
  echo -e "  ${C}[1]${NC} 🇹🇷 Türkçe       ${DIM}← varsayılan / default${NC}"
  echo -e "  ${C}[2]${NC} 🇬🇧 English"
  echo -e "  ${C}[3]${NC} 🇩🇪 Deutsch"
  echo -e "  ${C}[4]${NC} 🇫🇷 Français"
  echo -e "  ${C}[5]${NC} 🇪🇸 Español"
  echo -e "  ${C}[6]${NC} 🇸🇦 العربية"
  echo -e "  ${C}[7]${NC} 🇨🇳 中文"
  echo ""
  prompt "Seçim [1-7, Enter=Türkçe]:"
  read -r choice

  case "${choice:-1}" in
    1|"") LANGUAGE="tr"; LANG_NAME="Türkçe"   ;;
    2)    LANGUAGE="en"; LANG_NAME="English"   ;;
    3)    LANGUAGE="de"; LANG_NAME="Deutsch"   ;;
    4)    LANGUAGE="fr"; LANG_NAME="Français"  ;;
    5)    LANGUAGE="es"; LANG_NAME="Español"   ;;
    6)    LANGUAGE="ar"; LANG_NAME="العربية"  ;;
    7)    LANGUAGE="zh"; LANG_NAME="中文"      ;;
    *)    LANGUAGE="tr"; LANG_NAME="Türkçe"; warn "Geçersiz seçim → Türkçe seçildi" ;;
  esac
  info "Dil / Language: ${W}$LANG_NAME${NC}"
}

# ── Sector Selection ───────────────────────────────────────────────────────────
select_category() {
  echo ""
  echo -e "  ${W}Hangi alanda kullanacaksınız?${NC}"
  echo ""
  echo -e "  ${C}[1]${NC} 🔐 Siber Güvenlik   — Pentest, CTF, zafiyet analizi"
  echo -e "  ${C}[2]${NC} 📈 Finans & Ekonomi  — Piyasa analizi, trading"
  echo -e "  ${C}[3]${NC} 💻 Yazılım Geliştirme — Kod, debug, mimari"
  echo -e "  ${C}[4]${NC} 🤖 Genel Kullanım    — Her türlü soru"
  echo -e "  ${C}[5]${NC} ✍️  Yaratıcı Yazarlık  — Hikaye, şiir, içerik"
  echo -e "  ${C}[6]${NC} 📊 Veri Bilimi & AI   — ML, analiz, istatistik"
  echo -e "  ${C}[0]${NC} ⏭️  Şimdi atla         — Web arayüzünden seçerim"
  echo ""
  prompt "Seçim [0-6, Enter=Genel]:"
  read -r choice

  case "${choice:-4}" in
    1) CATEGORY="cybersecurity"; CAT_NAME="Siber Güvenlik"    ;;
    2) CATEGORY="finance";       CAT_NAME="Finans & Ekonomi"  ;;
    3) CATEGORY="coding";        CAT_NAME="Yazılım Geliştirme";;
    4|"") CATEGORY="general";   CAT_NAME="Genel Kullanım"    ;;
    5) CATEGORY="creative";      CAT_NAME="Yaratıcı Yazarlık" ;;
    6) CATEGORY="data_science";  CAT_NAME="Veri Bilimi & AI"  ;;
    0) CATEGORY="general";       CAT_NAME="Genel (sonra seç)" ;;
    *) CATEGORY="general";       CAT_NAME="Genel Kullanım"; warn "Geçersiz seçim → Genel seçildi" ;;
  esac
  info "Sektör: ${W}$CAT_NAME${NC}"
}

# ── Language-aware model filter ────────────────────────────────────────────────
# Returns exit 0 if model is good for the given language, 1 if poor
lang_score() {
  local model="$1"
  local lang="$2"
  local base="${model%%:*}"  # strip tag (e.g. llama3.1)

  case "$lang" in
    tr|ar)
      # Turkish & Arabic: Qwen, Llama3, Mistral, Mixtral work well
      # Avoid: phi, tinyllama, gemma, starcoder, codellama (limited multilingual)
      [[ "$base" =~ ^(qwen|llama3|mistral|mixtral|aya|command|nous) ]] && return 0
      [[ "$base" =~ ^(phi|tinyllama|gemma|starcoder|codellama|deepseek-coder|starcoder2) ]] && return 1
      return 0
      ;;
    zh)
      # Chinese: Qwen is best, Llama3 decent
      [[ "$base" =~ ^(qwen|llama3|yi|baichuan) ]] && return 0
      return 1
      ;;
    de|fr|es)
      # European: most modern models work, avoid tiny/code-only
      [[ "$base" =~ ^(tinyllama|starcoder|codellama|starcoder2) ]] && return 1
      return 0
      ;;
    *)
      return 0
      ;;
  esac
}

# ── Model Lists (per category × tier) ─────────────────────────────────────────
get_model_list() {
  local cat="$1" tier="$2"
  case "${cat}:${tier}" in
    cybersecurity:high)   echo "llama3.1:70b mixtral:8x7b deepseek-coder:33b qwen2.5:72b" ;;
    cybersecurity:medium) echo "llama3.1:8b mistral:7b qwen2.5:7b codellama:13b"          ;;
    cybersecurity:low)    echo "phi3:mini deepseek-coder:1.3b qwen2.5:0.5b tinyllama"      ;;
    finance:high)         echo "llama3.1:70b mixtral:8x7b qwen2.5:72b"                    ;;
    finance:medium)       echo "llama3.1:8b qwen2.5:7b mistral:7b"                        ;;
    finance:low)          echo "phi3:mini qwen2.5:0.5b gemma2:2b"                         ;;
    coding:high)          echo "deepseek-coder-v2:16b codellama:34b starcoder2:15b llama3.1:70b" ;;
    coding:medium)        echo "codellama:13b deepseek-coder:6.7b qwen2.5:7b starcoder2:7b" ;;
    coding:low)           echo "deepseek-coder:1.3b phi3:mini qwen2.5:0.5b"               ;;
    creative:high)        echo "llama3.1:70b mixtral:8x7b qwen2.5:72b"                    ;;
    creative:medium)      echo "llama3.1:8b mistral:7b qwen2.5:7b"                        ;;
    creative:low)         echo "phi3:mini gemma2:2b qwen2.5:0.5b"                         ;;
    data_science:high)    echo "llama3.1:70b deepseek-coder-v2:16b qwen2.5:72b"           ;;
    data_science:medium)  echo "llama3.1:8b codellama:13b qwen2.5:7b"                     ;;
    data_science:low)     echo "phi3:mini deepseek-coder:1.3b qwen2.5:0.5b"               ;;
    *:high)               echo "llama3.1:70b mixtral:8x7b qwen2.5:72b llama3.2:90b"       ;;
    *:medium)             echo "llama3.1:8b qwen2.5:7b mistral:7b llama3.2:3b"            ;;
    *:low)                echo "phi3:mini qwen2.5:0.5b gemma2:2b tinyllama"               ;;
  esac
}

# ── Model Selection ────────────────────────────────────────────────────────────
select_model() {
  echo ""
  echo -e "  ${W}── Model Seçimi ──────────────────────────────${NC}"

  local raw_list; raw_list=$(get_model_list "$CATEGORY" "$HW_TIER")
  local -a ALL_MODELS=()
  local -a RECOMMENDED=()    # language-compatible
  local -a NOT_RECOMMENDED=()# language issues

  for m in $raw_list; do
    ALL_MODELS+=("$m")
    if lang_score "$m" "$LANGUAGE"; then
      RECOMMENDED+=("$m")
    else
      NOT_RECOMMENDED+=("$m")
    fi
  done

  # If no lang-recommended, fall back to all
  [[ ${#RECOMMENDED[@]} -eq 0 ]] && RECOMMENDED=("${ALL_MODELS[@]}")

  # ── Show already installed models first ────────────────────────────────────
  local -a ALREADY_INST_SHOW=()
  if [[ ${#INSTALLED_MODELS[@]} -gt 0 ]]; then
    echo -e "\n  ${G}Sunucuda zaten yüklü modeller:${NC}"
    for m in "${INSTALLED_MODELS[@]}"; do
      local lang_ok=""
      lang_score "$m" "$LANGUAGE" && lang_ok=" ${G}[${LANGUAGE} ✓]${NC}" || lang_ok=" ${Y}[${LANGUAGE} ±]${NC}"
      echo -e "    ${G}✔${NC} $m$lang_ok"
      ALREADY_INST_SHOW+=("$m")
    done
  fi

  # ── Show recommended models ────────────────────────────────────────────────
  echo ""
  echo -e "  ${W}Önerilen modeller${NC} ${DIM}(donanım: $HW_TIER | dil: $LANGUAGE):${NC}"
  echo ""

  local -a DISPLAY_LIST=()
  local idx=1

  # First: recommended (lang-compatible) not yet installed
  for m in "${RECOMMENDED[@]}"; do
    local already=""
    for im in "${INSTALLED_MODELS[@]}"; do
      [[ "$im" == "$m"* || "$m" == "$im"* ]] && already="installed" && break
    done
    if [[ "$already" == "installed" ]]; then
      echo -e "  ${C}[$idx]${NC} $m  ${G}← zaten yüklü${NC}"
    else
      echo -e "  ${C}[$idx]${NC} $m  ${G}[${LANGUAGE} ✓]${NC}"
    fi
    DISPLAY_LIST+=("$m")
    ((idx++))
  done

  # Then: not-recommended with warning (only if few options)
  if [[ ${#RECOMMENDED[@]} -lt 2 && ${#NOT_RECOMMENDED[@]} -gt 0 ]]; then
    for m in "${NOT_RECOMMENDED[@]}"; do
      echo -e "  ${C}[$idx]${NC} $m  ${Y}[${LANGUAGE} ±]${NC}"
      DISPLAY_LIST+=("$m")
      ((idx++))
    done
  fi

  # Already installed not in list
  for im in "${INSTALLED_MODELS[@]}"; do
    local found=false
    for dm in "${DISPLAY_LIST[@]}"; do
      [[ "$dm" == "$im" ]] && found=true && break
    done
    if ! $found; then
      echo -e "  ${C}[$idx]${NC} $im  ${G}← yüklü${NC}"
      DISPLAY_LIST+=("$im")
      ((idx++))
    fi
  done

  echo -e "  ${C}[0]${NC} Manuel gir"
  echo ""
  prompt "Seçim [1-$((idx-1)) | 0=manuel | Enter=1]:"
  read -r choice

  local chosen="${choice:-1}"
  if [[ "$chosen" == "0" ]]; then
    prompt "Model adını girin (örn: llama3.1:8b):"
    read -r SELECTED_MODEL
    [[ -z "$SELECTED_MODEL" ]] && SELECTED_MODEL="${DISPLAY_LIST[0]}"
  elif [[ "$chosen" =~ ^[0-9]+$ ]] && (( chosen >= 1 && chosen < idx )); then
    SELECTED_MODEL="${DISPLAY_LIST[$((chosen-1))]}"
  else
    warn "Geçersiz seçim, ilk öneri seçildi"
    SELECTED_MODEL="${DISPLAY_LIST[0]}"
  fi

  # Language warning
  if ! lang_score "$SELECTED_MODEL" "$LANGUAGE"; then
    echo ""
    warn "${Y}$SELECTED_MODEL${NC} modeli ${W}$LANGUAGE${NC} dili için ${Y}sınırlı${NC} destek sunuyor."
    warn "Daha iyi Türkçe için ${G}qwen2.5:7b${NC} veya ${G}llama3.1:8b${NC} öneririz."
    prompt "Yine de devam et? [E/h]:"
    read -r confirm
    [[ "${confirm,,}" == "h" ]] && select_model && return
  fi

  info "Seçilen model: ${W}$SELECTED_MODEL${NC}"
}

# ── Download Model ─────────────────────────────────────────────────────────────
pull_selected_model() {
  # Check if already installed
  local already=false
  for im in "${INSTALLED_MODELS[@]}"; do
    [[ "$im" == "$SELECTED_MODEL"* || "$SELECTED_MODEL" == "$im"* ]] && already=true && break
  done

  if $already; then
    info "Model zaten yüklü, indirme atlanıyor: ${W}$SELECTED_MODEL${NC}"
    return 0
  fi

  echo ""
  echo -e "  ${Y}▼ Model indiriliyor: ${W}$SELECTED_MODEL${NC}"
  echo -e "  ${DIM}  İnternet bağlantısı gerekli. Boyuta göre birkaç dakika sürebilir.${NC}"
  echo ""
  ollama pull "$SELECTED_MODEL"
  info "Model indirildi: ${W}$SELECTED_MODEL${NC}"
}

# ── Save Config ────────────────────────────────────────────────────────────────
save_config() {
  cat > "$CONFIG_FILE" <<EOF
# NordGpT Configuration — $(date -u +%Y-%m-%dT%H:%M:%SZ)
LANGUAGE=$LANGUAGE
CATEGORY=$CATEGORY
DEFAULT_MODEL=$SELECTED_MODEL
HW_TIER=$HW_TIER
CONFIGURED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
  info "Yapılandırma kaydedildi: ${DIM}.nordgpt.conf${NC}"
}

# ── Full Setup Wizard ──────────────────────────────────────────────────────────
# ── Admin Account Setup ────────────────────────────────────────────────────────
setup_admin_account() {
  local users_file="$SCRIPT_DIR/data/users.json"

  # Skip if admin already exists
  if [[ -f "$users_file" ]] && python3 -c "
import json, sys
users = json.load(open('$users_file'))
sys.exit(0 if any(u.get('role')=='admin' for u in users) else 1)
" 2>/dev/null; then
    info "Admin hesabı zaten mevcut"
    return 0
  fi

  echo ""
  echo -e "  ${W}── Admin Hesabı Oluştur ──────────────────────${NC}"
  echo -e "  ${DIM}  Sisteme sadece admin yeni kullanıcı ekleyebilir.${NC}"
  echo ""

  # Username
  prompt "Admin kullanıcı adı [admin]:"
  read -r adm_user
  adm_user="${adm_user:-admin}"

  # Validate username: alphanumeric + underscore, 3-32 chars
  if ! [[ "$adm_user" =~ ^[a-zA-Z0-9_]{3,32}$ ]]; then
    warn "Geçersiz kullanıcı adı (3-32 karakter, harf/rakam/_ kullanın)"
    setup_admin_account; return
  fi

  # Password (hidden input)
  echo -en "\n  ${C}?${NC}  Admin şifresi (min 8 karakter):  "
  read -rs adm_pass; echo ""

  if [[ ${#adm_pass} -lt 8 ]]; then
    warn "Şifre en az 8 karakter olmalı"
    setup_admin_account; return
  fi
  if [[ ${#adm_pass} -gt 128 ]]; then
    warn "Şifre çok uzun (max 128 karakter)"
    setup_admin_account; return
  fi

  echo -en "\n  ${C}?${NC}  Şifre tekrar:  "
  read -rs adm_pass2; echo ""

  if [[ "$adm_pass" != "$adm_pass2" ]]; then
    warn "Şifreler eşleşmiyor, tekrar deneyin"
    setup_admin_account; return
  fi

  # Python scriptini temp dosyaya yaz (heredoc + pipe çakışmasını önler)
  local tmpscript; tmpscript=$(mktemp /tmp/nordgpt_admin_XXXXXX.py)
  chmod 600 "$tmpscript"
  cat > "$tmpscript" << 'PYEOF'
import sys, json
from pathlib import Path
from datetime import datetime
from passlib.context import CryptContext

lines = sys.stdin.read().splitlines()
if len(lines) < 2:
    print("ERROR:yetersiz_girdi")
    sys.exit(1)
username = lines[0].strip()
password = lines[1].strip()

pwd_ctx = CryptContext(schemes=["bcrypt"], deprecated="auto")
users_file = Path("data/users.json")
users_file.parent.mkdir(parents=True, exist_ok=True)

users = json.loads(users_file.read_text()) if users_file.exists() else []
users = [u for u in users if u["username"] != username]
users.insert(0, {
    "username": username,
    "password_hash": pwd_ctx.hash(password),
    "role": "admin",
    "created_at": datetime.utcnow().isoformat(),
    "created_by": "setup"
})
users_file.write_text(json.dumps(users, indent=2, ensure_ascii=False))
print("OK:" + username)
PYEOF

  local result
  result=$(printf '%s\n%s\n' "$adm_user" "$adm_pass" | "$VENV_DIR/bin/python3" "$tmpscript")
  rm -f "$tmpscript"

  if [[ "$result" == OK:* ]]; then
    local created_user="${result#OK:}"
    info "Admin hesabı oluşturuldu: ${W}$created_user${NC}"
    divider
  else
    error "Admin hesabı oluşturulamadı: $result"
    exit 1
  fi
}

run_wizard() {
  echo ""
  echo -e "  ${W}╔══════════════════════════════════════════╗${NC}"
  echo -e "  ${W}║        NordGpT Kurulum Sihirbazı         ║${NC}"
  echo -e "  ${W}╚══════════════════════════════════════════╝${NC}"

  print_hardware
  select_language
  select_category
  select_model
  pull_selected_model
  setup_admin_account
  save_config
}

# ── Reconfigure Prompt ─────────────────────────────────────────────────────────
prompt_reconfigure() {
  echo ""
  echo -e "  ${W}Ne yapmak istersiniz?${NC}"
  echo ""
  echo -e "  ${C}[1]${NC} Mevcut yapılandırmayla başlat  ${DIM}(model: $PREV_MODEL)${NC}"
  echo -e "  ${C}[2]${NC} Yeni model ekle / indir"
  echo -e "  ${C}[3]${NC} Dil veya sektörü değiştir"
  echo -e "  ${C}[4]${NC} Sıfırdan yapılandır"
  echo ""
  prompt "Seçim [1-4, Enter=1]:"
  read -r choice

  case "${choice:-1}" in
    1|"")
      LANGUAGE="$PREV_LANGUAGE"
      CATEGORY="$PREV_CATEGORY"
      SELECTED_MODEL="$PREV_MODEL"
      info "Mevcut yapılandırma kullanılıyor"
      ;;
    2)
      # Just pull a new model
      LANGUAGE="$PREV_LANGUAGE"
      CATEGORY="$PREV_CATEGORY"
      detect_hardware
      select_model
      pull_selected_model
      # Update config with new default model
      sed -i.bak "s/^DEFAULT_MODEL=.*/DEFAULT_MODEL=$SELECTED_MODEL/" "$CONFIG_FILE" 2>/dev/null || \
        save_config
      ;;
    3)
      LANGUAGE="$PREV_LANGUAGE"
      CATEGORY="$PREV_CATEGORY"
      SELECTED_MODEL="$PREV_MODEL"
      detect_hardware
      select_language
      select_category
      select_model
      save_config
      ;;
    4)
      rm -f "$CONFIG_FILE"
      NORDGPT_CONFIGURED=false
      detect_hardware
      run_wizard
      ;;
    *)
      LANGUAGE="$PREV_LANGUAGE"
      CATEGORY="$PREV_CATEGORY"
      SELECTED_MODEL="$PREV_MODEL"
      warn "Geçersiz seçim, mevcut yapılandırma kullanılıyor"
      ;;
  esac
}

# ── Dependencies ───────────────────────────────────────────────────────────────
check_python() {
  step "Python 3 kontrol ediliyor..."
  if command -v python3 &>/dev/null; then
    local ver; ver=$(python3 --version 2>&1 | cut -d' ' -f2)
    info "Python $ver"; return 0
  fi
  warn "Python 3 bulunamadı, kuruluyor..."
  case "$PKG" in
    brew)   brew install python3 ;;
    apt)    sudo apt-get update -qq && sudo apt-get install -y python3 python3-pip python3-venv ;;
    pacman) sudo pacman -S --noconfirm python ;;
    dnf)    sudo dnf install -y python3 python3-pip ;;
    *)      error "Python 3'ü manuel kurun: https://python.org"; exit 1 ;;
  esac
  info "Python kuruldu"
}

setup_venv() {
  step "Python ortamı hazırlanıyor..."
  [[ ! -d "$VENV_DIR" ]] && python3 -m venv "$VENV_DIR" && info "Sanal ortam oluşturuldu"
  "$VENV_DIR/bin/pip" install --quiet --upgrade pip
  "$VENV_DIR/bin/pip" install --quiet -r "$SCRIPT_DIR/requirements.txt"
  info "Bağımlılıklar hazır (fastapi, uvicorn, httpx)"
}

check_ollama() {
  step "Ollama kontrol ediliyor..."
  if command -v ollama &>/dev/null; then
    info "Ollama mevcut"; return 0
  fi
  warn "Ollama kuruluyor..."
  curl -fsSL https://ollama.com/install.sh | sh
  info "Ollama kuruldu"
}

start_ollama() {
  step "Ollama servisi kontrol ediliyor..."
  if curl -sf --max-time 3 "$OLLAMA_URL/api/tags" &>/dev/null; then
    info "Ollama zaten çalışıyor"; return 0
  fi
  warn "Ollama başlatılıyor..."
  if [[ "$OS" == "macos" ]]; then
    nohup ollama serve >/tmp/ollama_nordgpt.log 2>&1 &
  elif command -v systemctl &>/dev/null && systemctl is-enabled ollama &>/dev/null 2>&1; then
    sudo systemctl start ollama 2>/dev/null || nohup ollama serve >/tmp/ollama_nordgpt.log 2>&1 &
  else
    nohup ollama serve >/tmp/ollama_nordgpt.log 2>&1 &
  fi
  echo -n "  ⏳ Bekleniyor"
  for i in {1..20}; do
    sleep 1; echo -n "."
    curl -sf --max-time 2 "$OLLAMA_URL/api/tags" &>/dev/null && { echo ""; info "Ollama hazır"; return 0; }
  done
  echo ""
  warn "Ollama başlatılamadı. Manuel: ollama serve"
}

# ── Port Check ─────────────────────────────────────────────────────────────────
check_port() {
  if lsof -i ":$PORT" &>/dev/null 2>&1; then
    warn "Port $PORT kullanımda, eski süreç kapatılıyor..."
    lsof -ti ":$PORT" | xargs kill -9 2>/dev/null || true
    sleep 1
  fi
}

# ── Start UI ───────────────────────────────────────────────────────────────────
start_ui() {
  step "NordGpT başlatılıyor..."
  check_port
  local url="http://localhost:$PORT"
  echo ""
  echo -e "  ${G}╔══════════════════════════════════════════╗${NC}"
  echo -e "  ${G}║  🚀 NordGpT hazır!                       ║${NC}"
  echo -e "  ${G}║                                          ║${NC}"
  echo -e "  ${G}║  ${W}${url}${G}              ║${NC}"
  echo -e "  ${G}║                                          ║${NC}"
  echo -e "  ${G}║  Durdurmak: Ctrl+C                       ║${NC}"
  echo -e "  ${G}╚══════════════════════════════════════════╝${NC}"
  echo ""
  sleep 1
  { [[ "$OS" == "macos" ]] && open "$url"; } 2>/dev/null || \
  { command -v xdg-open &>/dev/null && xdg-open "$url"; } 2>/dev/null || true

  cd "$SCRIPT_DIR"
  exec "$VENV_DIR/bin/python" -m uvicorn app:app \
    --host 0.0.0.0 --port "$PORT" \
    --log-level warning --no-access-log
}

# ── Subcommands ────────────────────────────────────────────────────────────────
cmd_pull() {
  local model="${1:-}"
  [[ -z "$model" ]] && { error "Kullanım: ./nordgpt.sh pull <model>"; exit 1; }
  start_ollama; ollama pull "$model"; info "İndirildi: $model"
}

cmd_list() {
  start_ollama
  echo -e "\n  ${W}Yüklü Modeller:${NC}\n"
  ollama list
}

cmd_reset() {
  warn "Yapılandırma sıfırlanıyor..."
  rm -f "$CONFIG_FILE"
  info "Sıfırlandı. Bir sonraki çalıştırmada sihirbaz başlayacak."
}

cmd_clean() {
  warn "Sohbet geçmişi siliniyor..."
  rm -rf "$SCRIPT_DIR/data/chats/"*
  info "Geçmiş temizlendi."
}

show_help() {
  echo ""
  echo -e "  ${W}NordGpT — Komutlar${NC}"
  echo ""
  echo -e "  ${C}./nordgpt.sh${NC}               Başlat (ilk çalıştırmada kurulum sihirbazı)"
  echo -e "  ${C}./nordgpt.sh pull <model>${NC}  Model indir  ${DIM}(örn: llama3.1:8b)${NC}"
  echo -e "  ${C}./nordgpt.sh list${NC}          Yüklü modelleri listele"
  echo -e "  ${C}./nordgpt.sh reset${NC}         Yapılandırmayı sıfırla (sihirbazı tekrar çalıştır)"
  echo -e "  ${C}./nordgpt.sh clean${NC}         Sohbet geçmişini temizle"
  echo -e "  ${C}./nordgpt.sh help${NC}          Bu yardım"
  echo ""
  echo -e "  ${W}Ortam değişkenleri:${NC}"
  echo -e "  ${C}NORDGPT_PORT=8080${NC}          Farklı port kullan ${DIM}(varsayılan: 7860)${NC}"
  echo ""
}

# ── Main ───────────────────────────────────────────────────────────────────────
main() {
  banner
  detect_os

  case "${1:-}" in
    pull)  check_python; setup_venv; check_ollama; start_ollama; cmd_pull "${2:-}"; exit 0 ;;
    list)  check_ollama; start_ollama; cmd_list; exit 0 ;;
    reset) cmd_reset; exit 0 ;;
    clean) cmd_clean; exit 0 ;;
    help|--help|-h) show_help; exit 0 ;;
  esac

  # ── Detect current state ──────────────────────────────────────────────────
  check_existing
  print_status

  # ── Dependencies ─────────────────────────────────────────────────────────
  check_python
  setup_venv
  check_ollama
  start_ollama

  # ── Re-check models after starting Ollama ────────────────────────────────
  if ! $OLLAMA_RUNNING; then
    INSTALLED_MODELS=()
    while IFS= read -r line; do
      [[ "$line" =~ ^NAME ]] && continue; [[ -z "$line" ]] && continue
      m=$(awk '{print $1}' <<< "$line")
      [[ -n "$m" ]] && INSTALLED_MODELS+=("$m")
    done < <(ollama list 2>/dev/null || true)
  fi

  # ── Setup wizard or reconfigure prompt ───────────────────────────────────
  if ! $NORDGPT_CONFIGURED; then
    detect_hardware
    run_wizard
  else
    detect_hardware
    prompt_reconfigure
  fi

  start_ui
}

main "$@"
