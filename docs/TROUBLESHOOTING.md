# HMT Troubleshooting Guide

## Common Issues and Solutions

### 1. Services Won't Start

#### Symptom
```bash
docker-compose up
# Returns errors or containers exit immediately
```

#### Diagnostic Commands
```bash
# Check container status
docker-compose ps

# Check logs for specific service
./scripts/logs.sh -s api-gateway

# Check Docker resources
docker system df
docker system events --since 10m
```

#### Common Causes and Solutions

**Port Already in Use**
```bash
# Find what's using the port
sudo netstat -tlnp | grep :3000
sudo lsof -i :3000

# Kill the process or change port in .env
```

**Insufficient Resources**
```bash
# Check available resources
docker system df
free -h
df -h

# Clean up Docker
docker system prune -a
docker volume prune
```

**Environment Variables Missing**
```bash
# Check if .env file exists
ls -la .env

# Validate required variables
grep -E "POSTGRES_PASSWORD|JWT_SECRET|SMTP" .env
```

### 2. Database Connection Issues

#### Symptoms
- "Connection refused" errors
- Services can't connect to PostgreSQL
- Migration failures

#### Diagnostic Commands
```bash
# Test PostgreSQL connection
docker-compose exec postgres pg_isready
docker-compose exec postgres psql -U postgres -c "\l"

# Check database logs
./scripts/logs.sh -s postgres

# Verify network connectivity
docker network ls
docker network inspect hmt-deployment_hmt-network
```

#### Solutions

**Database Not Ready**
```bash
# Wait for database to be ready
docker-compose exec postgres pg_isready -U postgres

# Check initialization logs
./scripts/logs.sh -s postgres | grep "database system is ready"
```

**Wrong Credentials**
```bash
# Verify credentials in .env
grep DATABASE_URL .env
grep POSTGRES .env

# Test connection manually
docker-compose exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB
```

**Network Issues**
```bash
# Recreate network
docker-compose down
docker network prune
docker-compose up -d
```

### 3. Redis Connection Issues

#### Symptoms
- Queue jobs not processing
- Session storage failures
- Cache misses

#### Diagnostic Commands
```bash
# Test Redis connection
docker-compose exec redis redis-cli ping

# Check Redis info
docker-compose exec redis redis-cli info

# Monitor Redis commands
docker-compose exec redis redis-cli monitor
```

#### Solutions

**Redis Not Ready**
```bash
# Check Redis status
docker-compose exec redis redis-cli ping

# Restart Redis
docker-compose restart redis
```

**Memory Issues**
```bash
# Check Redis memory usage
docker-compose exec redis redis-cli info memory

# Clear Redis data if needed
docker-compose exec redis redis-cli flushall
```

### 4. Email Service Issues

#### Symptoms
- Emails not being sent
- gRPC connection failures
- Queue processing stopped

#### Diagnostic Commands
```bash
# Test gRPC port
nc -z localhost 5000

# Check email service logs
./scripts/logs.sh -s email-service

# Check queue status
docker-compose exec redis redis-cli llen email_queue
```

#### Solutions

**SMTP Configuration**
```bash
# Test SMTP settings
docker-compose exec email-service node -e "
const nodemailer = require('nodemailer');
const transport = nodemailer.createTransporter({
  host: process.env.SMTP_HOST,
  port: process.env.SMTP_PORT,
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASSWORD
  }
});
transport.verify().then(console.log).catch(console.error);
"
```

**gRPC Issues**
```bash
# Check if port is accessible
nc -z localhost 5000

# Test with grpcurl (if installed)
grpcurl -plaintext localhost:5000 list
```

### 5. Performance Issues

#### Symptoms
- Slow response times
- High memory usage
- CPU spikes

#### Diagnostic Commands
```bash
# Monitor resources
./scripts/monitor.sh

# Check container stats
docker stats

# Analyze slow queries
docker-compose exec postgres psql -U postgres -c "
SELECT query, mean_time, calls 
FROM pg_stat_statements 
ORDER BY mean_time DESC 
LIMIT 10;
"
```

#### Solutions

**Database Optimization**
```sql
-- Create indexes for frequently queried columns
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_emails_created_at ON emails(created_at);

-- Analyze tables
ANALYZE;

-- Check for missing indexes
SELECT schemaname, tablename, attname, n_distinct, correlation
FROM pg_stats
WHERE tablename = 'your_table';
```

**Memory Optimization**
```bash
# Increase container memory limits
# Edit docker-compose.yml
services:
  api-gateway:
    mem_limit: 2g
    mem_reservation: 1g
```

**Connection Pooling**
```javascript
// Optimize Prisma connection pooling
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
  connectionLimit = 20
}
```

### 6. SSL/TLS Issues

#### Symptoms
- HTTPS not working
- Certificate errors
- Mixed content warnings

#### Diagnostic Commands
```bash
# Check certificate validity
openssl x509 -in ssl/cert.pem -text -noout

# Test SSL connection
openssl s_client -connect localhost:443

# Check certificate expiry
openssl x509 -in ssl/cert.pem -noout -dates
```

#### Solutions

