/**
 * Webhook Server
 * Handles webhooks from Fastmail and other services
 */

import express from 'express';
import crypto from 'crypto';
import { EmailSyncService } from '../services/email-sync.js';
import winston from 'winston';

export class WebhookServer {
  constructor(config) {
    this.config = config;
    this.app = express();
    this.syncService = new EmailSyncService(config);
    this.logger = this.setupLogger();
    this.setupMiddleware();
    this.setupRoutes();
  }

  setupLogger() {
    return winston.createLogger({
      level: this.config.logLevel || 'info',
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.errors({ stack: true }),
        winston.format.json()
      ),
      transports: [
        new winston.transports.Console({
          format: winston.format.combine(
            winston.format.colorize(),
            winston.format.simple()
          )
        }),
        new winston.transports.File({ 
          filename: 'logs/webhook-server.log',
          maxsize: 10485760, // 10MB
          maxFiles: 5
        })
      ]
    });
  }

  setupMiddleware() {
    // Raw body parser for webhook verification
    this.app.use('/webhook', express.raw({ type: 'application/json' }));
    
    // JSON parser for other routes
    this.app.use(express.json());
    
    // CORS
    this.app.use((req, res, next) => {
      res.header('Access-Control-Allow-Origin', '*');
      res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
      res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization, X-Webhook-Signature');
      if (req.method === 'OPTIONS') {
        res.sendStatus(200);
      } else {
        next();
      }
    });

    // Request logging
    this.app.use((req, res, next) => {
      this.logger.info('Webhook request', {
        method: req.method,
        url: req.url,
        ip: req.ip,
        userAgent: req.get('User-Agent')
      });
      next();
    });
  }

  setupRoutes() {
    // Health check
    this.app.get('/health', (req, res) => {
      res.json({ 
        status: 'healthy', 
        timestamp: new Date().toISOString(),
        service: 'webhook-server'
      });
    });

    // Fastmail webhook
    this.app.post('/webhook/fastmail', this.handleFastmailWebhook.bind(this));

    // Generic webhook handler
    this.app.post('/webhook/generic', this.handleGenericWebhook.bind(this));

    // Manual sync trigger
    this.app.post('/sync/trigger', this.triggerSync.bind(this));

    // Sync status
    this.app.get('/sync/status', this.getSyncStatus.bind(this));

    // Error handling
    this.app.use(this.errorHandler.bind(this));
  }

  /**
   * Handle Fastmail webhook
   */
  async handleFastmailWebhook(req, res) {
    try {
      // Verify webhook signature
      if (!this.verifyWebhookSignature(req)) {
        this.logger.warn('Invalid webhook signature');
        return res.status(401).json({ error: 'Invalid signature' });
      }

      const payload = JSON.parse(req.body);
      this.logger.info('Fastmail webhook received', { 
        type: payload.type,
        accountId: payload.accountId 
      });

      // Process webhook based on type
      switch (payload.type) {
        case 'email.received':
          await this.handleEmailReceived(payload);
          break;
        case 'email.updated':
          await this.handleEmailUpdated(payload);
          break;
        case 'email.deleted':
          await this.handleEmailDeleted(payload);
          break;
        case 'mailbox.updated':
          await this.handleMailboxUpdated(payload);
          break;
        default:
          this.logger.warn('Unknown webhook type', { type: payload.type });
      }

      res.json({ success: true });

    } catch (error) {
      this.logger.error('Fastmail webhook processing failed', { 
        error: error.message,
        stack: error.stack 
      });
      res.status(500).json({ error: 'Webhook processing failed' });
    }
  }

  /**
   * Handle generic webhook
   */
  async handleGenericWebhook(req, res) {
    try {
      const payload = req.body;
      this.logger.info('Generic webhook received', { 
        source: req.get('X-Webhook-Source'),
        type: payload.type 
      });

      // Process based on source
      const source = req.get('X-Webhook-Source');
      switch (source) {
        case 'fastmail':
          await this.handleFastmailWebhook(req, res);
          return;
        default:
          this.logger.warn('Unknown webhook source', { source });
          res.status(400).json({ error: 'Unknown webhook source' });
      }

    } catch (error) {
      this.logger.error('Generic webhook processing failed', { 
        error: error.message 
      });
      res.status(500).json({ error: 'Webhook processing failed' });
    }
  }

  /**
   * Handle email received event
   */
  async handleEmailReceived(payload) {
    try {
      const { accountId, emailId } = payload;
      
      this.logger.info('Processing email received event', { accountId, emailId });
      
      // Sync the specific email
      await this.syncService.syncEmailById(emailId);
      
      this.logger.info('Email received event processed successfully', { accountId, emailId });

    } catch (error) {
      this.logger.error('Failed to process email received event', { 
        error: error.message,
        payload 
      });
      throw error;
    }
  }

  /**
   * Handle email updated event
   */
  async handleEmailUpdated(payload) {
    try {
      const { accountId, emailId, changes } = payload;
      
      this.logger.info('Processing email updated event', { 
        accountId, 
        emailId, 
        changes: Object.keys(changes) 
      });
      
      // Sync the updated email
      await this.syncService.syncEmailById(emailId);
      
      this.logger.info('Email updated event processed successfully', { accountId, emailId });

    } catch (error) {
      this.logger.error('Failed to process email updated event', { 
        error: error.message,
        payload 
      });
      throw error;
    }
  }

  /**
   * Handle email deleted event
   */
  async handleEmailDeleted(payload) {
    try {
      const { accountId, emailId } = payload;
      
      this.logger.info('Processing email deleted event', { accountId, emailId });
      
      // Mark email as deleted in database
      await this.syncService.storageService.supabase
        .from('emails')
        .update({ is_deleted: true, updated_at: new Date().toISOString() })
        .eq('fastmail_id', emailId);
      
      this.logger.info('Email deleted event processed successfully', { accountId, emailId });

    } catch (error) {
      this.logger.error('Failed to process email deleted event', { 
        error: error.message,
        payload 
      });
      throw error;
    }
  }

  /**
   * Handle mailbox updated event
   */
  async handleMailboxUpdated(payload) {
    try {
      const { accountId, mailboxId } = payload;
      
      this.logger.info('Processing mailbox updated event', { accountId, mailboxId });
      
      // Trigger full sync to update mailbox statistics
      await this.syncService.performSync();
      
      this.logger.info('Mailbox updated event processed successfully', { accountId, mailboxId });

    } catch (error) {
      this.logger.error('Failed to process mailbox updated event', { 
        error: error.message,
        payload 
      });
      throw error;
    }
  }

  /**
   * Trigger manual sync
   */
  async triggerSync(req, res) {
    try {
      const { accountId, force = false } = req.body;
      
      this.logger.info('Manual sync triggered', { accountId, force });
      
      if (force) {
        // Reset sync state and perform full sync
        await this.syncService.resetSyncState(accountId);
      }
      
      await this.syncService.performSync();
      
      res.json({ 
        success: true, 
        message: 'Sync triggered successfully' 
      });

    } catch (error) {
      this.logger.error('Manual sync trigger failed', { 
        error: error.message 
      });
      res.status(500).json({ error: 'Sync trigger failed' });
    }
  }

  /**
   * Get sync status
   */
  async getSyncStatus(req, res) {
    try {
      const { accountId } = req.query;
      
      if (accountId) {
        const status = await this.syncService.getSyncStatus(accountId);
        res.json(status);
      } else {
        const allStatuses = await this.syncService.getAllSyncStatuses();
        res.json(allStatuses);
      }

    } catch (error) {
      this.logger.error('Failed to get sync status', { 
        error: error.message 
      });
      res.status(500).json({ error: 'Failed to get sync status' });
    }
  }

  /**
   * Verify webhook signature
   */
  verifyWebhookSignature(req) {
    const signature = req.get('X-Webhook-Signature');
    if (!signature) {
      return false;
    }

    const secret = this.config.webhookSecret;
    if (!secret) {
      this.logger.warn('No webhook secret configured');
      return false;
    }

    const expectedSignature = crypto
      .createHmac('sha256', secret)
      .update(req.body)
      .digest('hex');

    const providedSignature = signature.replace('sha256=', '');
    
    return crypto.timingSafeEqual(
      Buffer.from(expectedSignature, 'hex'),
      Buffer.from(providedSignature, 'hex')
    );
  }

  /**
   * Error handler middleware
   */
  errorHandler(error, req, res, next) {
    this.logger.error('Webhook server error', { 
      error: error.message,
      stack: error.stack,
      url: req.url,
      method: req.method
    });

    res.status(500).json({ 
      error: 'Internal server error',
      message: error.message 
    });
  }

  /**
   * Start the webhook server
   */
  start(port = 3002) {
    return new Promise((resolve, reject) => {
      try {
        this.server = this.app.listen(port, () => {
          this.logger.info(`Webhook server started on port ${port}`);
          resolve();
        });
      } catch (error) {
        this.logger.error('Failed to start webhook server', { error: error.message });
        reject(error);
      }
    });
  }

  /**
   * Stop the webhook server
   */
  stop() {
    return new Promise((resolve) => {
      if (this.server) {
        this.server.close(() => {
          this.logger.info('Webhook server stopped');
          resolve();
        });
      } else {
        resolve();
      }
    });
  }
}
