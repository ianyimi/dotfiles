#!/bin/bash

# Check if daemon is already running
if pgrep -f "aerospace-monitor-daemon" > /dev/null; then
    # Already running, do nothing
    exit 0
fi

# Start the daemon
~/.config/aerospace-monitor/aerospace-monitor-daemon > ~/.config/aerospace-monitor/daemon.log 2>&1 &
