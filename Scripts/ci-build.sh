#!/bin/bash
# CI Build with provisioning support

PROJECT_NAME="$1"
SCHEME="${2:-MyApp}"
CONFIGURATION="${3:-Release}"
DERIVED_DATA="build/DerivedData"

if [ -z "$PROJECT_NAME" ]; then
    echo "Usage: $0 <project-name> [scheme] [configuration]"
    exit 1
fi

echo "🚀 Building $PROJECT_NAME ($SCHEME - $CONFIGURATION)"

# Find project file
if [ -f "${PROJECT_NAME}.xcworkspace" ]; then
    PROJECT_FLAG="-workspace ${PROJECT_NAME}.xcworkspace"
elif [ -f "${PROJECT_NAME}.xcodeproj" ]; then
    PROJECT_FLAG="-project ${PROJECT_NAME}.xcodeproj"
else
    echo "❌ No project file found"
    exit 1
fi

# Build with provisioning support
xcodebuild \
    $PROJECT_FLAG \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "generic/platform=iOS" \
    -derivedDataPath "$DERIVED_DATA" \
    -allowProvisioningUpdates \
    -allowProvisioningDeviceRegistration \
    -showBuildTimingSummary \
    -quiet

echo "✅ Build complete!"
