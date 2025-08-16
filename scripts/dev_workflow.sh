#!/bin/bash

# 🚀 AI POS System - Development Workflow Scripts
# Manages dev and prod environments with proper git workflow

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
DEV_DIR="../ai-pos-dev"
PROD_DIR="."
DEV_REPO="ai-pos-dev"
PROD_REPO="ai-pos-system"

# Helper functions
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

log_step() {
    echo -e "${PURPLE}🔧 $1${NC}"
}

# Check if we're in the right directory
check_directory() {
    if [[ ! -f "pubspec.yaml" ]]; then
        log_error "This script must be run from the POS project root directory"
        exit 1
    fi
}

# Initialize development environment
init_dev_environment() {
    log_step "Initializing development environment..."
    
    if [[ ! -d "$DEV_DIR" ]]; then
        log_info "Creating development directory..."
        mkdir -p "$DEV_DIR"
        cp -r . "$DEV_DIR/"
        cd "$DEV_DIR"
        
        # Initialize git repository
        git init
        git add .
        git commit -m "🚀 Initial dev environment setup - Copy from production baseline"
        
        log_success "Development environment created at $DEV_DIR"
    else
        log_warning "Development directory already exists at $DEV_DIR"
    fi
}

# Sync latest changes from production to development
sync_from_prod() {
    log_step "Syncing latest changes from production to development..."
    
    # Get current directory
    local current_dir=$(pwd)
    
    # Go to production directory
    cd "$PROD_DIR"
    
    # Get latest changes
    git pull origin main 2>/dev/null || log_warning "No remote repository configured for production"
    
    # Copy changes to development
    cd "$DEV_DIR"
    rsync -av --exclude='.git' --exclude='build' --exclude='.dart_tool' --exclude='node_modules' "$PROD_DIR/" .
    
    # Commit the sync
    git add .
    git commit -m "🔄 Sync from production - $(date '+%Y-%m-%d %H:%M:%S')"
    
    # Return to original directory
    cd "$current_dir"
    
    log_success "Successfully synced from production to development"
}

# Promote changes from development to production
promote_to_prod() {
    log_step "Promoting changes from development to production..."
    
    # Get current directory
    local current_dir=$(pwd)
    
    # Go to development directory
    cd "$DEV_DIR"
    
    # Check if there are uncommitted changes
    if [[ -n $(git status --porcelain) ]]; then
        log_error "Development environment has uncommitted changes. Please commit or stash them first."
        cd "$current_dir"
        exit 1
    fi
    
    # Get the latest commit hash
    local latest_commit=$(git rev-parse HEAD)
    local commit_message=$(git log -1 --pretty=format:"%s")
    
    # Go to production directory
    cd "$PROD_DIR"
    
    # Copy changes from development
    rsync -av --exclude='.git' --exclude='build' --exclude='.dart_tool' --exclude='node_modules' "$DEV_DIR/" .
    
    # Commit the promotion
    git add .
    git commit -m "🚀 Promote from dev: $commit_message (commit: $latest_commit)"
    
    # Return to original directory
    cd "$current_dir"
    
    log_success "Successfully promoted changes from development to production"
}

# Switch to development environment
switch_to_dev() {
    log_step "Switching to development environment..."
    
    if [[ -d "$DEV_DIR" ]]; then
        cd "$DEV_DIR"
        log_success "Switched to development environment"
        log_info "Current directory: $(pwd)"
        log_info "Run 'flutter run' to start development mode"
    else
        log_error "Development environment not found. Run 'init_dev_environment' first."
        exit 1
    fi
}

# Switch to production environment
switch_to_prod() {
    log_step "Switching to production environment..."
    
    cd "$PROD_DIR"
    log_success "Switched to production environment"
    log_info "Current directory: $(pwd)"
}

# Build for production
build_prod() {
    log_step "Building for production..."
    
    # Switch to production
    cd "$PROD_DIR"
    
    # Clean build
    flutter clean
    flutter pub get
    
    # Build for different platforms
    log_info "Building for macOS..."
    flutter build macos --release
    
    log_info "Building for iOS..."
    flutter build ios --release
    
    log_info "Building for Android..."
    flutter build appbundle --release
    
    log_info "Building for Web..."
    flutter build web --release
    
    log_success "Production builds completed"
}

# Run tests
run_tests() {
    log_step "Running tests..."
    
    flutter test
    log_success "Tests completed"
}

# Show status
show_status() {
    log_step "Environment Status..."
    
    echo -e "${CYAN}Production Environment:${NC}"
    cd "$PROD_DIR"
    echo "  Directory: $(pwd)"
    echo "  Git Status: $(git status --porcelain | wc -l) changes"
    echo "  Last Commit: $(git log -1 --pretty=format:'%h - %s (%cr)')"
    
    echo -e "\n${CYAN}Development Environment:${NC}"
    if [[ -d "$DEV_DIR" ]]; then
        cd "$DEV_DIR"
        echo "  Directory: $(pwd)"
        echo "  Git Status: $(git status --porcelain | wc -l) changes"
        echo "  Last Commit: $(git log -1 --pretty=format:'%h - %s (%cr)')"
    else
        echo "  Not initialized"
    fi
    
    # Return to original directory
    cd "$PROD_DIR"
}

# Show help
show_help() {
    echo -e "${CYAN}🚀 AI POS System - Development Workflow${NC}"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  init-dev          Initialize development environment"
    echo "  sync-from-prod    Sync latest changes from production to development"
    echo "  promote-to-prod   Promote changes from development to production"
    echo "  switch-dev        Switch to development environment"
    echo "  switch-prod       Switch to production environment"
    echo "  build-prod        Build production versions"
    echo "  test              Run tests"
    echo "  status            Show environment status"
    echo "  help              Show this help message"
    echo ""
    echo "Workflow:"
    echo "  1. init-dev                    # Set up dev environment"
    echo "  2. sync-from-prod              # Get latest from prod"
    echo "  3. switch-dev                  # Work in dev environment"
    echo "  4. [make changes and test]     # Development work"
    echo "  5. promote-to-prod             # Deploy to production"
    echo "  6. build-prod                  # Build production versions"
}

# Main script
main() {
    check_directory
    
    case "${1:-help}" in
        "init-dev")
            init_dev_environment
            ;;
        "sync-from-prod")
            sync_from_prod
            ;;
        "promote-to-prod")
            promote_to_prod
            ;;
        "switch-dev")
            switch_to_dev
            ;;
        "switch-prod")
            switch_to_prod
            ;;
        "build-prod")
            build_prod
            ;;
        "test")
            run_tests
            ;;
        "status")
            show_status
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# Run main function
main "$@" 