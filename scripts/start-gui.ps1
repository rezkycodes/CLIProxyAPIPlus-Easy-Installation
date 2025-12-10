<#
.SYNOPSIS
    Start CLIProxyAPI+ GUI Control Panel

.DESCRIPTION
    Starts the web-based GUI control panel for CLIProxyAPI+

.PARAMETER Port
    Port to listen on (default: 8173)

.PARAMETER Background
    Run in background

.EXAMPLE
    .\start-gui.ps1
    Start GUI on default port 8173

.EXAMPLE
    .\start-gui.ps1 -Port 8080 -Background
    Start GUI on port 8080 in background
#>

param(
    [int]$Port = 8173,
    [switch]$Background
)

$ErrorActionPreference = "Stop"

# Configuration
$GuiDir = Join-Path $PSScriptRoot "..\gui"
$ServerScript = Join-Path $GuiDir "server.py"
$ConfigDir = Join-Path $env:USERPROFILE ".cli-proxy-api"
$PidFile = Join-Path $ConfigDir "gui.pid"

# Colors
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

# Check if Python 3 is installed
try {
    $null = Get-Command python3 -ErrorAction Stop
    $PythonCmd = "python3"
} catch {
    try {
        $null = Get-Command python -ErrorAction Stop
        $PythonCmd = "python"
    } catch {
        Write-ColorOutput Red "Error: Python 3 is required but not installed"
        exit 1
    }
}

# Check if server script exists
if (-not (Test-Path $ServerScript)) {
    Write-ColorOutput Red "Error: GUI server script not found: $ServerScript"
    exit 1
}

# Create config directory if it doesn't exist
if (-not (Test-Path $ConfigDir)) {
    New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
}

# Check if already running
if (Test-Path $PidFile) {
    $OldPid = Get-Content $PidFile
    $Process = Get-Process -Id $OldPid -ErrorAction SilentlyContinue
    if ($Process) {
        Write-ColorOutput Yellow "GUI server is already running (PID: $OldPid)"
        Write-Host "Visit: " -NoNewline
        Write-ColorOutput Cyan "http://localhost:$Port"
        exit 0
    } else {
        # Clean up stale PID file
        Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
    }
}

# Start server
Write-ColorOutput Green "Starting CLIProxyAPI+ GUI Control Panel..."

if ($Background) {
    # Start in background
    $Process = Start-Process -FilePath $PythonCmd -ArgumentList $ServerScript -WindowStyle Hidden -PassThru
    $Process.Id | Out-File -FilePath $PidFile -Encoding ASCII
    
    # Wait a bit to check if it started
    Start-Sleep -Milliseconds 1000
    if (Get-Process -Id $Process.Id -ErrorAction SilentlyContinue) {
        Write-ColorOutput Green "✓ GUI server started successfully (PID: $($Process.Id))"
        Write-Host "  Visit: " -NoNewline
        Write-ColorOutput Cyan "http://localhost:$Port"
        Write-Host ""
        Write-Host "To stop the server, run:"
        Write-Host "  Stop-Process -Id $($Process.Id)"
    } else {
        Write-ColorOutput Red "✗ Failed to start GUI server"
        Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
        exit 1
    }
} else {
    # Start in foreground
    Write-Host "  Visit: " -NoNewline
    Write-ColorOutput Cyan "http://localhost:$Port"
    Write-Host "  Press " -NoNewline
    Write-ColorOutput Yellow "Ctrl+C" -NoNewline
    Write-Host " to stop"
    Write-Host ""
    
    try {
        # Start server
        & $PythonCmd $ServerScript
    } finally {
        # Clean up PID file on exit
        Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
    }
}
