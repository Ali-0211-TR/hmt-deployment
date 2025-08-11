# HMT Security Guide

## Security Overview

This document outlines security measures, best practices, and configurations for the HMT deployment infrastructure.

## Network Security

### 1. Docker Network Isolation

**Default Configuration**
```yaml
networks:
  hmt-network:
    driver: bridge
    internal: false  # Allow external access
```

**Production Configuration**
```yaml
networks:
  hmt-internal:
    driver: bridge
    internal: true   # Internal services only
  hmt-external:
    driver: bridge
    internal: false  # External access for API Gateway
```

### 2. Firewall Configuration

**Ubuntu/Debian (ufw)**
```bash
# Enable firewall
sudo ufw enable

# Allow SSH
sudo ufw allow 22/tcp

# Allow HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Deny other ports (services should be internal only)
sudo ufw deny 5432/tcp  # PostgreSQL
sudo ufw deny 6379/tcp  # Redis
sudo ufw deny 5000/tcp  # gRPC (internal only)

# Check status
sudo ufw status verbose
```

**iptables Rules**
```bash
# Block direct access to internal services
iptables -A INPUT -p tcp --dport 5432 -s 172.16.0.0/12 -j ACCEPT
iptables -A INPUT -p tcp --dport 5432 -j DROP
iptables -A INPUT -p tcp --dport 6379 -s 172.16.0.0/12 -j ACCEPT
iptables -A INPUT -p tcp --dport 6379 -j DROP
```

### 3. Reverse Proxy Security

**Nginx Security Headers**
```nginx
# Security headers
add_header X-Frame-Options "DENY" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline';" always;

# Hide server information
server_tokens off;
```

**Rate Limiting**
```nginx
# Rate limiting zones
limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;
limit_req_zone $binary_remote_addr zone=api:10m rate=100r/m;
limit_req_zone $binary_remote_addr zone=upload:10m rate=10r/m;

# Apply rate limiting
location /auth/login {
    limit_req zone=login burst=3 nodelay;
}

location /api/ {
    limit_req zone=api burst=20 nodelay;
}
```

## Application Security

### 1. Authentication & Authorization

**JWT Configuration**
```typescript
// JWT Secret (256-bit minimum)
JWT_SECRET=your-256-bit-secret-here-change-in-production

// Token expiration
JWT_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=7d

// JWT Strategy
@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor() {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: process.env.JWT_SECRET,
    });
  }
}
```

**Password Hashing**
```typescript
import * as bcrypt from 'bcrypt';

// Hash password with salt rounds
const saltRounds = 12;
const hashedPassword = await bcrypt.hash(password, saltRounds);

// Verify password
const isValid = await bcrypt.compare(password, hashedPassword);
```

### 2. Input Validation

**DTO Validation**
```typescript
import { IsEmail, IsString, MinLength, MaxLength } from 'class-validator';

export class CreateUserDto {
  @IsEmail()
  email: string;

  @IsString()
  @MinLength(8)
  @MaxLength(128)
  password: string;

  @IsString()
  @MaxLength(100)
  name: string;
}
```

**Sanitization**
```typescript
import { Transform } from 'class-transformer';
import * as sanitizeHtml from 'sanitize-html';

export class CreatePostDto {
  @Transform(({ value }) => sanitizeHtml(value))
  content: string;
}
```

### 3. CORS Configuration

```typescript
// Strict CORS policy
app.enableCors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true,
});
```

### 4. API Security

**Request Size Limits**
```typescript
// Limit request size
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ limit: '10mb', extended: true }));
```

**File Upload Security**
```typescript
import * as multer from 'multer';

const upload = multer({
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB
  },
  fileFilter: (req, file, cb) => {
    // Allowed file types
    const allowedTypes = /jpeg|jpg|png|pdf|doc|docx/;
    const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
    const mimetype = allowedTypes.test(file.mimetype);

    if (mimetype && extname) {
      return cb(null, true);
    } else {
      cb(new Error('Invalid file type'));
    }
  },
});
```

## Database Security

### 1. PostgreSQL Security

