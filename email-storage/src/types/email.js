/**
 * Email Storage Types for Supabase Integration
 */

export class StoredEmail {
  constructor(data) {
    this.id = data.id;
    this.fastmailId = data.fastmail_id;
    this.threadId = data.thread_id;
    this.mailboxId = data.mailbox_id;
    this.subject = data.subject;
    this.fromAddress = data.from_address;
    this.toAddresses = data.to_addresses || [];
    this.ccAddresses = data.cc_addresses || [];
    this.bccAddresses = data.bcc_addresses || [];
    this.replyToAddresses = data.reply_to_addresses || [];
    this.dateReceived = data.date_received ? new Date(data.date_received) : null;
    this.dateSent = data.date_sent ? new Date(data.date_sent) : null;
    this.messageId = data.message_id;
    this.inReplyTo = data.in_reply_to;
    this.references = data.references || [];
    this.bodyText = data.body_text;
    this.bodyHtml = data.body_html;
    this.attachments = data.attachments || [];
    this.flags = data.flags || {};
    this.sizeBytes = data.size_bytes || 0;
    this.isRead = data.is_read || false;
    this.isFlagged = data.is_flagged || false;
    this.isDeleted = data.is_deleted || false;
    this.createdAt = data.created_at ? new Date(data.created_at) : new Date();
    this.updatedAt = data.updated_at ? new Date(data.updated_at) : new Date();
  }
  
  static fromFastmailEmail(fastmailEmail, mailboxId) {
    return new StoredEmail({
      fastmail_id: fastmailEmail.id,
      thread_id: fastmailEmail.threadId,
      mailbox_id: mailboxId,
      subject: fastmailEmail.subject,
      from_address: fastmailEmail.getFromAddress(),
      to_addresses: fastmailEmail.getToAddresses(),
      cc_addresses: fastmailEmail.getCcAddresses(),
      bcc_addresses: fastmailEmail.getBccAddresses(),
      reply_to_addresses: fastmailEmail.getReplyToAddresses(),
      date_received: fastmailEmail.receivedAt,
      date_sent: fastmailEmail.sentAt,
      message_id: fastmailEmail.messageId,
      in_reply_to: fastmailEmail.inReplyTo,
      email_references: fastmailEmail.references,
      body_text: fastmailEmail.textBody,
      body_html: fastmailEmail.htmlBody,
      attachments: fastmailEmail.attachments,
      flags: fastmailEmail.keywords,
      size_bytes: fastmailEmail.size,
      is_read: fastmailEmail.isRead,
      is_flagged: fastmailEmail.isFlagged,
      is_deleted: fastmailEmail.isDeleted
    });
  }
  
  toSupabaseRow() {
    return {
      fastmail_id: this.fastmailId,
      thread_id: this.threadId,
      mailbox_id: this.mailboxId,
      subject: this.subject,
      from_address: this.fromAddress,
      to_addresses: this.toAddresses,
      cc_addresses: this.ccAddresses,
      bcc_addresses: this.bccAddresses,
      reply_to_addresses: this.replyToAddresses,
      date_received: this.dateReceived?.toISOString(),
      date_sent: this.dateSent?.toISOString(),
      message_id: this.messageId,
      in_reply_to: this.inReplyTo,
      email_references: this.references,
      body_text: this.bodyText,
      body_html: this.bodyHtml,
      attachments: this.attachments,
      flags: this.flags,
      size_bytes: this.sizeBytes,
      is_read: this.isRead,
      is_flagged: this.isFlagged,
      is_deleted: this.isDeleted
    };
  }
}

export class StoredMailbox {
  constructor(data) {
    this.id = data.id;
    this.fastmailId = data.fastmail_id;
    this.name = data.name;
    this.parentId = data.parent_id;
    this.role = data.role;
    this.sortOrder = data.sort_order;
    this.totalEmails = data.total_emails || 0;
    this.unreadEmails = data.unread_emails || 0;
    this.createdAt = data.created_at ? new Date(data.created_at) : new Date();
    this.updatedAt = data.updated_at ? new Date(data.updated_at) : new Date();
  }
  
  static fromFastmailMailbox(fastmailMailbox) {
    return new StoredMailbox({
      fastmail_id: fastmailMailbox.id,
      name: fastmailMailbox.name,
      parent_id: fastmailMailbox.parentId,
      role: fastmailMailbox.role,
      sort_order: fastmailMailbox.sortOrder,
      total_emails: fastmailMailbox.totalEmails,
      unread_emails: fastmailMailbox.unreadEmails
    });
  }
  
  toSupabaseRow() {
    return {
      fastmail_id: this.fastmailId,
      name: this.name,
      parent_id: this.parentId,
      role: this.role,
      sort_order: this.sortOrder,
      total_emails: this.totalEmails,
      unread_emails: this.unreadEmails
    };
  }
}

export class EmailSearchResult {
  constructor(data) {
    this.emailId = data.email_id;
    this.subject = data.subject;
    this.fromAddress = data.from_address;
    this.snippet = data.snippet;
    this.rank = data.rank;
    this.dateReceived = data.date_received ? new Date(data.date_received) : null;
  }
}

