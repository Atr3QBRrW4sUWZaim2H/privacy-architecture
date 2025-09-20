/**
 * Fastmail JMAP Client
 * Implements API token authentication and JMAP API calls
 */

import axios from 'axios';
import { 
  JMAP_CAPABILITIES, 
  JMAP_METHODS, 
  JMAPSession, 
  FastmailEmail, 
  FastmailMailbox, 
  FastmailThread,
  JMAPRequest,
  JMAPResponse
} from '../types/fastmail.js';

export class FastmailJMAPClient {
  constructor(config) {
    this.apiToken = config.apiToken || config.clientId; // Use apiToken or fallback to clientId
    this.sessionUrl = 'https://api.fastmail.com/jmap/session';
    this.session = null;
    this.accountId = null;
  }

  /**
   * Validate API token by getting session
   */
  async validateToken() {
    try {
      await this.getSession();
      return true;
    } catch (error) {
      console.error('Token validation failed:', error.message);
      return false;
    }
  }

  /**
   * Generate PKCE code challenge
   */
  generateCodeChallenge() {
    const codeVerifier = this.generateCodeVerifier();
    const encoder = new TextEncoder();
    const data = encoder.encode(codeVerifier);
    return crypto.subtle.digest('SHA-256', data)
      .then(hash => {
        return btoa(String.fromCharCode(...new Uint8Array(hash)))
          .replace(/\+/g, '-')
          .replace(/\//g, '_')
          .replace(/=/g, '');
      });
  }

  /**
   * Generate PKCE code verifier
   */
  generateCodeVerifier() {
    const array = new Uint8Array(32);
    crypto.getRandomValues(array);
    return btoa(String.fromCharCode(...array))
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=/g, '');
  }

