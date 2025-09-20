#!/bin/bash

# Email Storage Backup Script
# Creates backups of email data and configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="$(dirname "$(dirname "$(readlink -f "$0")")")"
EMAIL_STORAGE_DIR="$PROJECT_ROOT/email-storage"
SUPABASE_DIR="$PROJECT_ROOT/../supabase"
BACKUP_DIR="$EMAIL_STORAGE_DIR/backups"
LOG_FILE="$EMAIL_STORAGE_DIR/logs/backup.log"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Get backup timestamp
get_backup_timestamp() {
    date +"%Y%m%d_%H%M%S"
}

# Create database backup
backup_database() {
    local timestamp=$(get_backup_timestamp)
    local backup_file="$BACKUP_DIR/email_database_$timestamp.sql"
    
    log "Creating database backup..."
    
    # Get database connection details
    local pg_password=$(grep POSTGRES_PASSWORD "$SUPABASE_DIR/.env" | cut -d'=' -f2)
    local pg_host="localhost"
    local pg_port="5432"
    local pg_user="postgres"
    local pg_database="postgres"
    
    if [ -z "$pg_password" ]; then
        error "POSTGRES_PASSWORD not found in Supabase .env file"
    fi
    
    # Create database backup
    PGPASSWORD="$pg_password" pg_dump \
        -h "$pg_host" \
        -p "$pg_port" \
        -U "$pg_user" \
        -d "$pg_database" \
        --schema-only \
        --no-owner \
        --no-privileges \
        -f "$backup_file"
    
    # Compress backup
    gzip "$backup_file"
    backup_file="$backup_file.gz"
    
    success "Database backup created: $backup_file"
    echo "$backup_file"
}

# Create email data backup
backup_email_data() {
    local timestamp=$(get_backup_timestamp)
    local backup_file="$BACKUP_DIR/email_data_$timestamp.json"
    
    log "Creating email data backup..."
    
    # Get Supabase configuration
    local supabase_url=$(grep SUPABASE_URL "$EMAIL_STORAGE_DIR/.env" | cut -d'=' -f2)
    local supabase_key=$(grep SUPABASE_SERVICE_ROLE_KEY "$EMAIL_STORAGE_DIR/.env" | cut -d'=' -f2)
    
    if [ -z "$supabase_url" ] || [ -z "$supabase_key" ]; then
        error "Supabase configuration not found in environment file"
    fi
    
    # Export email data using Node.js script
    node -e "
        const { createClient } = require('@supabase/supabase-js');
        const fs = require('fs');
        
        const supabase = createClient('$supabase_url', '$supabase_key');
        
        async function exportData() {
            try {
                // Export emails
                const { data: emails, error: emailError } = await supabase
                    .from('emails')
                    .select('*')
                    .order('date_received', { ascending: false });
                
                if (emailError) throw emailError;
                
                // Export mailboxes
                const { data: mailboxes, error: mailboxError } = await supabase
                    .from('mailboxes')
                    .select('*');
                
                if (mailboxError) throw mailboxError;
                
                // Export threads
                const { data: threads, error: threadError } = await supabase
                    .from('email_threads')
                    .select('*');
                
                if (threadError) throw threadError;
                
                // Export sync state
                const { data: syncState, error: syncError } = await supabase
                    .from('sync_state')
                    .select('*');
                
                if (syncError) throw syncError;
                
                // Combine all data
                const backupData = {
                    timestamp: new Date().toISOString(),
                    emails: emails,
                    mailboxes: mailboxes,
                    threads: threads,
                    syncState: syncState,
                    metadata: {
                        totalEmails: emails.length,
                        totalMailboxes: mailboxes.length,
                        totalThreads: threads.length,
                        totalSyncStates: syncState.length
                    }
                };
                
                fs.writeFileSync('$backup_file', JSON.stringify(backupData, null, 2));
                console.log('Email data backup created successfully');
                
            } catch (error) {
                console.error('Email data backup failed:', error.message);
                process.exit(1);
            }
        }
        
        exportData();
    "
    
    # Compress backup
    gzip "$backup_file"
    backup_file="$backup_file.gz"
    
    success "Email data backup created: $backup_file"
    echo "$backup_file"
}

