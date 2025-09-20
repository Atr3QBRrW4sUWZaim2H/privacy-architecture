/**
 * Email Sync Service
 * Handles synchronization of emails from Fastmail to Supabase
 */

import { FastmailJMAPClient } from '../lib/fastmail-client.js';
import { EmailStorageService } from '../lib/supabase-client.js';
import { SyncState, SYNC_STATUS } from '../types/fastmail.js';
import { EmailSyncStats } from '../types/email.js';
import winston from 'winston';

export class EmailSyncService {
  constructor(config) {
    this.config = config;
    this.fastmailClient = new FastmailJMAPClient(config.fastmail);
    this.storageService = new EmailStorageService(config.supabase);
    this.logger = this.setupLogger();
    this.isRunning = false;
    this.syncInterval = null;
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
          filename: 'logs/email-sync.log',
          maxsize: 10485760, // 10MB
          maxFiles: 5
        })
      ]
    });
  }

  /**
   * Start the sync service
   */
  async start() {
    if (this.isRunning) {
      this.logger.warn('Sync service is already running');
      return;
    }

    this.logger.info('Starting email sync service');
    this.isRunning = true;

    // Start periodic sync
    if (this.config.syncIntervalMinutes) {
      const intervalMs = this.config.syncIntervalMinutes * 60 * 1000;
      this.syncInterval = setInterval(() => {
        this.performSync().catch(error => {
          this.logger.error('Periodic sync failed', { error: error.message });
        });
      }, intervalMs);
      
      this.logger.info(`Periodic sync enabled: ${this.config.syncIntervalMinutes} minutes`);
    }

    // Perform initial sync
    await this.performSync();
  }

  /**
   * Stop the sync service
   */
  async stop() {
    if (!this.isRunning) {
      this.logger.warn('Sync service is not running');
      return;
    }

    this.logger.info('Stopping email sync service');
    this.isRunning = false;

    if (this.syncInterval) {
      clearInterval(this.syncInterval);
      this.syncInterval = null;
    }
  }

  /**
   * Perform a complete sync
   */
  async performSync() {
    const startTime = Date.now();
    const stats = new EmailSyncStats({});
    let accountInfo = null;
    
    try {
      this.logger.info('Starting email sync');
      
      // Validate Fastmail connection
      if (!await this.fastmailClient.validateToken()) {
        throw new Error('Invalid Fastmail access token');
      }

      // Get account info
      accountInfo = this.fastmailClient.getAccountInfo();
      if (!accountInfo) {
        throw new Error('Unable to get Fastmail account info');
      }

      const accountId = accountInfo.accountId;
      this.logger.info('Syncing account', { accountId });

      // Get current sync state
      let syncState = await this.storageService.getSyncState(accountId);
      if (!syncState) {
        this.logger.info('Initializing new sync state', { accountId });
        await this.storageService.supabase.rpc('initialize_sync_state', {
          account_id_param: accountId
        });
        syncState = await this.storageService.getSyncState(accountId);
      }

      // Update sync status to syncing
      await this.storageService.supabase.rpc('update_sync_progress', {
        account_id_param: accountId,
        sync_token: syncState.last_sync_token,
        emails_synced: 0,
        sync_status_param: SYNC_STATUS.SYNCING
      });

      // Sync mailboxes first
      await this.syncMailboxes(accountId, stats);

      // Sync emails
      await this.syncEmails(accountId, syncState.last_sync_token, stats);

      // Update sync state
      const syncDuration = Date.now() - startTime;
      stats.syncDuration = syncDuration;
      stats.lastSyncDate = new Date();

      await this.storageService.supabase.rpc('update_sync_progress', {
        account_id_param: accountId,
        sync_token: stats.lastSyncToken || syncState.last_sync_token,
        emails_synced: stats.newEmails + stats.updatedEmails,
        sync_status_param: SYNC_STATUS.COMPLETED
      });

      this.logger.info('Email sync completed', {
        duration: syncDuration,
        newEmails: stats.newEmails,
        updatedEmails: stats.updatedEmails,
        deletedEmails: stats.deletedEmails,
        successRate: stats.getSuccessRate()
      });

    } catch (error) {
      this.logger.error('Email sync failed', { error: error.message, stack: error.stack });
      stats.addError(error);

      // Record error in sync state
      if (accountInfo?.accountId) {
        await this.storageService.supabase.rpc('record_sync_error', {
          account_id_param: accountInfo.accountId,
          error_message: error.message
        });
      }

      throw error;
    }
  }

  /**
   * Sync mailboxes
   */
  async syncMailboxes(accountId, stats) {
    try {
      this.logger.info('Syncing mailboxes');
      
      const mailboxes = await this.fastmailClient.getMailboxes();
      if (mailboxes.length === 0) {
        this.logger.warn('No mailboxes found');
        return;
      }

      await this.storageService.storeMailboxes(mailboxes);
      
      this.logger.info('Mailboxes synced', { count: mailboxes.length });
    } catch (error) {
      this.logger.error('Mailbox sync failed', { error: error.message });
      stats.addError(error);
      throw error;
    }
  }

  /**
   * Sync emails
   */
  async syncEmails(accountId, lastSyncToken, stats) {
    try {
      this.logger.info('Syncing emails', { lastSyncToken });
      
      const batchSize = this.config.batchSize || 100;
      let hasMore = true;
      let offset = 0;
      let totalSynced = 0;

      while (hasMore) {
        const emails = await this.fastmailClient.getEmails({
          since: lastSyncToken,
          limit: batchSize
          // Note: Not passing sort parameter to avoid unsupportedSort error
        });

        if (emails.length === 0) {
          hasMore = false;
          break;
        }

        // Process emails in batches
        const batches = this.chunkArray(emails, batchSize);
        for (const batch of batches) {
          await this.processEmailBatch(batch, stats);
          totalSynced += batch.length;
        }

        offset += emails.length;
        
        // Check if we got fewer emails than requested (end of data)
        if (emails.length < batchSize) {
          hasMore = false;
        }

        // Update progress
        this.logger.debug('Email sync progress', {
          totalSynced,
          batchSize: emails.length,
          offset
        });
      }

      this.logger.info('Email sync completed', {
        totalSynced,
        newEmails: stats.newEmails,
        updatedEmails: stats.updatedEmails
      });

    } catch (error) {
      this.logger.error('Email sync failed', { error: error.message });
      stats.addError(error);
      throw error;
    }
  }

  /**
   * Process a batch of emails
   */
  async processEmailBatch(emails, stats) {
    try {
      const batchStartTime = Date.now();
      
      // Store emails in Supabase
      await this.storageService.storeEmails(emails);
      
      // Update statistics
      stats.newEmails += emails.length;
      stats.totalEmails += emails.length;

      const batchDuration = Date.now() - batchStartTime;
      this.logger.debug('Email batch processed', {
        count: emails.length,
        duration: batchDuration
      });

    } catch (error) {
      this.logger.error('Email batch processing failed', { 
        error: error.message,
        batchSize: emails.length 
      });
      stats.addError(error);
      throw error;
    }
  }

  /**
   * Sync specific email by ID
   */
  async syncEmailById(emailId) {
    try {
      this.logger.info('Syncing specific email', { emailId });
      
      const email = await this.fastmailClient.getEmailById(emailId);
      if (!email) {
        this.logger.warn('Email not found', { emailId });
        return null;
      }

      await this.storageService.storeEmail(email);
      
      this.logger.info('Email synced successfully', { emailId });
      return email;

    } catch (error) {
      this.logger.error('Email sync by ID failed', { 
        error: error.message,
        emailId 
      });
      throw error;
    }
  }

  /**
   * Get sync status
   */
  async getSyncStatus(accountId) {
    try {
      const syncState = await this.storageService.getSyncState(accountId);
      return syncState;
    } catch (error) {
      this.logger.error('Failed to get sync status', { 
        error: error.message,
        accountId 
      });
      throw error;
    }
  }

  /**
   * Get all sync statuses
   */
  async getAllSyncStatuses() {
    try {
      const { data, error } = await this.storageService.supabase
        .rpc('get_all_sync_status');

      if (error) {
        throw new Error(`Failed to get sync statuses: ${error.message}`);
      }

      return data;
    } catch (error) {
      this.logger.error('Failed to get all sync statuses', { error: error.message });
      throw error;
    }
  }

  /**
   * Get sync health status
   */
  async getSyncHealthStatus() {
    try {
      const { data, error } = await this.storageService.supabase
        .rpc('get_sync_health_status');

      if (error) {
        throw new Error(`Failed to get sync health: ${error.message}`);
      }

      return data[0]; // Return first (and only) result
    } catch (error) {
      this.logger.error('Failed to get sync health status', { error: error.message });
      throw error;
    }
  }

  /**
   * Reset sync state for an account
   */
  async resetSyncState(accountId, resetToken = null) {
    try {
      this.logger.info('Resetting sync state', { accountId, resetToken });
      
      await this.storageService.supabase.rpc('reset_sync_state', {
        account_id_param: accountId,
        reset_token: resetToken
      });

      this.logger.info('Sync state reset successfully', { accountId });
    } catch (error) {
      this.logger.error('Failed to reset sync state', { 
        error: error.message,
        accountId 
      });
      throw error;
    }
  }

  /**
   * Validate data integrity
   */
  async validateDataIntegrity() {
    try {
      this.logger.info('Validating data integrity');
      
      const { data, error } = await this.storageService.supabase
        .rpc('validate_email_integrity');

      if (error) {
        throw new Error(`Data integrity validation failed: ${error.message}`);
      }

      const results = data.map(result => ({
        check: result.check_name,
        result: result.check_result,
        issues: result.issue_count,
        details: result.details
      }));

      this.logger.info('Data integrity validation completed', { results });
      return results;

    } catch (error) {
      this.logger.error('Data integrity validation failed', { error: error.message });
      throw error;
    }
  }

  /**
   * Repair data integrity issues
   */
  async repairDataIntegrity() {
    try {
      this.logger.info('Repairing data integrity issues');
      
      const { data, error } = await this.storageService.supabase
        .rpc('repair_data_integrity');

      if (error) {
        throw new Error(`Data integrity repair failed: ${error.message}`);
      }

      const repairs = data.map(repair => ({
        action: repair.repair_action,
        itemsAffected: repair.items_affected,
        details: repair.details
      }));

      this.logger.info('Data integrity repair completed', { repairs });
      return repairs;

    } catch (error) {
      this.logger.error('Data integrity repair failed', { error: error.message });
      throw error;
    }
  }

  /**
   * Get sync performance metrics
   */
  async getSyncPerformanceMetrics(hoursBack = 24) {
    try {
      const { data, error } = await this.storageService.supabase
        .rpc('get_sync_performance_metrics', {
          hours_back: hoursBack
        });

      if (error) {
        throw new Error(`Failed to get performance metrics: ${error.message}`);
      }

      return data;
    } catch (error) {
      this.logger.error('Failed to get performance metrics', { error: error.message });
      throw error;
    }
  }

  /**
   * Utility function to chunk array
   */
  chunkArray(array, chunkSize) {
    const chunks = [];
    for (let i = 0; i < array.length; i += chunkSize) {
      chunks.push(array.slice(i, i + chunkSize));
    }
    return chunks;
  }

  /**
   * Test connection to both services
   */
  async testConnections() {
    const results = {
      fastmail: false,
      supabase: false,
      errors: []
    };

    try {
      // Test Fastmail connection
      await this.fastmailClient.getSession();
      results.fastmail = true;
    } catch (error) {
      results.errors.push(`Fastmail: ${error.message}`);
    }

    try {
      // Test Supabase connection
      await this.storageService.testConnection();
      results.supabase = true;
    } catch (error) {
      results.errors.push(`Supabase: ${error.message}`);
    }

    return results;
  }
}

