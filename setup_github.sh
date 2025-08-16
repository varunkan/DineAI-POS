#!/bin/bash

echo "🚀 Setting up GitHub repository for DineAI-POS..."

# Check if GitHub CLI is authenticated
if ! gh auth status &> /dev/null; then
    echo "❌ GitHub CLI not authenticated. Please run: gh auth login"
    echo "   Then run this script again."
    exit 1
fi

# Create repository on GitHub
echo "📦 Creating GitHub repository..."
gh repo create DineAI-POS \
    --public \
    --description "Multi-Tenant AI POS System with enhanced admin user management and restaurant management features" \
    --source=. \
    --remote=origin \
    --push

if [ $? -eq 0 ]; then
    echo "✅ Repository created and pushed successfully!"
    echo "🌐 Your repository is now available at: https://github.com/$(gh api user --jq .login)/DineAI-POS"
    
    # Push tags
    echo "🏷️  Pushing version tags..."
    git push --tags
    
    echo "🎉 All done! Your DineAI-POS repository is now on GitHub with all changes and version tags."
else
    echo "❌ Failed to create repository. Please check the error above."
fi 