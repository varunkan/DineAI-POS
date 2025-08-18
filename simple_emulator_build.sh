#!/bin/bash

echo "🚀 Starting Tablet Emulator Rebuild..."

# Set Android SDK path
export ANDROID_HOME=/Users/varunkumar/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools

echo "📱 Android SDK path: $ANDROID_HOME"

# Check if directory exists
if [ -d "$ANDROID_HOME" ]; then
    echo "✅ Android SDK found"
else
    echo "❌ Android SDK not found"
    exit 1
fi

echo "🔍 Checking available AVDs..."
$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager list avd

echo "🗑️  Deleting old tablet emulators..."
$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager delete avd -n Pixel_Tablet_API_34 2>/dev/null || echo "Pixel_Tablet_API_34 not found"
$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager delete avd -n Simple_Tablet 2>/dev/null || echo "Simple_Tablet not found"

echo "📱 Creating new Pixel Tablet emulator..."
$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager create avd -n Pixel_Tablet_API_34 -k "system-images;android-34;google_apis;x86_64" -d "pixel_tablet"

echo "📱 Creating new Simple Tablet emulator..."
$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager create avd -n Simple_Tablet_API_34 -k "system-images;android-34;google_apis;x86_64" -d "10.1in WXGA (Tablet)"

echo "📋 Final AVD list:"
$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager list avd

echo "🎉 Done! Emulators rebuilt successfully!" 