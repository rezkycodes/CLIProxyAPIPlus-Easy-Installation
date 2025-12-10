#!/usr/bin/env bash
# CLIProxyAPI-Plus Installation Script for Linux
#
# SYNOPSIS
#     Install CLIProxyAPI-Plus for Factory Droid on Linux systems
# 
# DESCRIPTION
#     Complete one-click installer that sets up CLIProxyAPI-Plus for Factory Droid.
#     - Downloads pre-built binary or builds from source
#     - Configures ~/.cli-proxy-api/config.yaml
#     - Updates ~/.factory/config.json with custom models
#     - Provides OAuth login prompts
#
# USAGE
#     ./install-cliproxyapi.sh                 # Interactive install
#     ./install-cliproxyapi.sh --use-prebuilt  # Download binary
#     ./install-cliproxyapi.sh --force         # Force reinstall
#     ./install-cliproxyapi.sh --skip-oauth    # Skip OAuth instructions

set -e

REPO_URL="https://github.com/router-for-me/CLIProxyAPIPlus.git"
RELEASE_API="https://api.github.com/repos/router-for-me/CLIProxyAPIPlus/releases/latest"
CLONE_DIR="$HOME/CLIProxyAPIPlus"
BIN_DIR="$HOME/bin"
CONFIG_DIR="$HOME/.cli-proxy-api"
FACTORY_DIR="$HOME/.factory"
BINARY_NAME="cliproxyapi-plus"

# Color output functions
print_step() { echo -e "\n\033[0;36m[*] $1\033[0m"; }
print_success() { echo -e "\033[0;32m[+] $1\033[0m"; }
print_warning() { echo -e "\033[0;33m[!] $1\033[0m"; }
print_error() { echo -e "\033[0;31m[-] $1\033[0m"; }

# Parse arguments
USE_PREBUILT=false
SKIP_OAUTH=false
FORCE=false

for arg in "$@"; do
    case $arg in
        --use-prebuilt) USE_PREBUILT=true ;;
        --skip-oauth) SKIP_OAUTH=true ;;
        --force) FORCE=true ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --use-prebuilt    Download pre-built binary (no Go required)"
            echo "  --skip-oauth      Skip OAuth instructions"
            echo "  --force           Force reinstall (overwrites existing)"
            echo "  --help            Show this help"
            exit 0
            ;;
        *)
            print_error "Unknown option: $arg"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

cat << "EOF"
==============================================
  CLIProxyAPI-Plus Installer for Droid CLI
==============================================
EOF

# Check prerequisites
print_step "Checking prerequisites..."

# Check Go (only if not using prebuilt)
if [ "$USE_PREBUILT" = false ]; then
    if command -v go &> /dev/null; then
        go_version=$(go version)
        print_success "Go found: $go_version"
    else
        print_warning "Go is not installed. Switching to prebuilt binary mode."
        USE_PREBUILT=true
    fi
fi

# Check Git
if command -v git &> /dev/null; then
    git_version=$(git --version)
    print_success "Git found: $git_version"
else
    print_error "Git is not installed. Please install Git first:"
    echo "  Ubuntu/Debian: sudo apt install git"
    echo "  Fedora/RHEL:   sudo dnf install git"
    echo "  Arch:          sudo pacman -S git"
    exit 1
fi

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    armv7l) ARCH="arm" ;;
    *)
        print_error "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

print_success "Detected platform: ${OS}_${ARCH}"

# Create directories
print_step "Creating directories..."
mkdir -p "$BIN_DIR" "$CONFIG_DIR" "$FACTORY_DIR"
print_success "Directories ready"