  /**
   * Exchange authorization code for tokens
   */
  async exchangeCodeForTokens(code, codeVerifier) {
    try {
      const response = await axios.post(this.tokenUrl, {
        client_id: this.clientId,
        redirect_uri: this.redirectUri,
        grant_type: 'authorization_code',
        code: code,
        code_verifier: codeVerifier
      }, {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        }
      });

      return new OAuthToken(response.data);
    } catch (error) {
      throw new Error(`Token exchange failed: ${error.response?.data?.error || error.message}`);
    }
  }

  /**
   * Refresh access token
   */
  async refreshAccessToken(refreshToken) {
    try {
      const response = await axios.post(this.tokenUrl, {
        client_id: this.clientId,
        grant_type: 'refresh_token',
        refresh_token: refreshToken
      }, {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        }
      });

      return new OAuthToken(response.data);
    } catch (error) {
      throw new Error(`Token refresh failed: ${error.response?.data?.error || error.message}`);
    }
  }

  /**
   * Set access token and get session
   */
  async setAccessToken(token) {
    this.accessToken = token;
    await this.getSession();
  }

  /**
   * Get JMAP session
   */
  async getSession() {
    if (!this.apiToken) {
      throw new Error('API token not set');
    }

    try {
      const response = await axios.get(this.sessionUrl, {
        headers: {
          'Authorization': `Bearer ${this.apiToken}`,
          'Content-Type': 'application/json'
        }
      });

      this.session = new JMAPSession(response.data);
      this.accountId = this.session.getAccountId();
      return this.session;
    } catch (error) {
      throw new Error(`Session fetch failed: ${error.response?.data?.error || error.message}`);
    }
  }

  /**
   * Make JMAP API call
   */
  async makeJMAPCall(using, methodCalls) {
    if (!this.session) {
      await this.getSession();
    }

    const request = new JMAPRequest(using, methodCalls);
    
    try {
      const response = await axios.post(this.session.apiUrl, request.toJSON(), {
        headers: {
          'Authorization': `Bearer ${this.apiToken}`,
          'Content-Type': 'application/json'
        }
      });

      return new JMAPResponse(response.data);
    } catch (error) {
      throw new Error(`JMAP call failed: ${error.response?.data?.error || error.message}`);
    }
  }

  /**
   * Get mailboxes
   */
  async getMailboxes() {
    const response = await this.makeJMAPCall(
      [JMAP_CAPABILITIES.CORE, JMAP_CAPABILITIES.MAIL],
      [
        [JMAP_METHODS.MAILBOX_GET, {
          accountId: this.accountId,
          ids: null
        }, 'get-mailboxes']
      ]
    );

    const methodResponse = response.getMethodResponse(JMAP_METHODS.MAILBOX_GET, 'get-mailboxes');
    if (methodResponse[0] === 'error') {
      throw new Error(`Get mailboxes failed: ${methodResponse[1]}`);
    }

    const mailboxes = methodResponse[1].list || [];
    return mailboxes.map(mb => new FastmailMailbox(mb));
  }

  /**
   * Get emails with optional filtering
   */
  async getEmails(options = {}) {
    const {
      mailboxIds = null,
      since = null,
      limit = 100,
      sort = [{ property: 'date', isAscending: false }]
    } = options;

    // First, query for email IDs
    const queryParams = {
      accountId: this.accountId,
      filter: {},
      sort: sort,
      limit: limit
    };

    if (mailboxIds) {
      queryParams.filter.inMailbox = mailboxIds;
    }

    if (since) {
      queryParams.filter.since = since;
    }

    const queryResponse = await this.makeJMAPCall(
      [JMAP_CAPABILITIES.CORE, JMAP_CAPABILITIES.MAIL],
      [
        [JMAP_METHODS.EMAIL_QUERY, queryParams, 'query-emails']
      ]
    );

    const queryMethodResponse = queryResponse.getMethodResponse(JMAP_METHODS.EMAIL_QUERY, 'query-emails');
    console.log('Query response:', JSON.stringify(queryResponse, null, 2));
    console.log('Query method response:', queryMethodResponse);
    if (!queryMethodResponse) {
      throw new Error('Email query failed: No response received');
    }
    if (queryMethodResponse[0] === 'error') {
      throw new Error(`Email query failed: ${queryMethodResponse[1]}`);
    }

    const emailIds = queryMethodResponse[1].ids || [];
    if (emailIds.length === 0) {
      return [];
    }

    // Then get the actual emails
    const getResponse = await this.makeJMAPCall(
      [JMAP_CAPABILITIES.CORE, JMAP_CAPABILITIES.MAIL],
      [
        [JMAP_METHODS.EMAIL_GET, {
          accountId: this.accountId,
          ids: emailIds,
          properties: [
            'id', 'threadId', 'mailboxIds', 'subject', 'from', 'to', 'cc', 'bcc', 'replyTo',
            'sentAt', 'receivedAt', 'messageId', 'inReplyTo', 'references', 'bodyValues',
            'attachments', 'keywords', 'size'
          ]
        }, 'get-emails']
      ]
    );

    const getMethodResponse = getResponse.getMethodResponse(JMAP_METHODS.EMAIL_GET, 'get-emails');
    if (!getMethodResponse) {
      throw new Error('Get emails failed: No response received');
    }
    if (getMethodResponse[0] === 'error') {
      throw new Error(`Get emails failed: ${getMethodResponse[1]}`);
    }

    const emails = getMethodResponse[1].list || [];
    return emails.map(email => new FastmailEmail(email));
  }

  /**
   * Get emails since last sync
   */
  async getEmailsSince(sinceToken, limit = 100) {
    return this.getEmails({
      since: sinceToken,
      limit: limit
    });
  }

  /**
   * Get email by ID
   */
  async getEmailById(emailId) {
    const response = await this.makeJMAPCall(
      [JMAP_CAPABILITIES.CORE, JMAP_CAPABILITIES.MAIL],
      [
        [JMAP_METHODS.EMAIL_GET, {
          accountId: this.accountId,
          ids: [emailId],
          properties: [
            'id', 'threadId', 'mailboxIds', 'subject', 'from', 'to', 'cc', 'bcc', 'replyTo',
            'sentAt', 'receivedAt', 'messageId', 'inReplyTo', 'references', 'bodyValues',
            'attachments', 'keywords', 'size'
          ]
        }, 'get-email']
      ]
    );

    const methodResponse = response.getMethodResponse(JMAP_METHODS.EMAIL_GET, 'get-email');
    if (methodResponse[0] === 'error') {
      throw new Error(`Get email failed: ${methodResponse[1]}`);
    }

    const emails = methodResponse[1].list || [];
    return emails.length > 0 ? new FastmailEmail(emails[0]) : null;
  }

  /**
   * Get threads
   */
  async getThreads(options = {}) {
    const {
      mailboxIds = null,
      since = null,
      limit = 100,
      sort = [{ property: 'date', isAscending: false }]
    } = options;

    const queryParams = {
      accountId: this.accountId,
      filter: {},
      sort: sort,
      limit: limit
    };

    if (mailboxIds) {
      queryParams.filter.inMailbox = mailboxIds;
    }

    if (since) {
      queryParams.filter.since = since;
    }

    const queryResponse = await this.makeJMAPCall(
      [JMAP_CAPABILITIES.CORE, JMAP_CAPABILITIES.MAIL],
      [
        [JMAP_METHODS.THREAD_QUERY, queryParams, 'query-threads']
      ]
    );

    const queryMethodResponse = queryResponse.getMethodResponse(JMAP_METHODS.THREAD_QUERY, 'query-threads');
    if (queryMethodResponse[0] === 'error') {
      throw new Error(`Thread query failed: ${queryMethodResponse[1]}`);
    }

    const threadIds = queryMethodResponse[1].ids || [];
    if (threadIds.length === 0) {
      return [];
    }

    const getResponse = await this.makeJMAPCall(
      [JMAP_CAPABILITIES.CORE, JMAP_CAPABILITIES.MAIL],
      [
        [JMAP_METHODS.THREAD_GET, {
          accountId: this.accountId,
          ids: threadIds,
          properties: ['id', 'emailIds', 'subject', 'mailboxIds']
        }, 'get-threads']
      ]
    );

    const getMethodResponse = getResponse.getMethodResponse(JMAP_METHODS.THREAD_GET, 'get-threads');
    if (getMethodResponse[0] === 'error') {
      throw new Error(`Get threads failed: ${getMethodResponse[1]}`);
    }

    const threads = getMethodResponse[1].list || [];
    return threads.map(thread => new FastmailThread(thread));
  }

  /**
   * Update email flags
   */
  async updateEmailFlags(emailId, flags) {
    const response = await this.makeJMAPCall(
      [JMAP_CAPABILITIES.CORE, JMAP_CAPABILITIES.MAIL],
      [
        [JMAP_METHODS.EMAIL_SET, {
          accountId: this.accountId,
          update: {
            [emailId]: {
              keywords: flags
            }
          }
        }, 'update-email']
      ]
    );

    const methodResponse = response.getMethodResponse(JMAP_METHODS.EMAIL_SET, 'update-email');
    if (methodResponse[0] === 'error') {
      throw new Error(`Update email failed: ${methodResponse[1]}`);
    }

    return methodResponse[1];
  }

  /**
   * Mark email as read
   */
  async markAsRead(emailId) {
    return this.updateEmailFlags(emailId, { '$seen': true });
  }

  /**
   * Mark email as unread
   */
  async markAsUnread(emailId) {
    return this.updateEmailFlags(emailId, { '$seen': false });
  }

  /**
   * Flag email
   */
  async flagEmail(emailId) {
    return this.updateEmailFlags(emailId, { '$flagged': true });
  }

  /**
   * Unflag email
   */
  async unflagEmail(emailId) {
    return this.updateEmailFlags(emailId, { '$flagged': false });
  }

  /**
   * Delete email
   */
  async deleteEmail(emailId) {
    return this.updateEmailFlags(emailId, { '$deleted': true });
  }

  /**
   * Get account information
   */
  getAccountInfo() {
    if (!this.session || !this.accountId) {
      return null;
    }

    return {
      accountId: this.accountId,
      username: this.session.username,
      capabilities: this.session.capabilities,
      apiUrl: this.session.apiUrl
    };
  }

  /**
   * Check if token is valid
   */
  async validateToken() {
    try {
      await this.getSession();
      return true;
    } catch (error) {
      return false;
    }
  }
}
