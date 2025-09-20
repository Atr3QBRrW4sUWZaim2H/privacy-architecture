# Email Storage Service

A comprehensive email storage and synchronization service that integrates Fastmail's JMAP API with Supabase for secure, private email archiving and search.

## 🎯 Overview

This service extends the Privacy Architecture project by providing:

- **Complete Email Archival**: Store all Fastmail emails in your homelab Supabase instance
- **Real-time Synchronization**: Incremental sync using JMAP API for efficiency
- **Full-text Search**: Powerful search capabilities across all stored emails
- **OAuth 2.0 Integration**: Secure authentication with Fastmail
- **Webhook Support**: Real-time updates for new emails
- **Privacy-First**: All data stays in your homelab

## 🏗️ Architecture

### Core Components

1. **Fastmail JMAP Client** (`src/lib/fastmail-client.js`)
   - OAuth 2.0 authentication
   - JMAP API integration
   - Email, mailbox, and thread management

2. **Supabase Storage Service** (`src/lib/supabase-client.js`)
   - Database operations
   - Full-text search
   - Data integrity management

3. **Email Sync Service** (`src/services/email-sync.js`)
   - Incremental synchronization
   - Batch processing
   - Error handling and retry logic

4. **OAuth Handler** (`src/services/oauth-handler.js`)
   - OAuth flow management
   - Token storage and refresh
   - Account management

5. **Webhook Server** (`src/api/webhook-server.js`)
   - Real-time email updates
   - Webhook verification
   - Event processing

### Database Schema

The service creates the following tables in Supabase:

- **`emails`**: Core email storage with full-text search
- **`mailboxes`**: Fastmail mailbox information
- **`email_threads`**: Email thread management
- **`email_search`**: Full-text search indexes
- **`sync_state`**: Synchronization tracking
- **`oauth_tokens`**: Encrypted OAuth token storage

## 🚀 Quick Start

### Prerequisites

- Node.js 18+
- Docker and Docker Compose
- Running Supabase instance
- Fastmail account with API access

### Installation

1. **Clone and setup**:
   ```bash
   cd /mnt/dev/projects/privacy-architecture/email-storage
   chmod +x scripts/setup-email-storage.sh
   ./scripts/setup-email-storage.sh
   ```

2. **Configure Fastmail OAuth**:
   - Register your application with Fastmail
   - Update `.env` file with OAuth credentials

3. **Start services**:
   ```bash
   docker-compose up -d
   ```

4. **Monitor the system**:
   ```bash
   node scripts/monitor.js monitor
   ```

## 📋 Configuration

### Environment Variables

```bash
# Fastmail OAuth Configuration
FASTMAIL_CLIENT_ID=your_fastmail_client_id
FASTMAIL_CLIENT_SECRET=your_fastmail_client_secret
FASTMAIL_REDIRECT_URI=https://oauth.privacy.ranch.sh/auth/callback
FASTMAIL_SCOPE=urn:ietf:params:jmap:core urn:ietf:params:jmap:mail urn:ietf:params:jmap:submission

# Supabase Configuration
SUPABASE_URL=https://api.supabase.ranch.sh
SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key

# Sync Configuration
SYNC_INTERVAL_MINUTES=15
BATCH_SIZE=100
MAX_RETRIES=3

# Security
JWT_SECRET=your_jwt_secret
ENCRYPTION_KEY=your_encryption_key
WEBHOOK_SECRET=your_webhook_secret
```

### Service URLs

- **OAuth Handler**: https://oauth.privacy.ranch.sh
- **Webhook Server**: https://webhooks.privacy.ranch.sh
- **Email API**: https://api.privacy.ranch.sh
- **Email Sync**: https://email-sync.privacy.ranch.sh

## 🔧 Usage

### OAuth Authentication

1. **Start OAuth flow**:
   ```bash
   curl https://oauth.privacy.ranch.sh/auth/start
   ```

2. **Complete authentication** in browser

3. **Check auth status**:
   ```bash
   curl "https://oauth.privacy.ranch.sh/auth/status?accountId=your_account_id"
   ```

### Manual Sync

```bash
# Trigger manual sync
curl -X POST https://webhooks.privacy.ranch.sh/sync/trigger \
  -H "Content-Type: application/json" \
  -d '{"accountId": "your_account_id", "force": true}'

# Check sync status
curl https://webhooks.privacy.ranch.sh/sync/status
```

### Search Emails

```bash
# Search emails via API
curl "https://api.privacy.ranch.sh/search?q=privacy&limit=10"
```

## 📊 Monitoring

### Health Checks

