# PowerShell script to get Microsoft Authentication Signature Hash for Android

Write-Host "===================================================================" -ForegroundColor Cyan
Write-Host "Microsoft Authentication Configuration for Claudine Voice" -ForegroundColor Cyan
Write-Host "===================================================================" -ForegroundColor Cyan
Write-Host ""

$PACKAGE_NAME = "com.franklab.claudine_voice"
Write-Host "Package Name: $PACKAGE_NAME" -ForegroundColor Yellow
Write-Host ""

# Find keytool
$keytoolPaths = @(
    "$env:JAVA_HOME\bin\keytool.exe",
    "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe",
    "C:\Program Files\Java\jdk-*\bin\keytool.exe"
)

$keytool = $null
foreach ($path in $keytoolPaths) {
    if (Test-Path $path) {
        $keytool = $path
        break
    }
}

if (-not $keytool) {
    Write-Host "ERROR: keytool not found!" -ForegroundColor Red
    Write-Host "Please install Java or Android Studio" -ForegroundColor Red
    exit 1
}

Write-Host "Using keytool: $keytool" -ForegroundColor Green
Write-Host ""

# Debug keystore location
$debugKeystore = "$env:USERPROFILE\.android\debug.keystore"

# Create .android directory if it doesn't exist
if (-not (Test-Path (Split-Path $debugKeystore))) {
    Write-Host "Creating .android directory..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path (Split-Path $debugKeystore) -Force | Out-Null
}

# Generate debug keystore if it doesn't exist
if (-not (Test-Path $debugKeystore)) {
    Write-Host "Generating debug keystore..." -ForegroundColor Yellow
    & $keytool -genkey -v -keystore $debugKeystore `
        -storepass android -alias androiddebugkey `
        -keypass android -keyalg RSA -keysize 2048 `
        -validity 10000 `
        -dname "CN=Android Debug,O=Android,C=US"
    Write-Host ""
}

Write-Host "===================================================================" -ForegroundColor Cyan
Write-Host "DEBUG BUILD - Signature Hashes" -ForegroundColor Cyan
Write-Host "===================================================================" -ForegroundColor Cyan
Write-Host ""

# Get certificate details
$certInfo = & $keytool -list -v -keystore $debugKeystore `
    -alias androiddebugkey -storepass android -keypass android 2>$null

# Extract SHA-1 and SHA-256
$sha1Line = ($certInfo | Select-String "SHA1:").ToString()
$sha1 = $sha1Line.Substring($sha1Line.IndexOf("SHA1:") + 5).Trim().Replace(":", "")

$sha256Line = ($certInfo | Select-String "SHA256:").ToString()
$sha256 = $sha256Line.Substring($sha256Line.IndexOf("SHA256:") + 7).Trim().Replace(":", "")

Write-Host "SHA-1 (Hex without colons):   $sha1" -ForegroundColor White
Write-Host "SHA-256: $sha256" -ForegroundColor White
Write-Host ""

# Format SHA-1 with colons
$sha1WithColons = -join ($sha1 -split '(.{2})' | Where-Object { $_ } | ForEach-Object { $_ + ':' })
$sha1WithColons = $sha1WithColons.TrimEnd(':')
Write-Host "SHA-1 (Hex with colons):" -ForegroundColor Yellow
Write-Host "  $sha1WithColons" -ForegroundColor White
Write-Host ""

# Convert SHA-1 to Base64 for Azure Platform Config
$sha1Bytes = [byte[]]::new($sha1.Length / 2)
for ($i = 0; $i -lt $sha1.Length; $i += 2) {
    $sha1Bytes[$i / 2] = [Convert]::ToByte($sha1.Substring($i, 2), 16)
}
$sha1Base64 = [Convert]::ToBase64String($sha1Bytes)
Write-Host "SHA-1 (Base64 for Platform Config):" -ForegroundColor Green
Write-Host "  $sha1Base64" -ForegroundColor Cyan
Write-Host ""

# URL encode the SHA-1 hash for redirect URI
$sha1Encoded = $sha1Base64.Replace('+', '-').Replace('/', '_').TrimEnd('=')

$redirectUri = "msauth://$PACKAGE_NAME/$sha1Encoded"

Write-Host "===================================================================" -ForegroundColor Cyan
Write-Host "AZURE APP REGISTRATION - Configuration" -ForegroundColor Cyan
Write-Host "===================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Package Name (for Azure Portal):" -ForegroundColor Yellow
Write-Host "  $PACKAGE_NAME" -ForegroundColor White
Write-Host ""
Write-Host "Signature Hash (for Azure Platform Config):" -ForegroundColor Yellow
Write-Host "  Format: Base64" -ForegroundColor White
Write-Host "  $sha1Base64" -ForegroundColor Cyan
Write-Host ""
Write-Host "Redirect URI (for .env file):" -ForegroundColor Yellow
Write-Host "  $redirectUri" -ForegroundColor White
Write-Host ""

Write-Host "===================================================================" -ForegroundColor Cyan
Write-Host ".env Configuration" -ForegroundColor Cyan
Write-Host "===================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Add these to your .env file:" -ForegroundColor Yellow
Write-Host "MS_OAUTH_CLIENT_ID=<your_client_id_from_azure>" -ForegroundColor White
Write-Host "MS_OAUTH_TENANT_ID=<your_tenant_id_from_azure>" -ForegroundColor White
Write-Host "MS_OAUTH_REDIRECT_URI=$redirectUri" -ForegroundColor White
Write-Host ""

Write-Host "===================================================================" -ForegroundColor Cyan
Write-Host "Azure Portal Configuration Steps" -ForegroundColor Cyan
Write-Host "===================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Go to https://portal.azure.com" -ForegroundColor White
Write-Host "2. Navigate to: App registrations > New registration" -ForegroundColor White
Write-Host "3. Name: Claudine Voice" -ForegroundColor White
Write-Host "4. Supported account types: Choose based on your needs" -ForegroundColor White
Write-Host "5. Click 'Register'" -ForegroundColor White
Write-Host ""
Write-Host "6. Copy the 'Application (client) ID' and 'Directory (tenant) ID'" -ForegroundColor Yellow
Write-Host ""
Write-Host "7. Go to: Authentication > Add a platform > Android" -ForegroundColor White
Write-Host "   - Package name: $PACKAGE_NAME" -ForegroundColor Cyan
Write-Host "   - Signature hash: $sha1Base64" -ForegroundColor Cyan
Write-Host "   (Use Base64 format, not Hex!)" -ForegroundColor Yellow
Write-Host ""
Write-Host "8. Save the configuration" -ForegroundColor White
Write-Host "9. Update your .env file with the Client ID and Tenant ID" -ForegroundColor White
Write-Host ""
Write-Host "===================================================================" -ForegroundColor Cyan
Write-Host "Done!" -ForegroundColor Green
Write-Host "===================================================================" -ForegroundColor Cyan
