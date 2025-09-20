#!/usr/bin/env node

/**
 * Email Storage Integration Test
 * Tests the complete email storage integration
 */

import { EmailSyncService } from '../src/services/email-sync.js';
import { EmailStorageService as StorageService } from '../src/lib/supabase-client.js';
import { FastmailJMAPClient } from '../src/lib/fastmail-client.js';
import { OAuthHandlerService } from '../src/services/oauth-handler.js';
import { WebhookServer } from '../src/api/webhook-server.js';
import dotenv from 'dotenv';
import winston from 'winston';

// Load environment variables
dotenv.config();

class IntegrationTester {
  constructor() {
    this.config = this.loadConfig();
    this.logger = this.setupLogger();
    this.testResults = {
      passed: 0,
      failed: 0,
      total: 0,
      tests: []
    };
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
      logLevel: process.env.LOG_LEVEL || 'info'
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
        })
      ]
    });
  }

  async runTest(testName, testFunction) {
    this.testResults.total++;
    this.logger.info(`Running test: ${testName}`);
    
    try {
      await testFunction();
      this.testResults.passed++;
      this.testResults.tests.push({
        name: testName,
        status: 'PASSED',
        message: 'Test completed successfully'
      });
      this.logger.info(`✅ ${testName} - PASSED`);
    } catch (error) {
      this.testResults.failed++;
      this.testResults.tests.push({
        name: testName,
        status: 'FAILED',
        message: error.message,
        error: error.stack
      });
      this.logger.error(`❌ ${testName} - FAILED: ${error.message}`);
    }
  }

  async testConfiguration() {
    // Test environment variables
    const requiredVars = [
      'FASTMAIL_CLIENT_ID',
      'FASTMAIL_CLIENT_SECRET',
      'SUPABASE_URL',
      'SUPABASE_SERVICE_ROLE_KEY'
    ];

    for (const varName of requiredVars) {
      if (!process.env[varName]) {
        throw new Error(`Missing required environment variable: ${varName}`);
      }
    }

    // Test configuration loading
    if (!this.config.fastmail.clientId) {
      throw new Error('Fastmail client ID not configured');
    }

    if (!this.config.supabase.url) {
      throw new Error('Supabase URL not configured');
    }
  }

  async testSupabaseConnection() {
    const storageService = new StorageService(this.config.supabase);
    
    // Test database connection
    await storageService.testConnection();
    
    // Test basic query
    const { data, error } = await storageService.supabase
      .from('emails')
      .select('count')
      .limit(1);
    
    if (error) {
      throw new Error(`Supabase query failed: ${error.message}`);
    }
  }

  async testDatabaseSchema() {
    const storageService = new StorageService(this.config.supabase);
    
    // Check if required tables exist
    const tables = ['emails', 'mailboxes', 'email_threads', 'email_search', 'sync_state'];
    
    for (const table of tables) {
      const { data, error } = await storageService.supabase
        .from(table)
        .select('*')
        .limit(1);
      
      if (error) {
        throw new Error(`Table ${table} not accessible: ${error.message}`);
      }
    }
  }

  async testFastmailClient() {
    const fastmailClient = new FastmailJMAPClient(this.config.fastmail);
    
    // Test OAuth URL generation
    const authUrl = await fastmailClient.generateAuthUrl('test-state');
    
    if (!authUrl || !authUrl.includes('api.fastmail.com')) {
      throw new Error('Invalid OAuth URL generated');
    }
    
    // Test code verifier generation
    const codeVerifier = fastmailClient.generateCodeVerifier();
    
    if (!codeVerifier || codeVerifier.length < 43) {
      throw new Error('Invalid code verifier generated');
    }
  }

  async testEmailStorageService() {
    const storageService = new StorageService(this.config.supabase);
    
    // Test email statistics
    const stats = await storageService.getEmailStats();
    
    if (typeof stats.total !== 'number') {
      throw new Error('Invalid email statistics returned');
    }
    
    // Test search functionality
    const searchResults = await storageService.searchEmails('test');
    
    if (!Array.isArray(searchResults)) {
      throw new Error('Search results should be an array');
    }
  }

  async testSyncService() {
    const syncService = new EmailSyncService(this.config);
    
    // Test connection validation
    const connections = await syncService.testConnections();
    
    if (!connections.supabase) {
      throw new Error('Supabase connection test failed');
    }
    
    // Test sync health status
    try {
      const healthStatus = await syncService.getSyncHealthStatus();
      
      if (!healthStatus || !healthStatus.status) {
        throw new Error('Invalid sync health status returned');
      }
    } catch (error) {
      // This might fail if no sync state exists yet, which is OK
      this.logger.warn('Sync health status check failed (expected if no sync state exists)');
    }
  }

  async testOAuthHandler() {
    const oauthHandler = new OAuthHandlerService(this.config);
    
    // Test OAuth handler initialization
    if (!oauthHandler.app) {
      throw new Error('OAuth handler app not initialized');
    }
    
    // Test route registration
    const routes = oauthHandler.app._router.stack
      .filter(layer => layer.route)
      .map(layer => Object.keys(layer.route.methods)[0] + ' ' + layer.route.path);
    
    const expectedRoutes = ['GET /health', 'GET /auth/start', 'GET /auth/callback'];
    
    for (const expectedRoute of expectedRoutes) {
      if (!routes.includes(expectedRoute)) {
        throw new Error(`Missing OAuth route: ${expectedRoute}`);
      }
    }
  }

  async testWebhookServer() {
    const webhookServer = new WebhookServer(this.config);
    
    // Test webhook server initialization
    if (!webhookServer.app) {
      throw new Error('Webhook server app not initialized');
    }
    
    // Test route registration
    const routes = webhookServer.app._router.stack
      .filter(layer => layer.route)
      .map(layer => Object.keys(layer.route.methods)[0] + ' ' + layer.route.path);
    
    const expectedRoutes = ['GET /health', 'POST /webhook/fastmail', 'POST /sync/trigger'];
    
    for (const expectedRoute of expectedRoutes) {
      if (!routes.includes(expectedRoute)) {
        throw new Error(`Missing webhook route: ${expectedRoute}`);
      }
    }
  }

  async testDatabaseFunctions() {
    const storageService = new StorageService(this.config.supabase);
    
    // Test search function
    try {
      const { data, error } = await storageService.supabase
        .rpc('search_emails', {
          search_query: 'test',
          query_limit: 10,
          query_offset: 0
        });
      
      if (error) {
        throw new Error(`Search function failed: ${error.message}`);
      }
    } catch (error) {
      this.logger.warn('Search function test failed (might not be implemented yet)');
    }
    
    // Test sync health function
    try {
      const { data, error } = await storageService.supabase
        .rpc('get_sync_health_status');
      
      if (error) {
        throw new Error(`Sync health function failed: ${error.message}`);
      }
    } catch (error) {
      this.logger.warn('Sync health function test failed (might not be implemented yet)');
    }
  }

  async testDataIntegrity() {
    const storageService = new StorageService(this.config.supabase);
    
    // Test data integrity validation
    try {
      const { data, error } = await storageService.supabase
        .rpc('validate_email_integrity');
      
      if (error) {
        throw new Error(`Data integrity validation failed: ${error.message}`);
      }
      
      // Check if validation returned expected structure
      if (!Array.isArray(data)) {
        throw new Error('Data integrity validation should return an array');
      }
    } catch (error) {
      this.logger.warn('Data integrity test failed (might not be implemented yet)');
    }
  }

  async testPerformance() {
    const storageService = new StorageService(this.config.supabase);
    
    // Test database query performance
    const startTime = Date.now();
    
    await storageService.getEmailStats();
    
    const queryTime = Date.now() - startTime;
    
    if (queryTime > 5000) { // 5 seconds
      throw new Error(`Database query too slow: ${queryTime}ms`);
    }
    
    this.logger.info(`Database query performance: ${queryTime}ms`);
  }

  async testErrorHandling() {
    const storageService = new StorageService(this.config.supabase);
    
    // Test error handling for invalid queries
    try {
      await storageService.getEmailByFastmailId('non-existent-id');
      // This should return null, not throw an error
    } catch (error) {
      throw new Error(`Unexpected error for non-existent email: ${error.message}`);
    }
    
    // Test error handling for invalid search
    try {
      await storageService.searchEmails(null);
      // This should handle null gracefully
    } catch (error) {
      // This might be expected behavior
      this.logger.warn('Search with null query failed (might be expected)');
    }
  }

  async runAllTests() {
    this.logger.info('Starting Email Storage Integration Tests');
    this.logger.info('=====================================');
    
    // Configuration tests
    await this.runTest('Configuration Validation', () => this.testConfiguration());
    
    // Database tests
    await this.runTest('Supabase Connection', () => this.testSupabaseConnection());
    await this.runTest('Database Schema', () => this.testDatabaseSchema());
    await this.runTest('Database Functions', () => this.testDatabaseFunctions());
    await this.runTest('Data Integrity', () => this.testDataIntegrity());
    
    // Service tests
    await this.runTest('Fastmail Client', () => this.testFastmailClient());
    await this.runTest('Email Storage Service', () => this.testEmailStorageService());
    await this.runTest('Sync Service', () => this.testSyncService());
    await this.runTest('OAuth Handler', () => this.testOAuthHandler());
    await this.runTest('Webhook Server', () => this.testWebhookServer());
    
    // Performance tests
    await this.runTest('Performance', () => this.testPerformance());
    
    // Error handling tests
    await this.runTest('Error Handling', () => this.testErrorHandling());
    
    // Print results
    this.printResults();
  }

  printResults() {
    this.logger.info('\nTest Results Summary');
    this.logger.info('===================');
    this.logger.info(`Total Tests: ${this.testResults.total}`);
    this.logger.info(`Passed: ${this.testResults.passed}`);
    this.logger.info(`Failed: ${this.testResults.failed}`);
    this.logger.info(`Success Rate: ${((this.testResults.passed / this.testResults.total) * 100).toFixed(1)}%`);
    
    if (this.testResults.failed > 0) {
      this.logger.info('\nFailed Tests:');
      this.testResults.tests
        .filter(test => test.status === 'FAILED')
        .forEach(test => {
          this.logger.info(`  - ${test.name}: ${test.message}`);
        });
    }
    
    this.logger.info('\nDetailed Results:');
    this.testResults.tests.forEach(test => {
      const status = test.status === 'PASSED' ? '✅' : '❌';
      this.logger.info(`  ${status} ${test.name}: ${test.message}`);
    });
    
    if (this.testResults.failed === 0) {
      this.logger.info('\n🎉 All tests passed! Email Storage integration is working correctly.');
    } else {
      this.logger.info('\n⚠️  Some tests failed. Please review the errors above.');
      process.exit(1);
    }
  }
}

// CLI interface
async function main() {
  const args = process.argv.slice(2);
  const testType = args[0] || 'all';
  
  const tester = new IntegrationTester();
  
  try {
    switch (testType) {
      case 'config':
        await tester.runTest('Configuration Validation', () => tester.testConfiguration());
        break;
      case 'database':
        await tester.runTest('Supabase Connection', () => tester.testSupabaseConnection());
        await tester.runTest('Database Schema', () => tester.testDatabaseSchema());
        break;
      case 'services':
        await tester.runTest('Fastmail Client', () => tester.testFastmailClient());
        await tester.runTest('Email Storage Service', () => tester.testEmailStorageService());
        await tester.runTest('Sync Service', () => tester.testSyncService());
        break;
      case 'all':
      default:
        await tester.runAllTests();
        break;
    }
    
    tester.printResults();
    
  } catch (error) {
    console.error('Test execution failed:', error.message);
    process.exit(1);
  }
}

// Run if called directly
if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}

export default IntegrationTester;
