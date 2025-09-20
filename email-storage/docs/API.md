# Email Storage API Documentation

## Overview

The Email Storage API provides comprehensive access to email data stored in Supabase, with full-text search capabilities and real-time synchronization features.

## Base URL

```
https://api.privacy.ranch.sh
```

## Authentication

The API uses JWT tokens for authentication. Include the token in the Authorization header:

```bash
Authorization: Bearer your_jwt_token
```

## Endpoints

### Health Check

#### GET /health

Check API health status.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00Z",
  "version": "1.0.0"
}
```

### Email Search

#### GET /search

Search emails with basic query.

**Parameters:**
- `q` (string): Search query
- `limit` (integer, default: 50): Number of results
- `offset` (integer, default: 0): Pagination offset
- `mailbox` (string): Filter by mailbox ID
- `isRead` (boolean): Filter by read status
- `isFlagged` (boolean): Filter by flagged status
- `hasAttachments` (boolean): Filter by attachment presence
- `dateFrom` (string): Start date (ISO 8601)
- `dateTo` (string): End date (ISO 8601)
- `sortBy` (string): Sort field (date_received, subject, from_address)
- `sortOrder` (string): Sort order (asc, desc)

**Example:**
```bash
GET /search?q=privacy&limit=10&isRead=false&sortBy=date_received&sortOrder=desc
```

**Response:**
```json
{
  "results": [
    {
      "email_id": "uuid",
      "subject": "Privacy Policy Update",
      "from_address": "noreply@example.com",
      "snippet": "We've updated our privacy policy...",
      "rank": 0.95,
      "date_received": "2024-01-15T09:00:00Z",
      "is_read": false,
      "is_flagged": true
    }
  ],
  "total": 150,
  "limit": 10,
  "offset": 0
}
```

#### POST /search/advanced

Advanced search with complex filters.

**Request Body:**
```json
{
  "query": "privacy policy",
  "filters": {
    "mailboxIds": ["inbox", "sent"],
    "dateFrom": "2024-01-01T00:00:00Z",
    "dateTo": "2024-12-31T23:59:59Z",
    "isRead": false,
    "isFlagged": true,
    "hasAttachments": true,
    "fromAddress": "noreply@example.com",
    "toAddress": "user@example.com",
    "subjectContains": "urgent",
    "bodyContains": "confidential"
  },
  "sortBy": "date_received",
  "sortOrder": "desc",
  "limit": 50,
  "offset": 0
}
```

**Response:**
```json
{
  "results": [...],
  "total": 25,
  "limit": 50,
  "offset": 0,
  "facets": {
    "mailboxes": {
      "inbox": 15,
      "sent": 10
    },
    "dateRanges": {
      "2024-01": 8,
      "2024-02": 12,
      "2024-03": 5
    }
  }
}
```

### Email Management

#### GET /emails/{id}

Get specific email by ID.

**Response:**
```json
{
  "id": "uuid",
  "fastmail_id": "email_id",
  "thread_id": "thread_id",
  "mailbox_id": "inbox",
  "subject": "Email Subject",
  "from_address": "sender@example.com",
  "to_addresses": ["recipient@example.com"],
  "cc_addresses": [],
  "bcc_addresses": [],
  "reply_to_addresses": [],
  "date_received": "2024-01-15T09:00:00Z",
  "date_sent": "2024-01-15T08:59:30Z",
  "message_id": "message-id@example.com",
  "in_reply_to": "previous-message-id@example.com",
  "references": ["ref1@example.com", "ref2@example.com"],
  "body_text": "Plain text content...",
  "body_html": "<html>HTML content...</html>",
  "attachments": [
    {
      "id": "attachment_id",
      "name": "document.pdf",
      "type": "application/pdf",
      "size": 1024000,
      "download_url": "https://api.privacy.ranch.sh/attachments/attachment_id"
    }
  ],
  "flags": {
    "$seen": true,
    "$flagged": false,
    "$answered": false
  },
  "size_bytes": 2048000,
  "is_read": true,
  "is_flagged": false,
  "is_deleted": false,
  "created_at": "2024-01-15T09:00:00Z",
  "updated_at": "2024-01-15T09:00:00Z"
}
```

#### PUT /emails/{id}

Update email flags or metadata.

**Request Body:**
```json
{
  "is_read": true,
  "is_flagged": false,
  "flags": {
    "$seen": true,
    "$flagged": false
  }
}
```

**Response:**
```json
{
  "success": true,
  "updated": {
    "is_read": true,
    "is_flagged": false
  }
}
```

#### DELETE /emails/{id}

Mark email as deleted.

**Response:**
```json
{
  "success": true,
  "message": "Email marked as deleted"
}
```

### Mailbox Management

#### GET /mailboxes

Get all mailboxes.

**Response:**
```json
{
  "mailboxes": [
    {
      "id": "uuid",
      "fastmail_id": "inbox",
      "name": "Inbox",
      "parent_id": null,
      "role": "inbox",
      "sort_order": 1,
      "total_emails": 150,
      "unread_emails": 25,
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-15T09:00:00Z"
    }
  ]
}
```

#### GET /mailboxes/{id}

Get specific mailbox with statistics.

**Response:**
```json
{
  "id": "uuid",
  "fastmail_id": "inbox",
  "name": "Inbox",
  "parent_id": null,
  "role": "inbox",
  "sort_order": 1,
  "total_emails": 150,
  "unread_emails": 25,
  "statistics": {
    "total_size_bytes": 1048576000,
    "avg_size_bytes": 6990507,
    "oldest_email": "2023-01-01T00:00:00Z",
    "newest_email": "2024-01-15T09:00:00Z",
    "emails_last_week": 15,
    "emails_last_month": 45
  },
  "created_at": "2024-01-01T00:00:00Z",
  "updated_at": "2024-01-15T09:00:00Z"
}
```

### Thread Management

#### GET /threads

Get email threads.

**Parameters:**
- `mailbox` (string): Filter by mailbox ID
- `limit` (integer): Number of threads
- `offset` (integer): Pagination offset
- `sortBy` (string): Sort field
- `sortOrder` (string): Sort order

**Response:**
```json
{
  "threads": [
    {
      "id": "thread_id",
      "subject": "Re: Discussion Topic",
      "message_count": 5,
      "unread_count": 2,
      "last_message_date": "2024-01-15T09:00:00Z",
      "participants": [
        "user1@example.com",
        "user2@example.com"
      ],
      "mailbox_ids": ["inbox"]
    }
  ],
  "total": 25,
  "limit": 50,
  "offset": 0
}
```

#### GET /threads/{id}

Get specific thread with all messages.

**Response:**
```json
{
  "id": "thread_id",
  "subject": "Re: Discussion Topic",
  "message_count": 5,
  "unread_count": 2,
  "last_message_date": "2024-01-15T09:00:00Z",
  "participants": [
    "user1@example.com",
    "user2@example.com"
  ],
  "mailbox_ids": ["inbox"],
  "messages": [
    {
      "id": "email_id_1",
      "subject": "Discussion Topic",
      "from_address": "user1@example.com",
      "date_received": "2024-01-15T08:00:00Z",
      "is_read": true,
      "is_flagged": false
    }
  ]
}
```

### Statistics

#### GET /stats

Get email statistics.

**Response:**
```json
{
  "total_emails": 1500,
  "unread_emails": 25,
  "flagged_emails": 10,
  "deleted_emails": 5,
  "total_size_bytes": 1048576000,
  "total_size_gb": 1.0,
  "emails_by_mailbox": {
    "inbox": {
      "total": 150,
      "unread": 25
    },
    "sent": {
      "total": 200,
      "unread": 0
    }
  },
  "emails_by_month": {
    "2024-01": 150,
    "2023-12": 200
  },
  "top_senders": [
    {
      "email": "noreply@example.com",
      "count": 50,
      "total_size": 104857600
    }
  ]
}
```

#### GET /stats/mailbox/{id}

Get mailbox-specific statistics.

**Response:**
```json
{
  "mailbox_id": "inbox",
  "mailbox_name": "Inbox",
  "total_emails": 150,
  "unread_emails": 25,
  "flagged_emails": 10,
  "total_size_bytes": 104857600,
  "avg_size_bytes": 699050,
  "oldest_email_date": "2023-01-01T00:00:00Z",
  "newest_email_date": "2024-01-15T09:00:00Z",
  "top_senders": [...],
  "emails_by_month": {...}
}
```

### Sync Management

#### GET /sync/status

Get synchronization status.

**Parameters:**
- `accountId` (string): Account ID (optional)

**Response:**
```json
{
  "account_id": "account_id",
  "last_sync_token": "sync_token",
  "last_sync_date": "2024-01-15T09:00:00Z",
  "total_emails_synced": 1500,
  "last_error": null,
  "sync_status": "completed",
  "created_at": "2024-01-01T00:00:00Z",
  "updated_at": "2024-01-15T09:00:00Z"
}
```

#### POST /sync/trigger

Trigger manual synchronization.

**Request Body:**
```json
{
  "accountId": "account_id",
  "force": false
}
```

**Response:**
```json
{
  "success": true,
  "message": "Sync triggered successfully",
  "sync_id": "sync_uuid"
}
```

### Attachments

#### GET /attachments/{id}

Download email attachment.

**Response:**
- Binary file content
- Content-Type header set appropriately

#### GET /attachments/{id}/info

Get attachment metadata.

**Response:**
```json
{
  "id": "attachment_id",
  "name": "document.pdf",
  "type": "application/pdf",
  "size": 1024000,
  "email_id": "email_uuid",
  "created_at": "2024-01-15T09:00:00Z"
}
```

## Error Responses

All errors follow this format:

```json
{
  "error": "Error type",
  "message": "Human-readable error message",
  "code": "ERROR_CODE",
  "timestamp": "2024-01-15T09:00:00Z",
  "request_id": "request_uuid"
}
```

### Common Error Codes

- `400` - Bad Request
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Not Found
- `429` - Rate Limited
- `500` - Internal Server Error

## Rate Limiting

The API implements rate limiting:

- **Search requests**: 100 requests per minute
- **Email operations**: 200 requests per minute
- **Sync operations**: 10 requests per minute

Rate limit headers are included in responses:

```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1642248000
```

## Webhooks

### Webhook Events

The API can send webhooks for:

- `email.received` - New email received
- `email.updated` - Email updated
- `email.deleted` - Email deleted
- `sync.completed` - Sync completed
- `sync.failed` - Sync failed

### Webhook Payload

```json
{
  "event": "email.received",
  "account_id": "account_id",
  "email_id": "email_uuid",
  "timestamp": "2024-01-15T09:00:00Z",
  "data": {
    "subject": "Email Subject",
    "from_address": "sender@example.com",
    "mailbox_id": "inbox"
  }
}
```

### Webhook Verification

Webhooks include a signature header for verification:

```
X-Webhook-Signature: sha256=signature
```

## SDK Examples

### JavaScript/Node.js

```javascript
const EmailStorageAPI = require('@privacy/email-storage-api');

const api = new EmailStorageAPI({
  baseURL: 'https://api.privacy.ranch.sh',
  token: 'your_jwt_token'
});

// Search emails
const results = await api.search({
  query: 'privacy',
  limit: 10,
  isRead: false
});

// Get email
const email = await api.getEmail('email_uuid');

// Update email
await api.updateEmail('email_uuid', {
  isRead: true,
  isFlagged: false
});
```

### Python

```python
import requests

class EmailStorageAPI:
    def __init__(self, base_url, token):
        self.base_url = base_url
        self.headers = {
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json'
        }
    
    def search(self, query, **kwargs):
        response = requests.get(
            f'{self.base_url}/search',
            params={'q': query, **kwargs},
            headers=self.headers
        )
        return response.json()
    
    def get_email(self, email_id):
        response = requests.get(
            f'{self.base_url}/emails/{email_id}',
            headers=self.headers
        )
        return response.json()
```

## Changelog

### v1.0.0 (2024-01-15)

- Initial API release
- Email search and management
- Thread support
- Statistics endpoints
- Sync management
- Attachment handling
