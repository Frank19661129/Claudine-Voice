#!/bin/bash

# Script to get Microsoft Authentication Signature Hash for Android

echo "==================================================================="
echo "Microsoft Authentication Configuration for Claudine Voice"
echo "==================================================================="
echo ""

PACKAGE_NAME="com.franklab.claudine_voice"
echo "Package Name: $PACKAGE_NAME"
echo ""

# Check for Java/keytool
if command -v keytool &> /dev/null; then
    KEYTOOL="keytool"
elif [ -f "/mnt/c/Program Files/Android/Android Studio/jbr/bin/keytool.exe" ]; then
    KEYTOOL="/mnt/c/Program Files/Android/Android Studio/jbr/bin/keytool.exe"
elif [ -f "/mnt/c/Program Files/Android/Android Studio/jbr/bin/keytool" ]; then
    KEYTOOL="/mnt/c/Program Files/Android/Android Studio/jbr/bin/keytool"
else
    echo "ERROR: keytool not found. Please install Java or Android Studio."
    echo "Looked in:"
    echo "  - System PATH"
    echo "  - /mnt/c/Program Files/Android/Android Studio/jbr/bin/"
    exit 1
fi

echo "Using keytool: $KEYTOOL"
echo ""

# Debug keystore location
DEBUG_KEYSTORE="$HOME/.android/debug.keystore"

# Check if debug keystore exists, if not create the directory
if [ ! -f "$DEBUG_KEYSTORE" ]; then
    echo "Debug keystore not found. Creating .android directory..."
    mkdir -p "$HOME/.android"
    echo ""
    echo "Generating debug keystore..."
    "$KEYTOOL" -genkey -v -keystore "$DEBUG_KEYSTORE" \
        -storepass android -alias androiddebugkey \
        -keypass android -keyalg RSA -keysize 2048 \
        -validity 10000 \
        -dname "CN=Android Debug,O=Android,C=US"
    echo ""
fi

echo "==================================================================="
echo "DEBUG BUILD - Signature Hashes"
echo "==================================================================="
echo ""

# Get SHA-1 and SHA-256
SHA1=$("$KEYTOOL" -list -v -keystore "$DEBUG_KEYSTORE" \
    -alias androiddebugkey -storepass android -keypass android 2>/dev/null | \
    grep "SHA1:" | sed 's/.*SHA1: //' | tr -d ':')

SHA256=$("$KEYTOOL" -list -v -keystore "$DEBUG_KEYSTORE" \
    -alias androiddebugkey -storepass android -keypass android 2>/dev/null | \
    grep "SHA256:" | sed 's/.*SHA256: //' | tr -d ':')

echo "SHA-1:   $SHA1"
echo "SHA-256: $SHA256"
echo ""

# URL encode the SHA-1 hash
SHA1_ENCODED=$(echo -n "$SHA1" | xxd -r -p | base64 | tr '+/' '-_' | tr -d '=')

echo "==================================================================="
echo "AZURE APP REGISTRATION - Redirect URI"
echo "==================================================================="
echo ""
echo "Use this Redirect URI in Azure Portal:"
echo "msauth://$PACKAGE_NAME/$SHA1_ENCODED"
echo ""

echo "==================================================================="
echo ".env Configuration"
echo "==================================================================="
echo ""
echo "Add these to your .env file:"
echo "MS_OAUTH_CLIENT_ID=<your_client_id_from_azure>"
echo "MS_OAUTH_TENANT_ID=<your_tenant_id_from_azure>"
echo "MS_OAUTH_REDIRECT_URI=msauth://$PACKAGE_NAME/$SHA1_ENCODED"
echo ""

echo "==================================================================="
echo "Azure Portal Configuration Steps"
echo "==================================================================="
echo ""
echo "1. Go to https://portal.azure.com"
echo "2. Navigate to Azure Active Directory > App registrations"
echo "3. Create new registration or select existing"
echo "4. Under 'Authentication' > 'Add a platform' > 'Android'"
echo "5. Enter Package name: $PACKAGE_NAME"
echo "6. Enter Signature hash: $SHA1"
echo "7. Save the configuration"
echo "8. Copy Client ID and Tenant ID to .env"
echo ""
echo "==================================================================="
