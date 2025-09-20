# Email Storage Deployment Guide

## Overview

This guide covers deploying the Email Storage Service in a production environment with proper security, monitoring, and maintenance procedures.

## Prerequisites

### System Requirements

- **OS**: Linux (Ubuntu 20.04+ recommended)
- **CPU**: 2+ cores
- **RAM**: 4GB+ (8GB+ recommended)
- **Storage**: 50GB+ SSD
- **Network**: Stable internet connection

### Software Dependencies

- Docker 20.10+
- Docker Compose 2.0+
- Node.js 18+
- PostgreSQL 13+ (via Supabase)
- Nginx (for reverse proxy)

### External Services

- **Supabase**: Self-hosted instance
- **Fastmail**: Account with API access
- **Domain**: For SSL certificates
- **DNS**: For service routing

## Architecture

### Production Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Traefik       │    │   Email Storage │    │   Supabase      │
│   (Reverse      │────│   Services      │────│   (Database)    │
│   Proxy)        │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │
         │                       │
┌─────────────────┐    ┌─────────────────┐
│   Fastmail      │    │   Monitoring    │
│   (Email API)   │    │   & Logging     │
└─────────────────┘    └─────────────────┘
```

### Service Components

1. **Email Sync Service**: Core synchronization
2. **OAuth Handler**: Authentication management
3. **Webhook Server**: Real-time updates
4. **Email API**: REST API for email access
5. **Monitoring**: Health checks and metrics

## Deployment Steps

### 1. Server Preparation

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install additional tools
sudo apt install -y curl wget git postgresql-client nginx
```

### 2. Clone and Setup

```bash
# Clone repository
git clone https://github.com/your-org/privacy-architecture.git
cd privacy-architecture/email-storage

# Make scripts executable
chmod +x scripts/*.sh

# Run setup script
./scripts/setup-email-storage.sh
```

### 3. Configure Environment

```bash
# Copy environment template
cp env.example .env

# Edit configuration
nano .env
```

**Required Environment Variables:**

```bash
# Fastmail OAuth (Required)
FASTMAIL_CLIENT_ID=your_client_id
FASTMAIL_CLIENT_SECRET=your_client_secret
FASTMAIL_REDIRECT_URI=https://oauth.yourdomain.com/auth/callback

# Supabase (Required)
SUPABASE_URL=https://api.yourdomain.com
SUPABASE_ANON_KEY=your_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_service_key

# Security (Required)
JWT_SECRET=your_jwt_secret
ENCRYPTION_KEY=your_encryption_key
WEBHOOK_SECRET=your_webhook_secret

# Production Settings
NODE_ENV=production
LOG_LEVEL=info
SYNC_INTERVAL_MINUTES=15
BATCH_SIZE=100
```

### 4. Database Setup

```bash
# Run migrations
node scripts/migrate.js

# Verify database connection
node -e "
const { createClient } = require('@supabase/supabase-js');
const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
supabase.from('emails').select('count').limit(1).then(() => {
  console.log('Database connection successful');
}).catch(err => {
  console.error('Database connection failed:', err.message);
  process.exit(1);
});
"
```

### 5. SSL Certificate Setup

```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx

# Generate certificates
sudo certbot --nginx -d oauth.yourdomain.com
sudo certbot --nginx -d webhooks.yourdomain.com
sudo certbot --nginx -d api.yourdomain.com
sudo certbot --nginx -d email-sync.yourdomain.com
```

### 6. Nginx Configuration

Create `/etc/nginx/sites-available/email-storage`:

```nginx
# OAuth Handler
server {
    listen 80;
    server_name oauth.yourdomain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name oauth.yourdomain.com;
    
    ssl_certificate /etc/letsencrypt/live/oauth.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/oauth.yourdomain.com/privkey.pem;
    
    location / {
        proxy_pass http://localhost:3001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# Webhook Server
server {
    listen 80;
    server_name webhooks.yourdomain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name webhooks.yourdomain.com;
    
    ssl_certificate /etc/letsencrypt/live/webhooks.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/webhooks.yourdomain.com/privkey.pem;
    
    location / {
        proxy_pass http://localhost:3002;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# Email API
server {
    listen 80;
    server_name api.yourdomain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.yourdomain.com;
    
    ssl_certificate /etc/letsencrypt/live/api.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.yourdomain.com/privkey.pem;
    
    location / {
        proxy_pass http://localhost:3003;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Enable the configuration:

```bash
sudo ln -s /etc/nginx/sites-available/email-storage /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 7. Start Services

```bash
# Start all services
docker-compose up -d

# Check service status
docker-compose ps

# View logs
docker-compose logs -f
```

### 8. Verify Deployment

```bash
# Check health endpoints
curl https://oauth.yourdomain.com/health
curl https://webhooks.yourdomain.com/health
curl https://api.yourdomain.com/health

# Test OAuth flow
curl https://oauth.yourdomain.com/auth/start

# Check sync status
curl https://webhooks.yourdomain.com/sync/status
```

## Production Configuration

### Security Hardening

1. **Firewall Configuration**:
```bash
# Allow only necessary ports
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw enable
```

2. **Docker Security**:
```bash
# Run containers as non-root user
# Use read-only filesystems where possible
# Limit container resources
```

3. **Environment Security**:
```bash
# Secure environment file
chmod 600 .env
chown root:root .env
```

### Monitoring Setup

1. **Health Monitoring**:
```bash
# Set up health check script
cat > /usr/local/bin/email-storage-health << 'EOF'
#!/bin/bash
curl -f https://api.yourdomain.com/health || exit 1
EOF
chmod +x /usr/local/bin/email-storage-health

# Add to crontab
echo "*/5 * * * * /usr/local/bin/email-storage-health" | crontab -
```

2. **Log Monitoring**:
```bash
# Install log monitoring
sudo apt install logwatch

# Configure log rotation
sudo nano /etc/logrotate.d/email-storage
```

3. **Resource Monitoring**:
```bash
# Install monitoring tools
sudo apt install htop iotop nethogs

# Set up alerts for high resource usage
```

### Backup Configuration

1. **Automated Backups**:
```bash
# Create backup script
cat > /usr/local/bin/email-storage-backup << 'EOF'
#!/bin/bash
cd /path/to/email-storage
./scripts/backup-emails.sh all 30
EOF
chmod +x /usr/local/bin/email-storage-backup

# Schedule daily backups
echo "0 2 * * * /usr/local/bin/email-storage-backup" | crontab -
```

2. **Backup Storage**:
```bash
# Set up remote backup storage
# Configure backup retention policies
# Test backup restoration procedures
```

### Performance Optimization

1. **Database Tuning**:
```sql
-- Optimize PostgreSQL settings
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET effective_cache_size = '1GB';
ALTER SYSTEM SET maintenance_work_mem = '64MB';
ALTER SYSTEM SET checkpoint_completion_target = 0.9;
ALTER SYSTEM SET wal_buffers = '16MB';
ALTER SYSTEM SET default_statistics_target = 100;
```

2. **Application Tuning**:
```bash
# Adjust sync settings
SYNC_INTERVAL_MINUTES=30
BATCH_SIZE=50
MAX_RETRIES=5

# Enable connection pooling
DB_CONNECTION_POOL_SIZE=20
```

3. **Caching**:
```bash
# Implement Redis for session storage
# Add application-level caching
# Use CDN for static assets
```

## Maintenance Procedures

### Daily Tasks

1. **Health Checks**:
```bash
# Check service status
docker-compose ps

# Review error logs
docker-compose logs --tail=100 email-sync | grep ERROR

# Check disk usage
df -h
```

2. **Backup Verification**:
```bash
# Verify latest backup
./scripts/backup-emails.sh list

# Test backup integrity
gunzip -t backups/email_data_*.json.gz
```

### Weekly Tasks

1. **Performance Review**:
```bash
# Generate performance report
node scripts/monitor.js report

# Check resource usage
docker stats --no-stream
```

