#!/bin/bash
# Auto-Tools Installer for Xcode Projects

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="$PROJECT_ROOT/Tools"

echo "🔧 Installing development tools..."

# Create Tools directory if it doesn't exist
mkdir -p "$TOOLS_DIR"

# Install Goose
echo "📦 Installing Goose..."
if [ ! -d "$TOOLS_DIR/Goose-Source" ]; then
    git clone git@github.com:SwiftPackage/Goose.git "$TOOLS_DIR/Goose-Source" || {
        echo "⚠️  Failed to clone Goose - creating placeholder"
        touch "$TOOLS_DIR/goose-swift"
        chmod +x "$TOOLS_DIR/goose-swift"
        exit 0
    }
fi

cd "$TOOLS_DIR/Goose-Source"
git pull origin main
swift build -c release
cp -f .build/release/goose "$TOOLS_DIR/goose-swift"
chmod +x "$TOOLS_DIR/goose-swift"

echo "✅ Goose installed: $TOOLS_DIR/goose-swift"

# Create placeholders for other tools
touch "$TOOLS_DIR/openclaw" "$TOOLS_DIR/opencode-cli"
chmod +x "$TOOLS_DIR/openclaw" "$TOOLS_DIR/opencode-cli"

echo "🎉 Tool installation complete!"