# Create configuration backup
backup_configuration() {
    local timestamp=$(get_backup_timestamp)
    local backup_file="$BACKUP_DIR/email_config_$timestamp.tar.gz"
    
    log "Creating configuration backup..."
    
    # Create temporary directory for config files
    local temp_dir=$(mktemp -d)
    
    # Copy configuration files
    cp "$EMAIL_STORAGE_DIR/.env" "$temp_dir/" 2>/dev/null || true
    cp "$EMAIL_STORAGE_DIR/docker-compose.yml" "$temp_dir/"
    cp "$EMAIL_STORAGE_DIR/package.json" "$temp_dir/"
    cp -r "$EMAIL_STORAGE_DIR/migrations" "$temp_dir/" 2>/dev/null || true
    cp -r "$EMAIL_STORAGE_DIR/scripts" "$temp_dir/" 2>/dev/null || true
    
    # Create archive
    tar -czf "$backup_file" -C "$temp_dir" .
    
    # Clean up
    rm -rf "$temp_dir"
    
    success "Configuration backup created: $backup_file"
    echo "$backup_file"
}

# Create logs backup
backup_logs() {
    local timestamp=$(get_backup_timestamp)
    local backup_file="$BACKUP_DIR/email_logs_$timestamp.tar.gz"
    
    log "Creating logs backup..."
    
    if [ -d "$EMAIL_STORAGE_DIR/logs" ]; then
        tar -czf "$backup_file" -C "$EMAIL_STORAGE_DIR" logs/
        success "Logs backup created: $backup_file"
        echo "$backup_file"
    else
        warning "No logs directory found"
        echo ""
    fi
}

# Clean up old backups
cleanup_old_backups() {
    local days_to_keep=${1:-30}
    
    log "Cleaning up backups older than $days_to_keep days..."
    
    find "$BACKUP_DIR" -name "*.sql.gz" -mtime +$days_to_keep -delete
    find "$BACKUP_DIR" -name "*.json.gz" -mtime +$days_to_keep -delete
    find "$BACKUP_DIR" -name "*.tar.gz" -mtime +$days_to_keep -delete
    
    success "Old backups cleaned up"
}

# Verify backup integrity
verify_backup() {
    local backup_file="$1"
    
    if [ -z "$backup_file" ] || [ ! -f "$backup_file" ]; then
        return 1
    fi
    
    # Check if file is compressed
    if [[ "$backup_file" == *.gz ]]; then
        if gzip -t "$backup_file" 2>/dev/null; then
            return 0
        else
            return 1
        fi
    elif [[ "$backup_file" == *.tar.gz ]]; then
        if tar -tzf "$backup_file" >/dev/null 2>&1; then
            return 0
        else
            return 1
        fi
    else
        # For uncompressed files, just check if they exist and are readable
        [ -r "$backup_file" ]
    fi
}

# List available backups
list_backups() {
    log "Available backups:"
    
    if [ -d "$BACKUP_DIR" ]; then
        ls -lah "$BACKUP_DIR" | grep -E "\.(sql\.gz|json\.gz|tar\.gz)$" | while read -r line; do
            echo "  $line"
        done
    else
        warning "No backup directory found"
    fi
}

# Restore from backup
restore_backup() {
    local backup_type="$1"
    local backup_file="$2"
    
    if [ -z "$backup_type" ] || [ -z "$backup_file" ]; then
        error "Usage: restore_backup <type> <backup_file>"
    fi
    
    if [ ! -f "$backup_file" ]; then
        error "Backup file not found: $backup_file"
    fi
    
    log "Restoring from $backup_type backup: $backup_file"
    
    case "$backup_type" in
        "database")
            restore_database_backup "$backup_file"
            ;;
        "data")
            restore_data_backup "$backup_file"
            ;;
        "config")
            restore_config_backup "$backup_file"
            ;;
        *)
            error "Unknown backup type: $backup_type"
            ;;
    esac
}

