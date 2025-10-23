#!/bin/bash

# This script requests media permissions for terminal and sketchybar
# It compiles and runs a Swift script that prompts for permissions

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SWIFT_SCRIPT="$SCRIPT_DIR/request_media_permissions.swift"

echo "Requesting Media permissions..."
echo "This will help sketchybar access media information."

# Check if Swift script exists
if [ ! -f "$SWIFT_SCRIPT" ]; then
    echo "Error: Swift script not found at $SWIFT_SCRIPT"
    exit 1
fi

# Compile and run the Swift script
echo "Running permission request..."

# Option 1: Run directly with swift
swift "$SWIFT_SCRIPT"

# Additional steps for Spotify permissions
osascript -e '
tell application "Spotify"
    if it is running then
        try
            set currentTrack to name of current track
            display dialog "Successfully accessed Spotify information: " & currentTrack buttons {"OK"} default button "OK"
        on error
            display dialog "Failed to access Spotify information. Please ensure Spotify is playing music and try again." buttons {"OK"} default button "OK"
        end try
    else
        display dialog "Spotify is not running. If you use Spotify, please start it and play a track." buttons {"OK"} default button "OK"
    end if
end tell
'

# Instructions for the user
echo ""
echo "After granting permissions, restart sketchybar with:"
echo "brew services restart sketchybar"
echo ""
echo "If sketchybar still doesn't show media info, try restarting your Mac."