# Install binary
if [ "$USE_PREBUILT" = true ]; then
    print_step "Downloading pre-built binary from GitHub Releases..."
    
    # Get latest release info
    release_json=$(curl -sL -H "User-Agent: bash-script" "$RELEASE_API")
    
    # Find the correct asset for this platform
    asset_name="${BINARY_NAME}_${OS}_${ARCH}"
    download_url=$(echo "$release_json" | grep -o "\"browser_download_url\": \"[^\"]*${asset_name}[^\"]*\"" | head -1 | cut -d'"' -f4)
    
    if [ -z "$download_url" ]; then
        print_error "Could not find binary for ${OS}_${ARCH} in latest release"
        print_warning "Available assets:"
        echo "$release_json" | grep -o "\"name\": \"[^\"]*\"" | cut -d'"' -f4
        exit 1
    fi
    
    print_success "Found: $(basename "$download_url")"
    
    # Download and extract
    tmp_dir=$(mktemp -d)
    cd "$tmp_dir"
    
    if [[ "$download_url" == *.tar.gz ]]; then
        curl -L -o binary.tar.gz "$download_url"
        tar -xzf binary.tar.gz
        binary_file=$(find . -type f -executable -name "*cliproxyapi*" | head -1)
    elif [[ "$download_url" == *.zip ]]; then
        curl -L -o binary.zip "$download_url"
        unzip -q binary.zip
        binary_file=$(find . -type f -executable -name "*cliproxyapi*" | head -1)
    else
        # Direct binary download
        curl -L -o "$BINARY_NAME" "$download_url"
        binary_file="$BINARY_NAME"
    fi
    
    if [ -n "$binary_file" ] && [ -f "$binary_file" ]; then
        chmod +x "$binary_file"
        cp "$binary_file" "$BIN_DIR/$BINARY_NAME"
        print_success "Binary installed: $BIN_DIR/$BINARY_NAME"
    else
        print_error "Could not find binary in downloaded archive"
        ls -la
        exit 1
    fi
    
    cd - > /dev/null
    rm -rf "$tmp_dir"
else
    print_step "Building from source..."
    
    # Clone or update repo
    if [ -d "$CLONE_DIR" ]; then
        if [ "$FORCE" = true ] || [ ! -f "$CLONE_DIR/go.mod" ]; then
            print_warning "Removing existing clone..."
            rm -rf "$CLONE_DIR"
            git clone --depth 1 "$REPO_URL" "$CLONE_DIR"
        fi
    else
        git clone --depth 1 "$REPO_URL" "$CLONE_DIR"
    fi
    
    print_step "Building binary..."
    cd "$CLONE_DIR"
    go build -o "$BIN_DIR/$BINARY_NAME" ./cmd/server
    cd - > /dev/null
    
    print_success "Binary built: $BIN_DIR/$BINARY_NAME"
fi

# Make binary executable
chmod +x "$BIN_DIR/$BINARY_NAME"

# Create config.yaml
print_step "Configuring ~/.cli-proxy-api/config.yaml..."

cat > "$CONFIG_DIR/config.yaml" << EOF
port: 8317
auth-dir: "$CONFIG_DIR"
api-keys:
  - "sk-dummy"
quota-exceeded:
  switch-project: true
  switch-preview-model: true
incognito-browser: true
request-retry: 3
remote-management:
  allow-remote: false
  secret-key: ""
  disable-control-panel: false
EOF

if [ -f "$CONFIG_DIR/config.yaml" ] && [ "$FORCE" = false ]; then
    print_warning "config.yaml already exists, skipping (use --force to overwrite)"
else
    print_success "config.yaml created"
fi

# Update .factory/config.json
print_step "Updating ~/.factory/config.json..."

