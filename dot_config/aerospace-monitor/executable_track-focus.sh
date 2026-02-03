#!/bin/bash
STATE_FILE="$HOME/.config/aerospace-monitor/window-focus.json"
LOCK_FILE="$HOME/.config/aerospace-monitor/switching.lock"

# Skip tracking if a switch is in progress
if [[ -f "$LOCK_FILE" ]]; then
    # Check if lock is stale (older than 1 second)
    if [[ $(find "$LOCK_FILE" -mtime +1s 2>/dev/null) ]]; then
        rm -f "$LOCK_FILE"
    else
        exit 0
    fi
fi

# Get focused window info
INFO=$(/opt/homebrew/bin/aerospace list-windows --focused --format '%{window-id}	%{workspace}	%{app-name}' 2>/dev/null)
[[ -z "$INFO" ]] && exit 0

IFS=$'\t' read -r WINDOW_ID WORKSPACE APP_NAME <<< "$INFO"
[[ -z "$WINDOW_ID" || -z "$WORKSPACE" ]] && exit 0

TIMESTAMP=$(date +%s)

# Initialize file if missing or empty/invalid
if [[ ! -f "$STATE_FILE" ]] || [[ ! -s "$STATE_FILE" ]] || ! jq empty "$STATE_FILE" 2>/dev/null; then
    echo '{"version":1,"workspaces":{}}' > "$STATE_FILE"
fi

# Update JSON with jq - only move if jq succeeds and output is non-empty
if jq --arg ws "$WORKSPACE" \
      --arg wid "$WINDOW_ID" \
      --arg app "$APP_NAME" \
      --arg ts "$TIMESTAMP" \
      '.workspaces[$ws] = {windowId: $wid, appName: $app, timestamp: ($ts | tonumber)} | .lastUpdated = (now | todate)' \
      "$STATE_FILE" > "$STATE_FILE.tmp" 2>/dev/null && [[ -s "$STATE_FILE.tmp" ]]; then
    mv "$STATE_FILE.tmp" "$STATE_FILE"
else
    rm -f "$STATE_FILE.tmp"
fi
