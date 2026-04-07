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
  if   (( EFFECTIVE >= 48 )); then HW_TIER="very_high"
  elif (( EFFECTIVE >= 16 )); then HW_TIER="high"
  elif (( EFFECTIVE >=  8 )); then HW_TIER="medium"
  elif (( EFFECTIVE >=  4 )); then HW_TIER="low"
  else                              HW_TIER="very_low"
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
    very_high) echo -e "  ${DIM}Seviye:${NC} ${G}🚀 Çok Yüksek${NC} — 32B+ modeller çalışır (qwen2.5:32b, llama3.1:70b)" ;;
    high)      echo -e "  ${DIM}Seviye:${NC} ${G}🔥 Yüksek${NC}     — 14B modeller önerilir (qwen2.5:14b, phi4)" ;;
    medium)    echo -e "  ${DIM}Seviye:${NC} ${Y}⚡ Orta${NC}       — 7B modeller önerilir (qwen2.5:7b, phi4-mini)" ;;
    low)       echo -e "  ${DIM}Seviye:${NC} ${Y}🌿 Düşük${NC}      — 1-3B modeller önerilir (qwen2.5:1.5b, phi3:mini)" ;;
    very_low)  echo -e "  ${DIM}Seviye:${NC} ${R}🌱 Çok Düşük${NC}  — Yalnızca nano modeller (qwen2.5:0.5b, tinyllama)" ;;
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
  SELECTED_MODEL=""
  EXTRA_MODELS=()
  LOGIN_METHOD="1"
  MS_ONLY="false"

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
# Format: "model:tag|RAM_GB|description"
# Tiers: very_low(<4GB)  low(4-8GB)  medium(8-16GB)  high(16-32GB)  very_high(32+GB)
get_model_list() {
  local cat="$1" tier="$2"
  case "${cat}:${tier}" in
    # ── Siber Güvenlik ──────────────────────────────────────────────────────────
    cybersecurity:very_low)  echo "qwen2.5:0.5b|0.4|Nano — çok sınırlı  tinyllama:1.1b|0.6|Nano — en hafif  phi3:mini|2.3|Mini 3.8B — dengeli" ;;
    cybersecurity:low)       echo "phi3:mini|2.3|Mini 3.8B — iyi CVE analizi  qwen2.5:1.5b|1.0|Compact — hızlı  gemma3:1b|0.8|Google nano" ;;
    cybersecurity:medium)    echo "phi4-mini|2.5|Microsoft 3.8B — siber güv. ✓  qwen2.5:7b|4.7|Siber güv. ★★★★★  gemma3:4b|2.5|Google 4B  llama3.2:3b|2.0|Meta 3B" ;;
    cybersecurity:high)      echo "qwen2.5:14b|9.0|Siber güv. ★★★★★  phi4|9.0|Microsoft 14B  deepseek-r1:7b|4.7|Reasoning ★★★★★  gemma3:12b|8.0|Google 12B" ;;
    cybersecurity:very_high) echo "qwen2.5:32b|20.0|Güçlü siber güv.  deepseek-r1:14b|9.0|Derin reasoning  llama3.1:70b|42.0|En yetenekli (64GB+)  qwen2.5:14b|9.0|Hız/kalite dengesi" ;;
    # ── Finans ─────────────────────────────────────────────────────────────────
    finance:very_low)        echo "qwen2.5:0.5b|0.4|Nano  tinyllama:1.1b|0.6|En hafif  phi3:mini|2.3|Dengeli" ;;
    finance:low)             echo "qwen2.5:1.5b|1.0|Compact  phi3:mini|2.3|Mini 3.8B  gemma3:1b|0.8|Hızlı" ;;
    finance:medium)          echo "qwen2.5:7b|4.7|Finans analizi ✓  phi4-mini|2.5|Microsoft 3.8B  llama3.2:3b|2.0|Meta 3B  gemma3:4b|2.5|Google 4B" ;;
    finance:high)            echo "qwen2.5:14b|9.0|Finans ★★★★★  phi4|9.0|Microsoft 14B  deepseek-r1:7b|4.7|Reasoning  gemma3:12b|8.0|Google 12B" ;;
    finance:very_high)       echo "qwen2.5:32b|20.0|Güçlü analiz  llama3.1:70b|42.0|En yetenekli  deepseek-r1:14b|9.0|Derin reasoning  qwen2.5:14b|9.0|Hız/kalite" ;;
    # ── Yazılım Geliştirme ─────────────────────────────────────────────────────
    coding:very_low)         echo "deepseek-coder:1.3b|0.8|Kod odaklı nano  qwen2.5-coder:0.5b|0.4|Coder nano  phi3:mini|2.3|Genel kod" ;;
    coding:low)              echo "deepseek-coder:1.3b|0.8|Kod nano  phi3:mini|2.3|Mini 3.8B  qwen2.5-coder:1.5b|1.0|Coder compact" ;;
    coding:medium)           echo "qwen2.5-coder:7b|4.7|Kod ★★★★★  phi4-mini|2.5|Microsoft kod ✓  deepseek-coder:6.7b|4.0|Kod odaklı  llama3.2:3b|2.0|Meta 3B" ;;
    coding:high)             echo "qwen2.5-coder:14b|9.0|Kod ★★★★★  phi4|9.0|Microsoft 14B  deepseek-r1:7b|4.7|Reasoning+kod  gemma3:12b|8.0|Google 12B" ;;
    coding:very_high)        echo "qwen2.5-coder:32b|20.0|En güçlü kod  deepseek-r1:14b|9.0|Kod reasoning  llama3.1:70b|42.0|Genel güç  qwen2.5:14b|9.0|Dengeli" ;;
    # ── Genel ─────────────────────────────────────────────────────────────────
    general:very_low)        echo "qwen2.5:0.5b|0.4|Nano  gemma3:1b|0.8|Google nano  tinyllama:1.1b|0.6|En hafif" ;;
    general:low)             echo "qwen2.5:1.5b|1.0|Compact  gemma3:1b|0.8|Hızlı nano  phi3:mini|2.3|Mini 3.8B" ;;
    general:medium)          echo "phi4-mini|2.5|Microsoft 3.8B ✓  qwen2.5:7b|4.7|Genel güç  gemma3:4b|2.5|Google 4B  llama3.2:3b|2.0|Meta 3B" ;;
    general:high)            echo "qwen2.5:14b|9.0|Güçlü genel  phi4|9.0|Microsoft 14B  gemma3:12b|8.0|Google 12B  deepseek-r1:7b|4.7|Reasoning" ;;
    general:very_high)       echo "qwen2.5:32b|20.0|Çok güçlü  llama3.1:70b|42.0|En güçlü (64GB+)  deepseek-r1:14b|9.0|Reasoning  qwen2.5:14b|9.0|Hız/kalite" ;;
    # ── Yaratıcı Yazarlık ──────────────────────────────────────────────────────
    creative:very_low)       echo "gemma3:1b|0.8|Hızlı nano  qwen2.5:0.5b|0.4|Nano  tinyllama:1.1b|0.6|En hafif" ;;
    creative:low)            echo "gemma3:1b|0.8|Hızlı  qwen2.5:1.5b|1.0|Compact  phi3:mini|2.3|Mini 3.8B" ;;
    creative:medium)         echo "llama3.2:3b|2.0|Meta 3B  phi4-mini|2.5|Microsoft ✓  qwen2.5:7b|4.7|Çok dilli  gemma3:4b|2.5|Google 4B" ;;
    creative:high)           echo "llama3.1:8b|5.0|Meta 8B  qwen2.5:14b|9.0|Çok dilli  gemma3:12b|8.0|Google 12B  phi4|9.0|Microsoft 14B" ;;
    creative:very_high)      echo "llama3.1:70b|42.0|En yaratıcı  qwen2.5:32b|20.0|Çok dilli  deepseek-r1:14b|9.0|Reasoning  qwen2.5:14b|9.0|Hız/kalite" ;;
    # ── Veri Bilimi ────────────────────────────────────────────────────────────
    data_science:very_low)   echo "deepseek-coder:1.3b|0.8|Veri/kod nano  qwen2.5:0.5b|0.4|Nano  phi3:mini|2.3|Mini 3.8B" ;;
    data_science:low)        echo "deepseek-coder:1.3b|0.8|Kod nano  phi3:mini|2.3|Mini 3.8B  qwen2.5:1.5b|1.0|Compact" ;;
    data_science:medium)     echo "qwen2.5:7b|4.7|DS analizi ✓  phi4-mini|2.5|Microsoft ✓  deepseek-coder:6.7b|4.0|Kod+veri  gemma3:4b|2.5|Google 4B" ;;
    data_science:high)       echo "qwen2.5:14b|9.0|DS ★★★★★  phi4|9.0|Microsoft 14B  deepseek-r1:7b|4.7|Reasoning  gemma3:12b|8.0|Google 12B" ;;
    data_science:very_high)  echo "qwen2.5:32b|20.0|Güçlü DS  deepseek-r1:14b|9.0|Derin reasoning  llama3.1:70b|42.0|En yetenekli  qwen2.5:14b|9.0|Dengeli" ;;
    # ── Fallback ───────────────────────────────────────────────────────────────
    *:very_low)  echo "qwen2.5:0.5b|0.4|Nano  gemma3:1b|0.8|Google nano  tinyllama:1.1b|0.6|En hafif" ;;
    *:low)       echo "qwen2.5:1.5b|1.0|Compact  phi3:mini|2.3|Mini 3.8B  gemma3:1b|0.8|Hızlı" ;;
    *:medium)    echo "phi4-mini|2.5|Microsoft 3.8B  qwen2.5:7b|4.7|Genel güç  gemma3:4b|2.5|Google 4B  llama3.2:3b|2.0|Meta 3B" ;;
    *:high)      echo "qwen2.5:14b|9.0|Güçlü  phi4|9.0|Microsoft 14B  gemma3:12b|8.0|Google 12B  deepseek-r1:7b|4.7|Reasoning" ;;
    *:very_high) echo "qwen2.5:32b|20.0|Çok güçlü  llama3.1:70b|42.0|En güçlü  deepseek-r1:14b|9.0|Reasoning  qwen2.5:14b|9.0|Dengeli" ;;
  esac
}