cat > "$FACTORY_DIR/config.json" << 'EOF'
{
    "custom_models": [
        {
            "model_display_name": "Claude Opus 4.5 Thinking [Antigravity]",
            "model": "gemini-claude-opus-4-5-thinking",
            "base_url": "http://localhost:8317/v1",
            "api_key": "sk-dummy",
            "provider": "openai"
        },
        {
            "model_display_name": "Claude Sonnet 4.5 Thinking [Antigravity]",
            "model": "gemini-claude-sonnet-4-5-thinking",
            "base_url": "http://localhost:8317/v1",
            "api_key": "sk-dummy",
            "provider": "openai"
        },
        {
            "model_display_name": "Claude Sonnet 4.5 [Antigravity]",
            "model": "gemini-claude-sonnet-4-5",
            "base_url": "http://localhost:8317/v1",
            "api_key": "sk-dummy",
            "provider": "openai"
        },
        {
            "model_display_name": "Gemini 3 Pro [Antigravity]",
            "model": "gemini-3-pro-preview",
            "base_url": "http://localhost:8317/v1",
            "api_key": "sk-dummy",
            "provider": "openai"
        },
        {
            "model_display_name": "GPT OSS 120B [Antigravity]",
            "model": "gpt-oss-120b-medium",
            "base_url": "http://localhost:8317/v1",
            "api_key": "sk-dummy",
            "provider": "openai"
        },
        {
            "model_display_name": "Claude Opus 4.5 [Copilot]",
            "model": "claude-opus-4.5",
            "base_url": "http://localhost:8317/v1",
            "api_key": "sk-dummy",
            "provider": "openai"
        },
        {
            "model_display_name": "GPT-5 Mini [Copilot]",
            "model": "gpt-5-mini",
            "base_url": "http://localhost:8317/v1",
            "api_key": "sk-dummy",
            "provider": "openai"
        },
        {
            "model_display_name": "Grok Code Fast 1 [Copilot]",
            "model": "grok-code-fast-1",
            "base_url": "http://localhost:8317/v1",
            "api_key": "sk-dummy",
            "provider": "openai"
        },
        {
            "model_display_name": "Gemini 2.5 Pro [Gemini]",
            "model": "gemini-2.5-pro",
            "base_url": "http://localhost:8317/v1",
            "api_key": "sk-dummy",
            "provider": "openai"
        },
        {
            "model_display_name": "Gemini 3 Pro Preview [Gemini]",
            "model": "gemini-3-pro-preview",
            "base_url": "http://localhost:8317/v1",
            "api_key": "sk-dummy",
            "provider": "openai"
        },
        {
            "model_display_name": "GPT-5.1 Codex Max [Codex]",
            "model": "gpt-5.1-codex-max",
            "base_url": "http://localhost:8317/v1",
            "api_key": "sk-dummy",
            "provider": "openai"
        },
        {
            "model_display_name": "Qwen3 Coder Plus [Qwen]",
            "model": "qwen3-coder-plus",
            "base_url": "http://localhost:8317/v1",
            "api_key": "sk-dummy",
            "provider": "openai"
        },
        {
            "model_display_name": "GLM 4.6 [iFlow]",
            "model": "glm-4.6",
            "base_url": "http://localhost:8317/v1",
            "api_key": "sk-dummy",
            "provider": "openai"
        },
        {
            "model_display_name": "Minimax M2 [iFlow]",
            "model": "minimax-m2",
            "base_url": "http://localhost:8317/v1",
            "api_key": "sk-dummy",
            "provider": "openai"
        },
        {
            "model_display_name": "Claude Opus 4.5 [Kiro]",
            "model": "kiro-claude-opus-4.5",
            "base_url": "http://localhost:8317/v1",
            "api_key": "sk-dummy",
            "provider": "openai"
        },
        {
            "model_display_name": "Claude Sonnet 4.5 [Kiro]",
            "model": "kiro-claude-sonnet-4.5",
            "base_url": "http://localhost:8317/v1",
            "api_key": "sk-dummy",
            "provider": "openai"
        },
        {
            "model_display_name": "Claude Sonnet 4 [Kiro]",
            "model": "kiro-claude-sonnet-4",
            "base_url": "http://localhost:8317/v1",
            "api_key": "sk-dummy",
            "provider": "openai"
        },
        {
            "model_display_name": "Claude Haiku 4.5 [Kiro]",
            "model": "kiro-claude-haiku-4.5",
            "base_url": "http://localhost:8317/v1",
            "api_key": "sk-dummy",
            "provider": "openai"
        }
    ]
}
EOF

model_count=$(grep -c "model_display_name" "$FACTORY_DIR/config.json")
print_success "config.json updated with $model_count custom models"

# Verify installation
print_step "Verifying installation..."
if [ -f "$BIN_DIR/$BINARY_NAME" ]; then
    file_size=$(stat -f%z "$BIN_DIR/$BINARY_NAME" 2>/dev/null || stat -c%s "$BIN_DIR/$BINARY_NAME" 2>/dev/null)
    size_mb=$(echo "scale=1; $file_size / 1048576" | bc)
    print_success "Binary verification passed (${size_mb} MB)"
else
    print_error "Binary not found at $BIN_DIR/$BINARY_NAME"
    exit 1
fi

# Add ~/bin to PATH if not already
print_step "Configuring PATH..."

path_added=false
path_export_line="export PATH=\"\$HOME/bin:\$PATH\""

# Add to .bashrc
if [ -f "$HOME/.bashrc" ]; then
    if ! grep -q "export PATH=\"\$HOME/bin:\$PATH\"" "$HOME/.bashrc"; then
        echo "" >> "$HOME/.bashrc"
        echo "# Added by CLIProxyAPI-Plus installer" >> "$HOME/.bashrc"
        echo "$path_export_line" >> "$HOME/.bashrc"
        print_success "Added $BIN_DIR to PATH in .bashrc"
        path_added=true
    fi
