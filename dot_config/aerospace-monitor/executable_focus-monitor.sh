#!/bin/bash
DIRECTION="$1"
STATE_FILE="$HOME/.config/aerospace-monitor/window-focus.json"
LOCK_FILE="$HOME/.config/aerospace-monitor/switching.lock"

# Get current monitor and find target monitor's visible workspace
CURRENT_MONITOR=$(/opt/homebrew/bin/aerospace list-monitors --focused --format '%{monitor-id}')
ALL_MONITORS=$(/opt/homebrew/bin/aerospace list-monitors --format '%{monitor-id}')

# Find the other monitor (assumes 2 monitors)
TARGET_MONITOR=""
for m in $ALL_MONITORS; do
    if [[ "$m" != "$CURRENT_MONITOR" ]]; then
        TARGET_MONITOR="$m"
        break
    fi
done

# Get visible workspace on target monitor
TARGET_WORKSPACE=""
if [[ -n "$TARGET_MONITOR" ]]; then
    TARGET_WORKSPACE=$(/opt/homebrew/bin/aerospace list-workspaces --monitor "$TARGET_MONITOR" --visible)
fi

# Read target window BEFORE switching (avoids race with on-focus-changed)
WINDOW_ID=""
if [[ -f "$STATE_FILE" && -n "$TARGET_WORKSPACE" ]]; then
    WINDOW_ID=$(jq -r ".workspaces[\"$TARGET_WORKSPACE\"].windowId // empty" "$STATE_FILE" 2>/dev/null)
fi

# Create lock to prevent track-focus from recording intermediate states
touch "$LOCK_FILE"

/opt/homebrew/bin/aerospace focus-monitor --wrap-around "$DIRECTION"

if [[ -n "$WINDOW_ID" ]]; then
    sleep 0.05
    /opt/homebrew/bin/aerospace focus --window-id "$WINDOW_ID" 2>/dev/null
fi

# Remove lock after switch completes
sleep 0.1
rm -f "$LOCK_FILE"
