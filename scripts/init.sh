#!/bin/bash

# Initialize HMT Deployment Environment
set -e

echo "🚀 Initializing HMT Deployment Environment..."

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "❌ Git is not installed. Please install git first."
    exit 1
fi

# Check if docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if docker-compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Initialize git repository if not already initialized
if [ ! -d ".git" ]; then
    echo "📁 Initializing git repository..."
    git init
fi

# Initialize submodules if they don't exist
echo "📦 Initializing submodules..."
if [ ! -d "services" ]; then
    mkdir -p services
fi

# Add submodules if they don't exist
if [ ! -d "services/hmt-apigateway" ]; then
    echo "➕ Adding hmt-apigateway submodule..."
    # Replace with your actual repository URL
    # git submodule add https://github.com/your-org/hmt-apigateway.git services/hmt-apigateway
    echo "⚠️  Please add hmt-apigateway submodule manually:"
    echo "   git submodule add <your-repo-url> services/hmt-apigateway"
fi

if [ ! -d "services/hmt-email-service" ]; then
    echo "➕ Adding hmt-email-service submodule..."
    # Replace with your actual repository URL
    # git submodule add https://github.com/your-org/hmt-email-service.git services/hmt-email-service
    echo "⚠️  Please add hmt-email-service submodule manually:"
    echo "   git submodule add <your-repo-url> services/hmt-email-service"
fi

# Update existing submodules
if [ -f ".gitmodules" ]; then
    echo "🔄 Updating submodules..."
    git submodule update --init --recursive
fi

# Create necessary directories
echo "📁 Creating directory structure..."
mkdir -p configs/{nginx,postgres,redis}
mkdir -p ssl
mkdir -p monitoring/{prometheus,grafana}
mkdir -p backup
mkdir -p logs
mkdir -p uploads
mkdir -p docs
mkdir -p ci-cd

# Create environment file if it doesn't exist
if [ ! -f ".env" ]; then
    echo "📝 Creating .env file from template..."
    cp .env.example .env
    echo "⚠️  Please edit .env file with your configuration!"
fi

# Make scripts executable
echo "🔧 Making scripts executable..."
chmod +x scripts/*.sh

# Create initial configuration files
echo "⚙️  Creating configuration files..."

# Nginx configuration
if [ ! -f "configs/nginx/nginx.conf" ]; then
    cat > configs/nginx/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream api_gateway {
        server api-gateway:3000;
    }

    server {
        listen 80;
        server_name localhost;

        location / {
            proxy_pass http://api_gateway;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
}
EOF
fi

# PostgreSQL configuration
if [ ! -f "configs/postgres/postgresql.conf" ]; then
    cat > configs/postgres/postgresql.conf << 'EOF'
# Basic settings
max_connections = 100
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 4MB
maintenance_work_mem = 64MB

# Logging
log_statement = 'all'
log_duration = on
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '

# Performance
checkpoint_completion_target = 0.9
random_page_cost = 1.1
EOF
fi

# Redis configuration
if [ ! -f "configs/redis/redis.conf" ]; then
    cat > configs/redis/redis.conf << 'EOF'
# Basic configuration
save 900 1
save 300 10
save 60 10000

# Memory management
maxmemory 256mb
maxmemory-policy allkeys-lru

# Logging
loglevel notice
logfile ""

# Security
protected-mode yes
EOF
fi

echo "✅ HMT Deployment Environment initialized successfully!"
echo ""
echo "Next steps:"
echo "1. Edit .env file with your configuration"
echo "2. Add your service repositories as submodules"
echo "3. Run './scripts/dev-start.sh' for development or './scripts/prod-start.sh' for production"
echo ""
echo "For help, see README.md or run './scripts/help.sh'"
