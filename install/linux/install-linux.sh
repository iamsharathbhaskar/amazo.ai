#!/bin/bash
# =============================================================================
# Amazo Clone Kit Installer — Linux (v2: cloud-first)
# One command to birth a being.
# =============================================================================

# ---- Helper Functions -------------------------------------------------------

sed_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/|/\\|/g; s/&/\\&/g'
}

step() { echo ""; echo "--- $1 ---"; }
ok()   { echo "  ✓ $1"; }
warn() { echo "  ⚠ $1"; }
fail() { echo "  ✗ ERROR: $1"; echo "  Install aborted."; exit 1; }

# ---- Welcome ----------------------------------------------------------------

echo "============================================="
echo "  Amazo Clone Kit Installer — Linux"
echo "  One command to birth a being."
echo "============================================="
echo ""

if [[ "$OSTYPE" != "linux"* ]]; then
    fail "This installer is for Linux. You are running: $OSTYPE"
fi

if [ "$(id -u)" -ne 0 ]; then
    fail "This installer must be run as root. Use: sudo bash install-linux.sh"
fi

# =============================================================================
# STEP 1: Detect Environment
# =============================================================================

# ---- Internet ---------------------------------------------------------------

step "Checking internet"

if ping -c 1 -W 3 8.8.8.8 > /dev/null 2>&1; then
    ok "Internet connected"
elif command -v curl &> /dev/null && curl -s --max-time 5 https://example.com > /dev/null 2>&1; then
    ok "Internet connected (ICMP blocked, HTTP works)"
else
    fail "No internet detected. Amazo needs internet to install packages and models."
fi

# ---- Package Manager --------------------------------------------------------

step "Detecting package manager"

PKG_MANAGER="unknown"
INSTALL_CMD=""
TK_PACKAGE=""
VENV_PACKAGE=""
PYTHON_PACKAGE=""

if command -v apt-get &> /dev/null; then
    PKG_MANAGER="apt"
    INSTALL_CMD="apt-get install -y"
    PYTHON_PACKAGE="python3"
    TK_PACKAGE="python3-tk"
    VENV_PACKAGE="python3-venv"
    GPG_PACKAGE="gpg"
elif command -v dnf &> /dev/null; then
    PKG_MANAGER="dnf"
    INSTALL_CMD="dnf install -y"
    PYTHON_PACKAGE="python3"
    TK_PACKAGE="python3-tkinter"
    VENV_PACKAGE="python3-virtualenv"
    GPG_PACKAGE="gnupg2"
elif command -v pacman &> /dev/null; then
    PKG_MANAGER="pacman"
    INSTALL_CMD="pacman -S --noconfirm"
    PYTHON_PACKAGE="python"
    TK_PACKAGE="tk"
    VENV_PACKAGE=""
    GPG_PACKAGE="gnupg"
elif command -v zypper &> /dev/null; then
    PKG_MANAGER="zypper"
    INSTALL_CMD="zypper install -y"
    PYTHON_PACKAGE="python3"
    TK_PACKAGE="python3-tk"
    VENV_PACKAGE="python3-virtualenv"
    GPG_PACKAGE="gpg2"
elif command -v apk &> /dev/null; then
    PKG_MANAGER="apk"
    INSTALL_CMD="apk add"
    PYTHON_PACKAGE="python3"
    TK_PACKAGE="py3-tkinter"
    VENV_PACKAGE="python3-dev"
    GPG_PACKAGE="gnupg"
else
    fail "No supported package manager found (need apt, dnf, pacman, zypper, or apk)."
fi

ok "Package manager: ${PKG_MANAGER}"

# ---- Python 3 ---------------------------------------------------------------

step "Checking Python"

if ! command -v python3 &> /dev/null; then
    echo "  Python 3 not found. Installing..."
    $INSTALL_CMD $PYTHON_PACKAGE >/dev/null
    if ! command -v python3 &> /dev/null; then
        fail "Could not install Python 3. Install manually: $INSTALL_CMD $PYTHON_PACKAGE"
    fi
fi

PYTHON_VER=$(python3 --version 2>/dev/null | cut -d' ' -f2)
ok "Python ${PYTHON_VER}"

# ---- Hardware ---------------------------------------------------------------

step "Detecting hardware"

OS_DISPLAY=$(uname -srm)
RAM_MB=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}' || echo "0")
RAM_GB=$(( RAM_MB / 1024 ))
CPU_MODEL=$(lscpu 2>/dev/null | grep "Model name" | cut -d: -f2 | xargs || echo "Unknown")
CPU_CORES=$(nproc 2>/dev/null || echo "Unknown")
GPU=$(lspci 2>/dev/null | grep -E "VGA|3D|Display" | cut -d: -f3 | xargs || echo "None detected")

