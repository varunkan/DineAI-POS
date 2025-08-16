#!/bin/bash

# Development Freeze Script
# Enforces development freeze until critical issues are resolved

set -e

echo "🚫 DEVELOPMENT FREEZE ENFORCEMENT"
echo "=================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Check if we're on the critical-fixes branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "critical-fixes" ]; then
    print_status $RED "❌ ERROR: You must be on the 'critical-fixes' branch to continue development"
    print_status $YELLOW "💡 Run: git checkout critical-fixes"
    exit 1
fi

print_status $GREEN "✅ Current branch: $CURRENT_BRANCH"

# Check for critical issues
echo ""
print_status $BLUE "🔍 Checking for critical issues..."

# Check for hardcoded credentials
if grep -r "7165" lib/ --include="*.dart" > /dev/null 2>&1; then
    print_status $RED "❌ CRITICAL: Hardcoded credentials found!"
    print_status $YELLOW "   Files containing hardcoded PIN:"
    grep -r "7165" lib/ --include="*.dart" | head -5
    echo ""
    print_status $RED "🚫 DEVELOPMENT BLOCKED: Fix hardcoded credentials first"
    exit 1
fi

# Check for compilation errors
echo ""
print_status $BLUE "🔍 Checking for compilation errors..."
if flutter analyze --no-preamble 2>/dev/null | grep -E "error" > /dev/null; then
    print_status $RED "❌ CRITICAL: Compilation errors found!"
    print_status $YELLOW "   Run: flutter analyze --no-preamble"
    print_status $RED "🚫 DEVELOPMENT BLOCKED: Fix compilation errors first"
    exit 1
fi

# Check for security vulnerabilities
echo ""
print_status $BLUE "🔍 Checking for security vulnerabilities..."
if grep -r "password.*=.*\"" lib/ --include="*.dart" > /dev/null 2>&1; then
    print_status $RED "❌ CRITICAL: Hardcoded passwords found!"
    print_status $RED "🚫 DEVELOPMENT BLOCKED: Fix security vulnerabilities first"
    exit 1
fi

# Check APK size
echo ""
print_status $BLUE "🔍 Checking APK size..."
if [ -f "build/app/outputs/flutter-apk/app-debug.apk" ]; then
    APK_SIZE=$(stat -f%z build/app/outputs/flutter-apk/app-debug.apk 2>/dev/null || stat -c%s build/app/outputs/flutter-apk/app-debug.apk)
    MAX_SIZE=$((50*1024*1024)) # 50MB
    
    if [ $APK_SIZE -gt $MAX_SIZE ]; then
        print_status $YELLOW "⚠️ WARNING: APK size ($APK_SIZE bytes) exceeds 50MB limit"
        print_status $YELLOW "   Consider optimizing before continuing"
    else
        print_status $GREEN "✅ APK size is within limits"
    fi
fi

# Check for debug code in production
echo ""
print_status $BLUE "🔍 Checking for debug code in production..."
DEBUG_COUNT=$(grep -r "debugPrint\|print(" lib/ --include="*.dart" | grep -v "// TODO" | wc -l)
if [ $DEBUG_COUNT -gt 0 ]; then
    print_status $YELLOW "⚠️ WARNING: $DEBUG_COUNT debug statements found in production code"
    print_status $YELLOW "   Consider removing or conditionally compiling debug code"
fi

# All checks passed
echo ""
print_status $GREEN "✅ All critical checks passed!"
print_status $GREEN "✅ Development can continue on critical-fixes branch"

echo ""
print_status $BLUE "📋 Development Guidelines:"
echo "   1. Only work on critical fixes and security issues"
echo "   2. Run tests before committing: flutter test"
echo "   3. Check code quality: flutter analyze"
echo "   4. Create small, focused commits"
echo "   5. Document all changes"

echo ""
print_status $BLUE "🔄 Next Steps:"
echo "   1. Fix remaining critical issues"
echo "   2. Run automated tests"
echo "   3. Submit pull request to main branch"
echo "   4. Wait for CI/CD pipeline approval"

echo ""
print_status $GREEN "🚀 Ready to continue development!" 