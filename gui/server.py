#!/usr/bin/env python3
"""
CLIProxyAPI+ GUI Backend Server
Provides API endpoints for the web-based control panel
"""

import os
import sys
import json
import signal
import subprocess
import time
from pathlib import Path
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

# Configuration
HOST = '0.0.0.0'
PORT = 8173
HOME = Path.home()
BIN_DIR = HOME / 'bin'
CONFIG_DIR = HOME / '.cli-proxy-api'
CONFIG_FILE = CONFIG_DIR / 'config.yaml'
PID_FILE = CONFIG_DIR / 'server.pid'
SERVER_BIN = BIN_DIR / 'cliproxyapi-plus'


class APIHandler(BaseHTTPRequestHandler):
    """HTTP Request Handler with API endpoints"""

    def _set_headers(self, status=200, content_type='application/json'):
        """Set response headers"""
        self.send_response(status)
        self.send_header('Content-Type', content_type)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def _send_json(self, data, status=200):
        """Send JSON response"""
        self._set_headers(status)
        self.wfile.write(json.dumps(data).encode())

    def _send_file(self, filepath):
        """Send static file"""
        try:
            with open(filepath, 'rb') as f:
                content = f.read()
            
            # Determine content type
            if filepath.endswith('.html'):
                content_type = 'text/html'
            elif filepath.endswith('.css'):
                content_type = 'text/css'
            elif filepath.endswith('.js'):
                content_type = 'application/javascript'
            else:
                content_type = 'application/octet-stream'
            
            self._set_headers(200, content_type)
            self.wfile.write(content)
        except FileNotFoundError:
            self._set_headers(404, 'text/plain')
            self.wfile.write(b'404 Not Found')

    def do_OPTIONS(self):
        """Handle CORS preflight"""
        self._set_headers()

    def do_GET(self):
        """Handle GET requests"""
        parsed = urlparse(self.path)
        path = parsed.path

        # Static files
        if path == '/' or path == '/index.html':
            self._send_file('index.html')
        elif path.startswith('/api/'):
            self._handle_api_get(path)
        else:
            self._set_headers(404, 'text/plain')
            self.wfile.write(b'404 Not Found')

    def do_POST(self):
        """Handle POST requests"""
        parsed = urlparse(self.path)
        path = parsed.path

        if path.startswith('/api/'):
            # Read POST data
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            try:
                data = json.loads(post_data) if post_data else {}
            except json.JSONDecodeError:
                data = {}
            
            self._handle_api_post(path, data)
        else:
            self._send_json({'error': 'Not Found'}, 404)

    def _handle_api_get(self, path):
        """Handle API GET requests"""
        if path == '/api/status':
            self._api_status()
        elif path == '/api/auth-status':
            self._api_auth_status()
        elif path == '/api/models':
            self._api_models()
        elif path == '/api/stats':
            self._api_stats()
        elif path == '/api/config':
            self._api_get_config()
        elif path == '/api/update/check':
            self._api_check_update()
        else:
            self._send_json({'error': 'Not Found'}, 404)

    def _handle_api_post(self, path, data):
        """Handle API POST requests"""
        if path == '/api/start':
            self._api_start()
        elif path == '/api/stop':
            self._api_stop()
        elif path == '/api/restart':
            self._api_restart()
        elif path == '/api/config':
            self._api_save_config(data)
        elif path == '/api/provider/login':
            self._api_provider_login(data)
        elif path == '/api/update/apply':
            self._api_apply_update()
        else:
            self._send_json({'error': 'Not Found'}, 404)

    def _get_server_pid(self):
        """Get CLIProxyAPI server PID"""
        if not PID_FILE.exists():
            return None
        
        try:
            with open(PID_FILE) as f:
                pid = int(f.read().strip())
            
            # Check if process is running
            try:
                os.kill(pid, 0)
                return pid
            except OSError:
                # Process not running, clean up PID file
                PID_FILE.unlink(missing_ok=True)
                return None
        except (ValueError, FileNotFoundError):
            return None

    def _is_server_running(self):
        """Check if CLIProxyAPI server is running"""
        pid = self._get_server_pid()
        if pid:
            try:
                os.kill(pid, 0)
                return True
            except OSError:
                return False
        return False

    def _api_status(self):
        """API: Get server status"""
        pid = self._get_server_pid()
        running = self._is_server_running()
        
        status = {
            'running': running,
            'pid': pid if running else None,
            'port': 8317,
            'startTime': None
        }
        
        # Get start time from PID file mtime
        if running and PID_FILE.exists():
            mtime = PID_FILE.stat().st_mtime
            status['startTime'] = int(mtime * 1000)  # milliseconds
        
        self._send_json(status)

    def _api_auth_status(self):
        """API: Get provider authentication status"""
        # Check config for API keys
        auth_status = {
            'gemini': False,
            'copilot': False,
            'antigravity': False,
            'codex': False,
            'claude': False,
            'qwen': False,
            'iflow': False,
            'kiro': False
        }
        
        if CONFIG_FILE.exists():
            try:
                import yaml
                with open(CONFIG_FILE) as f:
                    config = yaml.safe_load(f) or {}
                
                # Check for API keys
                providers = config.get('providers', {})
                for provider in auth_status.keys():
                    provider_config = providers.get(provider, {})
                    if isinstance(provider_config, dict):
                        auth_status[provider] = bool(provider_config.get('api_key') or provider_config.get('token'))
            except Exception as e:
                print(f"Error checking auth status: {e}", file=sys.stderr)
        
        self._send_json(auth_status)

    def _api_models(self):
        """API: Get available models"""
        if not self._is_server_running():
            self._send_json({'success': False, 'models': []})
            return
        
        # Try to get models from server
        try:
            import urllib.request
            req = urllib.request.Request('http://localhost:8317/v1/models')
            with urllib.request.urlopen(req, timeout=2) as response:
                data = json.loads(response.read())
                models = [m['id'] for m in data.get('data', [])]
                self._send_json({'success': True, 'models': models})
        except Exception as e:
            self._send_json({'success': False, 'models': [], 'error': str(e)})

    def _api_stats(self):
        """API: Get request statistics"""
        # Placeholder - would need to read from server stats
        stats = {
            'total': 0,
            'success': 0,
            'errors': 0,
            'avgLatency': 0
        }
        self._send_json(stats)

    def _api_get_config(self):
        """API: Get configuration file content"""
        if CONFIG_FILE.exists():
            try:
                with open(CONFIG_FILE) as f:
                    content = f.read()
                self._send_json({'success': True, 'content': content})
            except Exception as e:
                self._send_json({'success': False, 'error': str(e)})
        else:
            self._send_json({'success': False, 'error': 'Config file not found'})

    def _api_save_config(self, data):
        """API: Save configuration file"""
        try:
            content = data.get('content', '')
            with open(CONFIG_FILE, 'w') as f:
                f.write(content)
            self._send_json({'success': True})
        except Exception as e:
            self._send_json({'success': False, 'error': str(e)})

    def _api_start(self):
        """API: Start CLIProxyAPI server"""
        if self._is_server_running():
            self._send_json({'success': False, 'error': 'Server is already running'})
            return
        
        try:
            # Start server in background
            cmd = [str(SERVER_BIN), '--config', str(CONFIG_FILE)]
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True
            )
            
            # Save PID
            with open(PID_FILE, 'w') as f:
                f.write(str(process.pid))
            
            # Wait a bit to see if it starts
            time.sleep(0.5)
            
            if self._is_server_running():
                self._send_json({'success': True, 'pid': process.pid})
            else:
                self._send_json({'success': False, 'error': 'Server failed to start'})
        except Exception as e:
            self._send_json({'success': False, 'error': str(e)})

    def _api_stop(self):
        """API: Stop CLIProxyAPI server"""
        pid = self._get_server_pid()
        if not pid:
            self._send_json({'success': False, 'error': 'Server is not running'})
            return
        
        try:
            # Send SIGTERM
            os.kill(pid, signal.SIGTERM)
            
            # Wait for process to stop
            for _ in range(10):
                time.sleep(0.2)
                if not self._is_server_running():
                    break
            
            # Force kill if still running
            if self._is_server_running():
                os.kill(pid, signal.SIGKILL)
                time.sleep(0.2)
            
            # Clean up PID file
            PID_FILE.unlink(missing_ok=True)
            
            self._send_json({'success': True})
        except Exception as e:
            self._send_json({'success': False, 'error': str(e)})

    def _api_restart(self):
        """API: Restart CLIProxyAPI server"""
        try:
            # Stop first
            was_running = self._is_server_running()
            if was_running:
                pid = self._get_server_pid()
                if pid:
                    try:
                        os.kill(pid, signal.SIGTERM)
                        # Wait for process to stop
                        for _ in range(10):
                            time.sleep(0.2)
                            if not self._is_server_running():
                                break
                        
                        # Force kill if still running
                        if self._is_server_running():
                            os.kill(pid, signal.SIGKILL)
                            time.sleep(0.2)
                    except Exception:
                        pass
                    
                    # Clean up PID file
                    PID_FILE.unlink(missing_ok=True)
                
                # Wait before restart
                time.sleep(1)
            
            # Start server
            cmd = [str(SERVER_BIN), '--config', str(CONFIG_FILE)]
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True
            )
            
            # Save PID
            with open(PID_FILE, 'w') as f:
                f.write(str(process.pid))
            
            # Wait a bit to see if it starts
            time.sleep(0.5)
            
            if self._is_server_running():
                self._send_json({'success': True, 'pid': process.pid, 'restarted': was_running})
            else:
                self._send_json({'success': False, 'error': 'Server failed to start after restart'})
        except Exception as e:
            self._send_json({'success': False, 'error': f'Restart failed: {str(e)}'})

    def _api_provider_login(self, data):
        """API: Login to provider (OAuth flow)"""
        provider = data.get('provider')
        if not provider:
            self._send_json({'success': False, 'error': 'Provider not specified'})
            return
        
        # Map provider names to OAuth flags
        provider_flags = {
            'gemini': '--gemini',
            'copilot': '--copilot',
            'antigravity': '--antigravity',
            'codex': '--codex',
            'claude': '--claude',
            'qwen': '--qwen',
            'iflow': '--iflow',
            'kiro': '--kiro'
        }
        
        flag = provider_flags.get(provider)
        if not flag:
            self._send_json({'success': False, 'error': f'Unknown provider: {provider}'})
            return
        
        # Run OAuth script in a new terminal
        script = BIN_DIR / 'cliproxyapi-oauth'
        
        try:
            # Detect terminal emulator
            terminals = [
                ['x-terminal-emulator', '-e'],  # Debian/Ubuntu default
                ['gnome-terminal', '--'],       # GNOME
                ['konsole', '-e'],              # KDE
                ['xfce4-terminal', '-e'],       # XFCE
                ['xterm', '-e'],                # Fallback
            ]
            
            terminal_cmd = None
            for term in terminals:
                if subprocess.run(['which', term[0]], 
                                capture_output=True, 
                                check=False).returncode == 0:
                    terminal_cmd = term
                    break
            
            if terminal_cmd:
                # Launch in new terminal
                cmd = terminal_cmd + [str(script), flag]
                subprocess.Popen(cmd, start_new_session=True, 
                               stdout=subprocess.DEVNULL, 
                               stderr=subprocess.DEVNULL)
                self._send_json({'success': True, 'message': f'Opening terminal for {provider} login'})
            else:
                # No terminal found - provide manual instructions
                self._send_json({
                    'success': False, 
                    'error': 'No terminal emulator found',
                    'instructions': f'Please run manually: cliproxyapi-oauth {flag}'
                })
        except Exception as e:
            self._send_json({'success': False, 'error': str(e)})

    def _api_check_update(self):
        """API: Check for updates"""
        try:
            import urllib.request
            import json
            
            # Check GitHub releases
            url = 'https://api.github.com/repos/julianromli/CLIProxyAPIPlus-Easy-Installation/releases/latest'
            req = urllib.request.Request(url)
            req.add_header('User-Agent', 'CLIProxyAPI-GUI')
            
            with urllib.request.urlopen(req, timeout=5) as response:
                data = json.loads(response.read())
                latest = data.get('tag_name', 'v1.1.0').replace('v', '')
                current = '1.1.0'
                
                has_update = latest > current
                
                self._send_json({
                    'success': True,
                    'hasUpdate': has_update,
                    'currentVersion': f'v{current}',
                    'latestVersion': f'v{latest}',
                    'releaseNotes': data.get('body', 'No release notes available.')
                })
        except Exception as e:
            # Fallback - no update available
            self._send_json({
                'success': True,
                'hasUpdate': False,
                'currentVersion': 'v1.1.0',
                'latestVersion': 'v1.1.0',
                'releaseNotes': f'Could not check for updates: {str(e)}'
            })

    def _api_apply_update(self):
        """API: Apply update"""
        # Placeholder - would run update script
        self._send_json({'success': False, 'error': 'Updates not implemented yet'})

    def log_message(self, format, *args):
        """Override to customize logging"""
        message = format % args
        print(f"[{self.log_date_time_string()}] {message}")


