# Claudine Voice MVP - Quick Run Script (Windows PowerShell)
# Android only, geen wake word (komt later)

Write-Host "🚀 Claudine Voice MVP - Android" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan
Write-Host ""

# Check Flutter
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Flutter not found" -ForegroundColor Red
    exit 1
}

$flutterVersion = flutter --version | Select-Object -First 1
Write-Host "✓ Flutter: $flutterVersion" -ForegroundColor Green
Write-Host ""

# Check if we need to setup MVP
if (-not (Test-Path "pubspec.yaml") -or (Select-String -Path "pubspec.yaml" -Pattern "picovoice_flutter" -Quiet)) {
    Write-Host "📦 Switching to MVP mode..." -ForegroundColor Yellow

    # Use MVP pubspec (without wake word)
    if (Test-Path "pubspec_mvp.yaml") {
        Copy-Item "pubspec_mvp.yaml" "pubspec.yaml" -Force
        Write-Host "✓ Using MVP dependencies (no wake word)" -ForegroundColor Green
    }

    # Get dependencies
    flutter pub get
    Write-Host ""
}

# Check Android device/emulator
Write-Host "📱 Checking Android device..." -ForegroundColor Yellow
$devices = flutter devices | Select-String "android"

if ($null -eq $devices) {
    Write-Host "❌ No Android device/emulator found" -ForegroundColor Red
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  1. Connect Android phone via USB"
    Write-Host "  2. Start Android emulator: flutter emulators --launch <emulator>"
    Write-Host "  3. List available: flutter emulators"
    exit 1
}

Write-Host "✓ Found Android device" -ForegroundColor Green
Write-Host ""

# Build & Run
Write-Host "🏗️  Building and running..." -ForegroundColor Yellow
Write-Host ""

# Run MVP (lib/main.dart is the MVP version)
flutter run -d android

# Note: API key is hardcoded in lib/main.dart
# Full version with wake word is in _backup_full_version/
