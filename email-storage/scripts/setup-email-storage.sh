#!/bin/bash

# Email Storage Setup Script
# Sets up the email storage service with Supabase integration

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
LOG_FILE="$EMAIL_STORAGE_DIR/logs/setup.log"

# Create log directory
mkdir -p "$EMAIL_STORAGE_DIR/logs"

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

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root for security reasons"
    fi
}

# Check dependencies
check_dependencies() {
    log "Checking dependencies..."
    
    local missing_deps=()
    
    # Check for required commands
    for cmd in docker docker-compose node npm curl psql; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        error "Missing required dependencies: ${missing_deps[*]}"
    fi
    
    # Check Node.js version
    local node_version=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$node_version" -lt 18 ]; then
        error "Node.js version 18 or higher is required (found: $(node --version))"
    fi
    
    success "All dependencies found"
}

# Check Supabase status
check_supabase() {
    log "Checking Supabase status..."
    
    if [ ! -d "$SUPABASE_DIR" ]; then
        error "Supabase directory not found at $SUPABASE_DIR"
    fi
    
    # Check if Supabase is running
    if ! docker-compose -f "$SUPABASE_DIR/docker-compose.yml" ps | grep -q "Up"; then
        warning "Supabase appears to be down. Starting Supabase..."
        cd "$SUPABASE_DIR"
        docker-compose up -d
        cd "$EMAIL_STORAGE_DIR"
    fi
    
    # Wait for Supabase to be ready
    log "Waiting for Supabase to be ready..."
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s http://localhost:8000/health > /dev/null 2>&1; then
            success "Supabase is ready"
            return
        fi
        
        attempt=$((attempt + 1))
        log "Waiting for Supabase... (attempt $attempt/$max_attempts)"
        sleep 10
    done
    
    error "Supabase failed to start within expected time"
}

# Install Node.js dependencies
install_dependencies() {
    log "Installing Node.js dependencies..."
    
    cd "$EMAIL_STORAGE_DIR"
    
    if [ ! -f "package.json" ]; then
        error "package.json not found in $EMAIL_STORAGE_DIR"
    fi
    
    npm install --production
    success "Dependencies installed"
}