fi

# Add to .zshrc
if [ -f "$HOME/.zshrc" ]; then
    if ! grep -q "export PATH=\"\$HOME/bin:\$PATH\"" "$HOME/.zshrc"; then
        echo "" >> "$HOME/.zshrc"
        echo "# Added by CLIProxyAPI-Plus installer" >> "$HOME/.zshrc"
        echo "$path_export_line" >> "$HOME/.zshrc"
        print_success "Added $BIN_DIR to PATH in .zshrc"
        path_added=true
    fi
fi

# Fallback to .profile if neither exists
if [ ! -f "$HOME/.bashrc" ] && [ ! -f "$HOME/.zshrc" ] && [ -f "$HOME/.profile" ]; then
    if ! grep -q "export PATH=\"\$HOME/bin:\$PATH\"" "$HOME/.profile"; then
        echo "" >> "$HOME/.profile"
        echo "# Added by CLIProxyAPI-Plus installer" >> "$HOME/.profile"
        echo "$path_export_line" >> "$HOME/.profile"
        print_success "Added $BIN_DIR to PATH in .profile"
        path_added=true
    fi
fi

# Update current session PATH
if ! echo "$PATH" | grep -q "$BIN_DIR"; then
    export PATH="$HOME/bin:$PATH"
fi

if [ "$path_added" = false ]; then
    print_success "$BIN_DIR already in PATH"
fi

# Copy scripts to ~/bin
print_step "Installing utility scripts..."
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for script in start-cliproxyapi.sh cliproxyapi-oauth.sh update-cliproxyapi.sh uninstall-cliproxyapi.sh gui-cliproxyapi.sh; do
    if [ -f "$script_dir/$script" ]; then
        cp "$script_dir/$script" "$BIN_DIR/${script%.sh}"
        chmod +x "$BIN_DIR/${script%.sh}"
    fi
done
print_success "Utility scripts installed"

# OAuth login prompts
if [ "$SKIP_OAUTH" = false ]; then
    cat << EOF

==============================================
  OAuth Login Setup (Optional)
==============================================
Run these commands to login to each provider:

  # Gemini CLI
  $BINARY_NAME --config $CONFIG_DIR/config.yaml --login

  # Antigravity
  $BINARY_NAME --config $CONFIG_DIR/config.yaml --antigravity-login

  # GitHub Copilot
  $BINARY_NAME --config $CONFIG_DIR/config.yaml --github-copilot-login

  # Codex
  $BINARY_NAME --config $CONFIG_DIR/config.yaml --codex-login

  # Claude
  $BINARY_NAME --config $CONFIG_DIR/config.yaml --claude-login

  # Qwen
  $BINARY_NAME --config $CONFIG_DIR/config.yaml --qwen-login

  # iFlow
  $BINARY_NAME --config $CONFIG_DIR/config.yaml --iflow-login

  # Kiro (AWS)
  $BINARY_NAME --config $CONFIG_DIR/config.yaml --kiro-aws-login

==============================================
EOF
fi

cat << EOF

==============================================
  Installation Complete!
==============================================

Installed Files:
  Binary:   $BIN_DIR/$BINARY_NAME
  Config:   $CONFIG_DIR/config.yaml
  Droid:    $FACTORY_DIR/config.json

Available Commands (in $BIN_DIR):
  start-cliproxyapi     Start/stop/restart server
  cliproxyapi-oauth     Login to OAuth providers
  gui-cliproxyapi       Open Control Center GUI
  update-cliproxyapi    Update to latest version
  uninstall-cliproxyapi Remove everything

Quick Start:
  1. Start server:    start-cliproxyapi --background
  2. Login OAuth:     cliproxyapi-oauth --all
  3. Open GUI:        gui-cliproxyapi
  4. Use with Droid:  droid (select cliproxyapi-plus/* model)
EOF

if [ "$path_added" = true ]; then
    cat << EOF

NOTE: PATH has been added to your shell profiles.
      Restart your terminal or run:
        source ~/.bashrc    # for bash
        source ~/.zshrc     # for zsh
EOF
fi

echo "=============================================="
