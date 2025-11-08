#!/bin/bash

# Claudine Voice MVP - Quick Run Script
# Android only, geen wake word (komt later)

set -e

echo "🚀 Claudine Voice MVP - Android"
echo "==============================="
echo ""

# Check Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found"
    exit 1
fi

echo "✓ Flutter: $(flutter --version | head -1)"
echo ""

# Check if we need to setup MVP
if [ ! -f "pubspec.yaml" ] || grep -q "picovoice_flutter" pubspec.yaml; then
    echo "📦 Switching to MVP mode..."

    # Use MVP pubspec (without wake word)
    if [ -f "pubspec_mvp.yaml" ]; then
        cp pubspec_mvp.yaml pubspec.yaml
        echo "✓ Using MVP dependencies (no wake word)"
    fi

    # Get dependencies
    flutter pub get
    echo ""
fi

# Check Android device/emulator
echo "📱 Checking Android device..."
DEVICE_COUNT=$(flutter devices | grep -c "android" || true)

if [ "$DEVICE_COUNT" -eq 0 ]; then
    echo "❌ No Android device/emulator found"
    echo ""
    echo "Options:"
    echo "  1. Connect Android phone via USB"
    echo "  2. Start Android emulator: flutter emulators --launch <emulator>"
    echo "  3. List available: flutter emulators"
    exit 1
fi

echo "✓ Found Android device"
echo ""

# Build & Run
echo "🏗️  Building and running..."
echo ""

# Use main_mvp.dart as entry point
flutter run \
    --target=lib/main_mvp.dart \
    -d android \
    --verbose

# Note: API key is loaded from .env file
# Create .env file from .env.example and add your Anthropic API key
