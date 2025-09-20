/**
 * OAuth Handler Service
 * Handles Fastmail OAuth 2.0 authentication flow
 */

import express from 'express';
import crypto from 'crypto';
import { FastmailJMAPClient } from '../lib/fastmail-client.js';
import { EmailStorageService } from '../lib/supabase-client.js';
import winston from 'winston';

export class OAuthHandlerService {
  constructor(config) {
    this.config = config;
    this.app = express();
    this.fastmailClient = new FastmailJMAPClient(config.fastmail);
    this.storageService = new EmailStorageService(config.supabase);
    this.logger = this.setupLogger();
    this.codeVerifiers = new Map(); // Store code verifiers temporarily
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
          filename: 'logs/oauth-handler.log',
          maxsize: 10485760, // 10MB
          maxFiles: 5
        })
      ]
    });
  }

  setupRoutes() {
    // Enable CORS
    this.app.use((req, res, next) => {
      res.header('Access-Control-Allow-Origin', '*');
      res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
      res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization');
      if (req.method === 'OPTIONS') {
        res.sendStatus(200);
      } else {
        next();
      }
    });

    this.app.use(express.json());

    // Health check endpoint
    this.app.get('/health', (req, res) => {
      res.json({ status: 'healthy', timestamp: new Date().toISOString() });
    });

    // Start OAuth flow
    this.app.get('/auth/start', this.startOAuthFlow.bind(this));

    // OAuth callback
    this.app.get('/auth/callback', this.handleOAuthCallback.bind(this));

    // Token refresh
    this.app.post('/auth/refresh', this.refreshToken.bind(this));

    // Get auth status
    this.app.get('/auth/status', this.getAuthStatus.bind(this));

    // Revoke token
    this.app.post('/auth/revoke', this.revokeToken.bind(this));

    // Error handling middleware
    this.app.use(this.errorHandler.bind(this));
  }

  /**
   * Start OAuth flow
   */
  async startOAuthFlow(req, res) {
    try {
      const state = crypto.randomBytes(32).toString('hex');
      const codeVerifier = this.generateCodeVerifier();
      
      // Store code verifier for later use
      this.codeVerifiers.set(state, codeVerifier);
      
      // Set expiration for code verifier (10 minutes)
      setTimeout(() => {
        this.codeVerifiers.delete(state);
      }, 10 * 60 * 1000);

      const authUrl = await this.fastmailClient.generateAuthUrl(state);
      
      this.logger.info('OAuth flow started', { state });
      
      res.json({
        authUrl,
        state,
        expiresIn: 600 // 10 minutes
      });

    } catch (error) {
      this.logger.error('Failed to start OAuth flow', { error: error.message });
      res.status(500).json({ error: 'Failed to start OAuth flow' });
    }
  }

  /**
   * Handle OAuth callback
   */
  async handleOAuthCallback(req, res) {
    try {
      const { code, state, error } = req.query;

      if (error) {
        this.logger.error('OAuth callback error', { error });
        return res.status(400).json({ error: 'OAuth authorization failed' });
      }

      if (!code || !state) {
        this.logger.error('Missing OAuth parameters', { code: !!code, state: !!state });
        return res.status(400).json({ error: 'Missing authorization code or state' });
      }

      // Retrieve code verifier
      const codeVerifier = this.codeVerifiers.get(state);
      if (!codeVerifier) {
        this.logger.error('Invalid or expired state', { state });
        return res.status(400).json({ error: 'Invalid or expired state parameter' });
      }

      // Exchange code for tokens
      const token = await this.fastmailClient.exchangeCodeForTokens(code, codeVerifier);
      
      // Clean up code verifier
      this.codeVerifiers.delete(state);

      // Get account info
      await this.fastmailClient.setAccessToken(token);
      const accountInfo = this.fastmailClient.getAccountInfo();

      // Store token securely (in production, use proper encryption)
      await this.storeToken(accountInfo.accountId, token);

      this.logger.info('OAuth flow completed successfully', { 
        accountId: accountInfo.accountId,
        username: accountInfo.username 
      });

      res.json({
        success: true,
        accountId: accountInfo.accountId,
        username: accountInfo.username,
        expiresAt: token.expiresAt
      });

    } catch (error) {
      this.logger.error('OAuth callback failed', { error: error.message });
      res.status(500).json({ error: 'OAuth callback failed' });
    }
  }

  /**
   * Refresh access token
   */
  async refreshToken(req, res) {
    try {
      const { accountId, refreshToken } = req.body;

      if (!accountId || !refreshToken) {
        return res.status(400).json({ error: 'Account ID and refresh token required' });
      }

      // Get stored token
      const storedToken = await this.getStoredToken(accountId);
      if (!storedToken) {
        return res.status(404).json({ error: 'No stored token found for account' });
      }

      // Refresh token
      const newToken = await this.fastmailClient.refreshAccessToken(refreshToken);
      
      // Update stored token
      await this.storeToken(accountId, newToken);

      this.logger.info('Token refreshed successfully', { accountId });

      res.json({
        success: true,
        accessToken: newToken.accessToken,
        expiresAt: newToken.expiresAt
      });

    } catch (error) {
      this.logger.error('Token refresh failed', { error: error.message });
      res.status(500).json({ error: 'Token refresh failed' });
    }
  }

  /**
   * Get authentication status
   */
  async getAuthStatus(req, res) {
    try {
      const { accountId } = req.query;

      if (!accountId) {
        return res.status(400).json({ error: 'Account ID required' });
      }

      const storedToken = await this.getStoredToken(accountId);
      if (!storedToken) {
        return res.json({ authenticated: false });
      }

      // Check if token is valid
      await this.fastmailClient.setAccessToken(storedToken);
      const isValid = await this.fastmailClient.validateToken();

      if (!isValid) {
        // Token is invalid, try to refresh
        if (storedToken.refreshToken) {
          try {
            const newToken = await this.fastmailClient.refreshAccessToken(storedToken.refreshToken);
            await this.storeToken(accountId, newToken);
            
            return res.json({
              authenticated: true,
              needsRefresh: false,
              expiresAt: newToken.expiresAt
            });
          } catch (refreshError) {
            this.logger.warn('Token refresh failed during status check', { 
              accountId,
              error: refreshError.message 
            });
            return res.json({ authenticated: false });
          }
        } else {
          return res.json({ authenticated: false });
        }
      }

      res.json({
        authenticated: true,
        needsRefresh: storedToken.needsRefresh(),
        expiresAt: storedToken.expiresAt
      });

    } catch (error) {
      this.logger.error('Failed to get auth status', { error: error.message });
      res.status(500).json({ error: 'Failed to get authentication status' });
    }
  }

  /**
   * Revoke token
   */
  async revokeToken(req, res) {
    try {
      const { accountId } = req.body;

      if (!accountId) {
        return res.status(400).json({ error: 'Account ID required' });
      }

      // Remove stored token
      await this.removeStoredToken(accountId);

      this.logger.info('Token revoked successfully', { accountId });

      res.json({ success: true });

    } catch (error) {
      this.logger.error('Token revocation failed', { error: error.message });
      res.status(500).json({ error: 'Token revocation failed' });
    }
  }

  /**
   * Store token securely
   */
  async storeToken(accountId, token) {
    try {
      // In production, encrypt the token before storing
      const encryptedToken = this.encryptToken(token);
      
      // First try to insert the token
      let { error } = await this.storageService.supabase
        .from('oauth_tokens')
        .insert({
          account_id: accountId,
          access_token: encryptedToken.accessToken,
          refresh_token: encryptedToken.refreshToken,
          token_type: token.tokenType,
          expires_at: token.expiresAt.toISOString(),
          scope: token.scope,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        });

      // If insert fails due to duplicate, try to update instead
      if (error && error.code === '23505') { // Unique violation
        console.log(`OAuth token for account ${accountId} already exists, updating...`);
        const { error: updateError } = await this.storageService.supabase
          .from('oauth_tokens')
          .update({
            access_token: encryptedToken.accessToken,
            refresh_token: encryptedToken.refreshToken,
            token_type: token.tokenType,
            expires_at: token.expiresAt.toISOString(),
            scope: token.scope,
            updated_at: new Date().toISOString()
          })
          .eq('account_id', accountId);
        
        if (updateError) {
          throw new Error(`Failed to update token: ${updateError.message}`);
        }
      } else if (error) {
        throw new Error(`Failed to store token: ${error.message}`);
      }

    } catch (error) {
      this.logger.error('Failed to store token', { 
        error: error.message,
        accountId 
      });
      throw error;
    }
  }

  /**
   * Get stored token
   */
  async getStoredToken(accountId) {
    try {
      const { data, error } = await this.storageService.supabase
        .from('oauth_tokens')
        .select('*')
        .eq('account_id', accountId)
        .single();

      if (error) {
        if (error.code === 'PGRST116') {
          return null; // Not found
        }
        throw new Error(`Failed to get stored token: ${error.message}`);
      }

      // Decrypt token
      return this.decryptToken(data);

    } catch (error) {
      this.logger.error('Failed to get stored token', { 
        error: error.message,
        accountId 
      });
      throw error;
    }
  }

  /**
   * Remove stored token
   */
  async removeStoredToken(accountId) {
    try {
      const { error } = await this.storageService.supabase
        .from('oauth_tokens')
        .delete()
        .eq('account_id', accountId);

      if (error) {
        throw new Error(`Failed to remove stored token: ${error.message}`);
      }

    } catch (error) {
      this.logger.error('Failed to remove stored token', { 
        error: error.message,
        accountId 
      });
      throw error;
    }
  }

  /**
   * Encrypt token (simple implementation - use proper encryption in production)
   */
  encryptToken(token) {
    // In production, use proper encryption like AES-256-GCM
    const key = this.config.encryptionKey || 'default-key-change-in-production';
    const cipher = crypto.createCipher('aes192', key);
    
    let encryptedAccessToken = cipher.update(token.accessToken, 'utf8', 'hex');
    encryptedAccessToken += cipher.final('hex');
    
    let encryptedRefreshToken = '';
    if (token.refreshToken) {
      const refreshCipher = crypto.createCipher('aes192', key);
      encryptedRefreshToken = refreshCipher.update(token.refreshToken, 'utf8', 'hex');
      encryptedRefreshToken += refreshCipher.final('hex');
    }

    return {
      accessToken: encryptedAccessToken,
      refreshToken: encryptedRefreshToken,
      tokenType: token.tokenType,
      expiresAt: token.expiresAt,
      scope: token.scope
    };
  }

  /**
   * Decrypt token (simple implementation - use proper decryption in production)
   */
  decryptToken(data) {
    // In production, use proper decryption
    const key = this.config.encryptionKey || 'default-key-change-in-production';
    
    const decipher = crypto.createDecipher('aes192', key);
    let decryptedAccessToken = decipher.update(data.access_token, 'hex', 'utf8');
    decryptedAccessToken += decipher.final('utf8');
    
    let decryptedRefreshToken = '';
    if (data.refresh_token) {
      const refreshDecipher = crypto.createDecipher('aes192', key);
      decryptedRefreshToken = refreshDecipher.update(data.refresh_token, 'hex', 'utf8');
      decryptedRefreshToken += refreshDecipher.final('utf8');
    }

    return {
      accessToken: decryptedAccessToken,
      refreshToken: decryptedRefreshToken,
      tokenType: data.token_type,
      expiresAt: new Date(data.expires_at),
      scope: data.scope
    };
  }

  /**
   * Generate code verifier for PKCE
   */
  generateCodeVerifier() {
    const array = new Uint8Array(32);
    crypto.getRandomValues(array);
    return Buffer.from(array).toString('base64url');
  }

  /**
   * Error handler middleware
   */
  errorHandler(error, req, res, next) {
    this.logger.error('OAuth handler error', { 
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
   * Start the OAuth handler server
   */
  start(port = 3001) {
    return new Promise((resolve, reject) => {
      try {
        this.server = this.app.listen(port, () => {
          this.logger.info(`OAuth handler started on port ${port}`);
          resolve();
        });
      } catch (error) {
        this.logger.error('Failed to start OAuth handler', { error: error.message });
        reject(error);
      }
    });
  }

  /**
   * Stop the OAuth handler server
   */
  stop() {
    return new Promise((resolve) => {
      if (this.server) {
        this.server.close(() => {
          this.logger.info('OAuth handler stopped');
          resolve();
        });
      } else {
        resolve();
      }
    });
  }
}