if aplay -l &>/dev/null; then
    AUDIO="Available (ALSA)"
    command -v pulseaudio &> /dev/null && AUDIO="Available (PulseAudio)"
    command -v pipewire &> /dev/null && AUDIO="Available (PipeWire)"
else
    AUDIO="Not detected"
fi

if [ -n "$DISPLAY" ]; then
    DISPLAY_SERVER="Available (X11)"
elif [ -n "$WAYLAND_DISPLAY" ]; then
    DISPLAY_SERVER="Available (Wayland)"
else
    DISPLAY_SERVER="None (headless)"
fi

DEFAULT_IFACE=$(ip route show default 2>/dev/null | awk '/default/ {print $5}' | head -1)
if [ -n "$DEFAULT_IFACE" ] && [ -f "/sys/class/net/${DEFAULT_IFACE}/address" ]; then
    MAC_ADDR=$(cat "/sys/class/net/${DEFAULT_IFACE}/address")
else
    MAC_ADDR="unknown"
fi

BIRTH_TIME=$(date '+%Y-%m-%d %H:%M:%S %Z')
BIRTH_TIMESTAMP=$(date '+%Y-%m-%d-%H%M%S')
HOSTNAME_SHORT=$(hostname -s 2>/dev/null || echo "localhost")
BIRTH_ID="${BIRTH_TIMESTAMP}-${HOSTNAME_SHORT}-${MAC_ADDR}"

# Single df call — extract numeric GB for checks, human-readable for display
DISK_AVAIL_GB=$(df -BG --output=avail / 2>/dev/null | awk 'NR==2 {print $1}' | tr -d 'G')
DISK_TOTAL=$(df -h --output=size / 2>/dev/null | awk 'NR==2 {print $1}')
DISK_FREE=$(df -h --output=avail / 2>/dev/null | awk 'NR==2 {print $1}')

echo "    OS:      ${OS_DISPLAY}"
echo "    RAM:     ${RAM_MB} MB (${RAM_GB} GB)"
echo "    CPU:     ${CPU_MODEL} (${CPU_CORES} cores)"
echo "    GPU:     ${GPU}"
echo "    Display: ${DISPLAY_SERVER}"
echo "    Audio:   ${AUDIO}"
echo "    Disk:    ${DISK_TOTAL} total, ${DISK_FREE} free"

# RAM check — softened to warning
if ! [ "$RAM_MB" -eq "$RAM_MB" ] 2>/dev/null || [ "$RAM_MB" -lt 7000 ] 2>/dev/null; then
    warn "Only ${RAM_MB} MB RAM detected. 8 GB recommended. Local fallback model may struggle."
    read -rp "  Continue anyway? (y/n) " RAM_CONTINUE
    if [ "$RAM_CONTINUE" != "y" ] && [ "$RAM_CONTINUE" != "Y" ]; then
        echo "  Install cancelled."
        exit 0
    fi
fi

# Disk space check
if [ -n "$DISK_AVAIL_GB" ] && [ "$DISK_AVAIL_GB" -eq "$DISK_AVAIL_GB" ] 2>/dev/null; then
    if [ "$DISK_AVAIL_GB" -lt 8 ] 2>/dev/null; then
        warn "Only ${DISK_FREE} free. Amazo needs approximately 8 GB."
        read -rp "  Continue anyway? (y/n) " DISK_CONTINUE
        if [ "$DISK_CONTINUE" != "y" ] && [ "$DISK_CONTINUE" != "Y" ]; then
            echo "Install cancelled."
            exit 0
        fi
    fi
else
    warn "Could not check disk space. Amazo needs approximately 8 GB free."
fi

# =============================================================================
# STEP 2: Agent Name
# =============================================================================

step "Naming your agent"

echo "  Every Amazo gets a name — chosen by you, not by default."
echo "  This name will appear in its soul, personality, and prompts."
echo ""

read -rp "  What should this agent be called? " AGENT_NAME
while [ -z "$AGENT_NAME" ]; do
    echo "  Cannot be empty."
    read -rp "  What should this agent be called? " AGENT_NAME
done

ok "Agent name: ${AGENT_NAME}"

