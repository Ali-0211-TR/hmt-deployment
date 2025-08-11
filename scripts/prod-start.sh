#!/bin/bash

# Production Environment Startup Script
set -e

echo "🚀 Starting HMT Production Environment..."

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "❌ .env file not found. Please run './scripts/init.sh' first."
    exit 1
fi

# Load environment variables
source .env

# Validate required environment variables
required_vars=("POSTGRES_PASSWORD" "API_GATEWAY_JWT_SECRET" "SMTP_HOST" "SMTP_USER" "SMTP_PASSWORD")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "❌ Required environment variable $var is not set."
        exit 1
    fi
done

# Check if submodules are initialized
if [ ! -d "services/hmt-apigateway" ] || [ ! -d "services/hmt-email-service" ]; then
    echo "❌ Submodules not found. Please run './scripts/init.sh' first."
    exit 1
fi

# Pull latest changes for submodules
echo "🔄 Updating submodules..."
git submodule update --recursive --remote

# Create backup before deployment
echo "💾 Creating backup..."
./scripts/backup.sh

# Build and start production environment
echo "🏗️  Building and starting production environment..."
docker-compose down
docker-compose build --no-cache
docker-compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 60

# Run database migrations
echo "🗄️  Running database migrations..."
docker-compose exec api-gateway npx prisma migrate deploy || true
docker-compose exec email-service npx prisma migrate deploy || true

# Health check
echo "🏥 Running health checks..."
sleep 30
./scripts/health-check.sh

# Show running services
echo "📊 Running services:"
docker-compose ps

echo "✅ Production environment started successfully!"
echo ""
echo "🔗 Available services:"
if [ "${SSL_ENABLED:-false}" = "true" ]; then
    echo "   - API Gateway: https://localhost"
else
    echo "   - API Gateway: http://localhost"
fi
echo "   - Email Service: grpc://localhost:${EMAIL_SERVICE_GRPC_PORT:-5000}"
echo ""
echo "📋 Useful commands:"
echo "   - View logs: ./scripts/logs.sh"
echo "   - Stop services: ./scripts/prod-stop.sh"
echo "   - Health check: ./scripts/health-check.sh"
echo "   - Monitor: ./scripts/monitor.sh"
