#!/bin/bash

echo "🔄 RESTARTING BOTH EMULATORS..."

# Set Android SDK path
export ANDROID_HOME=/Users/varunkumar/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator

echo "📱 Android SDK path: $ANDROID_HOME"

# Kill existing emulator processes
echo "🛑 Stopping existing emulators..."
pkill -f "emulator" 2>/dev/null || echo "No emulators to stop"

# Wait a moment
sleep 3

# Check available AVDs
echo "🔍 Available AVDs:"
$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager list avd

# Create Pixel Tablet if it doesn't exist
echo "📱 Creating Pixel Tablet emulator..."
$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager create avd -n Pixel_Tablet_API_34 -k "system-images;android-34;google_apis;x86_64" -d "pixel_tablet" --force

# Create Pixel 7 Phone if it doesn't exist
echo "📱 Creating Pixel 7 Phone emulator..."
$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager create avd -n Pixel_7_API_34 -k "system-images;android-34;google_apis;x86_64" -d "pixel_7" --force

# Launch Pixel Tablet
echo "🚀 Launching Pixel Tablet emulator..."
$ANDROID_HOME/emulator/emulator -avd Pixel_Tablet_API_34 -no-snapshot-load &
echo "📱 Pixel Tablet launched with PID: $!"

# Wait a moment
sleep 5

# Launch Pixel 7 Phone
echo "🚀 Launching Pixel 7 Phone emulator..."
$ANDROID_HOME/emulator/emulator -avd Pixel_7_API_34 -no-snapshot-load &
echo "📱 Pixel 7 Phone launched with PID: $!"

echo "⏳ Both emulators are starting up..."
echo "📱 They will take 2-3 minutes to fully boot"
echo "🔍 Check your screen for the emulator windows"

# Wait and check status
sleep 30
echo "🔍 Checking device status..."
$ANDROID_HOME/platform-tools/adb devices

echo "🎉 Emulator restart completed!" 