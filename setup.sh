#!/bin/bash

# Claudine Voice - Quick Setup Script
# Run this after cloning the project

set -e

echo "🚀 Claudine Voice - Setup"
echo "========================="
echo ""

# Check Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Install from: https://flutter.dev"
    exit 1
fi

echo "✓ Flutter found: $(flutter --version | head -1)"
echo ""

# Check API keys
echo "📝 API Keys Setup"
echo "-----------------"

if [ -z "$CLAUDE_API_KEY" ]; then
    echo "⚠️  CLAUDE_API_KEY not set"
    echo "   Get your key from: https://console.anthropic.com/"
    echo "   Then: export CLAUDE_API_KEY='sk-ant-...'"
    echo ""
fi

if [ -z "$PICOVOICE_ACCESS_KEY" ]; then
    echo "⚠️  PICOVOICE_ACCESS_KEY not set"
    echo "   Get your key from: https://console.picovoice.ai/"
    echo "   Then: export PICOVOICE_ACCESS_KEY='...'"
    echo ""
fi

# Create directories
echo "📁 Creating directories..."
mkdir -p assets/wake_words
mkdir -p assets/sounds
mkdir -p assets/images
mkdir -p assets/fonts

# Get dependencies
echo ""
echo "📦 Installing dependencies..."
flutter pub get

# Check wake word model
echo ""
echo "🎤 Wake Word Model"
echo "------------------"
if [ ! -f "assets/wake_words/hee_claudine_nl.ppn" ]; then
    echo "⚠️  Wake word model not found!"
    echo ""
    echo "   Steps to get it:"
    echo "   1. Go to: https://console.picovoice.ai/ppn"
    echo "   2. Create wake word: 'hee claudine' (Dutch)"
    echo "   3. Download .ppn file"
    echo "   4. Save to: assets/wake_words/hee_claudine_nl.ppn"
    echo ""
else
    echo "✓ Wake word model found"
fi

# Run tests
echo ""
echo "🧪 Running tests..."
if flutter test; then
    echo "✓ All tests passed"
else
    echo "⚠️  Some tests failed (this is OK for initial setup)"
fi

# Done
echo ""
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Set API keys (see above)"
echo "  2. Download wake word model (see above)"
echo "  3. Run: flutter run"
echo ""
echo "Documentation: README.md"
echo "Stack: Same as FrankScan/Claudine-Scan"
