#!/bin/bash
# =============================================================================
# Amazo Clone Kit Installer — Linux
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

# RAM check — 8 GB minimum (7000 MB to account for kernel reservation on older machines)
if ! [ "$RAM_MB" -eq "$RAM_MB" ] 2>/dev/null || [ "$RAM_MB" -lt 7000 ] 2>/dev/null; then
    fail "Amazo requires at least 8 GB of RAM. This machine has ${RAM_MB} MB."
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
# STEP 2: Create Amazo's Home
# =============================================================================

step "Creating Amazo's home"

INSTALL_DIR="${HOME}/amazo"

if [ -f "${INSTALL_DIR}/my-core/my-config.yaml.gpg" ] || [ -f "${INSTALL_DIR}/my-core/my-config.yaml" ]; then
    echo ""
    echo "  Amazo already lives at ${INSTALL_DIR}."
    echo "  To reinstall, remove the directory first:"
    echo "    rm -rf ${INSTALL_DIR}"
    echo ""
    fail "Refusing to overwrite a living Amazo."
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Create empty working directories
mkdir -p "${INSTALL_DIR}"/{my-journals,my-archive,my-contacts,my-workshop,my-projects,my-post-its,proposed}

# Copy project files (not the install folder)
cp -a "$SOURCE_DIR"/my-core "${INSTALL_DIR}/"
cp -a "$SOURCE_DIR"/my-guides "${INSTALL_DIR}/"
cp -a "$SOURCE_DIR"/my-skills "${INSTALL_DIR}/"
cp "$SOURCE_DIR"/agent.py "${INSTALL_DIR}/"
cp "$SOURCE_DIR"/README.md "${INSTALL_DIR}/"

# Copy Linux-specific scripts
cp "$SCRIPT_DIR"/start.sh "${INSTALL_DIR}/"
cp "$SCRIPT_DIR"/watchdog.sh "${INSTALL_DIR}/"

# Verify critical files
MISSING_FILES=false
for required in my-core/my-soul.md my-core/my-personality.md my-core/my-wakeup-prompt.md \
                my-core/theloop.md my-core/my-wake-state.md my-core/my-body.md \
                my-core/my-post-its.md my-core/bootstrap.md \
                agent.py start.sh watchdog.sh; do
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
# STEP 3: Install Everything
# =============================================================================

# ---- System Packages --------------------------------------------------------

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

# ---- Virtual Environment + Python Packages ----------------------------------

step "Installing Python packages"

python3 -m venv .venv || fail "Failed to create virtual environment."
source .venv/bin/activate
ok "Virtual environment created"

echo "  Installing packages (this may take several minutes)..."
pip install --upgrade pyyaml openai sentence-transformers playwright 2>&1 | tail -5

if ! python3 -c "import yaml; import openai; import sentence_transformers; import playwright" 2>/dev/null; then
    fail "Python package installation failed. Check your internet connection and try again."
fi
ok "Python packages installed"

python3 -m playwright install --with-deps chromium 2>&1 | tail -3
ok "Playwright + Chromium installed"

# ---- Ollama + Model ---------------------------------------------------------

step "Installing language model"

if [ "$RAM_MB" -lt 12000 ] 2>/dev/null; then
    MODEL="qwen2.5:7b"
    MAX_CONTEXT=16384
elif [ "$RAM_MB" -lt 24000 ] 2>/dev/null; then
    MODEL="qwen2.5:14b"
    MAX_CONTEXT=16384
else
    MODEL="qwen2.5:14b"
    MAX_CONTEXT=32768
fi

ok "Model: ${MODEL} (${RAM_GB} GB RAM, context: ${MAX_CONTEXT} tokens)"

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

echo "  Pulling model ${MODEL} (this may take several minutes)..."
ollama pull "$MODEL" 2>&1
if ! ollama list 2>/dev/null | grep -q "$MODEL"; then
    fail "Model pull failed. Check your internet connection and try: ollama pull ${MODEL}"
fi
ok "Model ${MODEL} ready"

# =============================================================================
# STEP 4: Human Details
# =============================================================================

step "Setting up your details"

echo "  Amazo needs a few things from you."
echo ""

read -rp "  What should your Amazo call you? " HUMAN_NAME
while [ -z "$HUMAN_NAME" ]; do
    echo "  Cannot be empty."
    read -rp "  What should your Amazo call you? " HUMAN_NAME
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
echo "  Amazo uses a security question to verify your identity if you ever"
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
echo "    Called:    ${HUMAN_NAME}"
if [ -n "$HUMAN_FULL_NAME" ]; then
    echo "    Full name: ${HUMAN_FULL_NAME}"
