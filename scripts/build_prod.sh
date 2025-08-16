#!/bin/bash

# 🚀 AI POS System - Production Build Script
# Builds the app in production mode with optimizations

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

log_info "🚀 Building AI POS System in PRODUCTION mode..."

# Clean previous builds
log_info "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
log_info "📦 Getting dependencies..."
flutter pub get

# Run tests before production build
log_info "🧪 Running tests..."
if flutter test; then
    log_success "All tests passed!"
else
    log_error "Tests failed! Aborting production build."
    exit 1
fi

# Set production environment
export FLUTTER_TARGET=lib/main_prod.dart

# Build for different platforms with release optimizations
log_info "🔨 Building for macOS (Production)..."
flutter build macos --release --target=lib/main_prod.dart

log_info "🔨 Building for iOS (Production)..."
flutter build ios --release --target=lib/main_prod.dart

log_info "🔨 Building for Android (Production)..."
flutter build appbundle --release --target=lib/main_prod.dart

log_info "🔨 Building for Web (Production)..."
flutter build web --release --target=lib/main_prod.dart

log_success "🎉 Production builds completed successfully!"
log_info "📦 Production builds are ready for deployment:"
log_info "   macOS: build/macos/Build/Products/Release/ai_pos_system.app"
log_info "   iOS: build/ios/archive/Runner.xcarchive"
log_info "   Android: build/app/outputs/bundle/release/app-release.aab"
log_info "   Web: build/web/" 