# !/bin/bash

owuiup() {
    if pgrep -f "open-webui serve" > /dev/null; then
        echo "OpenWebUI is already running"
        return 1
    fi
    (source "$HOME/openwebui/.venv/bin/activate" &&
     open-webui serve > "$HOME/logs/webui.log" 2>&1 &)
    echo "OpenWebUI started. Logs at ~/logs/webui.log"
}

owuidown() {
    pkill -f "open-webui serve"
    echo "OpenWebUI stopped"
}
