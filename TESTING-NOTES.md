# GUI Testing Notes

## Issues Fixed

### ❌ Previous Issue: JSON Parse Error on Restart
**Error:** `Unexpected non-whitespace character after JSON at position 17`

**Root Cause:**
- `/api/restart` endpoint was calling `_api_stop()` and `_api_start()` which already sent JSON responses
- This caused multiple HTTP responses for a single request
- JavaScript couldn't parse the malformed response

**Fix:**
- Rewrote `_api_restart()` to handle stop/start logic internally
- Returns single JSON response: `{'success': True/False, 'pid': int, 'restarted': bool}`

### ❌ Previous Issue: Provider Login 404 Error
**Error:** `GET /api/oauth/gemini HTTP/1.1 404`

**Root Cause:**
- GUI JavaScript called `/api/oauth/{provider}` endpoint
- Backend only had `/api/provider/login` endpoint
- Endpoint mismatch caused 404

**Fix:**
- Updated `loginProvider()` function to use correct endpoint
- Changed from GET to POST with JSON body: `{"provider": "name"}`
- Added auto-refresh of auth status after login

### ❌ Issue: Provider Login Doesn't Work
**Error:** Click provider icon, but login doesn't happen

**Root Cause:**
- OAuth script requires interactive terminal
- Backend called subprocess without terminal
- Process ran but had no way to interact with user

**Fix:**
- Detect available terminal emulator (gnome-terminal, konsole, xterm, etc.)
- Launch OAuth script in new terminal window
- Map provider names to correct OAuth flags (--gemini, --copilot, etc.)
- Show fallback instructions if no terminal available
- Poll auth status multiple times (5s, 15s, 30s) after login attempt

### ✅ Improved Error Handling
**Changes:**
- All API calls now check `res.ok` before parsing JSON
- Added try-catch with detailed error messages
- Parse response text first, then JSON to avoid parse errors
- Show user-friendly toast notifications on errors

## Test Checklist

Before submitting PR, verify:

- [ ] **Start Server**: Click Start button → server starts, PID shown
- [ ] **Stop Server**: Click Stop button → server stops gracefully
- [ ] **Restart Server**: Click Restart button → server restarts without errors
- [ ] **Status Check**: Status updates every 5 seconds automatically
- [ ] **Provider Login**: 
  - Click provider icon → new terminal window opens
  - Complete OAuth in terminal
  - Provider icon turns green after authentication
  - Auth status updates in GUI after 5-30 seconds
- [ ] **Config Edit**: Open Configuration → edit → Save & Restart works
- [ ] **Models List**: When server running, models section shows available models
- [ ] **Activity Log**: All actions logged with timestamps
- [ ] **Update Check**: Click version badge → checks for updates from GitHub
- [ ] **Keyboard Shortcut**: Press 'R' key → refreshes status
- [ ] **Auto-start**: Enable toggle → next GUI load auto-starts server

## Manual Testing Commands

```bash
# 1. Start GUI server
./scripts/start-gui.sh

# 2. Check if running
curl -s http://localhost:8173/api/status | jq

# 3. Test start endpoint
curl -X POST http://localhost:8173/api/start | jq

# 4. Test status endpoint
curl http://localhost:8173/api/status | jq

# 5. Test restart endpoint
curl -X POST http://localhost:8173/api/restart | jq

# 6. Test stop endpoint
curl -X POST http://localhost:8173/api/stop | jq

# 7. Test auth status
curl http://localhost:8173/api/auth-status | jq

# 8. Test config get
curl http://localhost:8173/api/config | jq

# 9. Test update check
curl http://localhost:8173/api/update/check | jq
```

## Browser Console Testing

Open browser console (F12) and run:

```javascript
// Test status
fetch('/api/status').then(r => r.json()).then(console.log)

// Test start
fetch('/api/start', {method: 'POST'}).then(r => r.json()).then(console.log)

// Test restart
fetch('/api/restart', {method: 'POST'}).then(r => r.json()).then(console.log)

// Test provider login
fetch('/api/provider/login', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({provider: 'gemini'})
}).then(r => r.json()).then(console.log)
```

## Common Issues & Solutions

### Port 8173 already in use
```bash
# Find process
lsof -ti:8173

# Kill it
kill -9 $(lsof -ti:8173)
```

### PyYAML not found
```bash
python3 -m pip install pyyaml
```

### Server binary not found
```bash
# Check if exists
ls -la ~/bin/cliproxyapi-plus

# If missing, reinstall
./scripts/install-cliproxyapi.sh
```

### Config file not found
```bash
# Check if exists
ls -la ~/.cli-proxy-api/config.yaml

# Create from example
cp configs/config.example.yaml ~/.cli-proxy-api/config.yaml
```
