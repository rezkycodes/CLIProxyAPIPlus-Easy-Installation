# Kiro (AWS) Provider Setup Guide

## Problem

Error yang muncul:
```
[warning] [kiro_executor.go:124] kiro: profile ARN not found in auth, API calls may fail
[GIN] 2025/12/10 - 19:34:40 | 400 | 3.066s | ::1 | POST "/v1/responses"
```

**Root Cause:** Kiro auth file memiliki `profile_arn` kosong (`""`).

## Solution

Kiro memerlukan **AWS Profile ARN** yang harus diisi manual setelah OAuth login.

### Step 1: Get Your AWS Profile ARN

1. **Login ke AWS Console**: https://console.aws.amazon.com/
2. **Navigate ke IAM** → Users → Your User
3. **Copy ARN** dari halaman user, contoh:
   ```
   arn:aws:iam::123456789012:user/your-username
   ```

Atau gunakan AWS CLI:
```bash
aws sts get-caller-identity --query Arn --output text
```

### Step 2: Update Kiro Auth File

**Option A: Manual Edit**

1. Find latest Kiro auth file:
   ```bash
   ls -lt ~/.cli-proxy-api/kiro-aws-*.json | head -1
   ```

2. Edit file (replace `LATEST_FILE` with actual filename):
   ```bash
   nano ~/.cli-proxy-api/LATEST_FILE.json
   ```

3. Find line:
   ```json
   "profile_arn": "",
   ```

4. Replace with your ARN:
   ```json
   "profile_arn": "arn:aws:iam::123456789012:user/your-username",
   ```

5. Save and exit (Ctrl+O, Enter, Ctrl+X)

**Option B: Use Helper Script**

```bash
# Get your ARN
ARN=$(aws sts get-caller-identity --query Arn --output text)

# Find latest Kiro auth file
KIRO_FILE=$(ls -t ~/.cli-proxy-api/kiro-aws-*.json | head -1)

# Update profile_arn using jq
jq --arg arn "$ARN" '.profile_arn = $arn' "$KIRO_FILE" > /tmp/kiro-temp.json
mv /tmp/kiro-temp.json "$KIRO_FILE"

echo "✓ Updated profile_arn to: $ARN"
```

**Option C: Quick sed command**

```bash
# Replace YOUR_ARN_HERE with actual ARN
KIRO_FILE=$(ls -t ~/.cli-proxy-api/kiro-aws-*.json | head -1)
sed -i 's|"profile_arn": ""|"profile_arn": "arn:aws:iam::123456789012:user/your-username"|' "$KIRO_FILE"
```

### Step 3: Restart Server

From GUI:
- Click **Restart** button

Or from terminal:
```bash
# Stop
curl -X POST http://localhost:8173/api/stop

# Start
curl -X POST http://localhost:8173/api/start
```

Or restart script:
```bash
killall cliproxyapi-plus
start-cliproxyapi
```

### Step 4: Test Kiro