class ReuseAddrHTTPServer(HTTPServer):
    """HTTPServer with SO_REUSEADDR enabled"""
    allow_reuse_address = True


def main():
    """Start the GUI backend server"""
    # Change to GUI directory
    gui_dir = Path(__file__).parent
    os.chdir(gui_dir)
    
    # Create config directory if it doesn't exist
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    
    # Try to start HTTP server
    max_retries = 5
    port = PORT
    
    for attempt in range(max_retries):
        try:
            server = ReuseAddrHTTPServer((HOST, port), APIHandler)
            print(f"CLIProxyAPI+ GUI Server")
            print(f"Listening on http://{HOST}:{port}")
            print(f"Open http://localhost:{port} in your browser")
            print("Press Ctrl+C to stop")
            print()
            
            try:
                server.serve_forever()
            except KeyboardInterrupt:
                print("\nShutting down server...")
                server.shutdown()
            break
            
        except OSError as e:
            if e.errno == 98:  # Address already in use
                print(f"Port {port} is already in use", file=sys.stderr)
                if attempt < max_retries - 1:
                    port += 1
                    print(f"Trying port {port}...", file=sys.stderr)
                    time.sleep(0.5)
                else:
                    print("\nError: Could not find available port", file=sys.stderr)
                    print("Try killing the existing process:", file=sys.stderr)
                    print(f"  pkill -f 'python.*server.py'", file=sys.stderr)
                    print(f"  # or", file=sys.stderr)
                    print(f"  kill $(lsof -ti:{PORT})", file=sys.stderr)
                    sys.exit(1)
            else:
                raise


if __name__ == '__main__':
    main()
