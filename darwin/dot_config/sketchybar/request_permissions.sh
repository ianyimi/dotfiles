#!/bin/bash

# Request Media permissions for sketchybar
# This script creates a temporary AppleScript application that requests 
# media permissions, then grants those permissions to sketchybar

# Path to sketchybar binary
SKETCHYBAR_PATH=$(which sketchybar)
SKETCHYBAR_BREW_PATH="/opt/homebrew/opt/sketchybar/bin/sketchybar"

# Create a temporary directory
TEMP_DIR=$(mktemp -d)
APP_PATH="$TEMP_DIR/RequestMediaAccess.app"

# Create a simple AppleScript application that requests media access
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

# Create Info.plist
cat > "$APP_PATH/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>RequestMediaAccess</string>
    <key>CFBundleIdentifier</key>
    <string>com.sketchybar.requestmediaaccess</string>
    <key>CFBundleName</key>
    <string>RequestMediaAccess</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>NSAppleMusicUsageDescription</key>
    <string>This app needs access to your media library to display music information in sketchybar.</string>
</dict>
</plist>
EOF

# Create the executable script
cat > "$APP_PATH/Contents/MacOS/RequestMediaAccess" << EOF
#!/usr/bin/osascript

tell application "Music"
    try
        set currentTrack to name of current track
        display dialog "Successfully accessed Music information: " & currentTrack
    on error
        display dialog "Failed to access Music information. Please grant Media & Apple Music permissions in System Settings."
    end try
end tell

tell application "Spotify"
    if it is running then
        try
            set currentTrack to name of current track
            display dialog "Successfully accessed Spotify information: " & currentTrack
        on error
            display dialog "Failed to access Spotify information. Please grant permissions to Spotify if prompted."
        end try
    else
        display dialog "Spotify is not running. Please start Spotify and try again if you want to test Spotify permissions."
    end if
end tell
EOF

# Make the script executable
chmod +x "$APP_PATH/Contents/MacOS/RequestMediaAccess"

# Run the application
echo "Running permission request app..."
open "$APP_PATH"

# After permissions are granted, restart sketchybar
echo "After granting permissions, restart sketchybar with:"
echo "brew services restart sketchybar"

# Clean up after some time to allow the app to run
(sleep 60 && rm -rf "$TEMP_DIR") &