#!/bin/bash

# Development Environment Startup Script
set -e

echo "🔧 Starting HMT Development Environment..."

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "❌ .env file not found. Please run './scripts/init.sh' first."
    exit 1
fi

# Load environment variables
source .env

# Check if submodules are initialized
if [ ! -d "services/hmt-apigateway" ] || [ ! -d "services/hmt-email-service" ]; then
    echo "❌ Submodules not found. Please run './scripts/init.sh' first."
    exit 1
fi

# Pull latest changes for submodules
echo "🔄 Updating submodules..."
git submodule update --recursive --remote

# Build and start development environment
echo "🏗️  Building and starting development environment..."
docker-compose -f docker-compose.dev.yml down
docker-compose -f docker-compose.dev.yml build --no-cache
docker-compose -f docker-compose.dev.yml up -d

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 30

# Run database migrations
echo "🗄️  Running database migrations..."
docker-compose -f docker-compose.dev.yml exec api-gateway npx prisma migrate dev --name init || true
docker-compose -f docker-compose.dev.yml exec email-service npx prisma migrate dev --name init || true

# Seed database
echo "🌱 Seeding database..."
docker-compose -f docker-compose.dev.yml exec api-gateway npx prisma db seed || true
docker-compose -f docker-compose.dev.yml exec email-service npx prisma db seed || true

# Show running services
echo "📊 Running services:"
docker-compose -f docker-compose.dev.yml ps

echo "✅ Development environment started successfully!"
echo ""
echo "🔗 Available services:"
echo "   - API Gateway: http://localhost:3000"
echo "   - Email Service: grpc://localhost:5000"
echo "   - PostgreSQL: localhost:5432"
echo "   - Redis: localhost:6379"
echo ""
echo "📋 Useful commands:"
echo "   - View logs: ./scripts/logs.sh"
echo "   - Stop services: ./scripts/dev-stop.sh"
echo "   - Health check: ./scripts/health-check.sh"
