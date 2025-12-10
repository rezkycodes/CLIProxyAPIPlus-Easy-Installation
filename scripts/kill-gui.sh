#!/usr/bin/env bash
#
# Kill CLIProxyAPI+ GUI Server
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PID_FILE="$HOME/.cli-proxy-api/gui.pid"

echo -e "${YELLOW}Stopping GUI server...${NC}"

# Method 1: Kill by PID file
if [[ -f "$PID_FILE" ]]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        kill "$PID" 2>/dev/null || kill -9 "$PID" 2>/dev/null
        echo -e "${GREEN}✓ Stopped GUI server (PID: $PID)${NC}"
        rm -f "$PID_FILE"
    else
        echo -e "${YELLOW}PID file exists but process not running${NC}"
        rm -f "$PID_FILE"
    fi
fi

# Method 2: Kill by process name
PIDS=$(pgrep -f 'python.*gui/server.py' 2>/dev/null || true)
if [[ -n "$PIDS" ]]; then
    echo "$PIDS" | xargs kill 2>/dev/null || echo "$PIDS" | xargs kill -9 2>/dev/null
    echo -e "${GREEN}✓ Stopped GUI server processes${NC}"
fi

# Method 3: Kill by port
if command -v fuser &> /dev/null; then
    fuser -k 8173/tcp 2>/dev/null && echo -e "${GREEN}✓ Freed port 8173${NC}" || true
fi

echo -e "${GREEN}Done${NC}"