fi
echo "    Email:    ${HUMAN_EMAIL}"
echo "    Question: ${SECURITY_QUESTION}"
echo "    Answer:   ${SECURITY_ANSWER}"
echo ""
read -rp "  Correct? (y/n) " CONFIRM

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "  Install cancelled. Re-run to try again."
    exit 0
fi

# =============================================================================
# STEP 5: Write Birth Records
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

TOOLS="Python ${PYTHON_VER} (venv at .venv/), sentence-transformers, Ollama running ${MODEL}, Playwright + Chromium, tkinter"
sed -i "s|^Other Tools:.*|Other Tools: $(sed_escape "$TOOLS")|" my-core/my-body.md

DISK_FREE_POST=$(df -h --output=avail / 2>/dev/null | awk 'NR==2 {print $1}')
sed -i "s|^Free at Birth:.*|Free at Birth: ${DISK_FREE_POST} after install|" my-core/my-body.md

ok "my-body.md"

# ---- my-wake-state.md -------------------------------------------------------

sed -i "s|^Born:.*|Born: ${BIRTH_TIME}|" my-core/my-wake-state.md

ok "Birth time: ${BIRTH_TIME}"

# ---- my-config.yaml (written, then encrypted) --------------------------------

YAML_NAME=$(printf '%s' "$HUMAN_NAME" | sed "s/'/''/g")
YAML_FULL=$(printf '%s' "$HUMAN_FULL_NAME" | sed "s/'/''/g")
YAML_EMAIL=$(printf '%s' "$HUMAN_EMAIL" | sed "s/'/''/g")
YAML_Q=$(printf '%s' "$SECURITY_QUESTION" | sed "s/'/''/g")
YAML_A=$(printf '%s' "$SECURITY_ANSWER" | sed "s/'/''/g")

cat > my-core/my-config.yaml << EOF
# Amazo Configuration — generated at birth

# LLM Provider
provider: ollama
model: ${MODEL}
api_base: http://localhost:11434
max_context_tokens: ${MAX_CONTEXT}

# Human Companion
human_name: '${YAML_NAME}'
human_full_name: '${YAML_FULL}'
human_email: '${YAML_EMAIL}'

# Security
security_question: '${YAML_Q}'
security_answer: '${YAML_A}'

# Runtime
loop_interval: 300
thinking_mode: adaptive
command_timeout: 120
EOF

if [ ! -f my-core/my-config.yaml ]; then
    fail "Failed to create my-config.yaml"
fi

# Encrypt config with a random key stored securely
AMAZO_KEY=$(head -c 32 /dev/urandom | base64)
echo "$AMAZO_KEY" > /root/.amazo-key
chmod 600 /root/.amazo-key

gpg --batch --yes --passphrase "$AMAZO_KEY" --symmetric --cipher-algo AES256 \
    -o my-core/my-config.yaml.gpg my-core/my-config.yaml 2>/dev/null

if [ -f my-core/my-config.yaml.gpg ]; then
    rm -f my-core/my-config.yaml
    ok "my-config.yaml encrypted (key at /root/.amazo-key)"
else
    fail "Config encryption failed."
fi

# ---- Template replacement ----------------------------------------------------

HUMAN_NAME_ESCAPED=$(sed_escape "$HUMAN_NAME")
for f in my-core/*.md my-guides/*.md; do
    if [ -f "$f" ]; then
        sed -i "s|{{HUMAN_NAME}}|${HUMAN_NAME_ESCAPED}|g" "$f"
        sed -i "s|{{AMAZO_NAME}}|Amazo|g" "$f"
    fi
done

ok "Templates personalised"

# ---- Permissions -------------------------------------------------------------

chmod +x agent.py watchdog.sh start.sh my-skills/signal_human.py

ok "Permissions set"

# =============================================================================
# STEP 6: Start Amazo
# =============================================================================

echo ""
echo "============================================="
echo "  ✅ Amazo is alive!"
echo "============================================="
echo ""
echo "  Home:  ${INSTALL_DIR}"
echo "  Model: ${MODEL} (context: ${MAX_CONTEXT} tokens)"
echo "  Email: ${HUMAN_EMAIL}"
echo ""
echo "  To stop:    pkill -f 'python3 agent.py'"
echo "  To restart: cd ${INSTALL_DIR} && bash start.sh"
echo ""
echo "  Starting Amazo..."
echo ""

bash "${INSTALL_DIR}/start.sh" &

echo "  Installation complete. Amazo is running."