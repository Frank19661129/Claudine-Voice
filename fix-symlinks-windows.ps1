# Fix symlinks for Windows Flutter build
# Run as Administrator from PowerShell

$ErrorActionPreference = "Stop"

Write-Host "=== Fixing Claudine-Voice Symlinks for Windows ===" -ForegroundColor Cyan
Write-Host ""

# Check admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: Run as Administrator!" -ForegroundColor Red
    exit 1
}

$projectPath = "C:\Users\frank\OneDrive - Madano BV\Lab\Claudine\Claudine-Voice"
$buildRoot = "D:\flutter-builds\Claudine-Voice"

# Ensure build root exists
if (-not (Test-Path $buildRoot)) {
    New-Item -Path $buildRoot -ItemType Directory -Force | Out-Null
}

# Create target folders
$targets = @("build", ".dart_tool", "android-build")
foreach ($target in $targets) {
    $targetPath = Join-Path $buildRoot $target
    if (-not (Test-Path $targetPath)) {
        New-Item -Path $targetPath -ItemType Directory -Force | Out-Null
        Write-Host "Created: $targetPath" -ForegroundColor Green
    }
}

# Remove existing symlinks/folders
$links = @(
    @{Name = "build"; Target = (Join-Path $buildRoot "build")},
    @{Name = ".dart_tool"; Target = (Join-Path $buildRoot ".dart_tool")}
)

foreach ($link in $links) {
    $linkPath = Join-Path $projectPath $link.Name

    if (Test-Path $linkPath) {
        Write-Host "Removing existing: $($link.Name)" -ForegroundColor Yellow
        # Force remove
        cmd /c rmdir /s /q "$linkPath" 2>&1 | Out-Null
        Remove-Item -Path $linkPath -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Create junction (works better than symlink for folders in Windows)
    Write-Host "Creating junction: $($link.Name) -> $($link.Target)" -ForegroundColor Yellow
    cmd /c mklink /J "$linkPath" "$($link.Target)" | Out-Null

    if ($LASTEXITCODE -eq 0) {
        Write-Host "  OK" -ForegroundColor Green
    } else {
        Write-Host "  FAILED" -ForegroundColor Red
    }
}

# Android build
$androidPath = Join-Path $projectPath "android"
if (Test-Path $androidPath) {
    $androidBuildLink = Join-Path $androidPath "build"
    $androidBuildTarget = Join-Path $buildRoot "android-build"

    if (Test-Path $androidBuildLink) {
        Write-Host "Removing existing: android\build" -ForegroundColor Yellow
        cmd /c rmdir /s /q "$androidBuildLink" 2>&1 | Out-Null
        Remove-Item -Path $androidBuildLink -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host "Creating junction: android\build -> $androidBuildTarget" -ForegroundColor Yellow
    cmd /c mklink /J "$androidBuildLink" "$androidBuildTarget" | Out-Null

    if ($LASTEXITCODE -eq 0) {
        Write-Host "  OK" -ForegroundColor Green
    } else {
        Write-Host "  FAILED" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== Done! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Now run:" -ForegroundColor Yellow
Write-Host "  flutter clean" -ForegroundColor White
Write-Host "  flutter pub get" -ForegroundColor White
Write-Host "  flutter build apk --release" -ForegroundColor White
