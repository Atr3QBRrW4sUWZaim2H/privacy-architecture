#!/usr/bin/env node

/**
 * Email Storage Monitoring Script
 * Monitors the health and performance of email storage services
 */

import { EmailStorageService } from '../src/services/email-sync.js';
import { EmailStorageService as StorageService } from '../src/lib/supabase-client.js';
import dotenv from 'dotenv';
import winston from 'winston';

// Load environment variables
dotenv.config();

class EmailStorageMonitor {
  constructor() {
    this.config = this.loadConfig();
    this.logger = this.setupLogger();
    this.storageService = new StorageService(this.config.supabase);
  }

  loadConfig() {
    return {
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
        }),
        new winston.transports.File({ 
          filename: 'logs/monitor.log',
          maxsize: 10485760, // 10MB
          maxFiles: 5
        })
      ]
    });
  }

  async runHealthCheck() {
    this.logger.info('Running email storage health check');
    
    const health = {
      timestamp: new Date().toISOString(),
      overall: 'healthy',
      checks: {}
    };

    try {
      // Check database connection
      const dbHealth = await this.checkDatabaseHealth();
      health.checks.database = dbHealth;

      // Check sync status
      const syncHealth = await this.checkSyncHealth();
      health.checks.sync = syncHealth;

      // Check data integrity
      const integrityHealth = await this.checkDataIntegrity();
      health.checks.integrity = integrityHealth;

      // Check storage usage
      const storageHealth = await this.checkStorageUsage();
      health.checks.storage = storageHealth;

      // Determine overall health
      const allHealthy = Object.values(health.checks).every(check => check.status === 'healthy');
      health.overall = allHealthy ? 'healthy' : 'unhealthy';

      this.logger.info('Health check completed', { 
        overall: health.overall,
        checks: Object.keys(health.checks).length 
      });

      return health;

    } catch (error) {
      this.logger.error('Health check failed', { error: error.message });
      health.overall = 'error';
      health.error = error.message;
      return health;
    }
  }

  async checkDatabaseHealth() {
    try {
      const startTime = Date.now();
      await this.storageService.testConnection();
      const responseTime = Date.now() - startTime;

      return {
        status: 'healthy',
        responseTime: responseTime,
        timestamp: new Date().toISOString()
      };

    } catch (error) {
      return {
        status: 'unhealthy',
        error: error.message,
        timestamp: new Date().toISOString()
      };
    }
  }

  async checkSyncHealth() {
    try {
      const { data, error } = await this.storageService.supabase
        .rpc('get_sync_health_status');

      if (error) {
        throw new Error(`Sync health check failed: ${error.message}`);
      }

      const health = data[0];
      return {
        status: health.status.toLowerCase(),
        message: health.message,
        details: health.details,
        timestamp: new Date().toISOString()
      };

    } catch (error) {
      return {
        status: 'error',
        error: error.message,
        timestamp: new Date().toISOString()
      };
    }
  }

  async checkDataIntegrity() {
    try {
      const { data, error } = await this.storageService.supabase
        .rpc('validate_email_integrity');

      if (error) {
        throw new Error(`Data integrity check failed: ${error.message}`);
      }

      const issues = data.filter(check => check.check_result === 'FAIL');
      const status = issues.length === 0 ? 'healthy' : 'unhealthy';

      return {
        status,
        issues: issues.length,
        details: issues,
        timestamp: new Date().toISOString()
      };

    } catch (error) {
      return {
        status: 'error',
        error: error.message,
        timestamp: new Date().toISOString()
      };
    }
  }

  async checkStorageUsage() {
    try {
      const { data, error } = await this.storageService.supabase
        .rpc('get_email_stats');

      if (error) {
        throw new Error(`Storage usage check failed: ${error.message}`);
      }

      const stats = data[0];
      const totalSizeGB = (stats.total_size_bytes / (1024 * 1024 * 1024)).toFixed(2);
      
      // Determine status based on size thresholds
      let status = 'healthy';
      if (stats.total_size_bytes > 10 * 1024 * 1024 * 1024) { // 10GB
        status = 'warning';
      }
      if (stats.total_size_bytes > 50 * 1024 * 1024 * 1024) { // 50GB
        status = 'critical';
      }

      return {
        status,
        totalEmails: stats.total_emails,
        totalSizeBytes: stats.total_size_bytes,
        totalSizeGB: parseFloat(totalSizeGB),
        timestamp: new Date().toISOString()
      };

    } catch (error) {
      return {
        status: 'error',
        error: error.message,
        timestamp: new Date().toISOString()
      };
    }
  }

  async getPerformanceMetrics() {
    this.logger.info('Collecting performance metrics');
    
    try {
      const { data, error } = await this.storageService.supabase
        .rpc('get_sync_performance_metrics', {
          hours_back: 24
        });

      if (error) {
        throw new Error(`Performance metrics collection failed: ${error.message}`);
      }

      this.logger.info('Performance metrics collected', { 
        metrics: data.length 
      });

      return data;

    } catch (error) {
      this.logger.error('Performance metrics collection failed', { 
        error: error.message 
      });
      throw error;
    }
  }

  async getEmailStatistics() {
    this.logger.info('Collecting email statistics');
    
    try {
      const stats = await this.storageService.getEmailStats();
      
      this.logger.info('Email statistics collected', {
        totalEmails: stats.total,
        unreadEmails: stats.unread,
        flaggedEmails: stats.flagged
      });

      return stats;

    } catch (error) {
      this.logger.error('Email statistics collection failed', { 
        error: error.message 
      });
      throw error;
    }
  }

  async generateReport() {
    this.logger.info('Generating monitoring report');
    
    const report = {
      timestamp: new Date().toISOString(),
      health: await this.runHealthCheck(),
      performance: await this.getPerformanceMetrics(),
      statistics: await this.getEmailStatistics()
    };

    this.logger.info('Monitoring report generated', {
      healthStatus: report.health.overall,
      performanceMetrics: report.performance.length,
      totalEmails: report.statistics.total
    });

    return report;
  }

  async runContinuousMonitoring(intervalMinutes = 5) {
    this.logger.info(`Starting continuous monitoring (${intervalMinutes} minute intervals)`);
    
    const intervalMs = intervalMinutes * 60 * 1000;
    
    const monitor = async () => {
      try {
        const report = await this.generateReport();
        
        // Log critical issues
        if (report.health.overall !== 'healthy') {
          this.logger.warn('Health issues detected', {
            overall: report.health.overall,
            checks: report.health.checks
          });
        }

        // Log performance warnings
        const avgEmailsPerSync = report.performance.find(m => m.metric_name === 'avg_emails_per_sync');
        if (avgEmailsPerSync && avgEmailsPerSync.metric_value > 1000) {
          this.logger.warn('High email sync volume detected', {
            avgEmailsPerSync: avgEmailsPerSync.metric_value
          });
        }

      } catch (error) {
        this.logger.error('Continuous monitoring error', { 
          error: error.message 
        });
      }
    };

    // Run immediately
    await monitor();
    
    // Set up interval
    setInterval(monitor, intervalMs);
  }

  async repairDataIntegrity() {
    this.logger.info('Starting data integrity repair');
    
    try {
      const { data, error } = await this.storageService.supabase
        .rpc('repair_data_integrity');

      if (error) {
        throw new Error(`Data integrity repair failed: ${error.message}`);
      }

      this.logger.info('Data integrity repair completed', { 
        repairs: data.length 
      });

      return data;

    } catch (error) {
      this.logger.error('Data integrity repair failed', { 
        error: error.message 
      });
      throw error;
    }
  }

  async cleanupOldData(daysOld = 365) {
    this.logger.info(`Cleaning up data older than ${daysOld} days`);
    
    try {
      const { data, error } = await this.storageService.supabase
        .rpc('cleanup_old_emails', {
          days_old: daysOld,
          dry_run: false
        });

      if (error) {
        throw new Error(`Data cleanup failed: ${error.message}`);
      }

      this.logger.info('Data cleanup completed', { 
        action: data[0].action,
        emailCount: data[0].email_count,
        totalSizeBytes: data[0].total_size_bytes
      });

      return data[0];

    } catch (error) {
      this.logger.error('Data cleanup failed', { 
        error: error.message 
      });
      throw error;
    }
  }
}

