/**
 * Fastmail JMAP API Types
 * Based on RFC 8620 (JMAP) and Fastmail API documentation
 */

export const JMAP_CAPABILITIES = {
  CORE: 'urn:ietf:params:jmap:core',
  MAIL: 'urn:ietf:params:jmap:mail',
  SUBMISSION: 'urn:ietf:params:jmap:submission',
  MASKED_EMAIL: 'https://www.fastmail.com/dev/maskedemail'
};

export const JMAP_METHODS = {
  // Core methods
  GET_SESSION: 'Session/get',
  GET: 'get',
  SET: 'set',
  COPY: 'copy',
  QUERY: 'query',
  QUERY_CHANGES: 'queryChanges',
  
  // Mail methods
  EMAIL_GET: 'Email/get',
  EMAIL_SET: 'Email/set',
  EMAIL_QUERY: 'Email/query',
  EMAIL_QUERY_CHANGES: 'Email/queryChanges',
  EMAIL_COPY: 'Email/copy',
  MAILBOX_GET: 'Mailbox/get',
  MAILBOX_SET: 'Mailbox/set',
  MAILBOX_QUERY: 'Mailbox/query',
  THREAD_GET: 'Thread/get',
  THREAD_QUERY: 'Thread/query',
  
  // Submission methods
  IDENTITY_GET: 'Identity/get',
  IDENTITY_SET: 'Identity/set',
  EMAIL_SUBMISSION_SET: 'EmailSubmission/set',
  
  // Masked Email methods
  MASKED_EMAIL_GET: 'MaskedEmail/get',
  MASKED_EMAIL_SET: 'MaskedEmail/set'
};

export class JMAPSession {
  constructor(data) {
    this.capabilities = data.capabilities || {};
    this.accounts = data.accounts || {};
    this.primaryAccounts = data.primaryAccounts || {};
    this.username = data.username;
    this.apiUrl = data.apiUrl;
    this.downloadUrl = data.downloadUrl;
    this.uploadUrl = data.uploadUrl;
    this.eventSourceUrl = data.eventSourceUrl;
    this.state = data.state;
  }
  
  getAccountId() {
    return this.primaryAccounts[JMAP_CAPABILITIES.MAIL];
  }
  
  hasCapability(capability) {
    return this.capabilities.hasOwnProperty(capability);
  }
}

export class FastmailEmail {
  constructor(data) {
    this.id = data.id;
    this.threadId = data.threadId;
    this.mailboxIds = data.mailboxIds || {};
    this.subject = data.subject;
    this.from = data.from || [];
    this.to = data.to || [];
    this.cc = data.cc || [];
    this.bcc = data.bcc || [];
    this.replyTo = data.replyTo || [];
    this.sentAt = data.sentAt ? new Date(data.sentAt) : null;
    this.receivedAt = data.receivedAt ? new Date(data.receivedAt) : null;
    this.messageId = data.messageId;
    this.inReplyTo = data.inReplyTo;
    this.references = data.references || [];
    this.bodyValues = data.bodyValues || {};
    this.textBody = this.extractTextBody();
    this.htmlBody = this.extractHtmlBody();
    this.attachments = data.attachments || [];
    this.keywords = data.keywords || {};
    this.size = data.size || 0;
    this.isRead = this.keywords['$seen'] || false;
    this.isFlagged = this.keywords['$flagged'] || false;
    this.isDeleted = this.keywords['$deleted'] || false;
  }
  
  extractTextBody() {
    if (this.bodyValues.textBody) {
      return this.bodyValues.textBody.value || '';
    }
    return '';
  }
  
  extractHtmlBody() {
    if (this.bodyValues.htmlBody) {
      return this.bodyValues.htmlBody.value || '';
    }
    return '';
  }
  
  getFromAddress() {
    return this.from.length > 0 ? this.from[0].email : null;
  }
  
  getToAddresses() {
    return this.to.map(addr => addr.email);
  }
  
  getCcAddresses() {
    return this.cc.map(addr => addr.email);
  }
  
  getBccAddresses() {
    return this.bcc.map(addr => addr.email);
  }
  
  getReplyToAddresses() {
    return this.replyTo.map(addr => addr.email);
  }
}

