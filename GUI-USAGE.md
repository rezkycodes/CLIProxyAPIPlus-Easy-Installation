# CLIProxyAPI+ GUI Control Panel - Quick Start

## Start GUI Server

**Linux/Mac:**
```bash
# Method 1: Using startup script (recommended)
./scripts/start-gui.sh

# Method 2: Direct Python
cd gui && python3 server.py

# Background mode:
./scripts/start-gui.sh --background
```

**Windows (PowerShell):**
```powershell
# Method 1: Using startup script (recommended)
.\scripts\start-gui.ps1

# Method 2: Direct Python
cd gui; python server.py

# Background mode:
.\scripts\start-gui.ps1 -Background
```

## Access GUI

Open in your browser:
```
http://localhost:8173
```

## Features

- **Server Control**: Start/Stop/Restart CLIProxyAPI server
- **Status Monitor**: Real-time server status and uptime
- **Provider Login**: OAuth authentication for AI providers
- **Configuration**: Edit config.yaml directly from GUI
- **Auto-start**: Enable automatic server startup
- **Statistics**: Request stats and performance metrics

## Troubleshooting

**Port already in use:**
```bash
# Linux: Find and kill process on port 8173
lsof -ti:8173 | xargs kill -9

# Windows:
netstat -ano | findstr :8173
taskkill /PID <PID> /F
```

**Server won't start:**
1. Check if CLIProxyAPI binary exists: `~/bin/cliproxyapi-plus`
2. Check config file: `~/.cli-proxy-api/config.yaml`
3. Check permissions: `chmod +x ~/bin/cliproxyapi-plus`

**GUI shows errors:**
1. Make sure PyYAML is installed: `pip3 install pyyaml`
2. Check browser console (F12) for JavaScript errors
3. Clear browser cache and reload

## Stop GUI Server

**If running in foreground:**
Press `Ctrl+C`

**If running in background:**
```bash
# Linux
kill $(cat ~/.cli-proxy-api/gui.pid)

# Windows
$pid = Get-Content ~/.cli-proxy-api/gui.pid
Stop-Process -Id $pid
```
