# Build Flutter APK met OneDrive sync pause
# Voor Claudine-Voice project

Write-Host "=== Flutter Release Build Script ===" -ForegroundColor Cyan
Write-Host ""

# Stop Flutter/Gradle processen
Write-Host "1. Stopping existing processes..." -ForegroundColor Yellow
Get-Process | Where-Object {$_.Name -like "*dart*" -or $_.Name -like "*java*" -or $_.Name -like "*gradle*"} | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# Pause OneDrive sync
Write-Host "2. Pausing OneDrive sync for 2 hours..." -ForegroundColor Yellow
$oneDriveProcess = Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue
$oneDrivePaused = $false

if ($oneDriveProcess) {
    # Try Business OneDrive pause command
    try {
        Start-Process -FilePath "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe" -ArgumentList "/pause" -NoNewWindow -ErrorAction Stop
        $oneDrivePaused = $true
        Write-Host "   OneDrive paused" -ForegroundColor Green
        Start-Sleep -Seconds 3
    } catch {
        Write-Host "   Could not pause OneDrive automatically" -ForegroundColor Yellow
        Write-Host "   Please pause manually: Right-click OneDrive → Pause sync → 2 hours" -ForegroundColor Yellow
        Read-Host "   Press Enter when ready to continue"
    }
}

# Clean first
Write-Host "3. Cleaning previous build..." -ForegroundColor Yellow
flutter clean
Start-Sleep -Seconds 2

# Build APK
Write-Host ""
Write-Host "4. Building release APK..." -ForegroundColor Yellow
Write-Host "   This may take a few minutes..." -ForegroundColor Gray
Write-Host ""

flutter build apk --release

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "=== Build SUCCESS! ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "APK location:" -ForegroundColor Cyan
    Write-Host "  build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor White
    Write-Host ""

    # Show file info if it exists
    $apkPath = "build\app\outputs\flutter-apk\app-release.apk"
    if (Test-Path $apkPath) {
        $apk = Get-Item $apkPath
        $sizeMB = [math]::Round($apk.Length / 1MB, 2)
        Write-Host "  Size: $sizeMB MB" -ForegroundColor Gray
        Write-Host "  Modified: $($apk.LastWriteTime)" -ForegroundColor Gray
    }
} else {
    Write-Host ""
    Write-Host "=== Build FAILED ===" -ForegroundColor Red
    Write-Host "Check errors above" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Note: OneDrive sync is paused. It will auto-resume in 2 hours," -ForegroundColor Gray
Write-Host "or resume manually via system tray." -ForegroundColor Gray
