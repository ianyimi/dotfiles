#!/bin/bash
WORKSPACE="$1"
STATE_FILE="$HOME/.config/aerospace-monitor/window-focus.json"
LOCK_FILE="$HOME/.config/aerospace-monitor/switching.lock"

# Read target window BEFORE switching (avoids race with on-focus-changed)
WINDOW_ID=""
if [[ -f "$STATE_FILE" ]]; then
    WINDOW_ID=$(jq -r ".workspaces[\"$WORKSPACE\"].windowId // empty" "$STATE_FILE" 2>/dev/null)
fi

# Create lock to prevent track-focus from recording intermediate states
touch "$LOCK_FILE"

/opt/homebrew/bin/aerospace workspace "$WORKSPACE"

if [[ -n "$WINDOW_ID" ]]; then
    sleep 0.05
    /opt/homebrew/bin/aerospace focus --window-id "$WINDOW_ID" 2>/dev/null
fi

# Remove lock after switch completes
sleep 0.1
rm -f "$LOCK_FILE"
