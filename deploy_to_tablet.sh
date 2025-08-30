#!/bin/bash

# 🚀 AI POS System - Tablet Deployment Script
# Builds and deploys the app to tablet emulators and devices

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if we're in the right directory
if [[ ! -f "pubspec.yaml" ]]; then
    log_error "This script must be run from the POS project root directory"
    exit 1
fi

log_info "🚀 Starting AI POS System Tablet Deployment..."

# Clean previous builds
log_info "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
log_info "📦 Getting dependencies..."
flutter pub get

# Build APK in release mode
log_info "🔨 Building APK in release mode..."
flutter build apk --release

# Check for connected devices
log_info "📱 Checking connected devices..."
flutter devices

# Function to install and run on device
install_and_run() {
    local device_id=$1
    local device_name=$2
    
    log_info "📱 Installing APK on $device_name ($device_id)..."
    if flutter install --device-id=$device_id; then
        log_success "✅ APK installed successfully on $device_name"
        
        log_info "🚀 Launching app on $device_name..."
        flutter run --device-id=$device_id --release &
        log_success "✅ App launched on $device_name"
    else
        log_error "❌ Failed to install APK on $device_name"
    fi
}

# Get list of Android devices
android_devices=$(flutter devices | grep "android" | awk '{print $2}' | tr -d '•')

if [[ -z "$android_devices" ]]; then
    log_warning "⚠️  No Android devices found. Starting tablet emulator..."
    flutter emulators --launch Pixel_Tablet_API_34
    sleep 15
    android_devices=$(flutter devices | grep "android" | awk '{print $2}' | tr -d '•')
fi

# Install and run on each Android device
for device_id in $android_devices; do
    device_name=$(flutter devices | grep "$device_id" | awk '{print $1}')
    install_and_run "$device_id" "$device_name"
done

log_success "🎉 Tablet deployment completed!"
log_info "📦 APK location: build/app/outputs/flutter-apk/app-release.apk"
log_info "📱 APK size: $(ls -lh build/app/outputs/flutter-apk/app-release.apk | awk '{print $5}')"
log_info "🔧 To manually install: flutter install --device-id=<device_id>"
log_info "🚀 To manually run: flutter run --device-id=<device_id> --release" 