2. **Security Updates**:
```bash
# Update system packages
sudo apt update && sudo apt upgrade

# Update Docker images
docker-compose pull
docker-compose up -d
```

### Monthly Tasks

1. **Data Cleanup**:
```bash
# Clean up old data
node scripts/monitor.js cleanup 180

# Optimize database
node scripts/monitor.js repair
```

2. **Security Audit**:
```bash
# Review access logs
sudo grep "401\|403" /var/log/nginx/access.log

# Check for security updates
sudo apt list --upgradable
```

## Troubleshooting

### Common Issues

1. **Service Won't Start**:
```bash
# Check logs
docker-compose logs service-name

# Check configuration
docker-compose config

# Restart service
docker-compose restart service-name
```

2. **Database Connection Issues**:
```bash
# Test database connection
psql -h localhost -U postgres -d postgres

# Check Supabase status
curl https://api.yourdomain.com/health
```

3. **OAuth Authentication Issues**:
```bash
# Check OAuth configuration
curl https://oauth.yourdomain.com/auth/status

# Verify redirect URI
# Check Fastmail OAuth settings
```

4. **Sync Issues**:
```bash
# Check sync status
curl https://webhooks.yourdomain.com/sync/status

# Trigger manual sync
curl -X POST https://webhooks.yourdomain.com/sync/trigger

# Check sync logs
docker-compose logs email-sync
```

### Performance Issues

1. **High Memory Usage**:
```bash
# Check memory usage
docker stats

# Restart services
docker-compose restart

# Adjust batch size
# Increase sync interval
```

2. **Slow Search**:
```bash
# Rebuild search indexes
node scripts/monitor.js repair

# Check database performance
# Optimize queries
```

3. **High CPU Usage**:
```bash
# Check CPU usage
htop

# Identify resource-intensive processes
# Scale services horizontally
```

## Scaling

### Horizontal Scaling

1. **Load Balancer Setup**:
```bash
# Configure multiple instances
# Use load balancer for distribution
# Implement session affinity
```

2. **Database Scaling**:
```bash
# Set up read replicas
# Implement connection pooling
# Use database sharding
```

### Vertical Scaling

1. **Resource Increase**:
```bash
# Increase memory allocation
# Add more CPU cores
# Use faster storage
```

2. **Optimization**:
```bash
# Tune application settings
# Optimize database queries
# Implement caching
```

## Disaster Recovery

### Backup Strategy

1. **Database Backups**:
- Daily full backups
- Point-in-time recovery
- Cross-region replication

2. **Configuration Backups**:
- Version control
- Automated backups
- Documented procedures

### Recovery Procedures

1. **Service Recovery**:
```bash
# Restore from backup
./scripts/backup-emails.sh restore database backup_file

# Restart services
docker-compose up -d

# Verify functionality
curl https://api.yourdomain.com/health
```

2. **Data Recovery**:
```bash
# Restore email data
./scripts/backup-emails.sh restore data backup_file

# Rebuild search indexes
node scripts/monitor.js repair
```

## Security Considerations

### Access Control

1. **Authentication**:
- Use strong passwords
- Enable 2FA where possible
- Regular credential rotation

2. **Authorization**:
- Principle of least privilege
- Regular access reviews
- Audit logging

### Data Protection

1. **Encryption**:
- Encrypt data at rest
- Use HTTPS for all communications
- Secure key management

2. **Privacy**:
- Data minimization
- Regular data purging
- Compliance with regulations

## Support and Maintenance

### Monitoring

1. **Health Monitoring**:
- Automated health checks
- Alerting on failures
- Performance metrics

2. **Log Management**:
- Centralized logging
- Log analysis
- Retention policies

### Updates

1. **Security Updates**:
- Regular security patches
- Vulnerability scanning
- Update procedures

2. **Feature Updates**:
- Staged rollouts
- Rollback procedures
- Testing protocols

---

For additional support, refer to the main documentation or contact the development team.
