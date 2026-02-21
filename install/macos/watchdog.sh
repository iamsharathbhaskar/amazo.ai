#!/bin/bash
# =============================================================================
# Amazo Watchdog — macOS
# Runs agent.py in the foreground and restarts it if it crashes or hangs.
# =============================================================================

cd "$(dirname "$0")" || exit 1

HEARTBEAT_FILE="my-core/my-heartbeat.txt"
HEARTBEAT_TIMEOUT=1800
CHECK_INTERVAL=60

while true; do

    # Background heartbeat monitor
    (
        while true; do
            sleep "$CHECK_INTERVAL"
            if [ -f "$HEARTBEAT_FILE" ]; then
                age=$(( $(date +%s) - $(stat -f %m "$HEARTBEAT_FILE" 2>/dev/null || echo 0) ))
                if [ "$age" -gt "$HEARTBEAT_TIMEOUT" ]; then
                    echo ""
                    echo "[watchdog] Heartbeat stale (${age}s). Restarting agent..."
                    pkill -f "python3 agent.py"
                    exit 0
                fi
            fi
        done
    ) &
    MONITOR_PID=$!

    python3 agent.py
    EXIT_CODE=$?

    kill "$MONITOR_PID" 2>/dev/null
    wait "$MONITOR_PID" 2>/dev/null

    echo ""
    echo "[watchdog] agent.py exited (code: ${EXIT_CODE}). Restarting in 5 seconds..."
    sleep 5

done