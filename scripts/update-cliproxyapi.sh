#!/usr/bin/env bash
# CLIProxyAPI-Plus Update Script
#
# SYNOPSIS
#     Update CLIProxyAPI-Plus to the latest version
#
# USAGE
#     update-cliproxyapi                # Update from source if available
#     update-cliproxyapi --use-prebuilt # Download latest binary
#     update-cliproxyapi --force        # Force update even if up-to-date

set -e

REPO_URL="https://github.com/router-for-me/CLIProxyAPIPlus.git"
RELEASE_API="https://api.github.com/repos/router-for-me/CLIProxyAPIPlus/releases/latest"
CLONE_DIR="$HOME/CLIProxyAPIPlus"
BIN_DIR="$HOME/bin"
CONFIG_DIR="$HOME/.cli-proxy-api"
BINARY_NAME="cliproxyapi-plus"

# Color output
print_step() { echo -e "\033[0;36m[*] $1\033[0m"; }
print_success() { echo -e "\033[0;32m[+] $1\033[0m"; }
print_warning() { echo -e "\033[0;33m[!] $1\033[0m"; }
print_error() { echo -e "\033[0;31m[-] $1\033[0m"; }

# Parse arguments
USE_PREBUILT=false
FORCE=false

for arg in "$@"; do
    case $arg in
        --use-prebuilt) USE_PREBUILT=true ;;
        --force) FORCE=true ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --use-prebuilt    Download latest pre-built binary"
            echo "  --force           Force update even if up-to-date"
            echo "  --help, -h        Show this help"
            exit 0
            ;;
        *)
            print_error "Unknown option: $arg"
            exit 1
            ;;
    esac
done

cat << "EOF"
==============================================
  CLIProxyAPI-Plus Updater
==============================================
EOF

# Check current installation
print_step "Checking current installation..."
binary_path="$BIN_DIR/$BINARY_NAME"

if [ ! -f "$binary_path" ]; then
    print_warning "Binary not found. Run install-cliproxyapi.sh first."
    exit 1
fi

current_time=$(stat -c %Y "$binary_path" 2>/dev/null || stat -f %m "$binary_path" 2>/dev/null)
print_success "Current binary: $(date -d @$current_time 2>/dev/null || date -r $current_time 2>/dev/null)"

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    armv7l) ARCH="arm" ;;
esac

# Check for latest release
print_step "Fetching latest release info..."
release_json=$(curl -sL -H "User-Agent: bash-script" "$RELEASE_API")
tag_name=$(echo "$release_json" | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4)
published_at=$(echo "$release_json" | grep -o '"published_at": "[^"]*"' | cut -d'"' -f4)

print_success "Latest version: $tag_name"
echo "    Published: $published_at"

# Determine update method
if [ "$USE_PREBUILT" = false ] && [ -d "$CLONE_DIR" ] && [ -f "$CLONE_DIR/go.mod" ]; then
    print_step "Updating from source..."
    
    cd "$CLONE_DIR"
    
    # Fetch and check for updates
    print_success "Fetching latest changes..."
    git fetch origin main
    
    local_hash=$(git rev-parse HEAD)
    remote_hash=$(git rev-parse origin/main)
    
    if [ "$local_hash" = "$remote_hash" ] && [ "$FORCE" = false ]; then
        print_success "Already up to date!"
        exit 0
    fi
    
    print_success "Pulling latest changes..."
    if ! git pull origin main --rebase; then
        print_warning "Git pull failed, trying reset..."
        git fetch origin main
        git reset --hard origin/main
    fi
    
    print_step "Building binary..."
    go build -o "$binary_path" ./cmd/server
    
    cd - > /dev/null
    print_success "Binary rebuilt from source"
    
else
    print_step "Downloading latest pre-built binary..."
    
    # Find the correct asset
    asset_name="${BINARY_NAME}_${OS}_${ARCH}"
    download_url=$(echo "$release_json" | grep -o "\"browser_download_url\": \"[^\"]*${asset_name}[^\"]*\"" | head -1 | cut -d'"' -f4)
    
    if [ -z "$download_url" ]; then
        print_error "Could not find binary for ${OS}_${ARCH} in latest release"
        exit 1
    fi
    
    print_success "Found: $(basename "$download_url")"
    
    # Download and extract
    tmp_dir=$(mktemp -d)
    cd "$tmp_dir"
    
    # Backup old binary
    backup_path="${binary_path}.old"
    if [ -f "$binary_path" ]; then
        cp "$binary_path" "$backup_path"
        print_success "Backup saved: $backup_path"
    fi
    
    if [[ "$download_url" == *.tar.gz ]]; then
        curl -L -o binary.tar.gz "$download_url"
        tar -xzf binary.tar.gz
        binary_file=$(find . -type f -executable -name "*cliproxyapi*" | head -1)
    elif [[ "$download_url" == *.zip ]]; then
        curl -L -o binary.zip "$download_url"
        unzip -q binary.zip
        binary_file=$(find . -type f -executable -name "*cliproxyapi*" | head -1)
    else
        curl -L -o "$BINARY_NAME" "$download_url"
        binary_file="$BINARY_NAME"
    fi
    
    if [ -n "$binary_file" ] && [ -f "$binary_file" ]; then
        chmod +x "$binary_file"
        cp "$binary_file" "$binary_path"
        print_success "Binary updated: $binary_path"
    else
        print_error "Could not find binary in downloaded archive"
        exit 1
    fi
    
    cd - > /dev/null
    rm -rf "$tmp_dir"
fi

# Verify update
print_step "Verifying update..."
if [ -f "$binary_path" ]; then
    new_time=$(stat -c %Y "$binary_path" 2>/dev/null || stat -f %m "$binary_path" 2>/dev/null)
    print_success "Update complete!"
    echo "    Binary updated: $(date -d @$new_time 2>/dev/null || date -r $new_time 2>/dev/null)"
else
    print_error "Binary verification failed"
    exit 1
fi

cat << EOF

==============================================
  Update Complete!
==============================================
Binary:  $binary_path
Config:  $CONFIG_DIR/config.yaml (preserved)
Auth:    $CONFIG_DIR/*.json (preserved)

To start the server:
  $BINARY_NAME --config $CONFIG_DIR/config.yaml
==============================================
EOF
