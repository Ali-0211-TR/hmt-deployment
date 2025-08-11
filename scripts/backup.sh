#!/bin/bash

# Backup Script for HMT Services
set -e

# Default parameters
BACKUP_DIR="./backup"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
COMPOSE_FILE="docker-compose.yml"
KEEP_DAYS=30

# Load environment variables
if [ -f ".env" ]; then
    source .env
fi

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dev)
            COMPOSE_FILE="docker-compose.dev.yml"
            shift
            ;;
        --dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        --keep-days)
            KEEP_DAYS="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --dev                    Use development compose file"
            echo "  --dir DIR                Backup directory (default: ./backup)"
            echo "  --keep-days DAYS         Keep backups for N days (default: 30)"
            echo "  -h, --help               Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "💾 Starting HMT Backup Process..."

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Create timestamped backup subdirectory
BACKUP_PATH="$BACKUP_DIR/backup_$TIMESTAMP"
mkdir -p "$BACKUP_PATH"

echo "📁 Backup directory: $BACKUP_PATH"

# Function to backup PostgreSQL
backup_postgres() {
    echo "🗄️  Backing up PostgreSQL database..."
    
    local db_name=${POSTGRES_DB:-hmt_db}
    local db_user=${POSTGRES_USER:-postgres}
    
    # Create database dump
    docker-compose -f $COMPOSE_FILE exec -T postgres pg_dump \
        -U "$db_user" \
        -d "$db_name" \
        --clean \
        --if-exists \
        --create \
        --verbose \
        > "$BACKUP_PATH/postgres_backup.sql"
    
    # Compress the dump
    gzip "$BACKUP_PATH/postgres_backup.sql"
    
    echo "✅ PostgreSQL backup completed: postgres_backup.sql.gz"
}

# Function to backup Redis
backup_redis() {
    echo "🔴 Backing up Redis data..."
    
    # Create Redis backup
    docker-compose -f $COMPOSE_FILE exec -T redis redis-cli BGSAVE
    
    # Wait for background save to complete
    sleep 5
    
    # Copy the dump file
    docker-compose -f $COMPOSE_FILE exec -T redis cat /data/dump.rdb > "$BACKUP_PATH/redis_backup.rdb"
    
    # Compress the dump
    gzip "$BACKUP_PATH/redis_backup.rdb"
    
    echo "✅ Redis backup completed: redis_backup.rdb.gz"
}

# Function to backup application data
backup_app_data() {
    echo "📦 Backing up application data..."
    
    # Backup uploads directory
    if [ -d "uploads" ]; then
        tar -czf "$BACKUP_PATH/uploads_backup.tar.gz" uploads/
        echo "✅ Uploads backup completed: uploads_backup.tar.gz"
    fi
    
    # Backup logs
    if [ -d "logs" ]; then
        tar -czf "$BACKUP_PATH/logs_backup.tar.gz" logs/
        echo "✅ Logs backup completed: logs_backup.tar.gz"
    fi
    
    # Backup SSL certificates
    if [ -d "ssl" ]; then
        tar -czf "$BACKUP_PATH/ssl_backup.tar.gz" ssl/
        echo "✅ SSL backup completed: ssl_backup.tar.gz"
    fi
}

# Function to backup configuration
backup_config() {
    echo "⚙️  Backing up configuration..."
    
    # Backup environment files
    cp .env "$BACKUP_PATH/" 2>/dev/null || echo "⚠️  .env file not found"
    cp .env.example "$BACKUP_PATH/" 2>/dev/null || true
    
    # Backup docker-compose files
    cp docker-compose*.yml "$BACKUP_PATH/" 2>/dev/null || true
    
    # Backup configuration directory
    if [ -d "configs" ]; then
        tar -czf "$BACKUP_PATH/configs_backup.tar.gz" configs/
        echo "✅ Configuration backup completed: configs_backup.tar.gz"
    fi
}

# Function to create backup metadata
create_metadata() {
    echo "📝 Creating backup metadata..."
    
    cat > "$BACKUP_PATH/backup_info.txt" << EOF
HMT Backup Information
======================
Timestamp: $TIMESTAMP
Date: $(date)
Compose File: $COMPOSE_FILE
Environment: ${NODE_ENV:-unknown}

Services Status:
$(docker-compose -f $COMPOSE_FILE ps)

Git Information:
Repository: $(git remote get-url origin 2>/dev/null || echo "N/A")
Branch: $(git branch --show-current 2>/dev/null || echo "N/A")
Commit: $(git rev-parse HEAD 2>/dev/null || echo "N/A")

Submodules:
$(git submodule status 2>/dev/null || echo "N/A")

System Information:
Hostname: $(hostname)
User: $(whoami)
Docker Version: $(docker --version)
EOF
    
    echo "✅ Backup metadata created: backup_info.txt"
}

# Function to cleanup old backups
cleanup_old_backups() {
    echo "🧹 Cleaning up old backups (older than $KEEP_DAYS days)..."
    
    find "$BACKUP_DIR" -type d -name "backup_*" -mtime +$KEEP_DAYS -exec rm -rf {} \; 2>/dev/null || true
    
    local remaining_backups=$(find "$BACKUP_DIR" -type d -name "backup_*" | wc -l)
    echo "📊 Remaining backups: $remaining_backups"
}

# Check if services are running
if ! docker-compose -f $COMPOSE_FILE ps | grep -q "Up"; then
    echo "⚠️  No running services found. Creating configuration-only backup..."
    backup_config
    create_metadata
    cleanup_old_backups
    echo "✅ Configuration backup completed!"
    exit 0
fi

# Perform backup operations
backup_postgres
backup_redis
backup_app_data
backup_config
create_metadata

# Calculate backup size
BACKUP_SIZE=$(du -sh "$BACKUP_PATH" | cut -f1)
echo "📊 Backup size: $BACKUP_SIZE"

# Cleanup old backups
cleanup_old_backups

echo "✅ Backup completed successfully!"
echo "📁 Backup location: $BACKUP_PATH"
echo ""
echo "📋 Backup contents:"
ls -la "$BACKUP_PATH"

# Optional: Upload to cloud storage
if [ -n "${BACKUP_UPLOAD_CMD:-}" ]; then
    echo "☁️  Uploading backup to cloud storage..."
    eval "$BACKUP_UPLOAD_CMD $BACKUP_PATH"
fi