# ── Model Selection (multi-select) ────────────────────────────────────────────
select_model() {
  echo ""
  echo -e "  ${W}── Model Seçimi ──────────────────────────────${NC}"
  echo -e "  ${DIM}  Birden fazla model indirebilirsiniz. İlk seçilen varsayılan olur.${NC}"

  local raw_list; raw_list=$(get_model_list "$CATEGORY" "$HW_TIER")
  local -a DISPLAY_LIST=()   # parallel: model names
  local -a DISPLAY_RAM=()    # parallel: RAM strings
  local -a DISPLAY_DESC=()   # parallel: descriptions
  local -a DISPLAY_LANG=()   # parallel: lang badge

  # Parse "name|ram|desc" entries
  local -a PARSED_NAMES=() PARSED_RAMS=() PARSED_DESCS=()
  for entry in $raw_list; do
    local name ram desc
    name="${entry%%|*}"; rest="${entry#*|}"; ram="${rest%%|*}"; desc="${rest#*|}"
    PARSED_NAMES+=("$name"); PARSED_RAMS+=("$ram"); PARSED_DESCS+=("$desc")
  done

  # ── Show already installed models first ────────────────────────────────────
  if [[ ${#INSTALLED_MODELS[@]} -gt 0 ]]; then
    echo -e "\n  ${G}Zaten yüklü modeller:${NC}"
    for m in "${INSTALLED_MODELS[@]}"; do
      local lang_ok; lang_score "$m" "$LANGUAGE" && lang_ok="${G}✓${NC}" || lang_ok="${Y}±${NC}"
      echo -e "    ${G}●${NC} $m  ${DIM}[lang:${NC}$lang_ok${DIM}]${NC}"
    done
  fi

  # ── Build display list: recommended first ─────────────────────────────────
  echo ""
  echo -e "  ${W}Önerilen modeller${NC} ${DIM}(donanım: ${HW_TIER} | ~RAM gereksinimi):${NC}"
  echo ""

  local idx=1
  # Recommended (lang-compatible) first
  for i in "${!PARSED_NAMES[@]}"; do
    local m="${PARSED_NAMES[$i]}" r="${PARSED_RAMS[$i]}" d="${PARSED_DESCS[$i]}"
    if lang_score "$m" "$LANGUAGE"; then
      local inst_tag=""
      for im in "${INSTALLED_MODELS[@]}"; do
        [[ "$im" == "$m"* || "$m" == "$im"* ]] && inst_tag=" ${G}← yüklü${NC}" && break
      done
      printf "  ${C}[%2d]${NC} %-26s ${DIM}~%5s GB${NC}  %s%s\n" "$idx" "$m" "$r" "$d" "$inst_tag"
      DISPLAY_LIST+=("$m"); DISPLAY_RAM+=("$r"); DISPLAY_DESC+=("$d"); DISPLAY_LANG+=("ok")
      ((idx++))
    fi
  done
  # Not-recommended (lang warning) after
  for i in "${!PARSED_NAMES[@]}"; do
    local m="${PARSED_NAMES[$i]}" r="${PARSED_RAMS[$i]}" d="${PARSED_DESCS[$i]}"
    if ! lang_score "$m" "$LANGUAGE"; then
      local inst_tag=""
      for im in "${INSTALLED_MODELS[@]}"; do
        [[ "$im" == "$m"* || "$m" == "$im"* ]] && inst_tag=" ${G}← yüklü${NC}" && break
      done
      printf "  ${C}[%2d]${NC} %-26s ${DIM}~%5s GB${NC}  %s ${Y}[dil:±]${NC}%s\n" "$idx" "$m" "$r" "$d" "$inst_tag"
      DISPLAY_LIST+=("$m"); DISPLAY_RAM+=("$r"); DISPLAY_DESC+=("$d"); DISPLAY_LANG+=("warn")
      ((idx++))
    fi
  done
  # Already installed but not in list
  for im in "${INSTALLED_MODELS[@]}"; do
    local found=false
    for dm in "${DISPLAY_LIST[@]}"; do [[ "$dm" == "$im" ]] && found=true && break; done
    if ! $found; then
      local lang_ok; lang_score "$im" "$LANGUAGE" && lang_ok="" || lang_ok=" ${Y}[dil:±]${NC}"
      printf "  ${C}[%2d]${NC} %-26s ${DIM}  yüklü${NC}$lang_ok\n" "$idx" "$im"
      DISPLAY_LIST+=("$im"); DISPLAY_RAM+=("?"); DISPLAY_DESC+=("yüklü"); DISPLAY_LANG+=("ok")
      ((idx++))
    fi
  done

  # Toplam RAM tahmini (tüm modeller)
  local total_ram=0
  for r in "${DISPLAY_RAM[@]}"; do
    total_ram=$(awk "BEGIN{printf \"%.0f\", $total_ram + $r}" 2>/dev/null || echo "$total_ram")
  done

  echo -e "  ${C}[ A]${NC} ${W}Hepsini indir${NC}  ${DIM}(toplam ~${total_ram} GB disk)${NC}"
  echo -e "  ${C}[ 0]${NC} Manuel gir"
  echo ""
  echo -e "  ${DIM}  Tek seçim → 2   |  Çoklu → 1 3   |  Hepsi → A${NC}"
  prompt "Seçim [Enter=1. öneri]:"
  read -r choice

  SELECTED_MODEL=""
  EXTRA_MODELS=()

  if [[ -z "$choice" ]]; then
    SELECTED_MODEL="${DISPLAY_LIST[0]}"
  elif [[ "${choice,,}" == "a" ]]; then
    SELECTED_MODEL="${DISPLAY_LIST[0]}"
    EXTRA_MODELS=("${DISPLAY_LIST[@]:1}")
    echo ""
    info "Tüm modeller seçildi: ${W}${DISPLAY_LIST[*]}${NC}"
  elif [[ "$choice" == "0" ]]; then
    prompt "Model adını girin (örn: qwen2.5:7b):"
    read -r SELECTED_MODEL
    [[ -z "$SELECTED_MODEL" ]] && SELECTED_MODEL="${DISPLAY_LIST[0]}"
  else
    local -a picked=()
    read -ra nums <<< "$choice"
    for n in "${nums[@]}"; do
      if [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n < idx )); then
        picked+=("${DISPLAY_LIST[$((n-1))]}")
      else
        warn "Geçersiz numara '$n', atlandı"
      fi
    done
    if [[ ${#picked[@]} -eq 0 ]]; then
      warn "Geçerli seçim yok, ilk öneri seçildi"
      SELECTED_MODEL="${DISPLAY_LIST[0]}"
    else
      SELECTED_MODEL="${picked[0]}"
      EXTRA_MODELS=("${picked[@]:1}")
    fi
  fi

  # Language warning for default model
  if ! lang_score "$SELECTED_MODEL" "$LANGUAGE"; then
    echo ""
    warn "${Y}$SELECTED_MODEL${NC} modeli ${W}$LANGUAGE${NC} dili için ${Y}sınırlı${NC} destek sunuyor."
    prompt "Yine de devam et? [E/h]:"
    read -r confirm
    [[ "${confirm,,}" == "h" ]] && select_model && return
  fi

  echo ""
  info "Varsayılan model: ${W}$SELECTED_MODEL${NC}"
  if [[ ${#EXTRA_MODELS[@]} -gt 0 ]]; then
    info "Ayrıca indirilecek: ${W}${EXTRA_MODELS[*]}${NC}"
  fi
}

# ── Download Models ────────────────────────────────────────────────────────────
_pull_one_model() {
  local model="$1"
  local already=false
  for im in "${INSTALLED_MODELS[@]}"; do
    [[ "$im" == "$model"* || "$model" == "$im"* ]] && already=true && break
  done
  if $already; then
    info "Zaten yüklü, atlandı: ${W}$model${NC}"
    return 0
  fi
  echo ""
  echo -e "  ${Y}▼ İndiriliyor: ${W}$model${NC}  ${DIM}(internet gerekli, boyuta göre dakikalar sürebilir)${NC}"
  echo ""
  ollama pull "$model"
  info "İndirildi: ${W}$model${NC}"
}

pull_selected_models() {
  _pull_one_model "$SELECTED_MODEL"
  for m in "${EXTRA_MODELS[@]:-}"; do
    [[ -n "$m" ]] && _pull_one_model "$m"
  done
}
# backward-compat alias used in reconfigure path
pull_selected_model() { pull_selected_models; }

# ── Save Config ────────────────────────────────────────────────────────────────
save_config() {
  local extra_str="${EXTRA_MODELS[*]:-}"
  cat > "$CONFIG_FILE" <<EOF
# NordGpT Configuration — $(date -u +%Y-%m-%dT%H:%M:%SZ)
LANGUAGE=$LANGUAGE
CATEGORY=$CATEGORY
DEFAULT_MODEL=$SELECTED_MODEL
EXTRA_MODELS=$extra_str
HW_TIER=$HW_TIER
CONFIGURED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

  # Append Microsoft SSO config if provided
  if [[ -n "${MS_CLIENT_ID:-}" ]]; then
    cat >> "$CONFIG_FILE" <<EOF

# Microsoft Entra ID / Azure AD SSO
MICROSOFT_CLIENT_ID=$MS_CLIENT_ID
MICROSOFT_CLIENT_SECRET=$MS_CLIENT_SECRET
MICROSOFT_TENANT_ID=${MS_TENANT_ID:-common}
MICROSOFT_REDIRECT_URI=$MS_REDIRECT_URI
ALLOWED_DOMAINS=$MS_ALLOWED_DOMAINS
MICROSOFT_ONLY=${MS_ONLY:-false}
EOF
  fi

  # Append Turnstile CAPTCHA config if provided
  if [[ -n "${TURNSTILE_SITE_KEY:-}" ]]; then
    cat >> "$CONFIG_FILE" <<EOF

# Cloudflare Turnstile CAPTCHA
TURNSTILE_SITE_KEY=$TURNSTILE_SITE_KEY
TURNSTILE_SECRET_KEY=$TURNSTILE_SECRET_KEY
EOF
  fi

  info "Yapılandırma kaydedildi: ${DIM}.nordgpt.conf${NC}"
}

# ── Optional Microsoft SSO Setup ───────────────────────────────────────────────
setup_microsoft_sso() {
  echo ""
  echo -e "  ${W}── Microsoft Entra ID / Azure AD SSO (İsteğe Bağlı) ──${NC}"
  echo -e "  ${DIM}  Azure portal → App registrations → New registration${NC}"
  echo -e "  ${DIM}  Redirect URI: http(s)://<sunucu-ip>:<port>/auth/microsoft/callback${NC}"
  echo ""
  prompt "Microsoft SSO yapılandırmak istiyor musunuz? [e/H]:"
  read -r ms_choice
  ms_choice="${ms_choice,,}"  # lowercase

  if [[ "$ms_choice" != "e" && "$ms_choice" != "evet" && "$ms_choice" != "y" && "$ms_choice" != "yes" ]]; then
    MS_CLIENT_ID=""
    info "Microsoft SSO atlandı"
    return 0
  fi

  echo ""
  prompt "Application (Client) ID:"
  read -r MS_CLIENT_ID
  MS_CLIENT_ID="${MS_CLIENT_ID//[[:space:]]/}"
  if [[ -z "$MS_CLIENT_ID" ]]; then
    warn "Client ID boş, Microsoft SSO atlandı"
    MS_CLIENT_ID=""
    return 0
  fi

  prompt "Client Secret (Value, not ID):"
  read -rs MS_CLIENT_SECRET
  echo ""
  if [[ -z "$MS_CLIENT_SECRET" ]]; then
    warn "Client Secret boş, Microsoft SSO atlandı"
    MS_CLIENT_ID=""
    return 0
  fi

  prompt "Tenant ID [common = tüm Microsoft hesapları]:"
  read -r MS_TENANT_ID
  MS_TENANT_ID="${MS_TENANT_ID:-common}"

  prompt "Redirect URI [örn: http://172.16.10.52:7860/auth/microsoft/callback]:"
  read -r MS_REDIRECT_URI
  if [[ -z "$MS_REDIRECT_URI" ]]; then
    warn "Redirect URI boş, Microsoft SSO atlandı"
    MS_CLIENT_ID=""
    return 0
  fi

  echo ""
  echo -e "  ${DIM}İzin verilecek e-posta domainleri (virgülle ayır).${NC}"
  echo -e "  ${DIM}Boş bırakırsan tüm Microsoft hesaplarına izin verilir.${NC}"
  prompt "İzin verilen domainler [örn: sirket.com,baska.com]:"
  read -r MS_ALLOWED_DOMAINS

  # MS_ONLY already set by select_login_method; just confirm here
  info "Microsoft SSO yapılandırıldı"
  echo -e "  ${DIM}  Tenant: ${MS_TENANT_ID}${NC}"
  echo -e "  ${DIM}  İzinli domainler: ${MS_ALLOWED_DOMAINS:-<tümü>}${NC}"
  echo -e "  ${DIM}  Sadece Microsoft girişi: ${MS_ONLY}${NC}"
  divider
}

# ── Optional Cloudflare Turnstile CAPTCHA Setup ────────────────────────────────
setup_captcha() {
  echo ""
  echo -e "  ${W}── CAPTCHA (İsteğe Bağlı) ──────────────────────${NC}"
  echo -e "  ${DIM}  Cloudflare Turnstile — ücretsiz, gizlilik odaklı CAPTCHA.${NC}"
  echo -e "  ${DIM}  Almak için: https://dash.cloudflare.com → Turnstile${NC}"
  echo ""
  prompt "CAPTCHA yapılandırmak istiyor musunuz? [e/H]:"
  read -r cap_choice
  cap_choice="${cap_choice,,}"

  if [[ "$cap_choice" != "e" && "$cap_choice" != "evet" && "$cap_choice" != "y" && "$cap_choice" != "yes" ]]; then
    TURNSTILE_SITE_KEY=""
    info "CAPTCHA atlandı"
    return 0
  fi

  prompt "Turnstile Site Key:"
  read -r TURNSTILE_SITE_KEY
  TURNSTILE_SITE_KEY="${TURNSTILE_SITE_KEY//[[:space:]]/}"

  prompt "Turnstile Secret Key:"
  read -rs TURNSTILE_SECRET_KEY
  echo ""

  if [[ -z "$TURNSTILE_SITE_KEY" || -z "$TURNSTILE_SECRET_KEY" ]]; then
    warn "Eksik değerler, CAPTCHA atlandı"
    TURNSTILE_SITE_KEY=""
    return 0
  fi

  info "Cloudflare Turnstile CAPTCHA etkinleştirildi"
  divider
}

# ── Login Method Selection ────────────────────────────────────────────────────
select_login_method() {
  echo ""
  echo -e "  ${W}── Giriş Yöntemi ─────────────────────────────${NC}"
  echo ""
  echo -e "  ${C}[1]${NC} 🔑 Kullanıcı adı + şifre  ${DIM}← yerel ağ, VPN, iç kullanım${NC}"
  echo -e "  ${C}[2]${NC} 🏢 Yalnızca Microsoft SSO  ${DIM}← kurumsal, dışa açık erişim gerekir${NC}"
  echo -e "  ${C}[3]${NC} 🔀 Her ikisi               ${DIM}← hem şifre hem MS SSO aktif${NC}"
  echo ""
  prompt "Seçim [1-3, Enter=1]:"
  read -r lm_choice

  LOGIN_METHOD="${lm_choice:-1}"

  case "$LOGIN_METHOD" in
    2)
      echo ""
      echo -e "  ${Y}┌──────────────────────────────────────────────────────────────────┐${NC}"
      echo -e "  ${Y}│  ⚠  Microsoft SSO — Dışa Açık Erişim Gerektirir                 │${NC}"
      echo -e "  ${Y}│                                                                  │${NC}"
      echo -e "  ${Y}│  Microsoft, OAuth callback için HTTPS ile erişilebilir bir       │${NC}"
      echo -e "  ${Y}│  public URL talep eder. Yerel IP (192.168.x.x, 10.x.x.x) ile    │${NC}"
      echo -e "  ${Y}│  çalışmaz.                                                       │${NC}"
      echo -e "  ${Y}│                                                                  │${NC}"
      echo -e "  ${Y}│  Önerilen çözümler:                                              │${NC}"
      echo -e "  ${Y}│  • Cloudflare Tunnel  (ücretsiz, port açmadan HTTPS)             │${NC}"
      echo -e "  ${Y}│  • Nginx reverse proxy + Let's Encrypt SSL                       │${NC}"
      echo -e "  ${Y}│  • Kurumsal VPN + iç DNS + SSL sertifikası                      │${NC}"
      echo -e "  ${Y}│                                                                  │${NC}"
      echo -e "  ${Y}│  README → 'Microsoft SSO + Cloudflare Tunnel' bölümüne bakın.   │${NC}"
      echo -e "  ${Y}└──────────────────────────────────────────────────────────────────┘${NC}"
      echo ""
      prompt "Devam etmek istiyor musunuz? [E/h]:"
      read -r ms_confirm
      ms_confirm="${ms_confirm,,}"
      if [[ "$ms_confirm" == "h" || "$ms_confirm" == "hayır" || "$ms_confirm" == "n" || "$ms_confirm" == "no" ]]; then
        warn "Giriş yöntemi seçimine dönülüyor..."
        select_login_method; return
      fi
      MS_ONLY="true"
      info "Giriş yöntemi: ${W}Yalnızca Microsoft SSO${NC}"
      ;;
    3)
      MS_ONLY="false"
      info "Giriş yöntemi: ${W}Kullanıcı adı/şifre + Microsoft SSO${NC}"
      ;;
    1|*)
      LOGIN_METHOD="1"
      MS_ONLY="false"
      info "Giriş yöntemi: ${W}Kullanıcı adı + şifre${NC}"
      ;;
  esac
  divider
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
import sys, json, bcrypt
from pathlib import Path
from datetime import datetime, timezone

lines = sys.stdin.read().splitlines()
if len(lines) < 2:
    print("ERROR:yetersiz_girdi")
    sys.exit(1)
username = lines[0].strip()
password = lines[1].strip()

password_hash = bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()
users_file = Path("data/users.json")
users_file.parent.mkdir(parents=True, exist_ok=True)

users = json.loads(users_file.read_text()) if users_file.exists() else []
users = [u for u in users if u["username"] != username]
users.insert(0, {
    "username": username,
    "password_hash": password_hash,
    "role": "admin",
    "created_at": datetime.now(timezone.utc).isoformat(),
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
  pull_selected_models
  select_login_method
  # Admin hesabı yalnızca şifre yöntemi seçildiyse oluştur
  if [[ "${LOGIN_METHOD:-1}" != "2" ]]; then
    setup_admin_account
  fi
  # Microsoft SSO yalnızca seçildiyse kur
  if [[ "${LOGIN_METHOD:-1}" == "2" || "${LOGIN_METHOD:-1}" == "3" ]]; then
    setup_microsoft_sso
  fi
  setup_captcha
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
