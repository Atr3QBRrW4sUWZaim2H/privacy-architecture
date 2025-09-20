/**
 * Supabase Client for Email Storage
 * Handles all database operations for email storage
 */

import { createClient } from '@supabase/supabase-js';
import { 
  StoredEmail, 
  StoredMailbox, 
  EmailSearchResult, 
  EmailSearchQuery,
  EmailSyncStats,
  EmailThread
} from '../types/email.js';

export class EmailStorageService {
  constructor(config) {
    this.supabase = createClient(config.url, config.serviceKey);
    this.anonSupabase = createClient(config.url, config.anonKey);
  }

  /**
   * Store email in database
   */
  async storeEmail(email) {
    try {
      const storedEmail = email instanceof StoredEmail ? email : StoredEmail.fromFastmailEmail(email);
      const row = storedEmail.toSupabaseRow();

      // First try to insert the email
      let { data, error } = await this.supabase
        .from('emails')
        .insert(row)
        .select()
        .single();

      // If insert fails due to duplicate, try to update instead
      if (error && error.code === '23505') { // Unique violation
        console.log(`Email ${row.fastmail_id} already exists, updating...`);
        const { data: updateData, error: updateError } = await this.supabase
          .from('emails')
          .update(row)
          .eq('fastmail_id', row.fastmail_id)
          .select()
          .single();
        
        if (updateError) {
          throw new Error(`Failed to update email: ${updateError.message}`);
        }
        data = updateData;
      } else if (error) {
        throw new Error(`Failed to store email: ${error.message}`);
      }

      // Update search index
      await this.updateSearchIndex(data.id, storedEmail);

      return data;
    } catch (error) {
      throw new Error(`Email storage failed: ${error.message}`);
    }
  }

  /**
   * Store multiple emails in batch
   */
  async storeEmails(emails) {
    try {
      const results = [];
      
      // Process emails one by one to handle conflicts properly
      for (const email of emails) {
        try {
          const storedEmail = email instanceof StoredEmail ? email : StoredEmail.fromFastmailEmail(email);
          const row = storedEmail.toSupabaseRow();
          
          // First try to insert the email
          let { data, error } = await this.supabase
            .from('emails')
            .insert(row)
            .select()
            .single();
          
          // If insert fails due to duplicate, try to update instead
          if (error && error.code === '23505') { // Unique violation
            console.log(`Email ${row.fastmail_id} already exists, updating...`);
            const { data: updateData, error: updateError } = await this.supabase
              .from('emails')
              .update(row)
              .eq('fastmail_id', row.fastmail_id)
              .select()
              .single();
            
            if (updateError) {
              console.error(`Failed to update email ${row.fastmail_id}:`, updateError);
              continue;
            }
            data = updateData;
          } else if (error) {
            console.error(`Failed to store email ${row.fastmail_id}:`, error);
            continue;
          }
          
          if (data) {
            results.push(data);
            // Update search index
            await this.updateSearchIndex(data.id, storedEmail);
          }
        } catch (emailError) {
          console.error(`Error processing email:`, emailError);
          continue;
        }
      }

      return results;
    } catch (error) {
      throw new Error(`Batch email storage failed: ${error.message}`);
    }
  }

  /**
   * Store mailbox in database
   */
  async storeMailbox(mailbox) {
    try {
      const storedMailbox = mailbox instanceof StoredMailbox ? mailbox : StoredMailbox.fromFastmailMailbox(mailbox);
      const row = storedMailbox.toSupabaseRow();

      // First try to insert the mailbox
      let { data, error } = await this.supabase
        .from('mailboxes')
        .insert(row)
        .select()
        .single();

      // If insert fails due to duplicate, try to update instead
      if (error && error.code === '23505') { // Unique violation
        console.log(`Mailbox ${row.fastmail_id} already exists, updating...`);
        const { data: updateData, error: updateError } = await this.supabase
          .from('mailboxes')
          .update(row)
          .eq('fastmail_id', row.fastmail_id)
          .select()
          .single();
        
        if (updateError) {
          throw new Error(`Failed to update mailbox: ${updateError.message}`);
        }
        data = updateData;
      } else if (error) {
        throw new Error(`Failed to store mailbox: ${error.message}`);
      }

      return data;
    } catch (error) {
      throw new Error(`Mailbox storage failed: ${error.message}`);
    }
  }

