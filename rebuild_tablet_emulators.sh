#!/bin/bash

# 🚀 AI POS System - Tablet Emulator Rebuild Script
# This script will rebuild both tablet emulators for you

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

# Set Android SDK paths
export ANDROID_HOME=/Users/varunkumar/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools

log_info "🚀 Starting Tablet Emulator Rebuild Process..."

# Check if Android SDK is available
if [[ ! -d "$ANDROID_HOME" ]]; then
    log_error "Android SDK not found at $ANDROID_HOME"
    log_info "Please install Android Studio and Android SDK first"
    exit 1
fi

log_info "📱 Android SDK found at: $ANDROID_HOME"

# List current AVDs
log_info "📋 Current AVDs:"
avdmanager list avd || log_warning "Could not list AVDs"

# Delete existing tablet emulators
log_info "🗑️  Deleting existing tablet emulators..."

if avdmanager delete avd -n Pixel_Tablet_API_34 2>/dev/null; then
    log_success "Deleted Pixel_Tablet_API_34"
else
    log_warning "Pixel_Tablet_API_34 not found or already deleted"
fi

if avdmanager delete avd -n Simple_Tablet 2>/dev/null; then
    log_success "Deleted Simple_Tablet"
else
    log_warning "Simple_Tablet not found or already deleted"
fi

# Check available system images
log_info "🔍 Checking available system images..."
avdmanager list target

# Create new Pixel Tablet emulator
log_info "📱 Creating new Pixel Tablet emulator..."
avdmanager create avd -n Pixel_Tablet_API_34 -k "system-images;android-34;google_apis;x86_64" -d "pixel_tablet"

if [[ $? -eq 0 ]]; then
    log_success "✅ Pixel Tablet emulator created successfully!"
else
    log_warning "⚠️  Pixel Tablet creation failed, trying alternative approach..."
    # Try with different device definition
    avdmanager create avd -n Pixel_Tablet_API_34 -k "system-images;android-34;google_apis;x86_64" -d "10.1in WXGA (Tablet)"
    if [[ $? -eq 0 ]]; then
        log_success "✅ Pixel Tablet emulator created with alternative device!"
    else
        log_error "❌ Failed to create Pixel Tablet emulator"
    fi
fi

# Create new Simple Tablet emulator
log_info "📱 Creating new Simple Tablet emulator..."
avdmanager create avd -n Simple_Tablet_API_34 -k "system-images;android-34;google_apis;x86_64" -d "10.1in WXGA (Tablet)"

if [[ $? -eq 0 ]]; then
    log_success "✅ Simple Tablet emulator created successfully!"
else
    log_error "❌ Failed to create Simple Tablet emulator"
fi

# List all AVDs to confirm creation
log_info "📋 All available AVDs:"
avdmanager list avd

log_success "🎉 Tablet emulator rebuild process completed!"
log_info "📱 You can now launch the emulators using:"
log_info "   flutter emulators --launch Pixel_Tablet_API_34"
log_info "   flutter emulators --launch Simple_Tablet_API_34" 