export class FastmailMailbox {
  constructor(data) {
    this.id = data.id;
    this.name = data.name;
    this.parentId = data.parentId;
    this.role = data.role;
    this.sortOrder = data.sortOrder;
    this.totalEmails = data.totalEmails || 0;
    this.unreadEmails = data.unreadEmails || 0;
    this.totalThreads = data.totalThreads || 0;
    this.unreadThreads = data.unreadThreads || 0;
    this.mayReadItems = data.mayReadItems || false;
    this.mayAddItems = data.mayAddItems || false;
    this.mayRemoveItems = data.mayRemoveItems || false;
    this.mayCreateChild = data.mayCreateChild || false;
    this.mayRename = data.mayRename || false;
    this.mayDelete = data.mayDelete || false;
  }
}

export class FastmailThread {
  constructor(data) {
    this.id = data.id;
    this.emailIds = data.emailIds || [];
    this.subject = data.subject;
    this.mailboxIds = data.mailboxIds || {};
  }
}

export class OAuthToken {
  constructor(data) {
    this.accessToken = data.access_token;
    this.tokenType = data.token_type || 'bearer';
    this.expiresIn = data.expires_in;
    this.scope = data.scope;
    this.refreshToken = data.refresh_token;
    this.expiresAt = data.expires_at || new Date(Date.now() + (data.expires_in * 1000));
  }
  
  isExpired() {
    return new Date() >= this.expiresAt;
  }
  
  needsRefresh() {
    // Refresh if expires within 5 minutes
    const fiveMinutesFromNow = new Date(Date.now() + 5 * 60 * 1000);
    return this.expiresAt <= fiveMinutesFromNow;
  }
}

export class JMAPRequest {
  constructor(using, methodCalls) {
    this.using = using;
    this.methodCalls = methodCalls;
  }
  
  toJSON() {
    return {
      using: this.using,
      methodCalls: this.methodCalls
    };
  }
}

export class JMAPResponse {
  constructor(data) {
    this.methodResponses = data.methodResponses || [];
    this.sessionState = data.sessionState;
    this.createdIds = data.createdIds || {};
  }
  
  getMethodResponse(methodName, callId) {
    return this.methodResponses.find(response => 
      response[0] === methodName && response[2] === callId
    );
  }
  
  hasError() {
    return this.methodResponses.some(response => 
      response[0] === 'error'
    );
  }
  
  getErrors() {
    return this.methodResponses.filter(response => 
      response[0] === 'error'
    );
  }
}

export class SyncState {
  constructor(data) {
    this.accountId = data.accountId;
    this.lastSyncToken = data.lastSyncToken;
    this.lastSyncDate = data.lastSyncDate ? new Date(data.lastSyncDate) : null;
    this.totalEmailsSynced = data.totalEmailsSynced || 0;
    this.lastError = data.lastError;
    this.syncStatus = data.syncStatus || 'idle';
    this.createdAt = data.createdAt ? new Date(data.createdAt) : new Date();
    this.updatedAt = data.updatedAt ? new Date(data.updatedAt) : new Date();
  }
  
  updateSync(syncToken, emailCount) {
    this.lastSyncToken = syncToken;
    this.lastSyncDate = new Date();
    this.totalEmailsSynced += emailCount;
    this.syncStatus = 'completed';
    this.lastError = null;
    this.updatedAt = new Date();
  }
  
  setError(error) {
    this.lastError = error.message || error;
    this.syncStatus = 'error';
    this.updatedAt = new Date();
  }
  
  setSyncing() {
    this.syncStatus = 'syncing';
    this.updatedAt = new Date();
  }
}

export const SYNC_STATUS = {
  IDLE: 'idle',
  SYNCING: 'syncing',
  COMPLETED: 'completed',
  ERROR: 'error'
};

export const MAILBOX_ROLES = {
  INBOX: 'inbox',
  DRAFTS: 'drafts',
  SENT: 'sent',
  TRASH: 'trash',
  ARCHIVE: 'archive',
  SPAM: 'spam',
  JUNK: 'junk'
};

export const EMAIL_KEYWORDS = {
  SEEN: '$seen',
  FLAGGED: '$flagged',
  ANSWERED: '$answered',
  DRAFT: '$draft',
  DELETED: '$deleted',
  RECENT: '$recent'
};
