#!/bin/bash
# =============================================================================
# Start Amazo — macOS
# Opens a dedicated Terminal.app window and starts Amazo.
# Run after install, after a reboot, or after a manual stop.
# =============================================================================

cd "$(dirname "$0")" || exit 1

# Activate virtual environment
if [ -d .venv ]; then
    source .venv/bin/activate
fi

# Set up launchd auto-restart if not already present
PLIST_PATH="$HOME/Library/LaunchAgents/com.amazo.start.plist"
if [ ! -f "$PLIST_PATH" ]; then
    AMAZO_DIR="$(pwd)"
    cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.amazo.start</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${AMAZO_DIR}/start.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF
    launchctl load "$PLIST_PATH" 2>/dev/null
    echo "Auto-restart on login: enabled"
fi

# If already in a terminal, run the watchdog directly
if [ -t 1 ]; then
    exec bash watchdog.sh
fi

# Open a dedicated Terminal.app window
AMAZO_DIR="$(pwd)"
if ! osascript -e "tell application \"Terminal\" to do script \"cd '${AMAZO_DIR}' && if [ -d .venv ]; then source .venv/bin/activate; fi && bash watchdog.sh\"" 2>/dev/null; then
    echo "Could not open Terminal.app. Running headless."
    echo "Logs: ${AMAZO_DIR}/amazo.log"
    bash watchdog.sh >> amazo.log 2>&1 &
fi