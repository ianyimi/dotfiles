#!/bin/bash

# Get Apple Music track information
# This script serves as a reliable bridge between sketchybar and AppleScript

# Check if Music is running
if ! pgrep -x "Music" >/dev/null; then
    echo ""
    exit 0
fi

# Get track info using AppleScript
TRACK_INFO=$(osascript -e '
try
    tell application "Music"
        if player state is playing then
            set trackName to name of current track
            set artistName to artist of current track
            return "playing||" & trackName & "||" & artistName
        else
            return "paused"
        end if
    end tell
on error errMsg
    return "error||" & errMsg
end try
')

echo "$TRACK_INFO"