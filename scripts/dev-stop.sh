#!/bin/bash

# Development Environment Stop Script
set -e

echo "🛑 Stopping HMT Development Environment..."

# Stop and remove containers
docker-compose -f docker-compose.dev.yml down

# Optional: Remove volumes (uncomment if you want to clean data)
# docker-compose -f docker-compose.dev.yml down -v

echo "✅ Development environment stopped successfully!"
echo ""
echo "📋 To restart: ./scripts/dev-start.sh"
echo "📋 To clean volumes: docker-compose -f docker-compose.dev.yml down -v"