// CLI interface
async function main() {
  const args = process.argv.slice(2);
  const command = args[0];
  const monitor = new EmailStorageMonitor();

  try {
    switch (command) {
      case 'health':
        const health = await monitor.runHealthCheck();
        console.log(JSON.stringify(health, null, 2));
        break;

      case 'report':
        const report = await monitor.generateReport();
        console.log(JSON.stringify(report, null, 2));
        break;

      case 'monitor':
        const interval = parseInt(args[1]) || 5;
        await monitor.runContinuousMonitoring(interval);
        break;

      case 'repair':
        const repairs = await monitor.repairDataIntegrity();
        console.log(JSON.stringify(repairs, null, 2));
        break;

      case 'cleanup':
        const days = parseInt(args[1]) || 365;
        const cleanup = await monitor.cleanupOldData(days);
        console.log(JSON.stringify(cleanup, null, 2));
        break;

      default:
        console.log(`
Email Storage Monitor

Usage: node scripts/monitor.js <command> [options]

Commands:
  health                    Run health check
  report                    Generate full monitoring report
  monitor [interval]        Run continuous monitoring (default: 5 minutes)
  repair                    Repair data integrity issues
  cleanup [days]            Clean up old data (default: 365 days)

Examples:
  node scripts/monitor.js health
  node scripts/monitor.js report
  node scripts/monitor.js monitor 10
  node scripts/monitor.js repair
  node scripts/monitor.js cleanup 180
        `);
        process.exit(1);
    }

  } catch (error) {
    console.error('Monitor command failed:', error.message);
    process.exit(1);
  }
}

// Run if called directly
if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}

export default EmailStorageMonitor;
