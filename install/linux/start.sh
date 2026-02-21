#!/bin/bash
# =============================================================================
# Start Amazo — Linux
# Opens a dedicated terminal and starts Amazo.
# Run after install, after a reboot, or after a manual stop.
# =============================================================================

cd "$(dirname "$0")" || exit 1

# Activate virtual environment
if [ -d .venv ]; then
    source .venv/bin/activate
fi

# Set up cron auto-restart if not already present
SCRIPT_PATH="$(pwd)/start.sh"
if ! crontab -l 2>/dev/null | grep -qF "$SCRIPT_PATH"; then
    if (crontab -l 2>/dev/null; echo "@reboot /bin/bash \"${SCRIPT_PATH}\"") | crontab - 2>/dev/null; then
        echo "Auto-restart on reboot: enabled"
    fi
fi

# If already in a terminal, run the watchdog directly
if [ -t 1 ]; then
    exec bash watchdog.sh
fi

# Open a dedicated terminal window
AMAZO_DIR="$(pwd)"
LAUNCH_CMD="cd '${AMAZO_DIR}' && if [ -d .venv ]; then source .venv/bin/activate; fi && bash watchdog.sh"

if command -v xterm &> /dev/null; then
    xterm -title "Amazo" -e bash -c "$LAUNCH_CMD" &
elif command -v gnome-terminal &> /dev/null; then
    gnome-terminal --title="Amazo" -- bash -c "$LAUNCH_CMD" &
elif command -v konsole &> /dev/null; then
    konsole -e bash -c "$LAUNCH_CMD" &
elif command -v xfce4-terminal &> /dev/null; then
    xfce4-terminal --title="Amazo" -e "bash -c \"$LAUNCH_CMD\"" &
else
    echo "No terminal emulator found. Running headless."
    echo "Logs: ${AMAZO_DIR}/amazo.log"
    bash watchdog.sh >> amazo.log 2>&1 &
fi