# Clean Flutter build with OneDrive sync pause
# Voor Claudine-Voice project

Write-Host "=== Flutter Clean Build Script ===" -ForegroundColor Cyan
Write-Host ""

# Stop Flutter/Gradle processen
Write-Host "1. Stopping Flutter/Gradle processes..." -ForegroundColor Yellow
Get-Process | Where-Object {$_.Name -like "*dart*" -or $_.Name -like "*java*" -or $_.Name -like "*gradle*"} | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# Pause OneDrive sync
Write-Host "2. Pausing OneDrive sync..." -ForegroundColor Yellow
$oneDriveProcess = Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue
if ($oneDriveProcess) {
    # Pause via command line (works for OneDrive Business)
    Start-Process -FilePath "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe" -ArgumentList "/pause" -NoNewWindow -ErrorAction SilentlyContinue
    Write-Host "   OneDrive paused" -ForegroundColor Green
    Start-Sleep -Seconds 3
} else {
    Write-Host "   OneDrive not running" -ForegroundColor Gray
}

# Clean build
Write-Host "3. Cleaning Flutter build..." -ForegroundColor Yellow
flutter clean

# Extra: Force delete build folders if they still exist
if (Test-Path "build") {
    Write-Host "4. Force removing build folder..." -ForegroundColor Yellow
    Remove-Item -Path "build" -Recurse -Force -ErrorAction SilentlyContinue
}

if (Test-Path ".dart_tool") {
    Write-Host "5. Force removing .dart_tool folder..." -ForegroundColor Yellow
    Remove-Item -Path ".dart_tool" -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "=== Clean complete! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Ready to build. Run:" -ForegroundColor Cyan
Write-Host "  flutter build apk --release" -ForegroundColor White
Write-Host ""
Write-Host "Note: OneDrive is paused. Resume manually via system tray if needed." -ForegroundColor Gray