```bash
# Run health check
node scripts/monitor.js health

# Generate full report
node scripts/monitor.js report

# Continuous monitoring
node scripts/monitor.js monitor 5  # 5-minute intervals
```

### Performance Metrics

The service tracks:
- Sync performance and frequency
- Email processing rates
- Error rates and types
- Storage usage and growth
- Database performance

### Logs

Logs are stored in `logs/` directory:
- `email-sync.log` - Sync service logs
- `oauth-handler.log` - OAuth authentication logs
- `webhook-server.log` - Webhook processing logs
- `monitor.log` - Monitoring and health check logs

## 🔒 Security

### Data Protection

- **Encryption at Rest**: OAuth tokens encrypted in database
- **Encryption in Transit**: All API calls use HTTPS
- **Access Control**: Row-level security policies
- **Token Management**: Automatic refresh and secure storage

### Privacy Features

- **No External Dependencies**: All data stays in your homelab
- **Local Processing**: Email processing happens locally
- **Secure Storage**: Encrypted token storage
- **Audit Logging**: Complete activity logging

## 🛠️ Maintenance

### Backup

```bash
# Create full backup
./scripts/backup-emails.sh all

# Create specific backup
./scripts/backup-emails.sh database
./scripts/backup-emails.sh data
./scripts/backup-emails.sh config

# List available backups
./scripts/backup-emails.sh list
```

### Data Integrity

```bash
# Check data integrity
node scripts/monitor.js health

# Repair data issues
node scripts/monitor.js repair

# Clean up old data
node scripts/monitor.js cleanup 180  # 180 days
```

### Updates

```bash
# Update service
git pull
docker-compose down
docker-compose build
docker-compose up -d

# Run migrations
node scripts/migrate.js
```

## 🔍 API Reference

### Email Search API

```javascript
// Search emails
GET /api/search?q=query&limit=50&offset=0&mailbox=inbox

// Advanced search
POST /api/search/advanced
{
  "query": "privacy",
  "filters": {
    "dateFrom": "2024-01-01",
    "dateTo": "2024-12-31",
    "isRead": false,
    "hasAttachments": true
  },
  "sortBy": "date_received",
  "sortOrder": "desc"
}
```

### Sync API

```javascript
// Get sync status
GET /sync/status?accountId=account_id

// Trigger sync
POST /sync/trigger
{
  "accountId": "account_id",
  "force": false
}
```

### OAuth API

```javascript
// Start OAuth flow
GET /auth/start

// OAuth callback
GET /auth/callback?code=code&state=state

// Refresh token
POST /auth/refresh
{
  "accountId": "account_id",
  "refreshToken": "token"
}
```

## 🐛 Troubleshooting

### Common Issues

1. **OAuth Authentication Fails**
   - Check Fastmail OAuth credentials
   - Verify redirect URI matches configuration
   - Ensure HTTPS is properly configured

2. **Sync Not Working**
   - Check Supabase connection
   - Verify OAuth tokens are valid
   - Check sync service logs

3. **Search Not Working**
   - Run data integrity check
   - Rebuild search indexes
   - Check database permissions

4. **High Memory Usage**
   - Reduce batch size
   - Increase sync interval
   - Check for memory leaks

### Debug Mode

```bash
# Enable debug logging
export LOG_LEVEL=debug
docker-compose restart

# Check service logs
docker-compose logs -f email-sync
docker-compose logs -f oauth-handler
docker-compose logs -f webhook-server
```

### Performance Tuning

```bash
# Optimize database
node scripts/monitor.js repair

# Clean up old data
node scripts/monitor.js cleanup 90

# Adjust sync settings
# Edit .env file:
SYNC_INTERVAL_MINUTES=30
BATCH_SIZE=50
```

## 📈 Scaling

### Horizontal Scaling

- Run multiple sync instances
- Use load balancer for webhooks
- Implement Redis for session storage

### Vertical Scaling

- Increase batch sizes
- Optimize database queries
- Add more memory/CPU

### Storage Scaling

- Implement data partitioning
- Use database sharding
- Archive old emails

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Make changes
4. Add tests
5. Submit pull request

## 📄 License

MIT License - see LICENSE file for details

## 🆘 Support

- **Documentation**: See `docs/` directory
- **Issues**: Create GitHub issue
- **Discussions**: Use GitHub Discussions
- **Security**: Report to security@privacy.ranch.sh

## 🔗 Related Projects

- [Privacy Architecture](../README.md) - Main privacy project
- [Supabase Stack](../../supabase/README.md) - Database infrastructure
- [Fastmail API](https://www.fastmail.com/dev/) - Email service API

---

**Note**: This service is designed for personal use and requires a self-hosted Supabase instance. Ensure you have proper backups and security measures in place.
