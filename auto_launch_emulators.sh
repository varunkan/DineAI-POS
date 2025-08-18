#!/bin/bash

echo "🚀 AUTOMATIC EMULATOR LAUNCHER STARTING..."

# Set Android SDK paths
export ANDROID_HOME=/Users/varunkumar/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator

echo "📱 Setting up Android SDK environment..."

# Check if Android SDK exists
if [ ! -d "$ANDROID_HOME" ]; then
    echo "❌ Android SDK not found at $ANDROID_HOME"
    echo "Please install Android Studio first"
    exit 1
fi

echo "✅ Android SDK found at: $ANDROID_HOME"

# Kill any existing emulator processes
echo "🔄 Stopping any existing emulator processes..."
pkill -f "emulator" 2>/dev/null || echo "No existing emulator processes found"

# Wait a moment
sleep 2

# Check available AVDs
echo "🔍 Checking available AVDs..."
$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager list avd

# Create Pixel Tablet emulator if it doesn't exist
echo "📱 Creating Pixel Tablet emulator..."
$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager create avd -n Pixel_Tablet_API_34 -k "system-images;android-34;google_apis;x86_64" -d "pixel_tablet" --force 2>/dev/null || echo "Pixel Tablet already exists or creation failed"

# Create Pixel 7 Phone emulator if it doesn't exist  
echo "📱 Creating Pixel 7 Phone emulator..."
$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager create avd -n Pixel_7_API_34 -k "system-images;android-34;google_apis;x86_64" -d "pixel_7" --force 2>/dev/null || echo "Pixel 7 already exists or creation failed"

# List all AVDs
echo "📋 Available AVDs:"
$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager list avd

# Launch Pixel Tablet emulator
echo "🚀 Launching Pixel Tablet emulator..."
$ANDROID_HOME/emulator/emulator -avd Pixel_Tablet_API_34 -no-snapshot-load -no-boot-anim &
TABLET_PID=$!

# Wait a moment
sleep 5

# Launch Pixel 7 Phone emulator
echo "🚀 Launching Pixel 7 Phone emulator..."
$ANDROID_HOME/emulator/emulator -avd Pixel_7_API_34 -no-snapshot-load -no-boot-anim &
PHONE_PID=$!

echo "⏳ Both emulators are starting up..."
echo "📱 Pixel Tablet PID: $TABLET_PID"
echo "📱 Pixel 7 Phone PID: $PHONE_PID"

# Wait for emulators to boot
echo "⏳ Waiting for emulators to boot (this may take 2-3 minutes)..."
sleep 60

# Check device status
echo "🔍 Checking device status..."
$ANDROID_HOME/platform-tools/adb devices

echo "🎉 Emulator launch process completed!"
echo "📱 Both emulators should now be visible on your screen"
echo "💡 If you don't see them, check your Dock or Mission Control"
echo "🔧 To install your APK, run: flutter install --device-id=<emulator_id>" 