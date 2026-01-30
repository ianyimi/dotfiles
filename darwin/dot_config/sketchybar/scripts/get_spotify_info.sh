#!/bin/bash

# Get Spotify track information
# This script serves as a reliable bridge between sketchybar and AppleScript

# Check if Spotify is running
if ! pgrep -x "Spotify" >/dev/null; then
    echo ""
    exit 0
fi

# Get track info using AppleScript
TRACK_INFO=$(osascript -e '
try
    tell application "Spotify"
        if player state is playing then
            set trackName to name of current track
            set artistName to artist of current track
            set artworkUrl to artwork url of current track
            return "playing||" & trackName & "||" & artistName & "||" & artworkUrl
        else
            return "paused"
        end if
    end tell
on error errMsg
    return "error||" & errMsg
end try
')

echo "$TRACK_INFO"