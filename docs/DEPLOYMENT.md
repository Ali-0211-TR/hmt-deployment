# HMT Deployment Guide

## Prerequisites

### System Requirements
- **OS**: Linux (Ubuntu 20.04+ recommended)
- **Docker**: 20.10+
- **Docker Compose**: 2.0+
- **Memory**: 4GB+ RAM
- **Storage**: 50GB+ free space
- **Network**: Internet access for dependencies

### Development Requirements
- **Node.js**: 18.x
- **npm**: 8.x+
- **Git**: 2.x
- **SSH**: For server access

## Quick Start

### 1. Repository Setup

```bash
# Clone the deployment repository
git clone --recursive https://github.com/your-org/hmt-deployment.git
cd hmt-deployment

# Initialize the environment
./scripts/init.sh

# Configure environment
cp .env.example .env
# Edit .env with your settings
```

### 2. Add Service Submodules

```bash
# Add API Gateway submodule
git submodule add https://github.com/your-org/hmt-apigateway.git services/hmt-apigateway

# Add Email Service submodule
git submodule add https://github.com/your-org/hmt-email-service.git services/hmt-email-service

# Initialize submodules
git submodule update --init --recursive
```

### 3. Development Environment

```bash
# Start development environment
./scripts/dev-start.sh

# Check service health
./scripts/health-check.sh dev

# View logs
./scripts/logs.sh --dev
```

### 4. Production Environment

```bash
# Configure production settings
cp .env.example .env.production
# Edit .env.production with production settings

# Start production environment
./scripts/prod-start.sh

# Monitor services
./scripts/monitor.sh
```

## Environment Configuration

### Required Environment Variables

```env
# Database Configuration
DATABASE_URL=postgresql://user:password@postgres:5432/hmt_db
POSTGRES_DB=hmt_db
POSTGRES_USER=postgres
POSTGRES_PASSWORD=secure_password_here

# Redis Configuration
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=secure_redis_password

# API Gateway Configuration
API_GATEWAY_HOST=0.0.0.0
API_GATEWAY_PORT=3000
API_GATEWAY_JWT_SECRET=your_jwt_secret_256_bits_long

# Email Service Configuration
EMAIL_SERVICE_HOST=0.0.0.0
EMAIL_SERVICE_GRPC_PORT=5000

# SMTP Configuration
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=your_email@gmail.com
SMTP_PASSWORD=your_app_password
SMTP_FROM="HMT System <noreply@hmt.com>"

# Environment
NODE_ENV=production
LOG_LEVEL=info

# SSL Configuration (Production only)
SSL_ENABLED=true
SSL_CERT_PATH=./ssl/cert.pem
SSL_KEY_PATH=./ssl/key.pem
```

### Optional Configuration

```env
# Monitoring
ENABLE_METRICS=true
ENABLE_HEALTH_CHECKS=true
GRAFANA_PASSWORD=admin

# Backup
BACKUP_ENABLED=true
BACKUP_SCHEDULE="0 2 * * *"
BACKUP_RETENTION_DAYS=30
BACKUP_UPLOAD_CMD="aws s3 sync"

# Docker
COMPOSE_PROJECT_NAME=hmt
DOCKER_BUILDKIT=1
```

## Deployment Strategies

### 1. Single Server Deployment

For small to medium workloads:

```bash
# On your server
cd /opt
sudo git clone --recursive https://github.com/your-org/hmt-deployment.git
cd hmt-deployment
sudo ./scripts/init.sh
sudo ./scripts/prod-start.sh
```

### 2. Multi-Server Deployment

For high availability:

#### Load Balancer Server
```bash
# Install and configure Nginx
sudo apt update && sudo apt install nginx
# Copy nginx configuration from configs/nginx/
```

#### Application Servers
```bash
# Deploy on multiple servers
# Use external PostgreSQL and Redis
# Configure load balancing
```

#### Database Server
```bash
# Dedicated PostgreSQL server
# Configure replication
# Set up Redis cluster
```

### 3. Container Orchestration

#### Docker Swarm
```bash
# Initialize swarm
docker swarm init

# Deploy stack
docker stack deploy -c docker-compose.yml hmt
```

#### Kubernetes
```yaml
# Use provided Kubernetes manifests
kubectl apply -f k8s/
```

## SSL/TLS Configuration

### 1. Generate SSL Certificates

#### Self-signed (Development)
```bash
mkdir -p ssl
openssl req -x509 -newkey rsa:4096 -keyout ssl/key.pem -out ssl/cert.pem -days 365 -nodes
```

