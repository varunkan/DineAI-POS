#!/bin/bash

# Restaurant POS - App Store Build Script
# This script automates the build process for App Store submission

set -e  # Exit on any error

echo "🚀 Restaurant POS - App Store Build Script"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Flutter is installed
check_flutter() {
    print_status "Checking Flutter installation..."
    if ! command -v flutter &> /dev/null; then
        print_error "Flutter is not installed or not in PATH"
        exit 1
    fi
    
    flutter_version=$(flutter --version | head -n 1)
    print_success "Flutter found: $flutter_version"
}

# Clean the project
clean_project() {
    print_status "Cleaning project..."
    flutter clean
    print_success "Project cleaned"
}

# Get dependencies
get_dependencies() {
    print_status "Getting dependencies..."
    flutter pub get
    print_success "Dependencies updated"
}

# Run tests
run_tests() {
    print_status "Running tests..."
    if flutter test; then
        print_success "All tests passed"
    else
        print_error "Tests failed"
        exit 1
    fi
}

# Build for iOS
build_ios() {
    print_status "Building for iOS..."
    
    # Check if running on macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_warning "iOS builds require macOS. Skipping iOS build."
        return
    fi
    
    # Check if Xcode is installed
    if ! command -v xcodebuild &> /dev/null; then
        print_warning "Xcode not found. Skipping iOS build."
        return
    fi
    
    # Build iOS app
    if flutter build ios --release --no-codesign; then
        print_success "iOS build completed"
        print_status "iOS build location: build/ios/iphoneos/Runner.app"
    else
        print_error "iOS build failed"
        exit 1
    fi
}

# Build for Android
build_android() {
    print_status "Building for Android..."
    
    # Build Android App Bundle (recommended for Play Store)
    if flutter build appbundle --release; then
        print_success "Android App Bundle build completed"
        print_status "AAB location: build/app/outputs/bundle/release/app-release.aab"
    else
        print_error "Android build failed"
        exit 1
    fi
    
    # Also build APK for testing
    if flutter build apk --release; then
        print_success "Android APK build completed"
        print_status "APK location: build/app/outputs/flutter-apk/app-release.apk"
    else
        print_error "Android APK build failed"
        exit 1
    fi
}

# Analyze the project
analyze_project() {
    print_status "Analyzing project..."
    if flutter analyze; then
        print_success "Project analysis completed - no issues found"
    else
        print_warning "Project analysis found issues. Please review and fix."
    fi
}

# Check app size
check_app_size() {
    print_status "Checking app size..."
    
    # Check iOS app size
    if [[ "$OSTYPE" == "darwin"* ]] && [ -d "build/ios/iphoneos/Runner.app" ]; then
        ios_size=$(du -sh build/ios/iphoneos/Runner.app | cut -f1)
        print_status "iOS app size: $ios_size"
    fi
    
    # Check Android app size
    if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
        android_size=$(du -sh build/app/outputs/flutter-apk/app-release.apk | cut -f1)
        print_status "Android APK size: $android_size"
    fi
    
    if [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then
        aab_size=$(du -sh build/app/outputs/bundle/release/app-release.aab | cut -f1)
        print_status "Android AAB size: $aab_size"
    fi
}

# Generate build report
generate_report() {
    print_status "Generating build report..."
    
    report_file="build_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
Restaurant POS - Build Report
Generated: $(date)

Build Information:
- Flutter Version: $(flutter --version | head -n 1)
- Build Date: $(date)
- Build Type: Release

App Information:
- App Name: Restaurant POS
- Bundle ID: com.restaurantpos.ai_pos_system
- Version: 1.0.0
- Build Number: 1

Build Artifacts:
EOF

    # Add iOS build info
    if [[ "$OSTYPE" == "darwin"* ]] && [ -d "build/ios/iphoneos/Runner.app" ]; then
        echo "- iOS App: build/ios/iphoneos/Runner.app" >> "$report_file"
        echo "- iOS Size: $(du -sh build/ios/iphoneos/Runner.app | cut -f1)" >> "$report_file"
    fi
    
    # Add Android build info
    if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
        echo "- Android APK: build/app/outputs/flutter-apk/app-release.apk" >> "$report_file"
        echo "- Android APK Size: $(du -sh build/app/outputs/flutter-apk/app-release.apk | cut -f1)" >> "$report_file"
    fi
    
    if [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then
        echo "- Android AAB: build/app/outputs/bundle/release/app-release.aab" >> "$report_file"
        echo "- Android AAB Size: $(du -sh build/app/outputs/bundle/release/app-release.aab | cut -f1)" >> "$report_file"
    fi
    
    print_success "Build report generated: $report_file"
}

# Main build process
main() {
    echo ""
    print_status "Starting build process..."
    
    # Check prerequisites
    check_flutter
    
    # Clean and prepare
    clean_project
    get_dependencies
    
    # Analyze and test
    analyze_project
    run_tests
    
    # Build for platforms
    build_ios
    build_android
    
    # Check results
    check_app_size
    generate_report
    
    echo ""
    print_success "Build process completed successfully!"
    echo ""
    print_status "Next steps:"
    echo "1. Review the build report: build_report_*.txt"
    echo "2. Test the builds on real devices"
    echo "3. Upload to App Store Connect (iOS)"
    echo "4. Upload to Google Play Console (Android)"
    echo "5. Complete app store metadata and screenshots"
    echo ""
    print_status "For detailed submission instructions, see: APP_STORE_GUIDE.md"
}

# Handle command line arguments
case "${1:-}" in
    "ios")
        check_flutter
        clean_project
        get_dependencies
        build_ios
        check_app_size
        ;;
    "android")
        check_flutter
        clean_project
        get_dependencies
        build_android
        check_app_size
        ;;
    "test")
        check_flutter
        clean_project
        get_dependencies
        run_tests
        ;;
    "analyze")
        check_flutter
        clean_project
        get_dependencies
        analyze_project
        ;;
    "clean")
        clean_project
        ;;
    "help"|"-h"|"--help")
        echo "Restaurant POS Build Script"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  (no args)  Build for all platforms"
        echo "  ios        Build for iOS only"
        echo "  android    Build for Android only"
        echo "  test       Run tests only"
        echo "  analyze    Analyze project only"
        echo "  clean      Clean project only"
        echo "  help       Show this help message"
        ;;
    *)
        main
        ;;
esac 