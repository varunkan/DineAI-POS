#!/bin/bash

# Restaurant POS - App Store Deployment Script
# This script automates the deployment process for App Store submission

set -e  # Exit on any error

echo "🚀 Restaurant POS - App Store Deployment Script"
echo "=============================================="

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

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if running on macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_error "This script must be run on macOS for iOS deployment"
        exit 1
    fi
    
    # Check if Flutter is installed
    if ! command -v flutter &> /dev/null; then
        print_error "Flutter is not installed or not in PATH"
        exit 1
    fi
    
    # Check if Xcode is installed
    if ! command -v xcodebuild &> /dev/null; then
        print_error "Xcode is not installed"
        exit 1
    fi
    
    # Check if Xcode command line tools are installed
    if ! xcode-select -p &> /dev/null; then
        print_error "Xcode command line tools are not installed"
        print_status "Run: xcode-select --install"
        exit 1
    fi
    
    print_success "All prerequisites met"
}

# Clean and prepare the project
prepare_project() {
    print_status "Preparing project for release..."
    
    # Clean the project
    flutter clean
    
    # Get dependencies
    flutter pub get
    
    # Run tests
    print_status "Running tests..."
    if flutter test; then
        print_success "All tests passed"
    else
        print_error "Tests failed"
        exit 1
    fi
    
    # Analyze the project
    print_status "Analyzing project..."
    if flutter analyze; then
        print_success "Project analysis completed"
    else
        print_warning "Project analysis found issues. Please review and fix."
    fi
}

# Build for iOS release
build_ios_release() {
    print_status "Building iOS release..."
    
    # Build iOS app for release
    if flutter build ios --release --no-codesign; then
        print_success "iOS release build completed"
    else
        print_error "iOS build failed"
        exit 1
    fi
}

# Archive the app
archive_app() {
    print_status "Archiving app for App Store..."
    
    # Navigate to iOS directory
    cd ios
    
    # Archive the app
    if xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release -destination generic/platform=iOS -archivePath build/Runner.xcarchive archive; then
        print_success "App archived successfully"
    else
        print_error "App archiving failed"
        exit 1
    fi
    
    # Export the archive
    if xcodebuild -exportArchive -archivePath build/Runner.xcarchive -exportOptionsPlist exportOptions.plist -exportPath build/; then
        print_success "App exported successfully"
    else
        print_error "App export failed"
        exit 1
    fi
    
    cd ..
}

# Create export options plist
create_export_options() {
    print_status "Creating export options..."
    
    cat > ios/exportOptions.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
</dict>
</plist>
EOF
    
    print_warning "Please update ios/exportOptions.plist with your Team ID"
    print_status "You can find your Team ID in Apple Developer account"
}

# Validate the app
validate_app() {
    print_status "Validating app..."
    
    # Check app size
    if [ -d "build/ios/iphoneos/Runner.app" ]; then
        app_size=$(du -sh build/ios/iphoneos/Runner.app | cut -f1)
        print_status "App size: $app_size"
        
        # Check if app size is reasonable (less than 100MB)
        size_in_mb=$(du -sm build/ios/iphoneos/Runner.app | cut -f1)
        if [ "$size_in_mb" -gt 100 ]; then
            print_warning "App size is large ($size_in_mb MB). Consider optimizing."
        fi
    fi
    
    # Validate with Xcode
    cd ios
    if xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release -destination generic/platform=iOS validate; then
        print_success "App validation passed"
    else
        print_error "App validation failed"
        exit 1
    fi
    cd ..
}

# Upload to App Store Connect
upload_to_appstore() {
    print_status "Uploading to App Store Connect..."
    
    # Check if altool is available (Xcode 12 and earlier)
    if command -v altool &> /dev/null; then
        print_status "Using altool for upload..."
        # Note: You'll need to provide Apple ID and app-specific password
        print_warning "Please run the following command manually:"
        echo "xcrun altool --upload-app --type ios --file ios/build/Runner.ipa --username YOUR_APPLE_ID --password YOUR_APP_SPECIFIC_PASSWORD"
    else
        # Use xcrun notarytool for Xcode 13+
        print_status "Using xcrun notarytool for upload..."
        print_warning "Please run the following command manually:"
        echo "xcrun notarytool submit ios/build/Runner.ipa --apple-id YOUR_APPLE_ID --password YOUR_APP_SPECIFIC_PASSWORD --team-id YOUR_TEAM_ID"
    fi
}

# Generate deployment report
generate_deployment_report() {
    print_status "Generating deployment report..."
    
    report_file="appstore_deployment_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
Restaurant POS - App Store Deployment Report
Generated: $(date)

Deployment Information:
- App Name: Restaurant POS
- Bundle ID: com.restaurantpos.aiPosSystem
- Version: 1.0.0
- Build Number: 2
- Deployment Date: $(date)

Build Artifacts:
- iOS App: build/ios/iphoneos/Runner.app
- iOS Archive: ios/build/Runner.xcarchive
- iOS IPA: ios/build/Runner.ipa

Next Steps:
1. Update ios/exportOptions.plist with your Team ID
2. Upload the IPA to App Store Connect using:
   - For Xcode 12 and earlier: xcrun altool --upload-app --type ios --file ios/build/Runner.ipa --username YOUR_APPLE_ID --password YOUR_APP_SPECIFIC_PASSWORD
   - For Xcode 13+: xcrun notarytool submit ios/build/Runner.ipa --apple-id YOUR_APPLE_ID --password YOUR_APP_SPECIFIC_PASSWORD --team-id YOUR_TEAM_ID
3. Configure app metadata in App Store Connect
4. Submit for review

Requirements:
- Apple Developer Account ($99/year)
- App Store Connect access
- App-specific password for upload
- App Store review compliance

EOF
    
    print_success "Deployment report generated: $report_file"
}

# Main deployment process
main() {
    echo ""
    print_status "Starting App Store deployment process..."
    
    check_prerequisites
    prepare_project
    build_ios_release
    create_export_options
    archive_app
    validate_app
    generate_deployment_report
    
    echo ""
    print_success "Deployment preparation completed!"
    print_status "Next steps:"
    print_status "1. Update ios/exportOptions.plist with your Team ID"
    print_status "2. Upload the IPA to App Store Connect"
    print_status "3. Configure app metadata in App Store Connect"
    print_status "4. Submit for review"
    echo ""
    print_warning "Make sure you have:"
    print_warning "- Apple Developer Account ($99/year)"
    print_warning "- App Store Connect access"
    print_warning "- App-specific password"
}

# Run the main function
main "$@" 