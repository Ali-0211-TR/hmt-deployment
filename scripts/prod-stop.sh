#!/bin/bash

# Production Environment Stop Script
set -e

echo "🛑 Stopping HMT Production Environment..."

# Create backup before stopping
echo "💾 Creating backup before shutdown..."
./scripts/backup.sh

# Stop services gracefully
echo "🔄 Stopping services gracefully..."
docker-compose stop

# Remove containers
docker-compose down

echo "✅ Production environment stopped successfully!"
echo ""
echo "📋 To restart: ./scripts/prod-start.sh"
echo "📋 Backup created in backup/ directory"
