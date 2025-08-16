#!/bin/bash

# 🚀 AI POS System - Development Build Script
# Builds the app in development mode with enhanced debugging

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
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

# Check if we're in the right directory
if [[ ! -f "pubspec.yaml" ]]; then
    echo "❌ This script must be run from the POS project root directory"
    exit 1
fi

log_info "🚀 Building AI POS System in DEVELOPMENT mode..."

# Clean previous builds
log_info "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
log_info "📦 Getting dependencies..."
flutter pub get

# Set development environment
export FLUTTER_TARGET=lib/main_dev.dart

# Build for different platforms
log_info "🔨 Building for macOS (Development)..."
flutter build macos --debug --target=lib/main_dev.dart

log_info "🔨 Building for iOS (Development)..."
flutter build ios --debug --target=lib/main_dev.dart

log_info "🔨 Building for Android (Development)..."
flutter build apk --debug --target=lib/main_dev.dart

log_info "🔨 Building for Web (Development)..."
flutter build web --debug --target=lib/main_dev.dart

log_success "🎉 Development builds completed successfully!"
log_info "📱 You can now run the app in development mode with:"
log_info "   flutter run -d macos --target=lib/main_dev.dart"
log_info "   flutter run -d ios --target=lib/main_dev.dart"
log_info "   flutter run -d android --target=lib/main_dev.dart" 