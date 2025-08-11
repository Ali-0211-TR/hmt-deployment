#!/bin/bash

# Health Check Script
set -e

echo "🏥 Running HMT Health Checks..."

# Determine which compose file to use
COMPOSE_FILE="docker-compose.yml"
if [ "$1" = "dev" ]; then
    COMPOSE_FILE="docker-compose.dev.yml"
fi

# Function to check service health
check_service() {
    local service_name=$1
    local health_endpoint=$2
    local max_attempts=30
    local attempt=1
    
    echo "🔍 Checking $service_name..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s "$health_endpoint" > /dev/null 2>&1; then
            echo "✅ $service_name is healthy"
            return 0
        fi
        
        echo "⏳ Attempt $attempt/$max_attempts - $service_name not ready yet..."
        sleep 2
        ((attempt++))
    done
    
    echo "❌ $service_name health check failed"
    return 1
}

# Function to check database connection
check_database() {
    echo "🗄️  Checking PostgreSQL connection..."
    
    if docker-compose -f $COMPOSE_FILE exec -T postgres pg_isready -q; then
        echo "✅ PostgreSQL is healthy"
        return 0
    else
        echo "❌ PostgreSQL connection failed"
        return 1
    fi
}

# Function to check Redis connection
check_redis() {
    echo "🔴 Checking Redis connection..."
    
    if docker-compose -f $COMPOSE_FILE exec -T redis redis-cli ping | grep -q "PONG"; then
        echo "✅ Redis is healthy"
        return 0
    else
        echo "❌ Redis connection failed"
        return 1
    fi
}

# Function to check gRPC service
check_grpc() {
    local service_name=$1
    local port=$2
    
    echo "🔌 Checking $service_name gRPC connection..."
    
    if nc -z localhost $port; then
        echo "✅ $service_name gRPC is healthy"
        return 0
    else
        echo "❌ $service_name gRPC connection failed"
        return 1
    fi
}

# Load environment variables
if [ -f ".env" ]; then
    source .env
fi

# Check if services are running
echo "📊 Checking running services..."
docker-compose -f $COMPOSE_FILE ps

echo ""
echo "🔍 Starting health checks..."

# Initialize health check results
overall_health=0

# Check PostgreSQL
if ! check_database; then
    overall_health=1
fi

# Check Redis
if ! check_redis; then
    overall_health=1
fi

# Check API Gateway HTTP endpoint
API_PORT=${API_GATEWAY_PORT:-3000}
if ! check_service "API Gateway" "http://localhost:$API_PORT/health"; then
    # Fallback to simple port check
    if nc -z localhost $API_PORT; then
        echo "⚠️  API Gateway port is open but health endpoint failed"
    else
        overall_health=1
    fi
fi

# Check Email Service gRPC
EMAIL_PORT=${EMAIL_SERVICE_GRPC_PORT:-5000}
if ! check_grpc "Email Service" $EMAIL_PORT; then
    overall_health=1
fi

# Show container logs for failed services
if [ $overall_health -ne 0 ]; then
    echo ""
    echo "🔍 Showing logs for debugging..."
    echo "API Gateway logs:"
    docker-compose -f $COMPOSE_FILE logs --tail=20 api-gateway
    echo ""
    echo "Email Service logs:"
    docker-compose -f $COMPOSE_FILE logs --tail=20 email-service
fi

echo ""
if [ $overall_health -eq 0 ]; then
    echo "✅ All health checks passed! System is healthy."
else
    echo "❌ Some health checks failed. Please check the logs above."
fi

echo ""
echo "📋 Service endpoints:"
echo "   - API Gateway: http://localhost:$API_PORT"
echo "   - Email Service: grpc://localhost:$EMAIL_PORT"
echo "   - PostgreSQL: localhost:${POSTGRES_PORT:-5432}"
echo "   - Redis: localhost:${REDIS_PORT:-6379}"

exit $overall_health
