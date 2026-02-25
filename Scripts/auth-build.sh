#!/bin/bash
# Build with App Store Connect authentication

KEY_PATH="$1"
KEY_ID="$2" 
ISSUER_ID="$3"
SCHEME="${4:-MyApp}"

if [ -z "$KEY_PATH" ] || [ -z "$KEY_ID" ] || [ -z "$ISSUER_ID" ]; then
    echo "Usage: $0 <key-path> <key-id> <issuer-id> [scheme]"
    echo "Example: $0 ./AuthKeys/key.p8 ABC123DEFG 1234a1b2-1234-1234-1234-123456789012 MyApp"
    exit 1
fi

# Validate key path
if [ ! -f "$KEY_PATH" ]; then
    echo "❌ Authentication key not found: $KEY_PATH"
    echo "Get your key from: https://appstoreconnect.apple.com/access/api"
    exit 1
fi

echo "🔐 Authenticating with App Store Connect..."
echo "Key ID: $KEY_ID"
echo "Issuer ID: $ISSUER_ID"

xcodebuild \
    -project "${SCHEME}.xcodeproj" \
    -scheme "$SCHEME" \
    -authenticationKeyPath "$KEY_PATH" \
    -authenticationKeyID "$KEY_ID" \
    -authenticationKeyIssuerID "$ISSUER_ID" \
    -allowProvisioningUpdates \
    -showBuildTimingSummary
