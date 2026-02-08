#!/bin/bash
WORKSPACE="$1"
STATE_FILE="$HOME/.config/aerospace-monitor/window-focus.json"
LOCK_FILE="$HOME/.config/aerospace-monitor/switching.lock"

# Read target window BEFORE switching (avoids race with on-focus-changed)
WINDOW_ID=""
if [[ -f "$STATE_FILE" ]]; then
    WINDOW_ID=$(jq -r ".workspaces[\"$WORKSPACE\"].windowId // empty" "$STATE_FILE" 2>/dev/null)

    # Verify window still exists AND is on the target workspace
    if [[ -n "$WINDOW_ID" ]]; then
        ACTUAL_WS=$(/opt/homebrew/bin/aerospace list-windows --all --format '%{window-id}	%{workspace}' 2>/dev/null | awk -F'\t' -v wid="$WINDOW_ID" '$1 == wid {print $2}')
        if [[ "$ACTUAL_WS" != "$WORKSPACE" ]]; then
            WINDOW_ID=""  # Window moved or deleted, don't use it
        fi
    fi
fi

# Create lock to prevent track-focus from recording intermediate states
touch "$LOCK_FILE"

/opt/homebrew/bin/aerospace workspace "$WORKSPACE"

if [[ -n "$WINDOW_ID" ]]; then
    # Wait for focus to stabilize, then correct if needed
    # Poll until the focused window stops changing, then set ours
    PREV=""
    for i in 1 2 3 4 5 6; do
        sleep 0.05
        CURRENT=$(/opt/homebrew/bin/aerospace list-windows --focused --format '%{window-id}' 2>/dev/null)
        if [[ "$CURRENT" == "$WINDOW_ID" ]]; then
            break
        fi
        if [[ "$CURRENT" == "$PREV" ]]; then
            # Focus settled on wrong window - correct it
            /opt/homebrew/bin/aerospace focus --window-id "$WINDOW_ID" 2>/dev/null
            break
        fi
        PREV="$CURRENT"
    done
fi

# Remove lock after switch completes
sleep 0.1
rm -f "$LOCK_FILE"