**User Management**
```sql
-- Create application user with limited privileges
CREATE USER hmt_app WITH PASSWORD 'secure_password';

-- Grant only necessary privileges
GRANT CONNECT ON DATABASE hmt_db TO hmt_app;
GRANT USAGE ON SCHEMA public TO hmt_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO hmt_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO hmt_app;

-- Remove default privileges
REVOKE ALL ON DATABASE hmt_db FROM PUBLIC;
```

**Connection Security**
```bash
# PostgreSQL configuration (postgresql.conf)
ssl = on
ssl_cert_file = 'server.crt'
ssl_key_file = 'server.key'
ssl_ca_file = 'ca.crt'

# Require SSL connections
ssl_prefer = on
ssl_ciphers = 'HIGH:MEDIUM:+3DES:!aNULL'
```

**Audit Logging**
```sql
-- Enable audit logging
ALTER SYSTEM SET log_statement = 'all';
ALTER SYSTEM SET log_connections = on;
ALTER SYSTEM SET log_disconnections = on;
ALTER SYSTEM SET log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h ';
SELECT pg_reload_conf();
```

### 2. Redis Security

**Authentication**
```bash
# redis.conf
requirepass your_redis_password_here
rename-command FLUSHDB ""
rename-command FLUSHALL ""
rename-command KEYS ""
```

**Network Binding**
```bash
# Bind to specific interfaces only
bind 127.0.0.1 172.16.0.0/12

# Disable protected mode if using Docker networks
protected-mode no
```

## Container Security

### 1. Image Security

**Non-root User**
```dockerfile
# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nestjs -u 1001

# Switch to non-root user
USER nestjs
```

**Minimal Images**
```dockerfile
# Use Alpine Linux for smaller attack surface
FROM node:18-alpine

# Install only necessary packages
RUN apk add --no-cache \
    bash \
    curl \
    netcat-openbsd
```

**Security Scanning**
```yaml
# GitHub Actions security scan
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest
    format: 'sarif'
    output: 'trivy-results.sarif'
```

### 2. Runtime Security

**Read-only Root Filesystem**
```yaml
services:
  api-gateway:
    read_only: true
    tmpfs:
      - /tmp
      - /var/log
```

**Resource Limits**
```yaml
services:
  api-gateway:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 2G
        reservations:
          cpus: '0.5'
          memory: 512M
```

**Security Options**
```yaml
services:
  api-gateway:
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
```

## Environment Security

### 1. Secret Management

**Environment Variables**
```bash
# Use strong, unique passwords
POSTGRES_PASSWORD=$(openssl rand -base64 32)
REDIS_PASSWORD=$(openssl rand -base64 32)
JWT_SECRET=$(openssl rand -base64 32)

# Never commit secrets to git
echo ".env*" >> .gitignore
echo "!.env.example" >> .gitignore
```

**Docker Secrets (Production)**
```yaml
secrets:
  postgres_password:
    external: true
  redis_password:
    external: true
  jwt_secret:
    external: true

services:
  api-gateway:
    secrets:
      - jwt_secret
    environment:
      JWT_SECRET_FILE: /run/secrets/jwt_secret
```

### 2. SSL/TLS Configuration

**Certificate Generation**
```bash
# Generate strong SSL certificate
openssl req -x509 -newkey rsa:4096 -sha256 -days 365 -nodes \
  -keyout ssl/key.pem -out ssl/cert.pem \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=yourdomain.com"

# Set proper permissions
chmod 600 ssl/key.pem
chmod 644 ssl/cert.pem
```

**Nginx SSL Configuration**
```nginx
# SSL protocols and ciphers
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384;
ssl_prefer_server_ciphers off;

# SSL session settings
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 10m;

# HSTS
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

# OCSP stapling
ssl_stapling on;
ssl_stapling_verify on;
```

## Monitoring & Logging

### 1. Security Monitoring

**Log Aggregation**
```yaml
services:
  api-gateway:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        labels: "service=api-gateway"
```

