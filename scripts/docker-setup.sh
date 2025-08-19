#!/bin/bash

# Docker Setup Script for Query Optimizer API
# This script helps you get the API running with Docker quickly

set -e

echo "🐳 Query Optimizer API - Docker Setup"
echo "====================================="

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    echo "   Visit: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    echo "   Visit: https://docs.docker.com/compose/install/"
    exit 1
fi

echo "✅ Docker and Docker Compose are installed"

# Create master key if it doesn't exist
if [ ! -f config/master.key ]; then
    echo "🔑 Generating Rails master key..."
    openssl rand -hex 32 > config/master.key
    echo "✅ Master key created"
else
    echo "✅ Master key already exists"
fi

# Choose environment
echo ""
echo "Choose your environment:"
echo "1) Development (with live code reloading)"
echo "2) Production (optimized build)"
read -p "Enter your choice (1 or 2): " choice

case $choice in
    1)
        echo "🚀 Starting in Development mode..."
        docker-compose -f docker-compose.dev.yml up --build
        ;;
    2)
        echo "🚀 Starting in Production mode..."
        docker-compose up --build
        ;;
    *)
        echo "❌ Invalid choice. Please run the script again."
        exit 1
        ;;
esac
