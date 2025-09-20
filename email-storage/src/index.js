/**
 * Email Storage Service Main Entry Point
 * Orchestrates all email storage services
 */

import { EmailSyncService } from './services/email-sync.js';
import { OAuthHandlerService } from './services/oauth-handler.js';
import { WebhookServer } from './api/webhook-server.js';
import dotenv from 'dotenv';
import winston from 'winston';

// Load environment variables
dotenv.config();

class EmailStorageService {
  constructor() {
    this.config = this.loadConfig();
    this.logger = this.setupLogger();
    this.services = {};
    this.isRunning = false;
  }

  loadConfig() {
    return {
      fastmail: {
        clientId: process.env.FASTMAIL_CLIENT_ID,
        clientSecret: process.env.FASTMAIL_CLIENT_SECRET,
        redirectUri: process.env.FASTMAIL_REDIRECT_URI || 'http://localhost:3001/auth/callback',
        scope: process.env.FASTMAIL_SCOPE || 'urn:ietf:params:jmap:core urn:ietf:params:jmap:mail urn:ietf:params:jmap:submission'
      },
      supabase: {
        url: process.env.SUPABASE_URL,
        anonKey: process.env.SUPABASE_ANON_KEY,
        serviceKey: process.env.SUPABASE_SERVICE_ROLE_KEY
      },
      sync: {
        intervalMinutes: parseInt(process.env.SYNC_INTERVAL_MINUTES) || 15,
        batchSize: parseInt(process.env.BATCH_SIZE) || 100,
        maxRetries: parseInt(process.env.MAX_RETRIES) || 3,
        retryDelayMs: parseInt(process.env.RETRY_DELAY_MS) || 5000
      },
      webhook: {
        secret: process.env.WEBHOOK_SECRET,
        port: parseInt(process.env.WEBHOOK_PORT) || 3002
      },
      oauth: {
        port: parseInt(process.env.OAUTH_PORT) || 3001
      },
      api: {
        port: parseInt(process.env.API_PORT) || 3003
      },
      logLevel: process.env.LOG_LEVEL || 'info',
      encryptionKey: process.env.ENCRYPTION_KEY,
      jwtSecret: process.env.JWT_SECRET
    };
  }

  setupLogger() {
    return winston.createLogger({
      level: this.config.logLevel,
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
          filename: 'logs/email-storage.log',
          maxsize: 10485760, // 10MB
          maxFiles: 5
        })
      ]
    });
  }

  async start() {
    try {
      this.logger.info('Starting Email Storage Service');
      
      // Validate configuration
      this.validateConfig();
      
      // Initialize services
      await this.initializeServices();
      
      // Start services
      await this.startServices();
      
      this.isRunning = true;
      this.logger.info('Email Storage Service started successfully');
      
      // Setup graceful shutdown
      this.setupGracefulShutdown();
      
    } catch (error) {
      this.logger.error('Failed to start Email Storage Service', { 
        error: error.message,
        stack: error.stack 
      });
      process.exit(1);
    }
  }

  validateConfig() {
    const required = [
      'FASTMAIL_CLIENT_ID',
      'FASTMAIL_CLIENT_SECRET',
      'SUPABASE_URL',
      'SUPABASE_SERVICE_ROLE_KEY'
    ];

    const missing = required.filter(key => !process.env[key]);
    
    if (missing.length > 0) {
      throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
    }

    this.logger.info('Configuration validated successfully');
  }

  async initializeServices() {
    this.logger.info('Initializing services');
    
    // Initialize sync service
    this.services.sync = new EmailSyncService(this.config);
    
    // Initialize OAuth handler
    this.services.oauth = new OAuthHandlerService(this.config);
    
    // Initialize webhook server
    this.services.webhook = new WebhookServer(this.config);
    
    this.logger.info('Services initialized successfully');
  }

  async startServices() {
    this.logger.info('Starting services');
    
    // Start OAuth handler
    await this.services.oauth.start(this.config.oauth.port);
    this.logger.info(`OAuth handler started on port ${this.config.oauth.port}`);
    
    // Start webhook server
    await this.services.webhook.start(this.config.webhook.port);
    this.logger.info(`Webhook server started on port ${this.config.webhook.port}`);
    
    // Start sync service
    await this.services.sync.start();
    this.logger.info('Email sync service started');
    
    this.logger.info('All services started successfully');
  }

  async stop() {
    if (!this.isRunning) {
      this.logger.warn('Service is not running');
      return;
    }

    this.logger.info('Stopping Email Storage Service');
    
    try {
      // Stop sync service
      if (this.services.sync) {
        await this.services.sync.stop();
        this.logger.info('Email sync service stopped');
      }
      
      // Stop webhook server
      if (this.services.webhook) {
        await this.services.webhook.stop();
        this.logger.info('Webhook server stopped');
      }
      
      // Stop OAuth handler
      if (this.services.oauth) {
        await this.services.oauth.stop();
        this.logger.info('OAuth handler stopped');
      }
      
      this.isRunning = false;
      this.logger.info('Email Storage Service stopped successfully');
      
    } catch (error) {
      this.logger.error('Error stopping services', { 
        error: error.message 
      });
    }
  }

  setupGracefulShutdown() {
    const signals = ['SIGTERM', 'SIGINT', 'SIGUSR2'];
    
    signals.forEach(signal => {
      process.on(signal, async () => {
        this.logger.info(`Received ${signal}, shutting down gracefully`);
        await this.stop();
        process.exit(0);
      });
    });
  }

  async getStatus() {
    const status = {
      running: this.isRunning,
      services: {},
      timestamp: new Date().toISOString()
    };

    // Check sync service status
    if (this.services.sync) {
      try {
        const syncHealth = await this.services.sync.getSyncHealthStatus();
        status.services.sync = {
          running: true,
          health: syncHealth
        };
      } catch (error) {
        status.services.sync = {
          running: false,
          error: error.message
        };
      }
    }

    // Check OAuth handler status
    status.services.oauth = {
      running: !!this.services.oauth,
      port: this.config.oauth.port
    };

    // Check webhook server status
    status.services.webhook = {
      running: !!this.services.webhook,
      port: this.config.webhook.port
    };

    return status;
  }
}

// Create and start the service
const emailStorageService = new EmailStorageService();

// Start the service
emailStorageService.start().catch(error => {
  console.error('Failed to start Email Storage Service:', error);
  process.exit(1);
});

export default emailStorageService;