  /**
   * Store multiple mailboxes in batch
   */
  async storeMailboxes(mailboxes) {
    try {
      const rows = mailboxes.map(mailbox => {
        const storedMailbox = mailbox instanceof StoredMailbox ? mailbox : StoredMailbox.fromFastmailMailbox(mailbox);
        return storedMailbox.toSupabaseRow();
      });

      // Process mailboxes one by one to handle conflicts properly
      const results = [];
      for (const row of rows) {
        try {
          // First try to insert the mailbox
          let { data, error } = await this.supabase
            .from('mailboxes')
            .insert(row)
            .select()
            .single();

          // If insert fails due to duplicate, try to update instead
          if (error && error.code === '23505') { // Unique violation
            console.log(`Mailbox ${row.fastmail_id} already exists, updating...`);
            const { data: updateData, error: updateError } = await this.supabase
              .from('mailboxes')
              .update(row)
              .eq('fastmail_id', row.fastmail_id)
              .select()
              .single();
            
            if (updateError) {
              console.error(`Failed to update mailbox ${row.fastmail_id}:`, updateError);
              continue;
            }
            data = updateData;
          } else if (error) {
            console.error(`Failed to store mailbox ${row.fastmail_id}:`, error);
            continue;
          }
          
          if (data) {
            results.push(data);
          }
        } catch (mailboxError) {
          console.error(`Error processing mailbox:`, mailboxError);
          continue;
        }
      }
      
      const data = results;

      return data;
    } catch (error) {
      throw new Error(`Batch mailbox storage failed: ${error.message}`);
    }
  }

  /**
   * Store thread in database
   */
  async storeThread(thread) {
    try {
      const storedThread = thread instanceof EmailThread ? thread : EmailThread.fromFastmailThread(thread);
      const row = storedThread.toSupabaseRow();

      // First try to insert the thread
      let { data, error } = await this.supabase
        .from('email_threads')
        .insert(row)
        .select()
        .single();

      // If insert fails due to duplicate, try to update instead
      if (error && error.code === '23505') { // Unique violation
        console.log(`Thread ${row.id} already exists, updating...`);
        const { data: updateData, error: updateError } = await this.supabase
          .from('email_threads')
          .update(row)
          .eq('id', row.id)
          .select()
          .single();
        
        if (updateError) {
          throw new Error(`Failed to update thread: ${updateError.message}`);
        }
        data = updateData;
      } else if (error) {
        throw new Error(`Failed to store thread: ${error.message}`);
      }

      return data;
    } catch (error) {
      throw new Error(`Thread storage failed: ${error.message}`);
    }
  }

  /**
   * Search emails using full-text search
   */
  async searchEmails(searchQuery) {
    try {
      const query = searchQuery instanceof EmailSearchQuery ? searchQuery : new EmailSearchQuery(searchQuery);
      const supabaseQuery = query.toSupabaseQuery();

      const { data, error } = await this.supabase
        .rpc('search_emails', supabaseQuery);

      if (error) {
        throw new Error(`Email search failed: ${error.message}`);
      }

      return data.map(result => new EmailSearchResult(result));
    } catch (error) {
      throw new Error(`Search failed: ${error.message}`);
    }
  }

  /**
   * Get email by Fastmail ID
   */
  async getEmailByFastmailId(fastmailId) {
    try {
      const { data, error } = await this.supabase
        .from('emails')
        .select('*')
        .eq('fastmail_id', fastmailId)
        .single();

      if (error) {
        if (error.code === 'PGRST116') {
          return null; // Not found
        }
        throw new Error(`Failed to get email: ${error.message}`);
      }

      return new StoredEmail(data);
    } catch (error) {
      throw new Error(`Get email failed: ${error.message}`);
    }
  }

  /**
   * Get emails by mailbox
   */
  async getEmailsByMailbox(mailboxId, options = {}) {
    try {
      const {
        limit = 50,
        offset = 0,
        sortBy = 'date_received',
        sortOrder = 'desc'
      } = options;

      let query = this.supabase
        .from('emails')
        .select('*')
        .eq('mailbox_id', mailboxId)
        .order(sortBy, { ascending: sortOrder === 'asc' })
        .range(offset, offset + limit - 1);

      const { data, error } = await query;

      if (error) {
        throw new Error(`Failed to get emails: ${error.message}`);
      }

      return data.map(email => new StoredEmail(email));
    } catch (error) {
      throw new Error(`Get emails by mailbox failed: ${error.message}`);
    }
  }

  /**
   * Get mailbox by Fastmail ID
   */
  async getMailboxByFastmailId(fastmailId) {
    try {
      const { data, error } = await this.supabase
        .from('mailboxes')
        .select('*')
        .eq('fastmail_id', fastmailId)
        .single();

      if (error) {
        if (error.code === 'PGRST116') {
          return null; // Not found
        }
        throw new Error(`Failed to get mailbox: ${error.message}`);
      }

      return new StoredMailbox(data);
    } catch (error) {
      throw new Error(`Get mailbox failed: ${error.message}`);
    }
  }

  /**
   * Get all mailboxes
   */
  async getMailboxes() {
    try {
      const { data, error } = await this.supabase
        .from('mailboxes')
        .select('*')
        .order('sort_order');

      if (error) {
        throw new Error(`Failed to get mailboxes: ${error.message}`);
      }

      return data.map(mailbox => new StoredMailbox(mailbox));
    } catch (error) {
      throw new Error(`Get mailboxes failed: ${error.message}`);
    }
  }

