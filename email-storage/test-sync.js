#!/usr/bin/env node

import dotenv from 'dotenv';
import { EmailSyncService } from './src/services/email-sync.js';

dotenv.config();

console.log('Starting email sync test...');

const config = {
  fastmail: {
    apiToken: process.env.FASTMAIL_API_TOKEN
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
  logLevel: process.env.LOG_LEVEL || 'info'
};

console.log('Config loaded:', {
  fastmail: { apiToken: config.fastmail.apiToken ? '***' : 'missing' },
  supabase: { url: config.supabase.url, hasAnonKey: !!config.supabase.anonKey, hasServiceKey: !!config.supabase.serviceKey }
});

const syncService = new EmailSyncService(config);

// Test connections first
console.log('Testing connections...');
const connectionTest = await syncService.testConnections();
console.log('Connection test results:', connectionTest);

if (!connectionTest.fastmail || !connectionTest.supabase) {
  console.error('Connection test failed:', connectionTest.errors);
  process.exit(1);
}

console.log('Starting sync service...');
await syncService.start();

console.log('Sync service started successfully');
