#!/bin/bash
# Build script for Claudine Voice
# Sets correct JAVA_HOME and builds APK

export JAVA_HOME="C:\\Program Files\\Android\\Android Studio\\jbr"
export PATH="/home/frank/flutter/bin:$PATH"

cd "$(dirname "$0")"

echo "Building Claudine Voice APK..."
echo "JAVA_HOME: $JAVA_HOME"

/home/frank/flutter/bin/flutter build apk --release
