#!/bin/bash
# Port of aerospace 'close-all-windows-but-current' (service submap: backspace)

# 1. Get active window address + workspace id
ACTIVE_JSON=$(hyprctl activewindow -j 2>/dev/null) || exit 1
ACTIVE_ADDR=$(echo "$ACTIVE_JSON" | jq -r '.address // empty')
ACTIVE_WS=$(echo "$ACTIVE_JSON" | jq -r '.workspace.id // empty')
[[ -z "$ACTIVE_ADDR" || -z "$ACTIVE_WS" ]] && exit 1

# 2. List windows on the same workspace, excluding the active one
# 3. Gracefully close each
hyprctl clients -j \
    | jq -r --arg ws "$ACTIVE_WS" --arg addr "$ACTIVE_ADDR" \
        '.[] | select((.workspace.id | tostring) == $ws and .address != $addr) | .address' \
    | while read -r ADDR; do
        hyprctl dispatch closewindow "address:$ADDR" >/dev/null
    done
