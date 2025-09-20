-- Email Storage Schema Migration
-- Creates tables for storing Fastmail emails in Supabase

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Create emails table
CREATE TABLE IF NOT EXISTS emails (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    fastmail_id TEXT UNIQUE NOT NULL,
    thread_id TEXT,
    mailbox_id TEXT,
    subject TEXT,
    from_address TEXT,
    to_addresses JSONB DEFAULT '[]'::jsonb,
    cc_addresses JSONB DEFAULT '[]'::jsonb,
    bcc_addresses JSONB DEFAULT '[]'::jsonb,
    reply_to_addresses JSONB DEFAULT '[]'::jsonb,
    date_received TIMESTAMPTZ,
    date_sent TIMESTAMPTZ,
    message_id TEXT,
    in_reply_to TEXT,
    email_references TEXT[] DEFAULT '{}',
    body_text TEXT,
    body_html TEXT,
    attachments JSONB DEFAULT '[]'::jsonb,
    flags JSONB DEFAULT '{}'::jsonb,
    size_bytes INTEGER DEFAULT 0,
    is_read BOOLEAN DEFAULT false,
    is_flagged BOOLEAN DEFAULT false,
    is_deleted BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create mailboxes table
CREATE TABLE IF NOT EXISTS mailboxes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    fastmail_id TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    parent_id TEXT,
    role TEXT,
    sort_order INTEGER DEFAULT 0,
    total_emails INTEGER DEFAULT 0,
    unread_emails INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create email_threads table
CREATE TABLE IF NOT EXISTS email_threads (
    id TEXT PRIMARY KEY,
    email_ids TEXT[] DEFAULT '{}',
    subject TEXT,
    mailbox_ids JSONB DEFAULT '{}'::jsonb,
    message_count INTEGER DEFAULT 0,
    unread_count INTEGER DEFAULT 0,
    last_message_date TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create email_search table for full-text search
CREATE TABLE IF NOT EXISTS email_search (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email_id UUID REFERENCES emails(id) ON DELETE CASCADE,
    search_vector TSVECTOR,
    content_hash TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create sync_state table for tracking sync progress
CREATE TABLE IF NOT EXISTS sync_state (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_id TEXT UNIQUE NOT NULL,
    last_sync_token TEXT,
    last_sync_date TIMESTAMPTZ,
    total_emails_synced INTEGER DEFAULT 0,
    last_error TEXT,
    sync_status TEXT DEFAULT 'idle' CHECK (sync_status IN ('idle', 'syncing', 'completed', 'error')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_emails_fastmail_id ON emails(fastmail_id);
CREATE INDEX IF NOT EXISTS idx_emails_thread_id ON emails(thread_id);
CREATE INDEX IF NOT EXISTS idx_emails_mailbox_id ON emails(mailbox_id);
CREATE INDEX IF NOT EXISTS idx_emails_date_received ON emails(date_received);
CREATE INDEX IF NOT EXISTS idx_emails_from_address ON emails(from_address);
CREATE INDEX IF NOT EXISTS idx_emails_subject ON emails(subject);
CREATE INDEX IF NOT EXISTS idx_emails_is_read ON emails(is_read);
CREATE INDEX IF NOT EXISTS idx_emails_is_flagged ON emails(is_flagged);
CREATE INDEX IF NOT EXISTS idx_emails_is_deleted ON emails(is_deleted);
CREATE INDEX IF NOT EXISTS idx_emails_created_at ON emails(created_at);

CREATE INDEX IF NOT EXISTS idx_mailboxes_fastmail_id ON mailboxes(fastmail_id);
CREATE INDEX IF NOT EXISTS idx_mailboxes_role ON mailboxes(role);
CREATE INDEX IF NOT EXISTS idx_mailboxes_sort_order ON mailboxes(sort_order);

CREATE INDEX IF NOT EXISTS idx_email_threads_subject ON email_threads(subject);
CREATE INDEX IF NOT EXISTS idx_email_threads_last_message_date ON email_threads(last_message_date);

CREATE INDEX IF NOT EXISTS idx_email_search_vector ON email_search USING GIN(search_vector);
CREATE INDEX IF NOT EXISTS idx_email_search_email_id ON email_search(email_id);
CREATE INDEX IF NOT EXISTS idx_email_search_content_hash ON email_search(content_hash);

CREATE INDEX IF NOT EXISTS idx_sync_state_account_id ON sync_state(account_id);
CREATE INDEX IF NOT EXISTS idx_sync_state_sync_status ON sync_state(sync_status);
CREATE INDEX IF NOT EXISTS idx_sync_state_last_sync_date ON sync_state(last_sync_date);

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER update_emails_updated_at BEFORE UPDATE ON emails
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_mailboxes_updated_at BEFORE UPDATE ON mailboxes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_email_threads_updated_at BEFORE UPDATE ON email_threads
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_sync_state_updated_at BEFORE UPDATE ON sync_state
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create function to update search vector
CREATE OR REPLACE FUNCTION update_email_search_vector()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO email_search (email_id, search_vector, content_hash)
    VALUES (
        NEW.id,
        to_tsvector('english', 
            COALESCE(NEW.subject, '') || ' ' ||
            COALESCE(NEW.from_address, '') || ' ' ||
            COALESCE(NEW.body_text, '') || ' ' ||
            COALESCE(NEW.body_html, '')
        ),
        md5(
            COALESCE(NEW.subject, '') || ' ' ||
            COALESCE(NEW.from_address, '') || ' ' ||
            COALESCE(NEW.body_text, '') || ' ' ||
            COALESCE(NEW.body_html, '')
        )
    )
    ON CONFLICT (email_id) DO UPDATE SET
        search_vector = EXCLUDED.search_vector,
        content_hash = EXCLUDED.content_hash;
    
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for search vector update
CREATE TRIGGER update_email_search_vector_trigger
    AFTER INSERT OR UPDATE ON emails
    FOR EACH ROW EXECUTE FUNCTION update_email_search_vector();

-- Create function to search emails
CREATE OR REPLACE FUNCTION search_emails(
    search_query TEXT,
    query_limit INTEGER DEFAULT 50,
    query_offset INTEGER DEFAULT 0,
    mailbox_ids TEXT[] DEFAULT NULL,
    date_from TIMESTAMPTZ DEFAULT NULL,
    date_to TIMESTAMPTZ DEFAULT NULL,
    is_read_filter BOOLEAN DEFAULT NULL,
    is_flagged_filter BOOLEAN DEFAULT NULL,
    has_attachments_filter BOOLEAN DEFAULT NULL,
    sort_by TEXT DEFAULT 'date_received',
    sort_order TEXT DEFAULT 'desc'
)
RETURNS TABLE(
    email_id UUID,
    subject TEXT,
    from_address TEXT,
    snippet TEXT,
    rank REAL,
    date_received TIMESTAMPTZ,
    is_read BOOLEAN,
    is_flagged BOOLEAN
) AS $$
DECLARE
    query_tsquery TSQUERY;
    sort_clause TEXT;
BEGIN
    -- Parse search query
    query_tsquery := plainto_tsquery('english', search_query);
    
    -- Build sort clause
    sort_clause := sort_by || ' ' || sort_order;
    
    RETURN QUERY
    SELECT 
        e.id as email_id,
        e.subject,
        e.from_address,
        ts_headline('english', e.body_text, query_tsquery, 'MaxWords=50,MinWords=10') as snippet,
        ts_rank(es.search_vector, query_tsquery) as rank,
        e.date_received,
        e.is_read,
        e.is_flagged
    FROM emails e
    JOIN email_search es ON e.id = es.email_id
    WHERE 
        es.search_vector @@ query_tsquery
        AND e.is_deleted = false
        AND (mailbox_ids IS NULL OR e.mailbox_id = ANY(mailbox_ids))
        AND (date_from IS NULL OR e.date_received >= date_from)
        AND (date_to IS NULL OR e.date_received <= date_to)
        AND (is_read_filter IS NULL OR e.is_read = is_read_filter)
        AND (is_flagged_filter IS NULL OR e.is_flagged = is_flagged_filter)
        AND (has_attachments_filter IS NULL OR 
             (has_attachments_filter = true AND jsonb_array_length(e.attachments) > 0) OR
             (has_attachments_filter = false AND jsonb_array_length(e.attachments) = 0))
    ORDER BY 
        CASE WHEN sort_by = 'rank' THEN ts_rank(es.search_vector, query_tsquery) END DESC,
        CASE WHEN sort_by = 'date_received' AND sort_order = 'desc' THEN e.date_received END DESC,
        CASE WHEN sort_by = 'date_received' AND sort_order = 'asc' THEN e.date_received END ASC,
        CASE WHEN sort_by = 'subject' AND sort_order = 'desc' THEN e.subject END DESC,
        CASE WHEN sort_by = 'subject' AND sort_order = 'asc' THEN e.subject END ASC
    LIMIT query_limit OFFSET query_offset;
END;
$$ LANGUAGE plpgsql;

-- Create function to get email statistics
CREATE OR REPLACE FUNCTION get_email_stats()
RETURNS TABLE(
    total_emails BIGINT,
    unread_emails BIGINT,
    flagged_emails BIGINT,
    deleted_emails BIGINT,
    total_size_bytes BIGINT,
    emails_by_mailbox JSONB,
    emails_by_month JSONB
) AS $$
BEGIN
    RETURN QUERY
    WITH stats AS (
        SELECT 
            COUNT(*) as total,
            COUNT(*) FILTER (WHERE is_read = false) as unread,
            COUNT(*) FILTER (WHERE is_flagged = true) as flagged,
            COUNT(*) FILTER (WHERE is_deleted = true) as deleted,
            SUM(size_bytes) as total_size
        FROM emails
    ),
    mailbox_stats AS (
        SELECT 
            mailbox_id,
            COUNT(*) as count,
            COUNT(*) FILTER (WHERE is_read = false) as unread_count
        FROM emails
        WHERE is_deleted = false
        GROUP BY mailbox_id
    ),
    monthly_stats AS (
        SELECT 
            DATE_TRUNC('month', date_received) as month,
            COUNT(*) as count
        FROM emails
        WHERE is_deleted = false AND date_received IS NOT NULL
        GROUP BY DATE_TRUNC('month', date_received)
        ORDER BY month DESC
    )
    SELECT 
        s.total,
        s.unread,
        s.flagged,
        s.deleted,
        s.total_size,
        COALESCE(jsonb_object_agg(ms.mailbox_id, jsonb_build_object('total', ms.count, 'unread', ms.unread_count)) FILTER (WHERE ms.mailbox_id IS NOT NULL), '{}'::jsonb) as emails_by_mailbox,
        COALESCE(jsonb_object_agg(TO_CHAR(mos.month, 'YYYY-MM'), mos.count) FILTER (WHERE mos.month IS NOT NULL), '{}'::jsonb) as emails_by_month
    FROM stats s
    CROSS JOIN mailbox_stats ms
    CROSS JOIN monthly_stats mos
    GROUP BY s.total, s.unread, s.flagged, s.deleted, s.total_size;
END;
$$ LANGUAGE plpgsql;

-- Create function to clean up old search indexes
CREATE OR REPLACE FUNCTION cleanup_email_search()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM email_search 
    WHERE email_id NOT IN (SELECT id FROM emails);
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Create function to update mailbox statistics
CREATE OR REPLACE FUNCTION update_mailbox_stats()
RETURNS VOID AS $$
BEGIN
    UPDATE mailboxes SET
        total_emails = (
            SELECT COUNT(*) 
            FROM emails 
            WHERE emails.mailbox_id = mailboxes.fastmail_id 
            AND is_deleted = false
        ),
        unread_emails = (
            SELECT COUNT(*) 
            FROM emails 
            WHERE emails.mailbox_id = mailboxes.fastmail_id 
            AND is_deleted = false 
            AND is_read = false
        ),
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated;

-- Create RLS policies (if needed for multi-tenant)
-- ALTER TABLE emails ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE mailboxes ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE email_threads ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE email_search ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE sync_state ENABLE ROW LEVEL SECURITY;

-- Example RLS policies (uncomment if using multi-tenant setup)
-- CREATE POLICY "Users can only access their own emails" ON emails
--     FOR ALL USING (auth.uid() = user_id);

-- CREATE POLICY "Users can only access their own mailboxes" ON mailboxes
--     FOR ALL USING (auth.uid() = user_id);

-- CREATE POLICY "Users can only access their own sync state" ON sync_state
--     FOR ALL USING (auth.uid() = user_id);