#### Let's Encrypt (Production)
```bash
# Install certbot
sudo apt install certbot python3-certbot-nginx

# Generate certificate
sudo certbot --nginx -d your-domain.com

# Copy certificates
sudo cp /etc/letsencrypt/live/your-domain.com/fullchain.pem ssl/cert.pem
sudo cp /etc/letsencrypt/live/your-domain.com/privkey.pem ssl/key.pem
```

### 2. Configure Nginx

```nginx
server {
    listen 443 ssl http2;
    server_name your-domain.com;

    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;

    location / {
        proxy_pass http://api-gateway:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## Database Setup

### 1. Initial Setup

```bash
# Create database and user
docker-compose exec postgres psql -U postgres << EOF
CREATE DATABASE hmt_db;
CREATE USER hmt_user WITH PASSWORD 'secure_password';
GRANT ALL PRIVILEGES ON DATABASE hmt_db TO hmt_user;
EOF
```

### 2. Run Migrations

```bash
# API Gateway migrations
docker-compose exec api-gateway npx prisma migrate deploy

# Email Service migrations
docker-compose exec email-service npx prisma migrate deploy
```

### 3. Seed Data

```bash
# Seed initial data
docker-compose exec api-gateway npx prisma db seed
docker-compose exec email-service npx prisma db seed
```

## Monitoring Setup

### 1. Enable Monitoring Stack

```bash
# Start with monitoring profile
docker-compose --profile monitoring up -d
```

### 2. Access Monitoring

- **Grafana**: http://localhost:3001 (admin/admin)
- **Prometheus**: http://localhost:9090

### 3. Configure Alerts

```yaml
# prometheus/rules/alerts.yml
groups:
  - name: hmt.rules
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: High error rate detected
```

## Backup and Restore

### 1. Manual Backup

```bash
# Create backup
./scripts/backup.sh

# List backups
ls -la backup/

# Restore from specific backup
./scripts/restore.sh --restore-path backup/backup_20240101_120000
```

### 2. Automated Backup

```bash
# Configure cron job
crontab -e

# Add backup schedule
0 2 * * * cd /opt/hmt-deployment && ./scripts/backup.sh
```

### 3. Cloud Backup

```bash
# Configure cloud upload
export BACKUP_UPLOAD_CMD="aws s3 sync backup/ s3://your-backup-bucket/"

# Run backup with upload
./scripts/backup.sh
```

## Troubleshooting

### Common Issues

#### Services Not Starting
```bash
# Check logs
./scripts/logs.sh -s api-gateway

# Check ports
netstat -tlnp | grep :3000

# Check Docker resources
docker system df
docker system prune
```

#### Database Connection Issues
```bash
# Test database connection
docker-compose exec postgres pg_isready

# Check credentials
docker-compose exec postgres psql -U postgres -c "\l"

# Reset database
docker-compose down
docker volume rm hmt_postgres_data
docker-compose up -d postgres
```

#### Performance Issues
```bash
# Monitor resources
./scripts/monitor.sh

# Check container stats
docker stats

# Optimize database
docker-compose exec postgres psql -U postgres -c "ANALYZE;"
```

### Log Analysis

```bash
# View all logs
./scripts/logs.sh

# Filter by service
./scripts/logs.sh -s email-service

# Follow logs in real-time
./scripts/logs.sh -f

# Search logs
./scripts/logs.sh | grep "ERROR"
```

## Security Best Practices

### 1. Environment Security
- Use strong passwords
- Rotate secrets regularly
- Limit network access
- Enable firewall rules

### 2. Application Security
- Keep dependencies updated
- Run security scans
- Monitor for vulnerabilities
- Implement proper validation

### 3. Infrastructure Security
- Regular system updates
- Monitor access logs
- Use fail2ban for SSH
- Implement intrusion detection

## Performance Optimization

### 1. Database Optimization
```sql
-- Create indexes
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_emails_status ON emails(status);

-- Analyze query performance
EXPLAIN ANALYZE SELECT * FROM users WHERE email = 'user@example.com';
```

### 2. Redis Optimization
```bash
# Configure memory settings
redis-cli CONFIG SET maxmemory 256mb
redis-cli CONFIG SET maxmemory-policy allkeys-lru
```

### 3. Application Optimization
- Enable gzip compression
- Use connection pooling
- Implement caching strategies
- Optimize Docker images

## Scaling Guidelines

### Vertical Scaling
```yaml
# Increase container resources
services:
  api-gateway:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 2G
```

### Horizontal Scaling
```yaml
# Scale services
services:
  api-gateway:
    deploy:
      replicas: 3
```

### Load Balancing
```nginx
upstream api_backend {
    server api-gateway-1:3000;
    server api-gateway-2:3000;
    server api-gateway-3:3000;
}
```
