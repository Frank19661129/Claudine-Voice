@echo off
REM Claudine Voice MVP - Quick Run Script (Windows CMD)
REM Android only, geen wake word (komt later)

echo 🚀 Claudine Voice MVP - Android
echo ===============================
echo.

REM Check Flutter
where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Flutter not found
    exit /b 1
)

echo ✓ Flutter installed
echo.

REM Check if we need to setup MVP
if exist "pubspec_mvp.yaml" (
    findstr /C:"picovoice_flutter" pubspec.yaml >nul 2>nul
    if %ERRORLEVEL% EQU 0 (
        echo 📦 Switching to MVP mode...
        copy /Y pubspec_mvp.yaml pubspec.yaml >nul
        echo ✓ Using MVP dependencies ^(no wake word^)
        flutter pub get
        echo.
    )
)

REM Check Android device/emulator
echo 📱 Checking Android device...
flutter devices | findstr /C:"android" >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ❌ No Android device/emulator found
    echo.
    echo Options:
    echo   1. Connect Android phone via USB
    echo   2. Start Android emulator: flutter emulators --launch ^<emulator^>
    echo   3. List available: flutter emulators
    exit /b 1
)

echo ✓ Found Android device
echo.

REM Build & Run
echo 🏗️  Building and running...
echo.

REM Run MVP (lib/main.dart is the MVP version)
flutter run -d android

REM Note: API key is hardcoded in lib/main.dart
REM Full version with wake word is in _backup_full_version/
