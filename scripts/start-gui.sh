#!/usr/bin/env bash
#
# Start CLIProxyAPI+ GUI Control Panel
# Usage: ./start-gui.sh [--port PORT] [--background]
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
PORT=8173
BACKGROUND=false
GUI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/gui"
SERVER_SCRIPT="$GUI_DIR/server.py"
PID_FILE="$HOME/.cli-proxy-api/gui.pid"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --port)
            PORT="$2"
            shift 2
            ;;
        --background|-b)
            BACKGROUND=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --port PORT       Port to listen on (default: 8173)"
            echo "  --background, -b  Run in background"
            echo "  --help, -h        Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: Python 3 is required but not installed${NC}"
    exit 1
fi

# Check if server script exists
if [[ ! -f "$SERVER_SCRIPT" ]]; then
    echo -e "${RED}Error: GUI server script not found: $SERVER_SCRIPT${NC}"
    exit 1
fi

# Check if already running
if [[ -f "$PID_FILE" ]]; then
    OLD_PID=$(cat "$PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo -e "${YELLOW}GUI server is already running (PID: $OLD_PID)${NC}"
        echo -e "Visit: ${BLUE}http://localhost:$PORT${NC}"
        exit 0
    else
        # Clean up stale PID file
        rm -f "$PID_FILE"
    fi
fi

# Start server
echo -e "${GREEN}Starting CLIProxyAPI+ GUI Control Panel...${NC}"

if [[ "$BACKGROUND" == true ]]; then
    # Start in background
    nohup python3 "$SERVER_SCRIPT" > /dev/null 2>&1 &
    PID=$!
    echo "$PID" > "$PID_FILE"
    
    # Wait a bit to check if it started
    sleep 1
    if kill -0 "$PID" 2>/dev/null; then
        echo -e "${GREEN}✓ GUI server started successfully (PID: $PID)${NC}"
        echo -e "  Visit: ${BLUE}http://localhost:$PORT${NC}"
        echo -e ""
        echo -e "To stop the server, run:"
        echo -e "  kill $PID"
    else
        echo -e "${RED}✗ Failed to start GUI server${NC}"
        rm -f "$PID_FILE"
        exit 1
    fi
else
    # Start in foreground
    echo -e "  Visit: ${BLUE}http://localhost:$PORT${NC}"
    echo -e "  Press ${YELLOW}Ctrl+C${NC} to stop"
    echo ""
    
    # Trap Ctrl+C to clean up PID file
    trap 'rm -f "$PID_FILE"; exit' INT TERM
    
    # Start server and save PID
    python3 "$SERVER_SCRIPT" &
    PID=$!
    echo "$PID" > "$PID_FILE"
    
    # Wait for server process
    wait "$PID"
    rm -f "$PID_FILE"
fi
