#!/bin/bash

# Restore Script for HMT Services
set -e

# Default parameters
BACKUP_DIR="./backup"
COMPOSE_FILE="docker-compose.yml"
RESTORE_PATH=""

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
        --backup-dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        --restore-path)
            RESTORE_PATH="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --dev                    Use development compose file"
            echo "  --backup-dir DIR         Backup directory (default: ./backup)"
            echo "  --restore-path PATH      Specific backup to restore"
            echo "  -h, --help               Show this help"
            echo ""
            echo "If --restore-path is not specified, the latest backup will be used."
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "🔄 Starting HMT Restore Process..."

# Find backup to restore
if [ -z "$RESTORE_PATH" ]; then
    # Find the latest backup
    RESTORE_PATH=$(find "$BACKUP_DIR" -type d -name "backup_*" | sort -r | head -n1)
    
    if [ -z "$RESTORE_PATH" ]; then
        echo "❌ No backups found in $BACKUP_DIR"
        exit 1
    fi
    
    echo "📁 Using latest backup: $(basename $RESTORE_PATH)"
else
    if [ ! -d "$RESTORE_PATH" ]; then
        echo "❌ Backup path not found: $RESTORE_PATH"
        exit 1
    fi
fi

echo "📁 Restore path: $RESTORE_PATH"

# Display backup information
if [ -f "$RESTORE_PATH/backup_info.txt" ]; then
    echo "📋 Backup Information:"
    cat "$RESTORE_PATH/backup_info.txt"
    echo ""
fi

# Confirmation prompt
read -p "⚠️  This will replace current data. Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Restore cancelled"
    exit 1
fi

# Create current backup before restore
echo "💾 Creating backup before restore..."
./scripts/backup.sh

# Function to restore PostgreSQL
restore_postgres() {
    echo "🗄️  Restoring PostgreSQL database..."
    
    local backup_file="$RESTORE_PATH/postgres_backup.sql.gz"
    
    if [ ! -f "$backup_file" ]; then
        echo "⚠️  PostgreSQL backup file not found: $backup_file"
        return 1
    fi
    
    # Stop services that depend on database
    echo "🛑 Stopping dependent services..."
    docker-compose -f $COMPOSE_FILE stop api-gateway email-service
    
    # Restore database
    echo "📥 Restoring database..."
    gunzip -c "$backup_file" | docker-compose -f $COMPOSE_FILE exec -T postgres psql -U "${POSTGRES_USER:-postgres}"
    
    echo "✅ PostgreSQL restore completed"
}

# Function to restore Redis
restore_redis() {
    echo "🔴 Restoring Redis data..."
    
    local backup_file="$RESTORE_PATH/redis_backup.rdb.gz"
    
    if [ ! -f "$backup_file" ]; then
        echo "⚠️  Redis backup file not found: $backup_file"
        return 1
    fi
    
    # Stop Redis
    echo "🛑 Stopping Redis..."
    docker-compose -f $COMPOSE_FILE stop redis
    
    # Restore Redis data
    echo "📥 Restoring Redis data..."
    gunzip -c "$backup_file" > /tmp/redis_restore.rdb
    docker-compose -f $COMPOSE_FILE run --rm -v /tmp/redis_restore.rdb:/data/dump.rdb redis redis-server --save "" --appendonly no
    
    # Start Redis
    echo "▶️  Starting Redis..."
    docker-compose -f $COMPOSE_FILE start redis
    
    # Cleanup
    rm -f /tmp/redis_restore.rdb
    
    echo "✅ Redis restore completed"
}

# Function to restore application data
restore_app_data() {
    echo "📦 Restoring application data..."
    
    # Restore uploads
    local uploads_backup="$RESTORE_PATH/uploads_backup.tar.gz"
    if [ -f "$uploads_backup" ]; then
        echo "📁 Restoring uploads..."
        rm -rf uploads/
        tar -xzf "$uploads_backup"
        echo "✅ Uploads restored"
    fi
    
    # Restore logs
    local logs_backup="$RESTORE_PATH/logs_backup.tar.gz"
    if [ -f "$logs_backup" ]; then
        echo "📄 Restoring logs..."
        rm -rf logs/
        tar -xzf "$logs_backup"
        echo "✅ Logs restored"
    fi
    
    # Restore SSL certificates
    local ssl_backup="$RESTORE_PATH/ssl_backup.tar.gz"
    if [ -f "$ssl_backup" ]; then
        echo "🔒 Restoring SSL certificates..."
        rm -rf ssl/
        tar -xzf "$ssl_backup"
        echo "✅ SSL certificates restored"
    fi
}

# Function to restore configuration
restore_config() {
    echo "⚙️  Restoring configuration..."
    
    # Restore configuration directory
    local configs_backup="$RESTORE_PATH/configs_backup.tar.gz"
    if [ -f "$configs_backup" ]; then
        echo "📋 Restoring configuration files..."
        rm -rf configs/
        tar -xzf "$configs_backup"
        echo "✅ Configuration files restored"
    fi
    
    # Note: We don't restore .env files automatically for security reasons
    if [ -f "$RESTORE_PATH/.env" ]; then
        echo "⚠️  Environment file found in backup but not restored automatically"
        echo "    Manual action required: cp $RESTORE_PATH/.env .env"
    fi
}

# Stop all services
echo "🛑 Stopping all services..."
docker-compose -f $COMPOSE_FILE down

# Perform restore operations
restore_postgres
restore_redis
restore_app_data
restore_config

# Start services
echo "▶️  Starting services..."
docker-compose -f $COMPOSE_FILE up -d

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 30

# Run health check
echo "🏥 Running health check..."
./scripts/health-check.sh

echo "✅ Restore completed successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Verify your application is working correctly"
echo "2. Check logs: ./scripts/logs.sh"
echo "3. Run any necessary migrations if needed"
echo ""
echo "⚠️  Remember to:"
echo "- Update environment variables if needed"
echo "- Regenerate SSL certificates if expired"
echo "- Update application secrets if compromised"
