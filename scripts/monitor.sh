#!/bin/bash

# Monitor HMT Services
set -e

# Default parameters
INTERVAL=5
COMPOSE_FILE="docker-compose.yml"
SHOW_LOGS=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dev)
            COMPOSE_FILE="docker-compose.dev.yml"
            shift
            ;;
        --interval)
            INTERVAL="$2"
            shift 2
            ;;
        --logs)
            SHOW_LOGS=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --dev                    Use development compose file"
            echo "  --interval SECONDS       Refresh interval (default: 5)"
            echo "  --logs                   Show recent logs"
            echo "  -h, --help               Show this help"
            echo ""
            echo "Press Ctrl+C to exit monitoring"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "📊 Starting HMT Services Monitor..."
echo "🔄 Refresh interval: ${INTERVAL}s"
echo "📁 Using: $COMPOSE_FILE"
echo ""
echo "Press Ctrl+C to exit"
echo ""

# Function to display service status
show_status() {
    clear
    echo "=========================================="
    echo "HMT Services Monitor - $(date)"
    echo "=========================================="
    echo ""
    
    # Show running services
    echo "📊 Service Status:"
    docker-compose -f $COMPOSE_FILE ps
    echo ""
    
    # Show resource usage
    echo "💻 Resource Usage:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" $(docker-compose -f $COMPOSE_FILE ps -q) 2>/dev/null || echo "No containers running"
    echo ""
    
    # Show recent logs if requested
    if [ "$SHOW_LOGS" = true ]; then
        echo "📄 Recent Logs (last 10 lines):"
        echo "----------------------------------------"
        docker-compose -f $COMPOSE_FILE logs --tail=10 --since=30s
        echo ""
    fi
    
    # Show disk usage
    echo "💾 Disk Usage:"
    df -h | grep -E "(Filesystem|/dev/)"
    echo ""
    
    # Show Docker volumes
    echo "📦 Docker Volumes:"
    docker volume ls | grep -E "(DRIVER|hmt|postgres|redis)" || echo "No HMT volumes found"
    echo ""
    
    echo "🔄 Next refresh in ${INTERVAL}s... (Ctrl+C to exit)"
}

# Function to handle Ctrl+C
cleanup() {
    echo ""
    echo "👋 Monitoring stopped"
    exit 0
}

# Set trap for Ctrl+C
trap cleanup INT

# Main monitoring loop
while true; do
    show_status
    sleep $INTERVAL
done
