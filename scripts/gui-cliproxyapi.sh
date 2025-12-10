#!/usr/bin/env bash
# CLIProxyAPI-Plus GUI Control Center
#
# SYNOPSIS
#     Open GUI control center in web browser
#
# USAGE
#     gui-cliproxyapi          # Start GUI server on port 8318
#     gui-cliproxyapi --port 9000  # Use custom port
#     gui-cliproxyapi --no-browser # Don't auto-open browser

# Note: This is a simplified version for Linux. For full functionality,
# use the PowerShell version on Windows or interact directly with CLI commands.

SCRIPT_VERSION="1.0.0"
PORT=8318
NO_BROWSER=false

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUI_PATH="$(dirname "$SCRIPT_DIR")/gui/index.html"
BIN_DIR="$HOME/bin"
CONFIG_DIR="$HOME/.cli-proxy-api"
BINARY="$BIN_DIR/cliproxyapi-plus"
CONFIG="$CONFIG_DIR/config.yaml"

# Color output
print_step() { echo -e "\033[0;36m[*] $1\033[0m"; }
print_success() { echo -e "\033[0;32m[+] $1\033[0m"; }
print_warning() { echo -e "\033[0;33m[!] $1\033[0m"; }
print_error() { echo -e "\033[0;31m[-] $1\033[0m"; }

# Parse arguments
for arg in "$@"; do
    case $arg in
        --port=*) PORT="${arg#*=}" ;;
        --no-browser) NO_BROWSER=true ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --port=PORT      Use custom port (default: 8318)"
            echo "  --no-browser     Don't automatically open browser"
            echo "  --help, -h       Show this help"
            exit 0
            ;;
    esac
done

# Check if Python or other HTTP server is available
if command -v python3 &> /dev/null; then
    SERVER_CMD="python3 -m http.server"
elif command -v python &> /dev/null; then
    SERVER_CMD="python -m SimpleHTTPServer"
elif command -v php &> /dev/null; then
    SERVER_CMD="php -S"
else
    print_error "No HTTP server found. Please install python3 or php."
    echo ""
    echo "You can still use CLI commands:"
    echo "  start-cliproxyapi --background  # Start server"
    echo "  cliproxyapi-oauth --all         # Login to providers"
    echo "  start-cliproxyapi --status      # Check status"
    exit 1
fi

# Check if GUI file exists
if [ ! -f "$GUI_PATH" ]; then
    print_error "GUI file not found: $GUI_PATH"
    echo ""
    echo "Please use CLI commands instead:"
    echo "  start-cliproxyapi --background  # Start server"
    echo "  cliproxyapi-oauth --all         # Login to providers"
    echo "  start-cliproxyapi --status      # Check status"
    exit 1
fi

cat << "EOF"
==========================================
  CLIProxyAPI-Plus GUI Control Center
==========================================
EOF

print_step "Starting GUI server on port $PORT..."

# Check if port is already in use
if ss -ltn 2>/dev/null | grep -q ":$PORT " || netstat -ltn 2>/dev/null | grep -q ":$PORT "; then
    print_error "Port $PORT is already in use"
    exit 1
fi

# Start simple HTTP server
cd "$(dirname "$GUI_PATH")"

# Create a temporary server script with API endpoints
TMP_SERVER="/tmp/cliproxyapi-gui-server.py"

cat > "$TMP_SERVER" << 'PYEOF'
#!/usr/bin/env python3
import http.server
import socketserver
import json
import subprocess
import os
import signal
import sys
from urllib.parse import urlparse, parse_qs

PORT = int(os.environ.get('GUI_PORT', 8318))
BINARY = os.path.expanduser('~/bin/cliproxyapi-plus')
CONFIG = os.path.expanduser('~/.cli-proxy-api/config.yaml')
CONFIG_DIR = os.path.expanduser('~/.cli-proxy-api')

class APIHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        parsed = urlparse(self.path)
        
        if parsed.path == '/api/status':
            self.handle_status()
        elif parsed.path == '/api/version':
            self.handle_version()
        else:
            super().do_GET()
    
    def do_POST(self):
        parsed = urlparse(self.path)
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length).decode('utf-8') if content_length > 0 else '{}'
        
        if parsed.path == '/api/start':
            self.handle_start()
        elif parsed.path == '/api/stop':
            self.handle_stop()
        elif parsed.path == '/api/restart':
            self.handle_restart()
        elif parsed.path.startswith('/api/oauth/'):
            provider = parsed.path.split('/')[-1]
            self.handle_oauth(provider)
        else:
            self.send_error(404)
    
    def handle_status(self):
        try:
            result = subprocess.run(['pgrep', '-f', 'cliproxyapi-plus'], 
                                  capture_output=True, text=True)
            running = result.returncode == 0
            
            status = {
                'running': running,
                'pid': result.stdout.strip() if running else None,
                'port': 8317,
                'endpoint': 'http://localhost:8317/v1'
            }
            
            self.send_json_response(status)
        except Exception as e:
            self.send_json_response({'error': str(e)}, 500)
    
    def handle_version(self):
        self.send_json_response({'version': '1.0.0'})
    
    def handle_start(self):
        try:
            subprocess.Popen([BINARY, '--config', CONFIG],
                           stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL,
                           start_new_session=True)
            self.send_json_response({'success': True, 'message': 'Server started'})
        except Exception as e:
            self.send_json_response({'success': False, 'error': str(e)}, 500)
    
    def handle_stop(self):
        try:
            subprocess.run(['pkill', '-f', 'cliproxyapi-plus'])
            self.send_json_response({'success': True, 'message': 'Server stopped'})
        except Exception as e:
            self.send_json_response({'success': False, 'error': str(e)}, 500)
    
    def handle_restart(self):
        try:
            subprocess.run(['pkill', '-f', 'cliproxyapi-plus'])
            import time
            time.sleep(1)
            subprocess.Popen([BINARY, '--config', CONFIG],
                           stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL,
                           start_new_session=True)
            self.send_json_response({'success': True, 'message': 'Server restarted'})
        except Exception as e:
            self.send_json_response({'success': False, 'error': str(e)}, 500)
    
    def handle_oauth(self, provider):
        flags = {
            'gemini': '--login',
            'copilot': '--github-copilot-login',
            'antigravity': '--antigravity-login',
            'codex': '--codex-login',
            'claude': '--claude-login',
            'qwen': '--qwen-login',
            'iflow': '--iflow-login',
            'kiro': '--kiro-aws-login'
        }
        
        if provider not in flags:
            self.send_json_response({'success': False, 'error': 'Unknown provider'}, 400)
            return
        
        try:
            subprocess.Popen([BINARY, '--config', CONFIG, flags[provider]],
                           start_new_session=True)
            self.send_json_response({'success': True, 'message': f'OAuth started for {provider}'})
        except Exception as e:
            self.send_json_response({'success': False, 'error': str(e)}, 500)
    
    def send_json_response(self, data, status=200):
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())
    
    def log_message(self, format, *args):
        # Suppress logs for cleaner output
        pass

def signal_handler(sig, frame):
    print('\n\nShutting down GUI server...')
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)

with socketserver.TCPServer(("", PORT), APIHandler) as httpd:
    print(f"\n[+] GUI server running at http://localhost:{PORT}")
    print("    Press Ctrl+C to stop\n")
    httpd.serve_forever()
PYEOF

chmod +x "$TMP_SERVER"

# Export port for Python script
export GUI_PORT=$PORT

# Open browser if requested
if [ "$NO_BROWSER" = false ]; then
    sleep 1
    URL="http://localhost:$PORT/index.html"
    
    if command -v xdg-open &> /dev/null; then
        xdg-open "$URL" &> /dev/null &
    elif command -v open &> /dev/null; then
        open "$URL" &> /dev/null &
    elif command -v firefox &> /dev/null; then
        firefox "$URL" &> /dev/null &
    elif command -v google-chrome &> /dev/null; then
        google-chrome "$URL" &> /dev/null &
    fi
fi

# Start server
print_success "GUI server starting..."
echo "    URL: http://localhost:$PORT/index.html"
echo "    Press Ctrl+C to stop"
echo ""

python3 "$TMP_SERVER"

# Cleanup
rm -f "$TMP_SERVER"
