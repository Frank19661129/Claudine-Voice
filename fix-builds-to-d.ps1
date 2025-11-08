# Stap-voor-stap: Verplaats builds naar D: met correcte junctions
# Run als Administrator

param(
    [switch]$Step1,
    [switch]$Step2,
    [switch]$Step3,
    [switch]$Step4,
    [switch]$Verify
)

$ErrorActionPreference = "Stop"
$projectPath = "C:\Users\frank\OneDrive - Madano BV\Lab\Claudine\Claudine-Voice"
$buildRoot = "D:\flutter-builds\Claudine-Voice"

function Write-Step {
    param([string]$Message, [string]$Color = "Cyan")
    Write-Host ""
    Write-Host "=== $Message ===" -ForegroundColor $Color
    Write-Host ""
}

# Check admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: Run as Administrator!" -ForegroundColor Red
    exit 1
}

if ($Step1) {
    Write-Step "STEP 1: Stop processes en pause OneDrive"

    Write-Host "Stopping Flutter/Gradle/Dart processes..." -ForegroundColor Yellow
    Get-Process | Where-Object {$_.Name -like "*dart*" -or $_.Name -like "*java*" -or $_.Name -like "*gradle*"} | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    Write-Host "Pausing OneDrive..." -ForegroundColor Yellow
    $oneDrive = Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue
    if ($oneDrive) {
        Start-Process -FilePath "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe" -ArgumentList "/pause" -NoNewWindow -ErrorAction SilentlyContinue
        Write-Host "OneDrive paused (or pause manually via system tray)" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "DONE! Now run: .\fix-builds-to-d.ps1 -Step2" -ForegroundColor Green
}

if ($Step2) {
    Write-Step "STEP 2: Backup en verplaats build naar D:"

    # Ensure D: build root exists
    if (-not (Test-Path $buildRoot)) {
        New-Item -Path $buildRoot -ItemType Directory -Force | Out-Null
    }

    $buildSource = Join-Path $projectPath "build"
    $buildTarget = Join-Path $buildRoot "build"

    if (Test-Path $buildSource) {
        $size = (Get-ChildItem $buildSource -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
        Write-Host "Moving build folder ($([math]::Round($size, 0))MB) to D:..." -ForegroundColor Yellow

        if (Test-Path $buildTarget) {
            Remove-Item -Path $buildTarget -Recurse -Force -ErrorAction SilentlyContinue
        }

        # Use robocopy for reliable move
        robocopy "$buildSource" "$buildTarget" /E /MOVE /NFL /NDL /NJH /NJS | Out-Null

        if (Test-Path $buildTarget) {
            Write-Host "Build moved successfully!" -ForegroundColor Green
        }
    } else {
        Write-Host "Build folder doesn't exist, skipping" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "DONE! Now run: .\fix-builds-to-d.ps1 -Step3" -ForegroundColor Green
}

if ($Step3) {
    Write-Step "STEP 3: Verplaats .dart_tool naar D:"

    $dartSource = Join-Path $projectPath ".dart_tool"
    $dartTarget = Join-Path $buildRoot ".dart_tool"

    if (Test-Path $dartSource) {
        $size = (Get-ChildItem $dartSource -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
        Write-Host "Moving .dart_tool folder ($([math]::Round($size, 0))MB) to D:..." -ForegroundColor Yellow

        if (Test-Path $dartTarget) {
            Remove-Item -Path $dartTarget -Recurse -Force -ErrorAction SilentlyContinue
        }

        robocopy "$dartSource" "$dartTarget" /E /MOVE /NFL /NDL /NJH /NJS | Out-Null

        if (Test-Path $dartTarget) {
            Write-Host ".dart_tool moved successfully!" -ForegroundColor Green
        }
    } else {
        Write-Host ".dart_tool doesn't exist, skipping" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "DONE! Now run: .\fix-builds-to-d.ps1 -Step4" -ForegroundColor Green
}

if ($Step4) {
    Write-Step "STEP 4: Create Directory Junctions"

    # Create junctions
    $junctions = @(
        @{Link = (Join-Path $projectPath "build"); Target = (Join-Path $buildRoot "build")},
        @{Link = (Join-Path $projectPath ".dart_tool"); Target = (Join-Path $buildRoot ".dart_tool")}
    )

    foreach ($junction in $junctions) {
        $linkName = Split-Path $junction.Link -Leaf

        # Ensure target exists
        if (-not (Test-Path $junction.Target)) {
            New-Item -Path $junction.Target -ItemType Directory -Force | Out-Null
        }

        # Remove link if exists
        if (Test-Path $junction.Link) {
            Write-Host "Removing existing: $linkName" -ForegroundColor Yellow
            Remove-Item -Path $junction.Link -Force -Recurse -ErrorAction SilentlyContinue
        }

        Write-Host "Creating junction: $linkName -> $($junction.Target)" -ForegroundColor Yellow
        cmd /c mklink /J "$($junction.Link)" "$($junction.Target)" | Out-Null

        if ($LASTEXITCODE -eq 0) {
            Write-Host "  OK" -ForegroundColor Green
        } else {
            Write-Host "  FAILED" -ForegroundColor Red
        }
    }

    # Android build junction
    $androidPath = Join-Path $projectPath "android"
    if (Test-Path $androidPath) {
        $androidLink = Join-Path $androidPath "build"
        $androidTarget = Join-Path $buildRoot "android-build"

        if (-not (Test-Path $androidTarget)) {
            New-Item -Path $androidTarget -ItemType Directory -Force | Out-Null
        }

        if (Test-Path $androidLink) {
            Remove-Item -Path $androidLink -Force -Recurse -ErrorAction SilentlyContinue
        }

        Write-Host "Creating junction: android\build -> $androidTarget" -ForegroundColor Yellow
        cmd /c mklink /J "$androidLink" "$androidTarget" | Out-Null

        if ($LASTEXITCODE -eq 0) {
            Write-Host "  OK" -ForegroundColor Green
        }
    }

    Write-Host ""
    Write-Host "DONE! Now run: .\fix-builds-to-d.ps1 -Verify" -ForegroundColor Green
}

if ($Verify) {
    Write-Step "VERIFICATION" "Green"

    Write-Host "Checking junctions..." -ForegroundColor Yellow

    $items = @("build", ".dart_tool", "android\build")
    foreach ($item in $items) {
        $path = Join-Path $projectPath $item
        if (Test-Path $path) {
            $attr = (Get-Item $path -Force).Attributes
            if ($attr -band [System.IO.FileAttributes]::ReparsePoint) {
                $target = (Get-Item $path).Target
                Write-Host "  OK: $item -> $target" -ForegroundColor Green
            } else {
                Write-Host "  WARNING: $item is NOT a junction!" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  MISSING: $item" -ForegroundColor Red
        }
    }

    Write-Host ""
    Write-Host "Checking D: drive sizes..." -ForegroundColor Yellow

    $buildSize = (Get-ChildItem (Join-Path $buildRoot "build") -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
    $dartSize = (Get-ChildItem (Join-Path $buildRoot ".dart_tool") -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB

    Write-Host "  D:\flutter-builds\Claudine-Voice\build: $([math]::Round($buildSize, 0))MB" -ForegroundColor Cyan
    Write-Host "  D:\flutter-builds\Claudine-Voice\.dart_tool: $([math]::Round($dartSize, 0))MB" -ForegroundColor Cyan

    Write-Host ""
    Write-Host "ALL DONE! Resume OneDrive manually if needed." -ForegroundColor Green
    Write-Host "Test with: flutter build apk --release" -ForegroundColor Yellow
}

if (-not ($Step1 -or $Step2 -or $Step3 -or $Step4 -or $Verify)) {
    Write-Host "=== Fix Builds to D: - Stapsgewijs ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Gebruik:" -ForegroundColor Yellow
    Write-Host "  .\fix-builds-to-d.ps1 -Step1   # Stop processes, pause OneDrive" -ForegroundColor White
    Write-Host "  .\fix-builds-to-d.ps1 -Step2   # Verplaats build/ naar D:" -ForegroundColor White
    Write-Host "  .\fix-builds-to-d.ps1 -Step3   # Verplaats .dart_tool/ naar D:" -ForegroundColor White
    Write-Host "  .\fix-builds-to-d.ps1 -Step4   # Maak junctions" -ForegroundColor White
    Write-Host "  .\fix-builds-to-d.ps1 -Verify  # Verifieer alles" -ForegroundColor White
    Write-Host ""
    Write-Host "Start met: .\fix-builds-to-d.ps1 -Step1" -ForegroundColor Green
}
