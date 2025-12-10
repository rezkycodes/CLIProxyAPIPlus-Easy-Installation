# GUI Provider Login - How It Works

## Overview

The GUI provider login feature opens a **new terminal window** to run the interactive OAuth authentication script. This is necessary because OAuth flows require user interaction (browser redirects, credential input, etc.).

## How to Use

1. **Start GUI Server**:
   ```bash
   ./scripts/start-gui.sh
   ```

2. **Open GUI in Browser**:
   ```
   http://localhost:8173
   ```

3. **Click on a Provider Icon** (e.g., Gemini, Copilot, Claude)

4. **A New Terminal Window Opens** automatically with the OAuth script

5. **Follow Instructions in Terminal**:
   - The script will guide you through authentication
   - May open browser for OAuth flow
   - Enter credentials if prompted
   - Wait for "Login completed!" message

6. **Close Terminal** when authentication is complete

7. **GUI Updates Automatically**:
   - Provider icon turns green (connected)
   - Status shows in activity log
   - Models list updates after 5-30 seconds

## Supported Providers

| Provider | Flag | Status |
|----------|------|--------|
| **Gemini** | `--gemini` | ✅ OAuth via CLI |
| **Copilot** | `--copilot` | ✅ GitHub OAuth |
| **Antigravity** | `--antigravity` | ✅ Browser OAuth |
| **Codex** | `--codex` | ✅ OpenAI OAuth |
| **Claude** | `--claude` | ✅ Anthropic OAuth |
| **Qwen** | `--qwen` | ✅ API Key |
| **iFlow** | `--iflow` | ✅ Custom OAuth |
| **Kiro** | `--kiro` | ✅ AWS OAuth |

## Terminal Emulators Detected

The GUI automatically detects and uses available terminal emulators in this order:

1. **x-terminal-emulator** (Debian/Ubuntu default)
2. **gnome-terminal** (GNOME Desktop)
3. **konsole** (KDE Desktop)
4. **xfce4-terminal** (XFCE Desktop)
5. **xterm** (Fallback - always available)

## Manual Login (Fallback)

If no terminal emulator is detected, GUI will show:

```
Open terminal and run: cliproxyapi-oauth --gemini
```

Then manually run in your terminal:
```bash
cliproxyapi-oauth --gemini
```

## Troubleshooting

### ❌ Terminal Doesn't Open

**Symptom:** Click provider icon, nothing happens

**Solution:**
1. Check activity log in GUI for error messages
2. Manually run in terminal:
   ```bash
   cliproxyapi-oauth --<provider>
   ```
3. Install a terminal emulator:
   ```bash
   # Ubuntu/Debian
   sudo apt install gnome-terminal
   
   # Fedora
   sudo dnf install gnome-terminal
   
   # Arch
   sudo pacman -S gnome-terminal
   ```

### ❌ Provider Icon Doesn't Turn Green

**Symptom:** Completed login but icon still gray

**Possible Causes:**
1. **OAuth not completed** - Check terminal for errors
2. **Config not saved** - Restart server after login
3. **GUI cache** - Refresh page (F5) or click "Refresh" button

**Solutions:**
```bash
# 1. Verify auth tokens exist
ls -la ~/.cli-proxy-api/

# 2. Check config file
cat ~/.cli-proxy-api/config.yaml

# 3. Restart server from GUI
# Click "Restart" button

# 4. Force refresh auth status
# Press 'R' key in GUI
```

### ❌ "Error: No terminal emulator found"

**Symptom:** GUI shows error message

**Solution:**
Install terminal emulator:
```bash
# Quick fix - install xterm (lightweight)
sudo apt install xterm       # Ubuntu/Debian
sudo dnf install xterm       # Fedora
sudo pacman -S xterm         # Arch

# Or install full-featured terminal
sudo apt install gnome-terminal
```

### ❌ OAuth Fails with "Browser not found"

**Symptom:** Terminal opens but OAuth fails

**Solution:**
1. Install a web browser:
   ```bash
   sudo apt install firefox
   ```

2. Set default browser:
   ```bash
   xdg-settings set default-web-browser firefox.desktop
   ```

3. Or manually copy URL from terminal to browser

## Behind the Scenes

### What Happens When You Click Provider Icon:

1. **GUI sends POST request** to backend:
   ```javascript
   POST /api/provider/login
   Body: {"provider": "gemini"}
   ```

2. **Backend detects terminal emulator**:
   ```python
   terminals = [
       'x-terminal-emulator',
       'gnome-terminal',
       'konsole',
       'xfce4-terminal',
       'xterm'
   ]
   ```

3. **Backend launches OAuth script in terminal**:
   ```bash
   gnome-terminal -- cliproxyapi-oauth --gemini
   ```

4. **OAuth script runs interactively**:
   ```bash
   cliproxyapi-plus --config ~/.cli-proxy-api/config.yaml --login
   ```

5. **Credentials saved** to config directory:
   ```
   ~/.cli-proxy-api/
   ├── config.yaml       # Updated with auth tokens
   ├── gemini_token.json # Provider-specific tokens
   └── ...
   ```

6. **GUI polls auth status**:
   - Checks after 5 seconds
   - Checks again after 15 seconds
   - Final check after 30 seconds

7. **Provider icon updates** when auth detected

## Manual Testing

Test provider login from command line:

```bash
# Test single provider
cliproxyapi-oauth --gemini

# Test all providers
cliproxyapi-oauth --all

# Interactive menu
cliproxyapi-oauth
```

Check auth status:
```bash
# View saved tokens
ls -la ~/.cli-proxy-api/

# Test API endpoint
curl http://localhost:8173/api/auth-status | jq
```

## Debug Mode

Enable verbose logging in terminal:

```bash
# Run GUI server in foreground to see logs
python3 gui/server.py
```

Watch for lines like:
```
[INFO] Provider login request: gemini
[INFO] Launching terminal: gnome-terminal -- cliproxyapi-oauth --gemini
[SUCCESS] Terminal launched successfully
```

## Security Notes

- ✅ Credentials stored locally in `~/.cli-proxy-api/`
- ✅ Config files are **not** world-readable (600 permissions)
- ✅ OAuth tokens encrypted when possible
- ✅ GUI backend runs on localhost only (not exposed to network)
- ⚠️ Backend API has no authentication (assumes trusted local user)

## Next Steps After Login

Once provider is authenticated:

1. **Restart Server** (if needed):
   - Click "Restart" button in GUI
   - Or `curl -X POST http://localhost:8173/api/restart`

2. **Check Available Models**:
   - Models list appears in GUI automatically
   - Or `curl http://localhost:8173/api/models`

3. **Test API Endpoint**:
   ```bash
   curl http://localhost:8317/v1/models
   ```

4. **Use in Applications**:
   ```bash
   export OPENAI_API_BASE=http://localhost:8317/v1
   export OPENAI_API_KEY=dummy
   
   # Now use any OpenAI-compatible app
   ```
