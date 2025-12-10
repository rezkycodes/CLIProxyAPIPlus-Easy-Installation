#!/usr/bin/env bash
# CLIProxyAPI-Plus Server Manager
#
# SYNOPSIS
#     Manage the CLIProxyAPI-Plus proxy server (start/stop/status)
#
# USAGE
#     start-cliproxyapi                # Start in foreground
#     start-cliproxyapi --background   # Start in background
#     start-cliproxyapi --status       # Check if running
#     start-cliproxyapi --stop         # Stop server
#     start-cliproxyapi --restart      # Restart server
#     start-cliproxyapi --logs         # View logs

BINARY="$HOME/bin/cliproxyapi-plus"
CONFIG="$HOME/.cli-proxy-api/config.yaml"
LOG_DIR="$HOME/.cli-proxy-api/logs"
PID_FILE="$HOME/.cli-proxy-api/server.pid"
PORT=8317

# Color output functions
print_step() { echo -e "\033[0;36m[*] $1\033[0m"; }
print_success() { echo -e "\033[0;32m[+] $1\033[0m"; }
print_warning() { echo -e "\033[0;33m[!] $1\033[0m"; }
print_error() { echo -e "\033[0;31m[-] $1\033[0m"; }

# Get server process
get_server_pid() {
    pgrep -f "cliproxyapi-plus.*--config"
}

# Check if port is in use
is_port_in_use() {
    if command -v ss &> /dev/null; then
        ss -ltn | grep -q ":$PORT "
    elif command -v netstat &> /dev/null; then
        netstat -ltn | grep -q ":$PORT "
    else
        lsof -i ":$PORT" &> /dev/null
    fi
}

# Show server status
show_status() {
    echo ""
    echo "=== CLIProxyAPI-Plus Status ==="
    
    pid=$(get_server_pid)
    if [ -n "$pid" ]; then
        print_success "Server is RUNNING"
        echo "  PID: $pid"
        
        if [ -f "/proc/$pid/status" ]; then
            mem_kb=$(grep VmRSS /proc/$pid/status | awk '{print $2}')
            mem_mb=$(echo "scale=1; $mem_kb / 1024" | bc 2>/dev/null || echo "N/A")
            echo "  Memory: ${mem_mb} MB"
        fi
        
        if [ -f "/proc/$pid/stat" ]; then
            start_time=$(stat -c %Y "/proc/$pid" 2>/dev/null || echo "N/A")
            if [ "$start_time" != "N/A" ]; then
                echo "  Started: $(date -d @$start_time 2>/dev/null || date -r $start_time 2>/dev/null || echo 'N/A')"
            fi
        fi
    else
        print_warning "Server is NOT running"
    fi
    
    if is_port_in_use; then
        echo ""
        print_success "Port $PORT is in use"
    else
        echo ""
        print_warning "Port $PORT is free"
    fi
    
    # Test endpoint
    if curl -s -m 2 "http://localhost:$PORT/v1/models" &> /dev/null; then
        print_success "API endpoint responding"
    else
        print_warning "API endpoint not responding"
    fi
    
    echo ""
}

# Stop server
stop_server() {
    pid=$(get_server_pid)
    if [ -n "$pid" ]; then
        print_step "Stopping server (PID: $pid)..."
        kill "$pid" 2>/dev/null
        sleep 0.5
        
        if [ -z "$(get_server_pid)" ]; then
            print_success "Server stopped"
            rm -f "$PID_FILE"
        else
            print_warning "Sending SIGKILL..."
            kill -9 "$pid" 2>/dev/null
            sleep 0.5
            if [ -z "$(get_server_pid)" ]; then
                print_success "Server stopped"
                rm -f "$PID_FILE"
            else
                print_error "Failed to stop server"
            fi
        fi
    else
        print_warning "Server is not running"
    fi
}

# Show logs
show_logs() {
    if [ -d "$LOG_DIR" ]; then
        latest_log=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1)
        
        if [ -n "$latest_log" ]; then
            print_step "Showing logs from: $(basename "$latest_log")"
            echo "Press Ctrl+C to exit"
            echo ""
            tail -f -n 50 "$latest_log"
        else
            print_warning "No log files found in $LOG_DIR"
            echo "Server may be running without file logging."
        fi
    else
        print_warning "Log directory not found: $LOG_DIR"
    fi
}

# Start server
start_server() {
    local background_mode=$1
    
    # Check if already running
    if [ -n "$(get_server_pid)" ]; then
        print_warning "Server is already running!"
        show_status
        return
    fi
    
    # Verify binary exists
    if [ ! -f "$BINARY" ]; then
        print_error "Binary not found: $BINARY"
        echo "Run install-cliproxyapi.sh first."
        exit 1
    fi
    
    # Verify config exists
    if [ ! -f "$CONFIG" ]; then
        print_error "Config not found: $CONFIG"
        echo "Run install-cliproxyapi.sh first."
        exit 1
    fi
    
    if [ "$background_mode" = true ]; then
        print_step "Starting server in background..."
        
        # Create log directory
        mkdir -p "$LOG_DIR"
        log_file="$LOG_DIR/server_$(date +%Y%m%d_%H%M%S).log"
        
        # Start server in background
        nohup "$BINARY" --config "$CONFIG" > "$log_file" 2>&1 &
        pid=$!
        echo $pid > "$PID_FILE"
        sleep 2
        
        if [ -n "$(get_server_pid)" ]; then
            print_success "Server started in background (PID: $pid)"
            echo ""
            echo "Endpoint: http://localhost:$PORT/v1"
            echo "Logs:     $log_file"
            echo "To stop:  start-cliproxyapi --stop"
            echo "To check: start-cliproxyapi --status"
        else
            print_error "Server failed to start"
            echo "Check logs: $log_file"
            exit 1
        fi
    else
        echo "=== CLIProxyAPI-Plus Server ==="
        echo "Config:   $CONFIG"
        echo "Endpoint: http://localhost:$PORT/v1"
        echo "Press Ctrl+C to stop"
        echo ""
        
        exec "$BINARY" --config "$CONFIG"
    fi
}

# Parse arguments
ACTION=""
BACKGROUND=false

for arg in "$@"; do
    case $arg in
        --background|-b) BACKGROUND=true ;;
        --status|-s) ACTION="status" ;;
        --stop) ACTION="stop" ;;
        --restart|-r) ACTION="restart" ;;
        --logs|-l) ACTION="logs" ;;
        --help|-h)
            echo "Usage: start-cliproxyapi [OPTIONS]"
            echo "Options:"
            echo "  --background, -b    Start in background"
            echo "  --status, -s        Show server status"
            echo "  --stop              Stop server"
            echo "  --restart, -r       Restart server"
            echo "  --logs, -l          View server logs"
            echo "  --help, -h          Show this help"
            exit 0
            ;;
        *)
            print_error "Unknown option: $arg"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Execute action
case "$ACTION" in
    status)
        show_status
        ;;
    stop)
        stop_server
        ;;
    restart)
        stop_server
        sleep 1
        start_server "$BACKGROUND"
        ;;
    logs)
        show_logs
        ;;
    *)
        start_server "$BACKGROUND"
        ;;
esac
