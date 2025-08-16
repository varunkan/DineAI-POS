#!/bin/bash

# AI POS Cloud Sync Server Setup Script

echo "🚀 Setting up AI POS Cloud Sync Server..."

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js version 16 or higher."
    echo "   Visit: https://nodejs.org/"
    exit 1
fi

# Check Node.js version
NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 16 ]; then
    echo "❌ Node.js version 16 or higher is required. Current version: $(node -v)"
    exit 1
fi

echo "✅ Node.js version: $(node -v)"

# Install dependencies
echo "📦 Installing dependencies..."
npm install

if [ $? -ne 0 ]; then
    echo "❌ Failed to install dependencies"
    exit 1
fi

echo "✅ Dependencies installed successfully"

# Create logs directory
mkdir -p logs

# Start the server
echo "🚀 Starting cloud sync server..."
echo "📡 WebSocket endpoint: ws://localhost:3000"
echo "🌐 HTTP API endpoint: http://localhost:3000/api"
echo "📊 Health check: http://localhost:3000/api/health"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

# Start the server and log to file
npm start 2>&1 | tee logs/server.log 