  /**
   * Update sync state
   */
  async updateSyncState(accountId, syncData) {
    try {
      const { data, error } = await this.supabase
        .from('sync_state')
        .upsert({
          account_id: accountId,
          last_sync_token: syncData.lastSyncToken,
          last_sync_date: syncData.lastSyncDate?.toISOString(),
          total_emails_synced: syncData.totalEmailsSynced,
          last_error: syncData.lastError,
          sync_status: syncData.syncStatus
        }, {
          onConflict: 'account_id'
        })
        .select()
        .single();

      if (error) {
        throw new Error(`Failed to update sync state: ${error.message}`);
      }

      return data;
    } catch (error) {
      throw new Error(`Sync state update failed: ${error.message}`);
    }
  }

  /**
   * Get sync state
   */
  async getSyncState(accountId) {
    try {
      const { data, error } = await this.supabase
        .from('sync_state')
        .select('*')
        .eq('account_id', accountId)
        .single();

      if (error) {
        if (error.code === 'PGRST116') {
          return null; // Not found
        }
        throw new Error(`Failed to get sync state: ${error.message}`);
      }

      return data;
    } catch (error) {
      throw new Error(`Get sync state failed: ${error.message}`);
    }
  }

  /**
   * Update search index for email
   */
  async updateSearchIndex(emailId, email) {
    try {
      const searchContent = [
        email.subject || '',
        email.fromAddress || '',
        email.textBody || '',
        email.bodyHtml || ''
      ].join(' ');

      const { error } = await this.supabase
        .from('email_search')
        .upsert({
          email_id: emailId,
          search_vector: searchContent,
          content_hash: this.generateContentHash(searchContent)
        }, {
          onConflict: 'email_id'
        });

      if (error) {
        throw new Error(`Failed to update search index: ${error.message}`);
      }
    } catch (error) {
      console.warn(`Search index update failed: ${error.message}`);
    }
  }

  /**
   * Generate content hash for change detection
   */
  generateContentHash(content) {
    const crypto = require('crypto');
    return crypto.createHash('md5').update(content).digest('hex');
  }

  /**
   * Get email statistics
   */
  async getEmailStats() {
    try {
      const { data, error } = await this.supabase
        .from('emails')
        .select('is_read, is_flagged, is_deleted, mailbox_id, date_received')
        .eq('is_deleted', false);

      if (error) {
        throw new Error(`Failed to get email stats: ${error.message}`);
      }

      const stats = {
        total: data.length,
        unread: data.filter(email => !email.is_read).length,
        flagged: data.filter(email => email.is_flagged).length,
        byMailbox: {},
        byMonth: {}
      };

      // Group by mailbox
      data.forEach(email => {
        const mailboxId = email.mailbox_id;
        if (!stats.byMailbox[mailboxId]) {
          stats.byMailbox[mailboxId] = { total: 0, unread: 0 };
        }
        stats.byMailbox[mailboxId].total++;
        if (!email.is_read) {
          stats.byMailbox[mailboxId].unread++;
        }
      });

      // Group by month
      data.forEach(email => {
        if (email.date_received) {
          const month = new Date(email.date_received).toISOString().substring(0, 7);
          if (!stats.byMonth[month]) {
            stats.byMonth[month] = 0;
          }
          stats.byMonth[month]++;
        }
      });

      return stats;
    } catch (error) {
      throw new Error(`Get email stats failed: ${error.message}`);
    }
  }

  /**
   * Delete email by Fastmail ID
   */
  async deleteEmailByFastmailId(fastmailId) {
    try {
      const { error } = await this.supabase
        .from('emails')
        .delete()
        .eq('fastmail_id', fastmailId);

      if (error) {
        throw new Error(`Failed to delete email: ${error.message}`);
      }

      return true;
    } catch (error) {
      throw new Error(`Delete email failed: ${error.message}`);
    }
  }

  /**
   * Get recent emails
   */
  async getRecentEmails(limit = 20) {
    try {
      const { data, error } = await this.supabase
        .from('emails')
        .select('*')
        .eq('is_deleted', false)
        .order('date_received', { ascending: false })
        .limit(limit);

      if (error) {
        throw new Error(`Failed to get recent emails: ${error.message}`);
      }

      return data.map(email => new StoredEmail(email));
    } catch (error) {
      throw new Error(`Get recent emails failed: ${error.message}`);
    }
  }

  /**
   * Test database connection
   */
  async testConnection() {
    try {
      const { data, error } = await this.supabase
        .from('emails')
        .select('count')
        .limit(1);

      if (error) {
        throw new Error(`Database connection test failed: ${error.message}`);
      }

      return true;
    } catch (error) {
      throw new Error(`Connection test failed: ${error.message}`);
    }
  }
}