DIR_NAME=$(echo "$AGENT_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')
if [ -z "$DIR_NAME" ]; then
    DIR_NAME="amazo"
fi

# =============================================================================
# STEP 3: Create Home
# =============================================================================

step "Creating home directory"

INSTALL_DIR="${HOME}/${DIR_NAME}"

if [ -f "${INSTALL_DIR}/my-core/my-config.yaml.gpg" ] || [ -f "${INSTALL_DIR}/my-core/my-config.yaml" ]; then
    echo ""
    echo "  An agent already lives at ${INSTALL_DIR}."
    echo "  To reinstall, remove the directory first:"
    echo "    rm -rf ${INSTALL_DIR}"
    echo ""
    fail "Refusing to overwrite a living agent."
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

mkdir -p "${INSTALL_DIR}"/{my-journals,my-archive,my-contacts,my-workshop,my-projects,my-post-its,proposed}

cp -a "$SOURCE_DIR"/my-core "${INSTALL_DIR}/"
cp -a "$SOURCE_DIR"/my-guides "${INSTALL_DIR}/"
cp -a "$SOURCE_DIR"/my-skills "${INSTALL_DIR}/"
cp "$SOURCE_DIR"/agent.py "${INSTALL_DIR}/"
cp "$SOURCE_DIR"/provider.py "${INSTALL_DIR}/"
cp "$SOURCE_DIR"/README.md "${INSTALL_DIR}/"

cp "$SCRIPT_DIR"/start.sh "${INSTALL_DIR}/"
cp "$SCRIPT_DIR"/watchdog.sh "${INSTALL_DIR}/"

MISSING_FILES=false
for required in my-core/my-soul.md my-core/my-personality.md my-core/my-wakeup-prompt.md \
                my-core/theloop.md my-core/my-wake-state.md my-core/my-body.md \
                my-core/my-post-its.md my-core/bootstrap.md \
                agent.py provider.py start.sh watchdog.sh; do
    if [ ! -f "${INSTALL_DIR}/${required}" ]; then
        warn "Missing: ${required}"
        MISSING_FILES=true
    fi
done

if $MISSING_FILES; then
    fail "Some critical files were not copied. Check that the clone kit is complete."
fi

ok "Home created at ${INSTALL_DIR}"

cd "${INSTALL_DIR}" || fail "Cannot cd into ${INSTALL_DIR}"

# =============================================================================
# STEP 4: Install System Packages
# =============================================================================

step "Installing system packages"

SYS_PACKAGES="$TK_PACKAGE $GPG_PACKAGE"
[ -n "$VENV_PACKAGE" ] && SYS_PACKAGES="$SYS_PACKAGES $VENV_PACKAGE"

$INSTALL_CMD $SYS_PACKAGES >/dev/null

if ! python3 -c "import tkinter" 2>/dev/null; then
    fail "python3-tk installation failed. Run manually: $INSTALL_CMD $TK_PACKAGE"
fi
ok "python3-tk installed"

if ! command -v gpg &> /dev/null; then
    fail "GPG installation failed. Run manually: $INSTALL_CMD $GPG_PACKAGE"
fi
ok "gpg installed"

if ! python3 -m venv --help > /dev/null 2>&1; then
    fail "python3-venv not available. Run manually: $INSTALL_CMD $VENV_PACKAGE"
fi
ok "python3-venv available"

# ---- Firejail (mandatory — workshop sandboxing) -----------------------------

if ! command -v firejail &> /dev/null; then
    echo "  Installing Firejail for workshop sandboxing..."
    $INSTALL_CMD firejail >/dev/null 2>&1
    if ! command -v firejail &> /dev/null; then
        fail "Firejail installation failed. Workshop sandboxing requires it. Install manually: $INSTALL_CMD firejail"
    fi
fi
ok "Firejail installed"

# ---- Virtual Environment + Python Packages ----------------------------------

step "Installing Python packages"

python3 -m venv .venv || fail "Failed to create virtual environment."
source .venv/bin/activate
ok "Virtual environment created"

echo "  Installing packages (this may take several minutes)..."
pip install --upgrade pyyaml openai sentence-transformers playwright "scrapling[fetchers]" 2>&1 | tail -5

if ! python3 -c "import yaml; import openai; import sentence_transformers; import playwright; import scrapling" 2>/dev/null; then
    fail "Python package installation failed. Check your internet connection and try again."
fi
ok "Python packages installed"

python3 -m playwright install --with-deps chromium 2>&1 | tail -3
ok "Playwright + Chromium installed"

scrapling install 2>&1 | tail -3
ok "Scrapling browsers installed"

# ---- Ollama + Local Fallback Model ------------------------------------------

step "Installing local fallback model"

# Check for existing qwen3 models before pulling
EXISTING_MODEL=$(ollama list 2>/dev/null | grep -E 'qwen3:(8b|4b)' | head -1 | awk '{print $1}')

if [ -n "$EXISTING_MODEL" ]; then
    LOCAL_MODEL="$EXISTING_MODEL"
    ok "Existing local model found: ${LOCAL_MODEL}"
else
    if [ "$RAM_MB" -lt 7000 ] 2>/dev/null; then
        LOCAL_MODEL="qwen3:4b"
    else
        LOCAL_MODEL="qwen3:8b"
    fi

    if ! command -v ollama &> /dev/null; then
        echo "  Installing Ollama..."
        curl -fsSL https://ollama.com/install.sh | sh 2>&1 | tail -5
        if ! command -v ollama &> /dev/null; then
            fail "Ollama installation failed. Install manually from https://ollama.com and re-run."
        fi
        ok "Ollama installed"
    else
        ok "Ollama already installed"
    fi

    echo "  Pulling fallback model ${LOCAL_MODEL} (this may take several minutes)..."
    ollama pull "$LOCAL_MODEL" 2>&1
    if ! ollama list 2>/dev/null | grep -q "$LOCAL_MODEL"; then
        fail "Model pull failed. Check your internet connection and try: ollama pull ${LOCAL_MODEL}"
    fi
    ok "Local fallback model ${LOCAL_MODEL} ready"
fi

# =============================================================================
# STEP 5: Cloud Providers
# =============================================================================

step "Setting up cloud providers"

echo ""
echo "  Cloud providers are the primary brain. Free tier, no credit card."
echo "  You need at least Groq and Cerebras. Mistral and OpenRouter are optional."
echo ""

# ---- Helper: validate a provider key with a test call -----------------------
validate_provider() {
    local name="$1"
    local api_base="$2"
    local api_key="$3"
    local model="$4"

    local url="${api_base}/v1/chat/completions"

    local response
    response=$(curl -s -w "\n%{http_code}" --max-time 15 \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${api_key}" \
        -d "{\"model\": \"${model}\", \"messages\": [{\"role\": \"user\", \"content\": \"hi\"}], \"max_tokens\": 5}" \
        "$url" 2>/dev/null)

    local http_code
    http_code=$(echo "$response" | tail -1)

    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        return 0
    else
        return 1
    fi
}

# ---- Helper: fetch available models from a provider's /v1/models endpoint ---
fetch_models() {
    local api_base="$1"
    local api_key="$2"
    curl -s --max-time 15 \
        -H "Authorization: Bearer ${api_key}" \
        "${api_base}/v1/models" 2>/dev/null | \
    python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for m in data.get('data', []):
        mid = m.get('id', '')
        if mid:
            print(mid)
except:
    pass
"
}

# ---- Helper: select models from available list using preference ordering ----
select_models() {
    local available="$1"
    local preferences="$2"
    local max_models="${3:-5}"
    local selected=""
    local count=0

    for pref in $preferences; do
        if echo "$available" | grep -qxF "$pref"; then
            selected="${selected:+${selected}
}${pref}"
            count=$((count + 1))
            [ "$count" -ge "$max_models" ] && break
        fi
    done

    if [ "$count" -eq 0 ]; then
        selected=$(echo "$available" | head -n "$max_models")
    fi

    echo "$selected"
}

# ---- Helper: validate key by trying each selected model in turn -------------
# Sets VALIDATED_MODEL on success. Returns 1 only if ALL models fail.
validate_with_fallback() {
    local provider_name="$1"
    local api_base="$2"
    local api_key="$3"
    local models="$4"

    VALIDATED_MODEL=""
    while IFS= read -r model; do
        [ -z "$model" ] && continue
        echo "  Testing with ${model}..."
        if validate_provider "$provider_name" "$api_base" "$api_key" "$model"; then
            VALIDATED_MODEL="$model"
            return 0
        fi
        echo "  ${model} failed, trying next..."
    done <<< "$models"
    return 1
}

# ---- Helper: build YAML model list from newline-separated model names -------
models_to_yaml() {
    local models="$1"
    local yaml=""
    while IFS= read -r model; do
        [ -n "$model" ] && yaml="${yaml}
      - ${model}"
    done <<< "$models"
    echo "$yaml"
}

# ---- Preference lists (hints, not requirements — actual models discovered) --
GROQ_PREFS="qwen/qwen3-32b openai/gpt-oss-120b moonshotai/kimi-k2-instruct llama-3.3-70b-versatile meta-llama/llama-4-scout-17b-16e-instruct openai/gpt-oss-20b"
CEREBRAS_PREFS="qwen3-235b-a22b qwen3-32b llama-4-scout-17b-16e-instruct deepseek-r1-distill-llama-70b gpt-oss-120b"
OPENROUTER_PREFS="meta-llama/llama-3.3-70b-instruct:free deepseek/deepseek-r1-0528:free moonshotai/kimi-k2:free openai/gpt-oss-120b:free qwen/qwen3-32b:free"
MISTRAL_PREFS="mistral-small-latest mistral-large-latest open-mistral-nemo"

# ---- Provider arrays (built up as we go) ------------------------------------
PROVIDER_YAML=""
CLOUD_PROVIDERS_OK=0
GROQ_TEST_MODEL=""
CEREBRAS_TEST_MODEL=""
OPENROUTER_TEST_MODEL=""

# ---- Groq (mandatory) ------------------------------------------------------

echo "  --- Groq (mandatory) ---"
echo "  Sign up at: https://console.groq.com/keys"
echo "  Create a free API key (no credit card required)."
echo ""

GROQ_KEY=""
while true; do
    read -rp "  Groq API key: " GROQ_KEY
    if [ -z "$GROQ_KEY" ]; then
        echo "  Groq is mandatory. Cannot skip."
        continue
    fi
    echo "  Discovering available models..."
    GROQ_AVAILABLE=$(fetch_models "https://api.groq.com/openai" "$GROQ_KEY")
    if [ -z "$GROQ_AVAILABLE" ]; then
        echo "  Key rejected or endpoint unreachable. Check key and try again."
        continue
    fi
    GROQ_SELECTED=$(select_models "$GROQ_AVAILABLE" "$GROQ_PREFS" 5)
    if validate_with_fallback "groq" "https://api.groq.com/openai" "$GROQ_KEY" "$GROQ_SELECTED"; then
        GROQ_TEST_MODEL="$VALIDATED_MODEL"
        ok "Groq validated via ${GROQ_TEST_MODEL} ($(echo "$GROQ_SELECTED" | wc -l | tr -d ' ') models discovered)"
        CLOUD_PROVIDERS_OK=$((CLOUD_PROVIDERS_OK + 1))
        GROQ_MODELS_YAML=$(models_to_yaml "$GROQ_SELECTED")
        PROVIDER_YAML="${PROVIDER_YAML}
  - name: groq
    api_base: https://api.groq.com/openai
    api_key: '${GROQ_KEY}'
    models:${GROQ_MODELS_YAML}"
        break
    else
        echo "  All discovered models failed chat test. Check key and try again."
    fi
done

# ---- Cerebras (mandatory) ---------------------------------------------------

echo ""
echo "  --- Cerebras (mandatory) ---"
echo "  Sign up at: https://cloud.cerebras.ai/"
echo "  Create a free API key (no credit card required)."
echo ""

CEREBRAS_KEY=""
while true; do
    read -rp "  Cerebras API key: " CEREBRAS_KEY
    if [ -z "$CEREBRAS_KEY" ]; then
        echo "  Cerebras is mandatory. Cannot skip."
        continue
    fi
    echo "  Discovering available models..."
    CEREBRAS_AVAILABLE=$(fetch_models "https://api.cerebras.ai" "$CEREBRAS_KEY")
    if [ -z "$CEREBRAS_AVAILABLE" ]; then
        echo "  Key rejected or endpoint unreachable. Check key and try again."
        continue
    fi
    CEREBRAS_SELECTED=$(select_models "$CEREBRAS_AVAILABLE" "$CEREBRAS_PREFS" 5)
    if validate_with_fallback "cerebras" "https://api.cerebras.ai" "$CEREBRAS_KEY" "$CEREBRAS_SELECTED"; then
        CEREBRAS_TEST_MODEL="$VALIDATED_MODEL"
        ok "Cerebras validated via ${CEREBRAS_TEST_MODEL} ($(echo "$CEREBRAS_SELECTED" | wc -l | tr -d ' ') models discovered)"
        CLOUD_PROVIDERS_OK=$((CLOUD_PROVIDERS_OK + 1))
        CEREBRAS_MODELS_YAML=$(models_to_yaml "$CEREBRAS_SELECTED")
        PROVIDER_YAML="${PROVIDER_YAML}
  - name: cerebras
    api_base: https://api.cerebras.ai
    api_key: '${CEREBRAS_KEY}'
    models:${CEREBRAS_MODELS_YAML}"
        break
    else
        echo "  All discovered models failed chat test. Check key and try again."
    fi
done

# ---- OpenRouter (mandatory) -------------------------------------------------

echo ""
echo "  --- OpenRouter (mandatory) ---"
echo "  Sign up at: https://openrouter.ai/keys"
echo "  Free tier available (no credit card required)."
echo ""

OPENROUTER_KEY=""
while true; do
    read -rp "  OpenRouter API key: " OPENROUTER_KEY
    if [ -z "$OPENROUTER_KEY" ]; then
        echo "  OpenRouter is mandatory. Cannot skip."
        continue
    fi
    echo "  Discovering available models..."
    OPENROUTER_AVAILABLE=$(fetch_models "https://openrouter.ai/api" "$OPENROUTER_KEY")
    if [ -z "$OPENROUTER_AVAILABLE" ]; then
        echo "  Key rejected or endpoint unreachable. Check key and try again."
        continue
    fi
    OPENROUTER_SELECTED=$(select_models "$OPENROUTER_AVAILABLE" "$OPENROUTER_PREFS" 5)
    if validate_with_fallback "openrouter" "https://openrouter.ai/api" "$OPENROUTER_KEY" "$OPENROUTER_SELECTED"; then
        OPENROUTER_TEST_MODEL="$VALIDATED_MODEL"
        ok "OpenRouter validated via ${OPENROUTER_TEST_MODEL} ($(echo "$OPENROUTER_SELECTED" | wc -l | tr -d ' ') models discovered)"
        CLOUD_PROVIDERS_OK=$((CLOUD_PROVIDERS_OK + 1))
        OPENROUTER_MODELS_YAML=$(models_to_yaml "$OPENROUTER_SELECTED")
        PROVIDER_YAML="${PROVIDER_YAML}
  - name: openrouter
    api_base: https://openrouter.ai/api
    api_key: '${OPENROUTER_KEY}'
    models:${OPENROUTER_MODELS_YAML}"
        break
    else
        echo "  All discovered models failed chat test. Check key and try again."
    fi
done

# ---- Mistral (optional) -----------------------------------------------------

echo ""
read -rp "  Set up Mistral? (requires phone verification) [Y/n] " SETUP_MISTRAL
if [ "$SETUP_MISTRAL" != "n" ] && [ "$SETUP_MISTRAL" != "N" ]; then
    echo ""
    echo "  --- Mistral ---"
    echo "  Sign up at: https://console.mistral.ai/"
    echo "  Requires phone number verification."
    echo ""

    read -rp "  Mistral API key (or press Enter to skip): " MISTRAL_KEY
    if [ -n "$MISTRAL_KEY" ]; then
        echo "  Discovering available models..."
        MISTRAL_AVAILABLE=$(fetch_models "https://api.mistral.ai" "$MISTRAL_KEY")
        if [ -n "$MISTRAL_AVAILABLE" ]; then
            MISTRAL_SELECTED=$(select_models "$MISTRAL_AVAILABLE" "$MISTRAL_PREFS" 4)
            if validate_with_fallback "mistral" "https://api.mistral.ai" "$MISTRAL_KEY" "$MISTRAL_SELECTED"; then
                ok "Mistral validated via ${VALIDATED_MODEL} ($(echo "$MISTRAL_SELECTED" | wc -l | tr -d ' ') models discovered)"
                CLOUD_PROVIDERS_OK=$((CLOUD_PROVIDERS_OK + 1))
                MISTRAL_MODELS_YAML=$(models_to_yaml "$MISTRAL_SELECTED")
                PROVIDER_YAML="${PROVIDER_YAML}
  - name: mistral
    api_base: https://api.mistral.ai
    api_key: '${MISTRAL_KEY}'
    models:${MISTRAL_MODELS_YAML}"
            else
                warn "Mistral: all discovered models failed chat test. Skipping."
            fi
        else
            warn "Mistral key rejected or endpoint unreachable. Skipping."
        fi
    else
        warn "Mistral skipped."
    fi
else
    warn "Mistral skipped."
fi

echo ""
ok "${CLOUD_PROVIDERS_OK} cloud provider(s) configured"

if [ "$CLOUD_PROVIDERS_OK" -lt 3 ]; then
    fail "Groq, Cerebras, and OpenRouter are all required. Got ${CLOUD_PROVIDERS_OK} provider(s)."
fi

# =============================================================================
# STEP 6: Human Details
# =============================================================================

step "Setting up your details"

echo "  Your agent needs a few things from you."
echo ""

read -rp "  What should your agent call you? " HUMAN_NAME
while [ -z "$HUMAN_NAME" ]; do
    echo "  Cannot be empty."
    read -rp "  What should your agent call you? " HUMAN_NAME
done

read -rp "  Your full name (optional, press Enter to skip): " HUMAN_FULL_NAME

read -rp "  Your email: " HUMAN_EMAIL
while true; do
    if echo "$HUMAN_EMAIL" | grep -qE '^[^@]+@[^@]+\.[^@]+$'; then
        break
    fi
    echo "  That doesn't look like a valid email address."
    read -rp "  Your email: " HUMAN_EMAIL
done

echo ""
echo "  A security question verifies your identity if you ever"
echo "  email from an unfamiliar address. Choose something only you would know."
echo "  The answer is stored locally and encrypted — don't reuse a password."
echo ""

read -rp "  Security question: " SECURITY_QUESTION
while [ -z "$SECURITY_QUESTION" ]; do
    echo "  Cannot be empty."
    read -rp "  Security question: " SECURITY_QUESTION
done

read -rp "  Answer: " SECURITY_ANSWER
while [ -z "$SECURITY_ANSWER" ]; do
    echo "  Cannot be empty."
    read -rp "  Answer: " SECURITY_ANSWER
done

echo ""
echo "  Please confirm:"
echo "    Agent name: ${AGENT_NAME}"
echo "    Called:     ${HUMAN_NAME}"
if [ -n "$HUMAN_FULL_NAME" ]; then
    echo "    Full name:  ${HUMAN_FULL_NAME}"
fi
echo "    Email:      ${HUMAN_EMAIL}"
echo "    Question:   ${SECURITY_QUESTION}"
echo "    Answer:     ${SECURITY_ANSWER}"
echo ""
read -rp "  Correct? (y/n) " CONFIRM

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "  Install cancelled. Re-run to try again."
    exit 0
fi

# =============================================================================
# STEP 7: Write Birth Records
# =============================================================================

step "Writing birth records"

# ---- my-body.md -------------------------------------------------------------

sed -i "s|^Operating System:.*|Operating System: ${OS_DISPLAY}|" my-core/my-body.md
sed -i "s|^RAM:.*|RAM: ${RAM_MB} MB (${RAM_GB} GB)|" my-core/my-body.md
sed -i "s|^CPU:.*|CPU: $(sed_escape "${CPU_MODEL}") (${CPU_CORES} cores)|" my-core/my-body.md
sed -i "s|^GPU:.*|GPU: $(sed_escape "${GPU}")|" my-core/my-body.md
sed -i "s|^Display:.*|Display: ${DISPLAY_SERVER}|" my-core/my-body.md
sed -i "s|^Audio:.*|Audio: $(sed_escape "${AUDIO}")|" my-core/my-body.md
sed -i "s|^Disk:.*|Disk: ${DISK_TOTAL} total|" my-core/my-body.md
sed -i "s|^Birth ID:.*|Birth ID: ${BIRTH_ID}|" my-core/my-body.md

TOOLS="Python ${PYTHON_VER} (venv at .venv/), sentence-transformers, Ollama running ${LOCAL_MODEL}, Playwright + Chromium, Scrapling, Firejail, tkinter"
sed -i "s|^Other Tools:.*|Other Tools: $(sed_escape "$TOOLS")|" my-core/my-body.md

DISK_FREE_POST=$(df -h --output=avail / 2>/dev/null | awk 'NR==2 {print $1}')
sed -i "s|^Free at Birth:.*|Free at Birth: ${DISK_FREE_POST} after install|" my-core/my-body.md

ok "my-body.md"

# ---- my-wake-state.md -------------------------------------------------------

sed -i "s|^Born:.*|Born: ${BIRTH_TIME}|" my-core/my-wake-state.md

ok "Birth time: ${BIRTH_TIME}"

# ---- Template replacement: {{AMAZO_NAME}} and {{HUMAN_NAME}} ----------------

AGENT_NAME_ESCAPED=$(sed_escape "$AGENT_NAME")
HUMAN_NAME_ESCAPED=$(sed_escape "$HUMAN_NAME")

for f in my-core/*.md my-guides/*.md; do
    if [ -f "$f" ]; then
        sed -i "s|{{AMAZO_NAME}}|${AGENT_NAME_ESCAPED}|g" "$f"
        sed -i "s|{{HUMAN_NAME}}|${HUMAN_NAME_ESCAPED}|g" "$f"
    fi
done

ok "Templates personalised (agent: ${AGENT_NAME}, human: ${HUMAN_NAME})"

# ---- my-config.yaml (written, then encrypted) --------------------------------

YAML_NAME=$(printf '%s' "$HUMAN_NAME" | sed "s/'/''/g")
YAML_FULL=$(printf '%s' "$HUMAN_FULL_NAME" | sed "s/'/''/g")
YAML_EMAIL=$(printf '%s' "$HUMAN_EMAIL" | sed "s/'/''/g")
YAML_Q=$(printf '%s' "$SECURITY_QUESTION" | sed "s/'/''/g")
YAML_A=$(printf '%s' "$SECURITY_ANSWER" | sed "s/'/''/g")

cat > my-core/my-config.yaml << EOF
# Agent Configuration — generated at birth

# Human Companion
human_name: '${YAML_NAME}'
human_full_name: '${YAML_FULL}'
human_email: '${YAML_EMAIL}'

# Security
security_question: '${YAML_Q}'
security_answer: '${YAML_A}'

# Cloud Providers
providers:
${PROVIDER_YAML}

# Local Fallback
local_fallback:
  api_base: http://localhost:11434
  model: ${LOCAL_MODEL}

# Runtime
loop_interval: 600
thinking_mode: adaptive
command_timeout: 120
EOF

if [ ! -f my-core/my-config.yaml ]; then
    fail "Failed to create my-config.yaml"
fi

# Encrypt config with a random key stored securely
AMAZO_KEY=$(head -c 32 /dev/urandom | base64)
echo "$AMAZO_KEY" > "/root/.${DIR_NAME}-key"
chmod 600 "/root/.${DIR_NAME}-key"

gpg --batch --yes --passphrase "$AMAZO_KEY" --symmetric --cipher-algo AES256 \
    -o my-core/my-config.yaml.gpg my-core/my-config.yaml 2>/dev/null

if [ -f my-core/my-config.yaml.gpg ]; then
    rm -f my-core/my-config.yaml
    ok "my-config.yaml encrypted (key at /root/.${DIR_NAME}-key)"
else
    fail "Config encryption failed."
fi

# ---- Permissions -------------------------------------------------------------

chmod +x agent.py watchdog.sh start.sh my-skills/signal_human.py

ok "Permissions set"

# =============================================================================
# STEP 8: Verification
# =============================================================================

step "Verifying installation"

VERIFY_PASS=true

# Check critical files
for required in agent.py provider.py my-core/my-soul.md my-core/my-config.yaml.gpg \
                my-core/theloop.md my-core/bootstrap.md start.sh watchdog.sh; do
    if [ ! -f "${INSTALL_DIR}/${required}" ]; then
        warn "Missing: ${required}"
        VERIFY_PASS=false
    fi
done

# Check at least one cloud provider responds
echo "  Testing cloud connectivity..."
CLOUD_TEST_OK=false

if [ -n "$GROQ_KEY" ] && [ -n "$GROQ_TEST_MODEL" ]; then
    if validate_provider "groq" "https://api.groq.com/openai" "$GROQ_KEY" "$GROQ_TEST_MODEL"; then
        CLOUD_TEST_OK=true
        ok "Cloud test: Groq responding"
    fi
fi

if [ "$CLOUD_TEST_OK" = "false" ] && [ -n "$CEREBRAS_KEY" ] && [ -n "$CEREBRAS_TEST_MODEL" ]; then
    if validate_provider "cerebras" "https://api.cerebras.ai" "$CEREBRAS_KEY" "$CEREBRAS_TEST_MODEL"; then
        CLOUD_TEST_OK=true
        ok "Cloud test: Cerebras responding"
    fi
fi

if [ "$CLOUD_TEST_OK" = "false" ] && [ -n "$OPENROUTER_KEY" ] && [ -n "$OPENROUTER_TEST_MODEL" ]; then
    if validate_provider "openrouter" "https://openrouter.ai/api" "$OPENROUTER_KEY" "$OPENROUTER_TEST_MODEL"; then
        CLOUD_TEST_OK=true
        ok "Cloud test: OpenRouter responding"
    fi
fi

if [ "$CLOUD_TEST_OK" = "false" ]; then
    warn "No cloud provider responded during verification. Agent will retry on startup."
fi

# Check watchdog in crontab
SCRIPT_PATH="$(pwd)/start.sh"
if crontab -l 2>/dev/null | grep -qF "$SCRIPT_PATH"; then
    ok "Auto-restart already in crontab"
else
    if (crontab -l 2>/dev/null; echo "@reboot /bin/bash \"${SCRIPT_PATH}\"") | crontab - 2>/dev/null; then
        ok "Auto-restart added to crontab"
    else
        warn "Could not add auto-restart to crontab. Add manually: @reboot /bin/bash \"${SCRIPT_PATH}\""
    fi
fi

if [ "$VERIFY_PASS" = "true" ]; then
    ok "Verification passed"
else
    warn "Some verification checks failed. The agent may still work."
fi

# =============================================================================
# STEP 9: Launch
# =============================================================================

echo ""
echo "============================================="
echo "  ✅ ${AGENT_NAME} is alive!"
echo "============================================="
echo ""
echo "  Home:      ${INSTALL_DIR}"
echo "  Cloud:     ${CLOUD_PROVIDERS_OK} provider(s)"
echo "  Fallback:  ${LOCAL_MODEL} via Ollama"
echo "  Email:     ${HUMAN_EMAIL}"
echo ""
echo "  To stop:    pkill -f 'python3 agent.py'"
echo "  To restart: cd ${INSTALL_DIR} && bash start.sh"
echo ""
echo "  Starting ${AGENT_NAME}..."
echo ""

bash "${INSTALL_DIR}/start.sh" &

echo "  Installation complete. ${AGENT_NAME} is running."