export class EmailSearchQuery {
  constructor(query, options = {}) {
    this.query = query;
    this.limit = options.limit || 50;
    this.offset = options.offset || 0;
    this.mailboxIds = options.mailboxIds || [];
    this.dateFrom = options.dateFrom;
    this.dateTo = options.dateTo;
    this.isRead = options.isRead;
    this.isFlagged = options.isFlagged;
    this.hasAttachments = options.hasAttachments;
    this.sortBy = options.sortBy || 'date_received';
    this.sortOrder = options.sortOrder || 'desc';
  }
  
  toSupabaseQuery() {
    const query = {
      query: this.query,
      limit: this.limit,
      offset: this.offset
    };
    
    if (this.mailboxIds.length > 0) {
      query.mailbox_ids = this.mailboxIds;
    }
    
    if (this.dateFrom) {
      query.date_from = this.dateFrom.toISOString();
    }
    
    if (this.dateTo) {
      query.date_to = this.dateTo.toISOString();
    }
    
    if (this.isRead !== undefined) {
      query.is_read = this.isRead;
    }
    
    if (this.isFlagged !== undefined) {
      query.is_flagged = this.isFlagged;
    }
    
    if (this.hasAttachments !== undefined) {
      query.has_attachments = this.hasAttachments;
    }
    
    query.sort_by = this.sortBy;
    query.sort_order = this.sortOrder;
    
    return query;
  }
}

export class EmailSyncStats {
  constructor(data) {
    this.totalEmails = data.total_emails || 0;
    this.newEmails = data.new_emails || 0;
    this.updatedEmails = data.updated_emails || 0;
    this.deletedEmails = data.deleted_emails || 0;
    this.syncDuration = data.sync_duration || 0;
    this.lastSyncDate = data.last_sync_date ? new Date(data.last_sync_date) : null;
    this.errors = data.errors || [];
    this.warnings = data.warnings || [];
  }
  
  addError(error) {
    this.errors.push({
      message: error.message || error,
      timestamp: new Date(),
      type: 'error'
    });
  }
  
  addWarning(warning) {
    this.warnings.push({
      message: warning.message || warning,
      timestamp: new Date(),
      type: 'warning'
    });
  }
  
  getSuccessRate() {
    const total = this.newEmails + this.updatedEmails + this.deletedEmails;
    if (total === 0) return 100;
    return ((total - this.errors.length) / total) * 100;
  }
}

export class EmailAttachment {
  constructor(data) {
    this.id = data.id;
    this.blobId = data.blobId;
    this.name = data.name;
    this.type = data.type;
    this.size = data.size;
    this.cid = data.cid;
    this.isInline = data.isInline || false;
    this.downloadUrl = data.downloadUrl;
  }
  
  static fromFastmailAttachment(attachment, downloadUrl) {
    return new EmailAttachment({
      id: attachment.id,
      blobId: attachment.blobId,
      name: attachment.name,
      type: attachment.type,
      size: attachment.size,
      cid: attachment.cid,
      isInline: attachment.isInline,
      downloadUrl: downloadUrl
    });
  }
}

export class EmailThread {
  constructor(data) {
    this.id = data.id;
    this.emailIds = data.email_ids || [];
    this.subject = data.subject;
    this.mailboxIds = data.mailbox_ids || {};
    this.messageCount = data.message_count || 0;
    this.unreadCount = data.unread_count || 0;
    this.lastMessageDate = data.last_message_date ? new Date(data.last_message_date) : null;
    this.createdAt = data.created_at ? new Date(data.created_at) : new Date();
    this.updatedAt = data.updated_at ? new Date(data.updated_at) : new Date();
  }
  
  static fromFastmailThread(fastmailThread) {
    return new EmailThread({
      id: fastmailThread.id,
      email_ids: fastmailThread.emailIds,
      subject: fastmailThread.subject,
      mailbox_ids: fastmailThread.mailboxIds,
      message_count: fastmailThread.emailIds.length
    });
  }
  
  toSupabaseRow() {
    return {
      id: this.id,
      email_ids: this.emailIds,
      subject: this.subject,
      mailbox_ids: this.mailboxIds,
      message_count: this.messageCount,
      unread_count: this.unreadCount,
      last_message_date: this.lastMessageDate?.toISOString()
    };
  }
}

export const EMAIL_SORT_OPTIONS = {
  DATE_RECEIVED: 'date_received',
  DATE_SENT: 'date_sent',
  SUBJECT: 'subject',
  FROM_ADDRESS: 'from_address',
  SIZE: 'size_bytes'
};

export const SORT_ORDER = {
  ASC: 'asc',
  DESC: 'desc'
};

export const EMAIL_FILTER_OPTIONS = {
  UNREAD: 'unread',
  FLAGGED: 'flagged',
  WITH_ATTACHMENTS: 'attachments',
  RECENT: 'recent',
  IMPORTANT: 'important'
};
