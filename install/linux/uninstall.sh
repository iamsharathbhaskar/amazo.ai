#!/bin/bash
# =============================================================================
# Amazo Uninstaller
# Removes an Amazo agent: stops processes, removes cron, deletes key & files.
# =============================================================================

ok()   { echo "  ✓ $1"; }
warn() { echo "  ⚠ $1"; }

echo ""
echo "============================================="
echo "  Amazo Uninstaller"
echo "============================================="
echo ""

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~${REAL_USER}")

# If an argument is passed, treat it as the agent directory
if [ -n "$1" ] && [ -d "$1" ]; then
    AGENT_DIR="$(cd "$1" && pwd)"
else
    # If run from inside an agent directory, offer to uninstall it
    if [ -f "$(pwd)/agent.py" ] && [ -d "$(pwd)/my-core" ]; then
        AGENT_DIR="$(pwd)"
    else
        # Scan for agents
        AGENTS=()
        SCAN_DIRS=("$REAL_HOME" "$HOME")
        for scan_dir in "${SCAN_DIRS[@]}"; do
            [ -d "$scan_dir" ] || continue
            for candidate in "$scan_dir"/*/; do
                [ -d "$candidate" ] || continue
                if [ -f "${candidate}agent.py" ] && [ -d "${candidate}my-core" ] && [ -f "${candidate}my-core/my-soul.md" ]; then
                    abs_path=$(cd "$candidate" && pwd)
                    already=false
                    for e in "${AGENTS[@]}"; do
                        [ "$e" = "$abs_path" ] && already=true && break
                    done
                    $already || AGENTS+=("$abs_path")
                fi
            done
        done

        if [ ${#AGENTS[@]} -eq 0 ]; then
            echo "  No Amazo agents found."
            exit 0
        fi

        echo "  Found agents:"
        for i in "${!AGENTS[@]}"; do
            echo "    $((i+1)). $(basename "${AGENTS[$i]}")  (${AGENTS[$i]})"
        done
        echo ""
        read -rp "  Which agent to uninstall? (1-${#AGENTS[@]}, or q to quit): " CHOICE

        if [ "$CHOICE" = "q" ] || [ "$CHOICE" = "Q" ]; then
            echo "  Cancelled."
            exit 0
        fi

        if [ -z "$CHOICE" ] || [ "$CHOICE" -lt 1 ] 2>/dev/null || [ "$CHOICE" -gt ${#AGENTS[@]} ] 2>/dev/null; then
            echo "  Invalid selection."
            exit 1
        fi

        AGENT_DIR="${AGENTS[$((CHOICE-1))]}"
    fi
fi

DIR_NAME=$(basename "$AGENT_DIR")

echo ""
echo "  Agent:     ${DIR_NAME}"
echo "  Location:  ${AGENT_DIR}"
echo ""
echo "  This will:"
echo "    - Stop the running agent"
echo "    - Remove its cron entry"
echo "    - Delete the encryption key (~/.${DIR_NAME}-key)"
echo "    - Delete the entire agent directory"
echo ""
read -rp "  Are you sure? Type 'yes' to confirm: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "  Uninstall cancelled."
    exit 0
fi

echo ""

# Stop running processes
echo "  Stopping agent..."
pkill -f "python3 ${AGENT_DIR}/agent.py" 2>/dev/null
pkill -f "${AGENT_DIR}/watchdog.sh" 2>/dev/null
sleep 1
ok "Processes stopped"

# Remove cron entry
CRON_PATH="${AGENT_DIR}/start.sh"
if crontab -u "$REAL_USER" -l 2>/dev/null | grep -qF "$CRON_PATH"; then
    (crontab -u "$REAL_USER" -l 2>/dev/null | grep -vF "$CRON_PATH") | crontab -u "$REAL_USER" - 2>/dev/null
    ok "Cron entry removed for ${REAL_USER}"
fi
if crontab -l 2>/dev/null | grep -qF "$CRON_PATH"; then
    (crontab -l 2>/dev/null | grep -vF "$CRON_PATH") | crontab - 2>/dev/null
    ok "Cron entry removed for root"
fi

# Remove key files
for key_path in "${REAL_HOME}/.${DIR_NAME}-key" "/root/.${DIR_NAME}-key" "/var/root/.${DIR_NAME}-key"; do
    if [ -f "$key_path" ]; then
        rm -f "$key_path"
        ok "Removed key: ${key_path}"
    fi
done

# Remove agent directory
rm -rf "$AGENT_DIR"
ok "Removed: ${AGENT_DIR}"

# Check if any other agents remain
REMAINING=0
for scan_dir in "$REAL_HOME" "$HOME"; do
    [ -d "$scan_dir" ] || continue
    for candidate in "$scan_dir"/*/; do
        [ -d "$candidate" ] || continue
        if [ -f "${candidate}agent.py" ] && [ -d "${candidate}my-core" ]; then
            REMAINING=$((REMAINING + 1))
        fi
    done
done

if [ "$REMAINING" -eq 0 ]; then
    echo ""
    read -rp "  No other agents remain. Remove Ollama too? [y/N] " REMOVE_OLLAMA
    if [ "$REMOVE_OLLAMA" = "y" ] || [ "$REMOVE_OLLAMA" = "Y" ]; then
        systemctl stop ollama 2>/dev/null
        systemctl disable ollama 2>/dev/null
        rm -f /usr/local/bin/ollama 2>/dev/null
        rm -rf /usr/share/ollama 2>/dev/null
        userdel ollama 2>/dev/null
        groupdel ollama 2>/dev/null
        ok "Ollama removed"
    fi
fi

echo ""
echo "  ${DIR_NAME} has been uninstalled."
echo ""
