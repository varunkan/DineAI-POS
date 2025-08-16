#!/bin/bash

# DineAI-POS Deployment Script
# Usage: ./scripts/deploy.sh [staging|production] [version]

set -e

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

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    print_error "This script must be run from the project root directory"
    exit 1
fi

# Check if gh CLI is available
if ! command -v gh &> /dev/null; then
    print_error "GitHub CLI (gh) is not installed. Please install it first."
    exit 1
fi

# Check if user is authenticated
if ! gh auth status &> /dev/null; then
    print_error "GitHub CLI not authenticated. Please run: gh auth login"
    exit 1
fi

# Function to deploy to staging
deploy_staging() {
    print_status "Deploying to staging environment..."
    
    # Check if we're on develop branch
    current_branch=$(git branch --show-current)
    if [ "$current_branch" != "develop" ]; then
        print_warning "You're not on the develop branch. Current branch: $current_branch"
        read -p "Do you want to continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Deployment cancelled"
            exit 0
        fi
    fi
    
    # Push to develop branch to trigger automatic deployment
    print_status "Pushing to develop branch..."
    git push origin develop
    
    print_success "Staging deployment triggered! Check GitHub Actions for progress."
    print_status "Staging URL: https://staging.dineai-pos.com"
}

# Function to deploy to production
deploy_production() {
    local version=$1
    
    if [ -z "$version" ]; then
        print_error "Version is required for production deployment"
        print_status "Usage: $0 production <version>"
        exit 1
    fi
    
    print_status "Deploying to production environment..."
    print_status "Version: $version"
    
    # Check if we're on main branch
    current_branch=$(git branch --show-current)
    if [ "$current_branch" != "main" ]; then
        print_warning "You're not on the main branch. Current branch: $current_branch"
        read -p "Do you want to continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Deployment cancelled"
            exit 0
        fi
    fi
    
    # Create and push tag
    print_status "Creating version tag: $version"
    git tag -a "v$version" -m "Release version $version"
    git push origin "v$version"
    
    # Create GitHub release
    print_status "Creating GitHub release..."
    gh release create "v$version" \
        --title "Release v$version" \
        --notes "Production release for DineAI-POS v$version" \
        --target main
    
    print_success "Production deployment triggered! Check GitHub Actions for progress."
    print_status "Production URL: https://dineai-pos.com"
}

# Function to check deployment status
check_status() {
    print_status "Checking deployment status..."
    
    # Get latest workflow runs
    print_status "Recent workflow runs:"
    gh run list --limit 5
    
    # Get latest deployments
    print_status "Recent deployments:"
    gh api repos/:owner/:repo/deployments --paginate | jq -r '.[] | "\(.environment) - \(.status) - \(.created_at)"' | head -5
}

# Function to show help
show_help() {
    echo "DineAI-POS Deployment Script"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  staging              Deploy to staging environment"
    echo "  production <version> Deploy to production environment"
    echo "  status               Check deployment status"
    echo "  help                 Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 staging                    # Deploy to staging"
    echo "  $0 production 1.2.0          # Deploy v1.2.0 to production"
    echo "  $0 status                     # Check deployment status"
    echo ""
    echo "Note: Make sure you're on the correct branch before deploying"
}

# Main script logic
case "${1:-help}" in
    "staging")
        deploy_staging
        ;;
    "production")
        deploy_production "$2"
        ;;
    "status")
        check_status
        ;;
    "help"|*)
        show_help
        ;;
esac 