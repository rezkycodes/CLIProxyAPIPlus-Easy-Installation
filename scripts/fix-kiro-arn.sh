#!/usr/bin/env bash
#
# Fix Kiro Profile ARN
# Automatically updates Kiro auth file with your AWS Profile ARN
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Kiro Profile ARN Fixer${NC}"
echo "====================="
echo ""

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI not found${NC}"
    echo "Please install AWS CLI first:"
    echo "  pip install awscli"
    echo "  # or"
    echo "  sudo apt install awscli"
    exit 1
fi

# Get ARN from AWS
echo "Getting AWS identity..."
ARN=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null || echo "")

if [ -z "$ARN" ]; then
    echo -e "${RED}Error: Could not get AWS identity${NC}"
    echo ""
    echo "Please configure AWS credentials first:"
    echo "  aws configure"
    echo ""
    echo "You will need:"
    echo "  - AWS Access Key ID"
    echo "  - AWS Secret Access Key"
    echo "  - Default region (e.g., us-east-1)"
    exit 1
fi

echo -e "${GREEN}✓ Found ARN: ${NC}$ARN"
echo ""

# Find latest Kiro file
KIRO_FILE=$(ls -t ~/.cli-proxy-api/kiro-aws-*.json 2>/dev/null | head -1 || echo "")

if [ -z "$KIRO_FILE" ]; then
    echo -e "${RED}Error: No Kiro auth files found${NC}"
    echo ""
    echo "Please login to Kiro first:"
    echo "  cliproxyapi-oauth --kiro"
    echo "  # or from GUI: click Kiro provider icon"
    exit 1
fi

echo "Updating: $(basename $KIRO_FILE)"

# Backup original file
cp "$KIRO_FILE" "$KIRO_FILE.backup"

# Update with jq if available, otherwise use sed
if command -v jq &> /dev/null; then
    jq --arg arn "$ARN" '.profile_arn = $arn' "$KIRO_FILE" > /tmp/kiro-temp.json
    mv /tmp/kiro-temp.json "$KIRO_FILE"
    echo -e "${GREEN}✓ Updated successfully using jq${NC}"
else
    # Fallback to sed
    sed -i "s|\"profile_arn\": \"\"|\"profile_arn\": \"$ARN\"|" "$KIRO_FILE"
    echo -e "${GREEN}✓ Updated successfully using sed${NC}"
fi

# Verify
echo "Verifying..."
if command -v jq &> /dev/null; then
    NEW_ARN=$(jq -r '.profile_arn' "$KIRO_FILE")
else
    NEW_ARN=$(grep -oP '"profile_arn": "\K[^"]+' "$KIRO_FILE" || echo "")
fi

if [ "$NEW_ARN" = "$ARN" ]; then
    echo -e "${GREEN}✓ Verified: profile_arn is set correctly${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. Restart server from GUI (click Restart button)"
    echo "     Or run: curl -X POST http://localhost:8173/api/restart"
    echo ""
    echo "  2. Test Kiro models:"
    echo "     - kiro-aws/claude-3-5-sonnet-20241022-v2:0"
    echo "     - kiro-aws/claude-3-5-haiku-20241022-v1:0"
    echo "     - kiro-aws/nova-pro-v1:0"
    echo ""
    echo "  3. Check logs for warnings:"
    echo "     tail -f ~/.cli-proxy-api/server.log | grep kiro"
    echo ""
    echo -e "${GREEN}Backup saved: $(basename $KIRO_FILE).backup${NC}"
else
    echo -e "${RED}✗ Verification failed${NC}"
    echo "Expected: $ARN"
    echo "Got: $NEW_ARN"
    
    # Restore backup
    mv "$KIRO_FILE.backup" "$KIRO_FILE"
    echo "Restored original file from backup"
    exit 1
fi