Test API call:
```bash
curl http://localhost:8317/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "kiro-aws/claude-3-5-sonnet-20241022-v2:0",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

Check logs:
```bash
tail -f ~/.cli-proxy-api/server.log | grep kiro
```

## Kiro Models Available

After fixing profile_arn, these models should work:

```
kiro-aws/claude-3-5-sonnet-20241022-v2:0
kiro-aws/claude-3-5-haiku-20241022-v1:0
kiro-aws/nova-pro-v1:0
kiro-aws/nova-lite-v1:0
kiro-aws/nova-micro-v1:0
```

## Troubleshooting

### Still getting "profile ARN not found"?

1. **Check if file was updated**:
   ```bash
   cat $(ls -t ~/.cli-proxy-api/kiro-aws-*.json | head -1) | jq .profile_arn
   ```
   
   Should output your ARN, not empty string `""`

2. **Check file permissions**:
   ```bash
   ls -la ~/.cli-proxy-api/kiro-aws-*.json
   ```
   Should be `-rw-------` (600)

3. **Server using old auth file?**
   - Multiple kiro-aws files may exist
   - Server picks latest one
   - Delete old files:
     ```bash
     cd ~/.cli-proxy-api
     ls -t kiro-aws-*.json | tail -n +2 | xargs rm -f
     ```
   - Keep only the latest one

4. **ARN format incorrect?**
   - Must start with `arn:aws:`
   - Example: `arn:aws:iam::123456789012:user/username`
   - Get from: `aws sts get-caller-identity`

### How to verify Kiro is working?

Look for these log messages (no warnings):
```bash
tail -f ~/.cli-proxy-api/server.log | grep kiro
```

Success:
```
[info] [kiro_executor.go:1811] kiro executor: token refreshed successfully
[GIN] 2025/12/10 - 19:34:40 | 200 | 3.066s | ::1 | POST "/v1/chat/completions"
```

Failure (needs profile ARN):
```
[warning] [kiro_executor.go:124] kiro: profile ARN not found in auth
[GIN] 2025/12/10 - 19:34:40 | 400 | 3.066s | ::1 | POST "/v1/responses"
```

## Why is profile_arn empty?

The OAuth flow for Kiro only gets AWS tokens (access_token, refresh_token), but **does not** automatically detect your AWS Profile ARN. This must be added manually because:

1. AWS IAM identity requires explicit user ARN
2. Kiro uses this ARN to make AWS Bedrock API calls
3. OAuth doesn't provide ARN in token response

## Automated Fix Script

Save this as `fix-kiro-arn.sh`:

```bash
#!/usr/bin/env bash
set -e

echo "Kiro Profile ARN Fixer"
echo "====================="

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI not found"
    echo "Please install: pip install awscli"
    exit 1
fi

# Get ARN from AWS
echo "Getting AWS identity..."
ARN=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null)

if [ -z "$ARN" ]; then
    echo "Error: Could not get AWS identity"
    echo "Please configure AWS credentials: aws configure"
    exit 1
fi

echo "Found ARN: $ARN"

# Find latest Kiro file
KIRO_FILE=$(ls -t ~/.cli-proxy-api/kiro-aws-*.json 2>/dev/null | head -1)

if [ -z "$KIRO_FILE" ]; then
    echo "Error: No Kiro auth files found"
    echo "Please login first: cliproxyapi-oauth --kiro"
    exit 1
fi

echo "Updating: $KIRO_FILE"

# Update with jq
if command -v jq &> /dev/null; then
    jq --arg arn "$ARN" '.profile_arn = $arn' "$KIRO_FILE" > /tmp/kiro-temp.json
    mv /tmp/kiro-temp.json "$KIRO_FILE"
    echo "✓ Updated successfully using jq"
else
    # Fallback to sed
    sed -i "s|\"profile_arn\": \"\"|\"profile_arn\": \"$ARN\"|" "$KIRO_FILE"
    echo "✓ Updated successfully using sed"
fi

# Verify
NEW_ARN=$(cat "$KIRO_FILE" | grep -oP '"profile_arn": "\K[^"]+' || echo "")
if [ "$NEW_ARN" = "$ARN" ]; then
    echo "✓ Verified: profile_arn is set correctly"
    echo ""
    echo "Next steps:"
    echo "1. Restart server: curl -X POST http://localhost:8173/api/restart"
    echo "2. Test Kiro models in GUI"
else
    echo "✗ Verification failed"
    exit 1
fi
```

Run it:
```bash
chmod +x fix-kiro-arn.sh
./fix-kiro-arn.sh
```

## Summary

1. ✅ Login to Kiro via GUI → Terminal opens
2. ⚠️ **Profile ARN is empty** after login
3. 🔧 **Manually add ARN** to auth file
4. ✅ Restart server
5. ✅ Kiro models work

This is **not a bug**, but a Kiro-specific setup requirement.
