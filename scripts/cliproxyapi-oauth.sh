#!/usr/bin/env bash
# CLIProxyAPI-Plus OAuth Login Helper
#
# SYNOPSIS
#     Interactive OAuth login helper for all supported providers
#
# USAGE
#     cliproxyapi-oauth              # Interactive menu
#     cliproxyapi-oauth --all        # Login to all providers
#     cliproxyapi-oauth --gemini     # Login to Gemini only

CONFIG_DIR="$HOME/.cli-proxy-api"
CONFIG_FILE="$CONFIG_DIR/config.yaml"
BINARY="$HOME/bin/cliproxyapi-plus"

# Color output
print_step() { echo -e "\033[0;36m[*] $1\033[0m"; }
print_success() { echo -e "\033[0;32m[+] $1\033[0m"; }
print_warning() { echo -e "\033[0;33m[!] $1\033[0m"; }
print_error() { echo -e "\033[0;31m[-] $1\033[0m"; }

if [ ! -f "$BINARY" ]; then
    print_error "cliproxyapi-plus not found. Run install-cliproxyapi.sh first."
    exit 1
fi

# Provider definitions
declare -A PROVIDERS=(
    ["1"]="Gemini CLI|--login"
    ["2"]="Antigravity|--antigravity-login"
    ["3"]="GitHub Copilot|--github-copilot-login"
    ["4"]="Codex|--codex-login"
    ["5"]="Claude|--claude-login"
    ["6"]="Qwen|--qwen-login"
    ["7"]="iFlow|--iflow-login"
    ["8"]="Kiro (AWS)|--kiro-aws-login"
)

# Run login for a provider
run_login() {
    local name=$1
    local flag=$2
    
    echo ""
    print_step "Logging in to $name..."
    echo "    Command: $BINARY --config $CONFIG_FILE $flag"
    
    "$BINARY" --config "$CONFIG_FILE" "$flag"
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        print_success "$name login completed!"
    else
        print_warning "$name login may have issues (exit code: $exit_code)"
    fi
}

# Parse flags
ALL_FLAG=false
GEMINI_FLAG=false
ANTIGRAVITY_FLAG=false
COPILOT_FLAG=false
CODEX_FLAG=false
CLAUDE_FLAG=false
QWEN_FLAG=false
IFLOW_FLAG=false
KIRO_FLAG=false

for arg in "$@"; do
    case $arg in
        --all|-a) ALL_FLAG=true ;;
        --gemini) GEMINI_FLAG=true ;;
        --antigravity) ANTIGRAVITY_FLAG=true ;;
        --copilot) COPILOT_FLAG=true ;;
        --codex) CODEX_FLAG=true ;;
        --claude) CLAUDE_FLAG=true ;;
        --qwen) QWEN_FLAG=true ;;
        --iflow) IFLOW_FLAG=true ;;
        --kiro) KIRO_FLAG=true ;;
        --help|-h)
            echo "Usage: cliproxyapi-oauth [OPTIONS]"
            echo "Options:"
            echo "  --all          Login to all providers"
            echo "  --gemini       Login to Gemini CLI"
            echo "  --antigravity  Login to Antigravity"
            echo "  --copilot      Login to GitHub Copilot"
            echo "  --codex        Login to Codex"
            echo "  --claude       Login to Claude"
            echo "  --qwen         Login to Qwen"
            echo "  --iflow        Login to iFlow"
            echo "  --kiro         Login to Kiro (AWS)"
            echo "  --help, -h     Show this help"
            exit 0
            ;;
    esac
done

# Check if any flag was passed
any_flag=false
for arg in "$@"; do
    if [[ "$arg" == --* ]]; then
        any_flag=true
        break
    fi
done

if [ "$any_flag" = true ]; then
    # Direct mode - run specified logins
    echo "=== CLIProxyAPI-Plus OAuth Login ==="
    
    if [ "$ALL_FLAG" = true ] || [ "$GEMINI_FLAG" = true ]; then
        run_login "Gemini CLI" "--login"
    fi
    
    if [ "$ALL_FLAG" = true ] || [ "$ANTIGRAVITY_FLAG" = true ]; then
        run_login "Antigravity" "--antigravity-login"
    fi
    
    if [ "$ALL_FLAG" = true ] || [ "$COPILOT_FLAG" = true ]; then
        run_login "GitHub Copilot" "--github-copilot-login"
    fi
    
    if [ "$ALL_FLAG" = true ] || [ "$CODEX_FLAG" = true ]; then
        run_login "Codex" "--codex-login"
    fi
    
    if [ "$ALL_FLAG" = true ] || [ "$CLAUDE_FLAG" = true ]; then
        run_login "Claude" "--claude-login"
    fi
    
    if [ "$ALL_FLAG" = true ] || [ "$QWEN_FLAG" = true ]; then
        run_login "Qwen" "--qwen-login"
    fi
    
    if [ "$ALL_FLAG" = true ] || [ "$IFLOW_FLAG" = true ]; then
        run_login "iFlow" "--iflow-login"
    fi
    
    if [ "$ALL_FLAG" = true ] || [ "$KIRO_FLAG" = true ]; then
        run_login "Kiro (AWS)" "--kiro-aws-login"
    fi
else
    # Interactive menu mode
    cat << "EOF"
==========================================
  CLIProxyAPI-Plus OAuth Login Menu
==========================================
EOF
    
    echo "Available providers:"
    echo "  1. Gemini CLI"
    echo "  2. Antigravity"
    echo "  3. GitHub Copilot"
    echo "  4. Codex"
    echo "  5. Claude"
    echo "  6. Qwen"
    echo "  7. iFlow"
    echo "  8. Kiro (AWS)"
    echo "  A. Login to ALL providers"
    echo "  Q. Quit"
    echo ""
    
    while true; do
        read -p "Select provider(s) [1-8, A, or Q]: " choice
        
        case $choice in
            Q|q)
                echo "Bye!"
                break
                ;;
            A|a)
                echo ""
                echo "Logging in to ALL providers..."
                for key in $(echo "${!PROVIDERS[@]}" | tr ' ' '\n' | sort -n); do
                    IFS='|' read -r name flag <<< "${PROVIDERS[$key]}"
                    run_login "$name" "$flag"
                    echo ""
                    read -p "Press Enter to continue to next provider..."
                done
                print_success "All logins completed!"
                break
                ;;
            [1-8])
                if [ -n "${PROVIDERS[$choice]}" ]; then
                    IFS='|' read -r name flag <<< "${PROVIDERS[$choice]}"
                    run_login "$name" "$flag"
                else
                    print_warning "Invalid selection: $choice"
                fi
                echo ""
                ;;
            *)
                print_warning "Invalid input. Please select 1-8, A, or Q."
                ;;
        esac
    done
fi

cat << EOF

==========================================
  Auth files saved in: $CONFIG_DIR
==========================================
EOF
