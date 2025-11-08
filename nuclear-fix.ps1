# Nuclear option: Clean everything and rebuild with proper junctions
# Run as Administrator

$ErrorActionPreference = "Stop"

Write-Host "=== NUCLEAR FIX: Clean & Rebuild ===" -ForegroundColor Red
Write-Host ""

# Check admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: Run as Administrator!" -ForegroundColor Red
    exit 1
}

$projectPath = "C:\Users\frank\OneDrive - Madano BV\Lab\Claudine\Claudine-Voice"
$buildRoot = "D:\flutter-builds\Claudine-Voice"

Write-Host "This will:" -ForegroundColor Yellow
Write-Host "  1. Stop all processes" -ForegroundColor White
Write-Host "  2. Pause OneDrive" -ForegroundColor White
Write-Host "  3. Delete ALL build folders (OneDrive + D:)" -ForegroundColor White
Write-Host "  4. Run flutter clean" -ForegroundColor White
Write-Host "  5. Create fresh junctions to D:" -ForegroundColor White
Write-Host ""
$confirm = Read-Host "Continue? (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "Aborted" -ForegroundColor Gray
    exit 0
}

Write-Host ""
Write-Host "Step 1: Stopping processes..." -ForegroundColor Cyan
Get-Process | Where-Object {
    $_.Name -like "*dart*" -or
    $_.Name -like "*java*" -or
    $_.Name -like "*gradle*" -or
    $_.Name -like "*flutter*"
} | Stop-Process -Force -ErrorAction SilentlyContinue

Start-Sleep -Seconds 2
Write-Host "  Done" -ForegroundColor Green

Write-Host ""
Write-Host "Step 2: Pausing OneDrive..." -ForegroundColor Cyan
$oneDrive = Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue
if ($oneDrive) {
    Start-Process -FilePath "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe" -ArgumentList "/pause" -NoNewWindow -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    Write-Host "  OneDrive paused (or pause manually)" -ForegroundColor Green
}

Write-Host ""
Write-Host "Step 3: Nuking ALL build folders..." -ForegroundColor Cyan

cd $projectPath

# Remove build
if (Test-Path "build") {
    Write-Host "  Removing build..." -ForegroundColor Yellow
    cmd /c rmdir /s /q "build" 2>&1 | Out-Null
    Remove-Item -Path "build" -Recurse -Force -ErrorAction SilentlyContinue
}

# Remove .dart_tool
if (Test-Path ".dart_tool") {
    Write-Host "  Removing .dart_tool..." -ForegroundColor Yellow
    cmd /c rmdir /s /q ".dart_tool" 2>&1 | Out-Null
    Remove-Item -Path ".dart_tool" -Recurse -Force -ErrorAction SilentlyContinue
}

# Remove android/build
if (Test-Path "android\build") {
    Write-Host "  Removing android/build..." -ForegroundColor Yellow
    cmd /c rmdir /s /q "android\build" 2>&1 | Out-Null
    Remove-Item -Path "android\build" -Recurse -Force -ErrorAction SilentlyContinue
}

# Remove everything on D:
if (Test-Path $buildRoot) {
    Write-Host "  Removing D:\flutter-builds\Claudine-Voice..." -ForegroundColor Yellow
    Remove-Item -Path $buildRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "  Done" -ForegroundColor Green

Write-Host ""
Write-Host "Step 4: Running flutter clean..." -ForegroundColor Cyan
flutter clean 2>&1 | Out-Null
Write-Host "  Done" -ForegroundColor Green

Write-Host ""
Write-Host "Step 5: Creating D: structure..." -ForegroundColor Cyan

# Create fresh D: structure
New-Item -Path "$buildRoot\build" -ItemType Directory -Force | Out-Null
New-Item -Path "$buildRoot\.dart_tool" -ItemType Directory -Force | Out-Null
New-Item -Path "$buildRoot\android-build" -ItemType Directory -Force | Out-Null

Write-Host "  D: structure created" -ForegroundColor Green

Write-Host ""
Write-Host "Step 6: Creating junctions from project to D:..." -ForegroundColor Cyan

# Create junction: build
cmd /c mklink /J "$projectPath\build" "$buildRoot\build" 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  build -> D: [OK]" -ForegroundColor Green
} else {
    Write-Host "  build -> D: [FAILED]" -ForegroundColor Red
}

# Create junction: .dart_tool
cmd /c mklink /J "$projectPath\.dart_tool" "$buildRoot\.dart_tool" 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  .dart_tool -> D: [OK]" -ForegroundColor Green
} else {
    Write-Host "  .dart_tool -> D: [FAILED]" -ForegroundColor Red
}

# Create junction: android/build
if (Test-Path "$projectPath\android") {
    cmd /c mklink /J "$projectPath\android\build" "$buildRoot\android-build" 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  android/build -> D: [OK]" -ForegroundColor Green
    } else {
        Write-Host "  android/build -> D: [FAILED]" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Step 7: Verification..." -ForegroundColor Cyan

# Verify junctions
$buildAttr = (Get-Item "$projectPath\build" -Force).Attributes
$dartAttr = (Get-Item "$projectPath\.dart_tool" -Force).Attributes

$buildIsJunction = $buildAttr -band [System.IO.FileAttributes]::ReparsePoint
$dartIsJunction = $dartAttr -band [System.IO.FileAttributes]::ReparsePoint

Write-Host "  build is junction: $buildIsJunction" -ForegroundColor $(if ($buildIsJunction) {"Green"} else {"Red"})
Write-Host "  .dart_tool is junction: $dartIsJunction" -ForegroundColor $(if ($dartIsJunction) {"Green"} else {"Red"})

Write-Host ""
Write-Host "=== ALL DONE ===" -ForegroundColor Green
Write-Host ""
Write-Host "Now test with:" -ForegroundColor Yellow
Write-Host "  flutter pub get" -ForegroundColor White
Write-Host "  flutter build apk --release" -ForegroundColor White
Write-Host ""
Write-Host "Builds should now go to D: only!" -ForegroundColor Cyan
