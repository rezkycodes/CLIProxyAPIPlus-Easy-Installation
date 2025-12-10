#!/usr/bin/env bash
# CLIProxyAPI-Plus Uninstaller
#
# SYNOPSIS
#     Completely remove CLIProxyAPI-Plus and related files
#
# USAGE
#     uninstall-cliproxyapi              # Interactive, keeps auth
#     uninstall-cliproxyapi --all        # Remove everything including auth
#     uninstall-cliproxyapi --force      # No confirmation

BIN_DIR="$HOME/bin"
CONFIG_DIR="$HOME/.cli-proxy-api"
CLONE_DIR="$HOME/CLIProxyAPIPlus"
FACTORY_CONFIG="$HOME/.factory/config.json"
BINARY_NAME="cliproxyapi-plus"

# Color output
print_step() { echo -e "\033[0;36m[*] $1\033[0m"; }
print_success() { echo -e "\033[0;32m[+] $1\033[0m"; }
print_warning() { echo -e "\033[0;33m[!] $1\033[0m"; }
print_error() { echo -e "\033[0;31m[-] $1\033[0m"; }

# Parse arguments
REMOVE_ALL=false
FORCE=false

for arg in "$@"; do
    case $arg in
        --all|-a) REMOVE_ALL=true ;;
        --force|-f) FORCE=true ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --all, -a      Remove everything including auth files"
            echo "  --force, -f    No confirmation prompt"
            echo "  --help, -h     Show this help"
            exit 0
            ;;
    esac
done

cat << "EOF"
==========================================
  CLIProxyAPI-Plus Uninstaller
==========================================
EOF

# Get file size
get_size() {
    local path=$1
    if [ -d "$path" ]; then
        du -sh "$path" 2>/dev/null | cut -f1
    elif [ -f "$path" ]; then
        ls -lh "$path" 2>/dev/null | awk '{print $5}'
    else
        echo "N/A"
    fi
}

# Count files
count_files() {
    local pattern=$1
    find $(dirname "$pattern") -name "$(basename "$pattern")" 2>/dev/null | wc -l
}

print_step "Scanning installation..."

# Items to remove
declare -a to_remove=()
declare -a to_keep=()

# Always remove items
items_always=(
    "$BIN_DIR/$BINARY_NAME:Binary"
    "$BIN_DIR/${BINARY_NAME}.old:Binary backup"
    "$BIN_DIR/install-cliproxyapi:Install script"
    "$BIN_DIR/start-cliproxyapi:Start script"
    "$BIN_DIR/cliproxyapi-oauth:OAuth script"
    "$BIN_DIR/update-cliproxyapi:Update script"
    "$BIN_DIR/uninstall-cliproxyapi:Uninstall script"
    "$BIN_DIR/gui-cliproxyapi:GUI script"
    "$CLONE_DIR:Clone directory"
    "$CONFIG_DIR/config.yaml:Config file"
    "$CONFIG_DIR/logs:Logs directory"
)

# Conditional items (only remove with --all)
items_conditional=(
    "$CONFIG_DIR/*.json:Auth files"
    "$CONFIG_DIR:Config directory"
    "$FACTORY_CONFIG:Droid config"
)

# Check always remove items
for item in "${items_always[@]}"; do
    IFS=':' read -r path name <<< "$item"
    
    # Handle glob patterns
    if [[ "$path" == *\** ]]; then
        if [ "$(count_files "$path")" -gt 0 ]; then
            size=$(get_size "$(dirname "$path")")
            to_remove+=("$name|$path|$size")
        fi
    elif [ -e "$path" ]; then
        size=$(get_size "$path")
        to_remove+=("$name|$path|$size")
    fi
done

# Check conditional items
for item in "${items_conditional[@]}"; do
    IFS=':' read -r path name <<< "$item"
    
    # Handle glob patterns
    if [[ "$path" == *\** ]]; then
        if [ "$(count_files "$path")" -gt 0 ]; then
            size="$(count_files "$path") files"
            if [ "$REMOVE_ALL" = true ]; then
                to_remove+=("$name|$path|$size")
            else
                to_keep+=("$name|$path|$size")
            fi
        fi
    elif [ -e "$path" ]; then
        size=$(get_size "$path")
        if [ "$REMOVE_ALL" = true ]; then
            to_remove+=("$name|$path|$size")
        else
            to_keep+=("$name|$path|$size")
        fi
    fi
done

# Display what will be removed
if [ ${#to_remove[@]} -eq 0 ]; then
    print_warning "Nothing to remove. CLIProxyAPI-Plus is not installed."
    exit 0
fi

echo ""
print_error "The following items will be REMOVED:"
for item in "${to_remove[@]}"; do
    IFS='|' read -r name path size <<< "$item"
    echo -e "    - \033[1m$name\033[0m ($size)"
    echo -e "      \033[2m$path\033[0m"
done

if [ ${#to_keep[@]} -gt 0 ]; then
    echo ""
    print_success "The following items will be KEPT:"
    for item in "${to_keep[@]}"; do
        IFS='|' read -r name path size <<< "$item"
        echo -e "    - \033[1m$name\033[0m ($size)"
        echo -e "      \033[2m$path\033[0m"
    done
    echo ""
    echo "    Use --all to remove everything"
fi

# Confirmation
if [ "$FORCE" = false ]; then
    echo ""
    read -p "Are you sure you want to uninstall? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo ""
        print_warning "Uninstall cancelled."
        exit 0
    fi
fi

# Stop server first
if pgrep -f "cliproxyapi-plus" > /dev/null; then
    print_step "Stopping server..."
    pkill -f "cliproxyapi-plus" || true
    sleep 0.5
fi

# Remove items
echo ""
print_step "Removing CLIProxyAPI-Plus..."
removed=0
failed=0

for item in "${to_remove[@]}"; do
    IFS='|' read -r name path size <<< "$item"
    
    if [[ "$path" == *\** ]]; then
        # Handle glob patterns
        for file in $path; do
            if [ -e "$file" ]; then
                if rm -rf "$file" 2>/dev/null; then
                    ((removed++))
                else
                    ((failed++))
                    print_error "Failed to remove: $file"
                fi
            fi
        done
        if [ "$removed" -gt 0 ]; then
            print_success "Removed: $name"
        fi
    else
        if rm -rf "$path" 2>/dev/null; then
            print_success "Removed: $name"
            ((removed++))
        else
            print_error "Failed to remove: $name"
            ((failed++))
        fi
    fi
done

# Clean up empty config directory
if [ "$REMOVE_ALL" = true ] && [ -d "$CONFIG_DIR" ]; then
    if [ -z "$(ls -A "$CONFIG_DIR")" ]; then
        rmdir "$CONFIG_DIR" 2>/dev/null
        print_success "Removed: Empty config directory"
    fi
fi

# Summary
cat << EOF

==========================================
  Uninstall Complete!
==========================================
EOF

echo "Removed: $removed items"
if [ $failed -gt 0 ]; then
    echo "Failed:  $failed items"
fi
if [ ${#to_keep[@]} -gt 0 ]; then
    echo "Kept:    ${#to_keep[@]} items"
fi

if [ ${#to_keep[@]} -gt 0 ] && [ "$REMOVE_ALL" = false ]; then
    echo ""
    echo "To remove everything including auth files:"
    echo "  uninstall-cliproxyapi --all --force"
fi

echo ""