**Generate New Certificate**
```bash
# Self-signed certificate
openssl req -x509 -newkey rsa:4096 -keyout ssl/key.pem -out ssl/cert.pem -days 365 -nodes

# Let's Encrypt certificate
sudo certbot --nginx -d your-domain.com
```

**Fix Certificate Permissions**
```bash
sudo chown -R $USER:$USER ssl/
chmod 600 ssl/key.pem
chmod 644 ssl/cert.pem
```

### 7. Network Issues

#### Symptoms
- Services can't communicate
- External API calls failing
- DNS resolution issues

#### Diagnostic Commands
```bash
# Check Docker networks
docker network ls
docker network inspect hmt-deployment_hmt-network

# Test service connectivity
docker-compose exec api-gateway ping email-service
docker-compose exec api-gateway nslookup email-service
```

#### Solutions

**Recreate Network**
```bash
docker-compose down
docker network prune
docker-compose up -d
```

**DNS Issues**
```bash
# Add custom DNS
# Edit docker-compose.yml
services:
  api-gateway:
    dns:
      - 8.8.8.8
      - 8.8.4.4
```

### 8. File Permissions Issues

#### Symptoms
- Permission denied errors
- Can't write to mounted volumes
- Container user issues

#### Diagnostic Commands
```bash
# Check file permissions
ls -la
ls -la uploads/
ls -la logs/

# Check container user
docker-compose exec api-gateway id
```

#### Solutions

**Fix Permissions**
```bash
# Create directories with correct permissions
sudo mkdir -p uploads logs
sudo chown -R 1001:1001 uploads logs
sudo chmod -R 755 uploads logs
```

**User Mapping**
```yaml
# docker-compose.yml
services:
  api-gateway:
    user: "${UID:-1001}:${GID:-1001}"
```

### 9. Backup and Restore Issues

#### Symptoms
- Backup creation fails
- Restore process errors
- Data corruption

#### Diagnostic Commands
```bash
# Test backup creation
./scripts/backup.sh --dry-run

# Verify backup files
ls -la backup/
file backup/backup_*/postgres_backup.sql.gz
```

#### Solutions

**Backup Permissions**
```bash
# Ensure backup directory is writable
sudo mkdir -p backup
sudo chown -R $USER:$USER backup
chmod 755 backup
```

**Database Backup Issues**
```bash
# Manual database backup
docker-compose exec postgres pg_dump -U postgres -d hmt_db > manual_backup.sql

# Test restore
docker-compose exec postgres psql -U postgres -d hmt_db < manual_backup.sql
```

### 10. CI/CD Pipeline Issues

#### Symptoms
- Build failures
- Deployment errors
- Test failures

#### Diagnostic Commands
```bash
# Check GitHub Actions logs
# View logs in GitHub repository

# Test locally
npm test
npm run build
docker build -t test-image .
```

#### Solutions

**Build Issues**
```bash
# Clear build cache
docker builder prune

# Build without cache
docker-compose build --no-cache
```

**Secret Management**
```bash
# Verify GitHub secrets are set
# Check repository settings > Secrets and variables > Actions

# Test SSH connection
ssh -T git@github.com
```

## Emergency Procedures

### 1. Service Recovery

**Complete System Failure**
```bash
# Stop all services
docker-compose down

# Clean up
docker system prune -a

# Restore from backup
./scripts/restore.sh

# Start services
./scripts/prod-start.sh
```

**Database Corruption**
```bash
# Stop dependent services
docker-compose stop api-gateway email-service

# Restore database
./scripts/restore.sh --restore-path backup/latest

# Restart services
docker-compose start api-gateway email-service
```

### 2. Rollback Procedure

**Application Rollback**
```bash
# Find previous version
git log --oneline -10

# Checkout previous version
git checkout <previous-commit>
git submodule update --recursive

# Deploy
./scripts/prod-start.sh
```

**Database Rollback**
```bash
# Restore from specific backup
./scripts/restore.sh --restore-path backup/backup_20240101_120000
```

### 3. Data Recovery

**Lost Database Data**
```bash
# Check available backups
ls -la backup/

# Restore specific tables
docker-compose exec postgres pg_restore -U postgres -d hmt_db -t users backup.dump
```

## Prevention Best Practices

### 1. Monitoring
- Set up health checks
- Monitor resource usage
- Configure alerts
- Regular backup verification

### 2. Maintenance
- Regular dependency updates
- Security patches
- Performance optimization
- Capacity planning

### 3. Documentation
- Keep runbooks updated
- Document configuration changes
- Maintain troubleshooting logs
- Training for team members

## Getting Help

### 1. Log Analysis
```bash
# Collect all logs
./scripts/logs.sh > system.log

# Get system information
./scripts/monitor.sh --logs > monitoring.log

# Create support bundle
tar -czf support-bundle.tar.gz system.log monitoring.log .env docker-compose.yml
```

### 2. Community Support
- GitHub Issues
- Stack Overflow
- Docker Community
- NestJS Discord

### 3. Professional Support
- Cloud provider support
- Docker Enterprise support
- Third-party consultants
- Internal DevOps team