# Run database migrations
run_migrations() {
    log "Running database migrations..."
    
    # Get Supabase connection details
    local supabase_url="https://api.supabase.ranch.sh"
    local supabase_key=$(grep SUPABASE_SERVICE_ROLE_KEY "$SUPABASE_DIR/.env" | cut -d'=' -f2)
    
    if [ -z "$supabase_key" ]; then
        error "SUPABASE_SERVICE_ROLE_KEY not found in Supabase .env file"
    fi
    
    # Run migrations
    for migration in "$EMAIL_STORAGE_DIR/migrations"/*.sql; do
        if [ -f "$migration" ]; then
            log "Running migration: $(basename "$migration")"
            
            # Use psql to run migration
            PGPASSWORD=$(grep POSTGRES_PASSWORD "$SUPABASE_DIR/.env" | cut -d'=' -f2) \
            psql -h localhost -p 5432 -U postgres -d postgres -f "$migration" || {
                error "Migration failed: $(basename "$migration")"
            }
        fi
    done
    
    success "Database migrations completed"
}

# Create environment file
create_env_file() {
    log "Creating environment file..."
    
    local env_file="$EMAIL_STORAGE_DIR/.env"
    
    if [ -f "$env_file" ]; then
        warning "Environment file already exists, backing up..."
        cp "$env_file" "$env_file.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Read Supabase configuration
    local supabase_url="https://api.supabase.ranch.sh"
    local supabase_anon_key=$(grep ANON_KEY "$SUPABASE_DIR/.env" | cut -d'=' -f2)
    local supabase_service_key=$(grep SERVICE_ROLE_KEY "$SUPABASE_DIR/.env" | cut -d'=' -f2)
    local jwt_secret=$(grep JWT_SECRET "$SUPABASE_DIR/.env" | cut -d'=' -f2)
    
    # Generate encryption key
    local encryption_key=$(openssl rand -base64 32)
    
    # Generate webhook secret
    local webhook_secret=$(openssl rand -hex 32)
    
    cat > "$env_file" << EOF
# Email Storage Configuration
# Generated on $(date)

# Fastmail OAuth Configuration
FASTMAIL_CLIENT_ID=your_fastmail_client_id
FASTMAIL_CLIENT_SECRET=your_fastmail_client_secret
FASTMAIL_REDIRECT_URI=https://oauth.privacy.ranch.sh/auth/callback
FASTMAIL_SCOPE=urn:ietf:params:jmap:core urn:ietf:params:jmap:mail urn:ietf:params:jmap:submission

# Supabase Configuration
SUPABASE_URL=$supabase_url
SUPABASE_ANON_KEY=$supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=$supabase_service_key

# Application Configuration
NODE_ENV=production
LOG_LEVEL=info

# Sync Configuration
SYNC_INTERVAL_MINUTES=15
BATCH_SIZE=100
MAX_RETRIES=3
RETRY_DELAY_MS=5000

# Webhook Configuration
WEBHOOK_SECRET=$webhook_secret
WEBHOOK_PORT=3002

# OAuth Configuration
OAUTH_PORT=3001

# API Configuration
API_PORT=3003
API_RATE_LIMIT=1000
API_RATE_WINDOW_MS=900000

# Security Configuration
JWT_SECRET=$jwt_secret
ENCRYPTION_KEY=$encryption_key

# Monitoring Configuration
HEALTH_CHECK_INTERVAL_MS=60000
METRICS_ENABLED=true
EOF

    success "Environment file created: $env_file"
    warning "Please update Fastmail OAuth credentials in the environment file"
}

# Create necessary directories
create_directories() {
    log "Creating necessary directories..."
    
    local dirs=(
        "$EMAIL_STORAGE_DIR/logs"
        "$EMAIL_STORAGE_DIR/data"
        "$EMAIL_STORAGE_DIR/backups"
        "$EMAIL_STORAGE_DIR/config"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
    done
    
    success "Directories created"
}

# Set up log rotation
setup_log_rotation() {
    log "Setting up log rotation..."
    
    local logrotate_config="/etc/logrotate.d/privacy-email-storage"
    
    if [ -w "/etc/logrotate.d" ]; then
        cat > "$logrotate_config" << EOF
$EMAIL_STORAGE_DIR/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 $(whoami) $(whoami)
    postrotate
        # Reload services if needed
        docker-compose -f $EMAIL_STORAGE_DIR/docker-compose.yml restart email-sync oauth-handler webhook-server email-api || true
    endscript
}
EOF
        success "Log rotation configured"
    else
        warning "Cannot write to /etc/logrotate.d, skipping log rotation setup"
    fi
}

# Test the setup
test_setup() {
    log "Testing the setup..."
    
    cd "$EMAIL_STORAGE_DIR"
    
    # Test database connection
    log "Testing database connection..."
    if node -e "
        const { createClient } = require('@supabase/supabase-js');
        const config = require('dotenv').config();
        const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
        supabase.from('emails').select('count').limit(1).then(() => {
            console.log('Database connection successful');
            process.exit(0);
        }).catch(err => {
            console.error('Database connection failed:', err.message);
            process.exit(1);
        });
    "; then
        success "Database connection test passed"
    else
        error "Database connection test failed"
    fi
    
    # Test Docker build
    log "Testing Docker build..."
    if docker build -t privacy-email-storage:test . > /dev/null 2>&1; then
        success "Docker build test passed"
        docker rmi privacy-email-storage:test > /dev/null 2>&1
    else
        error "Docker build test failed"
    fi
}

# Main setup function
main() {
    log "Starting Email Storage Setup"
    log "Project root: $PROJECT_ROOT"
    log "Email storage directory: $EMAIL_STORAGE_DIR"
    
    check_root
    check_dependencies
    check_supabase
    create_directories
    install_dependencies
    run_migrations
    create_env_file
    setup_log_rotation
    test_setup
    
    success "Email Storage setup completed successfully!"
    
    echo
    echo -e "${GREEN}Next steps:${NC}"
    echo "1. Update Fastmail OAuth credentials in $EMAIL_STORAGE_DIR/.env"
    echo "2. Start the services: cd $EMAIL_STORAGE_DIR && docker-compose up -d"
    echo "3. Monitor the services: cd $EMAIL_STORAGE_DIR && node scripts/monitor.js monitor"
    echo
    echo -e "${BLUE}Service URLs:${NC}"
    echo "- OAuth Handler: https://oauth.privacy.ranch.sh"
    echo "- Webhook Server: https://webhooks.privacy.ranch.sh"
    echo "- Email API: https://api.privacy.ranch.sh"
    echo "- Email Sync: https://email-sync.privacy.ranch.sh"
    echo
    echo -e "${YELLOW}For more information, see the README.md file${NC}"
}

# Run main function
main "$@"