**Intrusion Detection**
```bash
# Install fail2ban
sudo apt install fail2ban

# Configure fail2ban for Nginx
cat > /etc/fail2ban/jail.local << EOF
[nginx-http-auth]
enabled = true
filter = nginx-http-auth
logpath = /var/log/nginx/error.log
maxretry = 3
bantime = 3600

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
logpath = /var/log/nginx/error.log
maxretry = 10
bantime = 600
EOF
```

### 2. Audit Logging

**Application Audit**
```typescript
// Audit middleware
@Injectable()
export class AuditMiddleware implements NestMiddleware {
  use(req: Request, res: Response, next: NextFunction) {
    const auditLog = {
      timestamp: new Date(),
      method: req.method,
      url: req.url,
      ip: req.ip,
      userAgent: req.get('User-Agent'),
      userId: req.user?.id,
    };
    
    console.log('AUDIT:', JSON.stringify(auditLog));
    next();
  }
}
```

**Database Audit**
```sql
-- Create audit table
CREATE TABLE audit_log (
  id SERIAL PRIMARY KEY,
  table_name VARCHAR(255),
  operation VARCHAR(10),
  old_values JSONB,
  new_values JSONB,
  user_id INTEGER,
  timestamp TIMESTAMP DEFAULT NOW()
);

-- Create audit trigger function
CREATE OR REPLACE FUNCTION audit_trigger_function()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO audit_log (table_name, operation, new_values, user_id)
    VALUES (TG_TABLE_NAME, TG_OP, to_jsonb(NEW), NEW.created_by);
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO audit_log (table_name, operation, old_values, new_values, user_id)
    VALUES (TG_TABLE_NAME, TG_OP, to_jsonb(OLD), to_jsonb(NEW), NEW.updated_by);
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO audit_log (table_name, operation, old_values, user_id)
    VALUES (TG_TABLE_NAME, TG_OP, to_jsonb(OLD), OLD.created_by);
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;
```

## Incident Response

### 1. Security Incident Procedures

**Immediate Response**
```bash
# Stop affected services
docker-compose stop <affected-service>

# Isolate network
docker network disconnect hmt-network <container>

# Create forensic backup
./scripts/backup.sh --forensic

# Collect logs
./scripts/logs.sh > incident-logs.txt
```

**Investigation Steps**
1. Preserve evidence
2. Analyze logs for indicators of compromise
3. Check for unauthorized access
4. Verify data integrity
5. Document findings

### 2. Recovery Procedures

**Clean Recovery**
```bash
# Stop all services
docker-compose down

# Remove potentially compromised data
docker volume rm hmt_app_data

# Restore from clean backup
./scripts/restore.sh --restore-path backup/clean-backup

# Update all secrets
# Update all passwords
# Regenerate JWT secrets
# Rotate SSL certificates

# Start services
./scripts/prod-start.sh
```

## Compliance

### 1. Data Protection

**GDPR Compliance**
- Data encryption at rest and in transit
- Right to be forgotten implementation
- Data processing audit trails
- Privacy by design principles

**Data Retention**
```sql
-- Implement data retention policy
DELETE FROM audit_log WHERE timestamp < NOW() - INTERVAL '2 years';
DELETE FROM user_sessions WHERE expires_at < NOW();
```

### 2. Security Standards

**SOC 2 Compliance**
- Access controls
- System monitoring
- Data backup and recovery
- Incident response procedures

**ISO 27001 Compliance**
- Information security management
- Risk assessment procedures
- Security awareness training
- Regular security audits

## Security Checklist

### Pre-deployment
- [ ] Change default passwords
- [ ] Generate strong JWT secrets
- [ ] Configure SSL certificates
- [ ] Set up firewall rules
- [ ] Enable audit logging
- [ ] Configure rate limiting
- [ ] Scan for vulnerabilities

### Post-deployment
- [ ] Monitor security logs
- [ ] Regular security updates
- [ ] Backup verification
- [ ] Access review
- [ ] Penetration testing
- [ ] Security training
- [ ] Incident response testing

### Regular Maintenance
- [ ] Update dependencies
- [ ] Rotate secrets
- [ ] Review access logs
- [ ] Security assessment
- [ ] Backup testing
- [ ] Documentation updates
- [ ] Team security training
