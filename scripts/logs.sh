#!/bin/bash

# Logs Viewing Script
set -e

# Default parameters
SERVICE=""
LINES=100
FOLLOW=false
COMPOSE_FILE="docker-compose.yml"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--service)
            SERVICE="$2"
            shift 2
            ;;
        -n|--lines)
            LINES="$2"
            shift 2
            ;;
        -f|--follow)
            FOLLOW=true
            shift
            ;;
        --dev)
            COMPOSE_FILE="docker-compose.dev.yml"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  -s, --service SERVICE    Show logs for specific service"
            echo "  -n, --lines LINES        Number of lines to show (default: 100)"
            echo "  -f, --follow             Follow log output"
            echo "  --dev                    Use development compose file"
            echo "  -h, --help               Show this help"
            echo ""
            echo "Available services:"
            echo "  - api-gateway"
            echo "  - email-service"
            echo "  - postgres"
            echo "  - redis"
            echo "  - nginx (production only)"
            echo ""
            echo "Examples:"
            echo "  $0                                    # Show all logs"
            echo "  $0 -s api-gateway                     # Show API Gateway logs"
            echo "  $0 -s email-service -f               # Follow Email Service logs"
            echo "  $0 -n 50 --dev                       # Show last 50 lines in dev mode"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

echo "📋 Viewing HMT Logs..."

# Check if compose file exists
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "❌ Compose file $COMPOSE_FILE not found"
    exit 1
fi

# Build docker-compose command
DOCKER_CMD="docker-compose -f $COMPOSE_FILE logs"

# Add lines parameter
DOCKER_CMD="$DOCKER_CMD --tail=$LINES"

# Add follow parameter if requested
if [ "$FOLLOW" = true ]; then
    DOCKER_CMD="$DOCKER_CMD -f"
fi

# Add service parameter if specified
if [ -n "$SERVICE" ]; then
    DOCKER_CMD="$DOCKER_CMD $SERVICE"
    echo "📊 Showing logs for service: $SERVICE"
else
    echo "📊 Showing logs for all services"
fi

echo "🔍 Command: $DOCKER_CMD"
echo ""

# Execute the command
eval $DOCKER_CMD