# Restore database backup
restore_database_backup() {
    local backup_file="$1"
    
    log "Restoring database from backup..."
    
    # Get database connection details
    local pg_password=$(grep POSTGRES_PASSWORD "$SUPABASE_DIR/.env" | cut -d'=' -f2)
    local pg_host="localhost"
    local pg_port="5432"
    local pg_user="postgres"
    local pg_database="postgres"
    
    if [ -z "$pg_password" ]; then
        error "POSTGRES_PASSWORD not found in Supabase .env file"
    fi
    
    # Decompress if needed
    if [[ "$backup_file" == *.gz ]]; then
        gunzip -c "$backup_file" | PGPASSWORD="$pg_password" psql -h "$pg_host" -p "$pg_port" -U "$pg_user" -d "$pg_database"
    else
        PGPASSWORD="$pg_password" psql -h "$pg_host" -p "$pg_port" -U "$pg_user" -d "$pg_database" -f "$backup_file"
    fi
    
    success "Database restored from backup"
}

# Restore data backup
restore_data_backup() {
    local backup_file="$1"
    
    log "Restoring email data from backup..."
    
    # This would require implementing the reverse of the backup process
    warning "Data restore not implemented yet"
}

# Restore config backup
restore_config_backup() {
    local backup_file="$1"
    
    log "Restoring configuration from backup..."
    
    # Extract to temporary directory
    local temp_dir=$(mktemp -d)
    tar -xzf "$backup_file" -C "$temp_dir"
    
    # Copy files back
    cp "$temp_dir/.env" "$EMAIL_STORAGE_DIR/" 2>/dev/null || true
    cp "$temp_dir/docker-compose.yml" "$EMAIL_STORAGE_DIR/"
    cp "$temp_dir/package.json" "$EMAIL_STORAGE_DIR/"
    
    # Clean up
    rm -rf "$temp_dir"
    
    success "Configuration restored from backup"
}

# Main backup function
main() {
    local backup_type="${1:-all}"
    local cleanup_days="${2:-30}"
    
    log "Starting email storage backup (type: $backup_type)"
    
    local backups=()
    
    case "$backup_type" in
        "database")
            backups+=($(backup_database))
            ;;
        "data")
            backups+=($(backup_email_data))
            ;;
        "config")
            backups+=($(backup_configuration))
            ;;
        "logs")
            backups+=($(backup_logs))
            ;;
        "all")
            backups+=($(backup_database))
            backups+=($(backup_email_data))
            backups+=($(backup_configuration))
            backups+=($(backup_logs))
            ;;
        "list")
            list_backups
            exit 0
            ;;
        "restore")
            restore_backup "$2" "$3"
            exit 0
            ;;
        *)
            error "Unknown backup type: $backup_type"
            ;;
    esac
    
    # Verify backups
    log "Verifying backups..."
    for backup in "${backups[@]}"; do
        if [ -n "$backup" ] && verify_backup "$backup"; then
            success "Backup verified: $(basename "$backup")"
        else
            error "Backup verification failed: $(basename "$backup")"
        fi
    done
    
    # Clean up old backups
    cleanup_old_backups "$cleanup_days"
    
    success "Backup completed successfully!"
    
    echo
    echo -e "${GREEN}Backup Summary:${NC}"
    for backup in "${backups[@]}"; do
        if [ -n "$backup" ]; then
            local size=$(du -h "$backup" | cut -f1)
            echo "  $(basename "$backup") - $size"
        fi
    done
}

# Show usage
show_usage() {
    echo "Email Storage Backup Script"
    echo
    echo "Usage: $0 [backup_type] [cleanup_days]"
    echo
    echo "Backup Types:"
    echo "  all       - Create all backups (default)"
    echo "  database  - Create database schema backup"
    echo "  data      - Create email data backup"
    echo "  config    - Create configuration backup"
    echo "  logs      - Create logs backup"
    echo "  list      - List available backups"
    echo "  restore   - Restore from backup (requires type and file)"
    echo
    echo "Examples:"
    echo "  $0                    # Create all backups"
    echo "  $0 database           # Create database backup only"
    echo "  $0 all 7              # Create all backups, keep for 7 days"
    echo "  $0 list               # List available backups"
    echo "  $0 restore database /path/to/backup.sql.gz"
    echo
}

# Check arguments
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_usage
    exit 0
fi

# Run main function
main "$@"
