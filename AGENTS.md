# AGENTS.md - CLIProxyAPIPlus Easy Installation

> Guidance for AI coding agents working on this repository.

## Project Snapshot

- **Type**: Utility scripts collection (PowerShell + Bash)
- **Purpose**: One-click installation scripts for CLIProxyAPIPlus proxy server
- **Platform**: Cross-platform (Windows PowerShell 5.1+ / Linux Bash 4.0+)
- **Sub-docs**: See [scripts/AGENTS.md](scripts/AGENTS.md) for script-specific patterns

## Quick Commands

**Windows (PowerShell):**
```powershell
# Test install script (dry run not available - test on VM/sandbox)
.\scripts\install-cliproxyapi.ps1 -UsePrebuilt

# Test OAuth script (interactive)
.\scripts\cliproxyapi-oauth.ps1

# Test update script
.\scripts\update-cliproxyapi.ps1 -UsePrebuilt

# Test uninstall (use -Force to skip confirmation)
.\scripts\uninstall-cliproxyapi.ps1 -Force
```

**Linux (Bash):**
```bash
# Test install script (dry run not available - test on VM/sandbox)
./scripts/install-cliproxyapi.sh --use-prebuilt

# Test OAuth script (interactive)
./scripts/cliproxyapi-oauth.sh

# Test update script
./scripts/update-cliproxyapi.sh --use-prebuilt

# Test uninstall (use --force to skip confirmation)
./scripts/uninstall-cliproxyapi.sh --force
```

## Repository Structure

```
├── scripts/           → PowerShell (.ps1) + Bash (.sh) scripts [see scripts/AGENTS.md]
│   ├── *.ps1         → Windows PowerShell versions
│   └── *.sh          → Linux Bash versions
├── configs/           → Example config files (YAML, JSON)
├── gui/              → Web-based GUI (index.html)
├── README.md          → English docs
├── README_ID.md       → Indonesian docs
└── LICENSE            → MIT
```

## Universal Conventions

### Code Style

**PowerShell (.ps1):**
- Use approved verbs (`Get-`, `Set-`, `New-`, `Remove-`)
- Indentation: 4 spaces (no tabs)
- Comments: Use `#` for inline, `<# #>` for block/help
- Encoding: UTF-8 with BOM for PowerShell scripts
- Parameters: Use `-PascalCase` (e.g., `-UsePrebuilt`, `-Force`)

**Bash (.sh):**
- Use POSIX-compliant commands where possible
- Indentation: 4 spaces (no tabs)
- Comments: Use `#` for inline and block comments
- Encoding: UTF-8 without BOM
- Shebang: Always start with `#!/usr/bin/env bash`
- Parameters: Use `--kebab-case` (e.g., `--use-prebuilt`, `--force`)
- Set strict mode: `set -e` (exit on error)

### Commit Format
```
type: short description

- detail 1
- detail 2
```
Types: `feat`, `fix`, `docs`, `refactor`, `chore`

### Branch Strategy
- `main` - stable releases only
- `dev` - development branch
- Feature branches: `feat/description`

## Security & Secrets

- **NEVER** commit real API keys or OAuth tokens
- Use `sk-dummy` as placeholder in examples
- Config paths:
  - Windows: Use `~` or `$env:USERPROFILE` (resolved at runtime)
  - Linux: Use `~` or `$HOME` (resolved at runtime)
- No hardcoded usernames or paths
- Make all `.sh` scripts executable: `chmod +x scripts/*.sh`

## JIT Index

### Find Script Functions
```powershell
# Find all functions in scripts
Select-String -Path "scripts\*.ps1" -Pattern "^function\s+\w+"

# Find param blocks
Select-String -Path "scripts\*.ps1" -Pattern "param\s*\("
```

### Find Config Patterns
```powershell
# Find model definitions
Select-String -Path "configs\*.json" -Pattern "model_display_name"

# Find YAML keys
Select-String -Path "configs\*.yaml" -Pattern "^\w+:"
```

## Definition of Done

Before PR:
- [ ] **Windows**: Script runs without errors on clean Windows install
- [ ] **Linux**: Script runs without errors on Ubuntu/Fedora
- [ ] **Windows**: Help text updated (`Get-Help .\script.ps1`)
- [ ] **Linux**: Help flag works (`./script.sh --help`)
- [ ] Both `.ps1` and `.sh` versions have feature parity
- [ ] README updated if new features added
- [ ] Both English and Indonesian READMEs in sync
- [ ] Scripts are executable on Linux (`chmod +x`)

## Cross-Platform Development

### Feature Parity
Both PowerShell and Bash versions should provide the same functionality:
- Same command-line parameters (adjusted for platform conventions)
- Same output messages and colors
- Same error handling behavior
- Same file operations and path handling

### Parameter Naming Conventions
| PowerShell | Bash | Description |
|------------|------|-------------|
| `-UsePrebuilt` | `--use-prebuilt` | Download binary instead of building |
| `-Force` | `--force` | Skip confirmations |
| `-Background` | `--background` | Run in background |
| `-Status` | `--status` | Check server status |
| `-All` | `--all` | Apply to all items |
| `-NoBrowser` | `--no-browser` | Don't open browser |

### Path Handling
```powershell
# PowerShell
$HOME_DIR = $env:USERPROFILE      # C:\Users\username
$BIN_DIR = "$env:USERPROFILE\bin"
$CONFIG = "$env:USERPROFILE\.cli-proxy-api\config.yaml"
```

```bash
# Bash
HOME_DIR=$HOME                     # /home/username
BIN_DIR="$HOME/bin"
CONFIG="$HOME/.cli-proxy-api/config.yaml"
```

### Testing Both Versions
```powershell
# Windows (PowerShell)
.\scripts\install-cliproxyapi.ps1 -UsePrebuilt -Force
start-cliproxyapi -Status
```

```bash
# Linux (Bash)
./scripts/install-cliproxyapi.sh --use-prebuilt --force
start-cliproxyapi --status
```
