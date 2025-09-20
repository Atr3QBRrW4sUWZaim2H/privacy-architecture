-- Search Indexes Migration
-- Creates additional indexes for improved search performance

-- Create GIN index for full-text search on email content
CREATE INDEX IF NOT EXISTS idx_emails_body_text_gin ON emails USING GIN(to_tsvector('english', body_text));
CREATE INDEX IF NOT EXISTS idx_emails_subject_gin ON emails USING GIN(to_tsvector('english', subject));
CREATE INDEX IF NOT EXISTS idx_emails_from_address_gin ON emails USING GIN(to_tsvector('english', from_address));

-- Create composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_emails_mailbox_date ON emails(mailbox_id, date_received DESC);
CREATE INDEX IF NOT EXISTS idx_emails_mailbox_read ON emails(mailbox_id, is_read, date_received DESC);
CREATE INDEX IF NOT EXISTS idx_emails_mailbox_flagged ON emails(mailbox_id, is_flagged, date_received DESC);
CREATE INDEX IF NOT EXISTS idx_emails_thread_date ON emails(thread_id, date_received DESC);

-- Create partial indexes for common filters
CREATE INDEX IF NOT EXISTS idx_emails_unread ON emails(date_received DESC) WHERE is_read = false AND is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_emails_flagged ON emails(date_received DESC) WHERE is_flagged = true AND is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_emails_recent ON emails(date_received DESC) WHERE date_received > NOW() - INTERVAL '30 days' AND is_deleted = false;

-- Create indexes for attachment queries
CREATE INDEX IF NOT EXISTS idx_emails_has_attachments ON emails(date_received DESC) 
    WHERE jsonb_array_length(attachments) > 0 AND is_deleted = false;

-- Create indexes for address-based queries
CREATE INDEX IF NOT EXISTS idx_emails_to_addresses_gin ON emails USING GIN(to_addresses);
CREATE INDEX IF NOT EXISTS idx_emails_cc_addresses_gin ON emails USING GIN(cc_addresses);
CREATE INDEX IF NOT EXISTS idx_emails_bcc_addresses_gin ON emails USING GIN(bcc_addresses);
CREATE INDEX IF NOT EXISTS idx_emails_reply_to_addresses_gin ON emails USING GIN(reply_to_addresses);

-- Create indexes for message threading
CREATE INDEX IF NOT EXISTS idx_emails_message_id ON emails(message_id) WHERE message_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_emails_in_reply_to ON emails(in_reply_to) WHERE in_reply_to IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_emails_references_gin ON emails USING GIN(email_references);

-- Create indexes for size-based queries
CREATE INDEX IF NOT EXISTS idx_emails_size ON emails(size_bytes DESC) WHERE is_deleted = false;

-- Create indexes for date range queries
CREATE INDEX IF NOT EXISTS idx_emails_date_range ON emails(date_received, date_sent) WHERE is_deleted = false;

-- Create function for advanced search with multiple criteria
CREATE OR REPLACE FUNCTION advanced_email_search(
    search_text TEXT DEFAULT NULL,
    from_address TEXT DEFAULT NULL,
    to_address TEXT DEFAULT NULL,
    subject_contains TEXT DEFAULT NULL,
    body_contains TEXT DEFAULT NULL,
    mailbox_ids TEXT[] DEFAULT NULL,
    date_from TIMESTAMPTZ DEFAULT NULL,
    date_to TIMESTAMPTZ DEFAULT NULL,
    is_read_filter BOOLEAN DEFAULT NULL,
    is_flagged_filter BOOLEAN DEFAULT NULL,
    has_attachments_filter BOOLEAN DEFAULT NULL,
    min_size_bytes INTEGER DEFAULT NULL,
    max_size_bytes INTEGER DEFAULT NULL,
    sort_by TEXT DEFAULT 'date_received',
    sort_order TEXT DEFAULT 'desc',
    result_limit INTEGER DEFAULT 50,
    result_offset INTEGER DEFAULT 0
)
RETURNS TABLE(
    email_id UUID,
    subject TEXT,
    from_address TEXT,
    to_addresses JSONB,
    date_received TIMESTAMPTZ,
    date_sent TIMESTAMPTZ,
    mailbox_id TEXT,
    is_read BOOLEAN,
    is_flagged BOOLEAN,
    size_bytes INTEGER,
    attachment_count INTEGER,
    snippet TEXT,
    rank REAL
) AS $$
DECLARE
    search_tsquery TSQUERY;
    where_clause TEXT := 'e.is_deleted = false';
    order_clause TEXT;
BEGIN
    -- Build search query
    IF search_text IS NOT NULL AND search_text != '' THEN
        search_tsquery := plainto_tsquery('english', search_text);
    END IF;
    
    -- Build WHERE clause
    IF search_text IS NOT NULL AND search_text != '' THEN
        where_clause := where_clause || ' AND es.search_vector @@ ' || quote_literal(search_tsquery);
    END IF;
    
    IF from_address IS NOT NULL THEN
        where_clause := where_clause || ' AND e.from_address ILIKE ' || quote_literal('%' || from_address || '%');
    END IF;
    
    IF to_address IS NOT NULL THEN
        where_clause := where_clause || ' AND (e.to_addresses::text ILIKE ' || quote_literal('%' || to_address || '%') || 
                   ' OR e.cc_addresses::text ILIKE ' || quote_literal('%' || to_address || '%') || ')';
    END IF;
    
    IF subject_contains IS NOT NULL THEN
        where_clause := where_clause || ' AND e.subject ILIKE ' || quote_literal('%' || subject_contains || '%');
    END IF;
    
    IF body_contains IS NOT NULL THEN
        where_clause := where_clause || ' AND (e.body_text ILIKE ' || quote_literal('%' || body_contains || '%') ||
                   ' OR e.body_html ILIKE ' || quote_literal('%' || body_contains || '%') || ')';
    END IF;
    
    IF mailbox_ids IS NOT NULL AND array_length(mailbox_ids, 1) > 0 THEN
        where_clause := where_clause || ' AND e.mailbox_id = ANY(' || quote_literal(mailbox_ids) || ')';
    END IF;
    
    IF date_from IS NOT NULL THEN
        where_clause := where_clause || ' AND e.date_received >= ' || quote_literal(date_from);
    END IF;
    
    IF date_to IS NOT NULL THEN
        where_clause := where_clause || ' AND e.date_received <= ' || quote_literal(date_to);
    END IF;
    
    IF is_read_filter IS NOT NULL THEN
        where_clause := where_clause || ' AND e.is_read = ' || is_read_filter;
    END IF;
    
    IF is_flagged_filter IS NOT NULL THEN
        where_clause := where_clause || ' AND e.is_flagged = ' || is_flagged_filter;
    END IF;
    
    IF has_attachments_filter IS NOT NULL THEN
        IF has_attachments_filter THEN
            where_clause := where_clause || ' AND jsonb_array_length(e.attachments) > 0';
        ELSE
            where_clause := where_clause || ' AND jsonb_array_length(e.attachments) = 0';
        END IF;
    END IF;
    
    IF min_size_bytes IS NOT NULL THEN
        where_clause := where_clause || ' AND e.size_bytes >= ' || min_size_bytes;
    END IF;
    
    IF max_size_bytes IS NOT NULL THEN
        where_clause := where_clause || ' AND e.size_bytes <= ' || max_size_bytes;
    END IF;
    
    -- Build ORDER BY clause
    order_clause := 'ORDER BY ';
    IF search_text IS NOT NULL AND search_text != '' THEN
        order_clause := order_clause || 'ts_rank(es.search_vector, ' || quote_literal(search_tsquery) || ') DESC, ';
    END IF;
    
    CASE sort_by
        WHEN 'date_received' THEN
            order_clause := order_clause || 'e.date_received ' || sort_order;
        WHEN 'date_sent' THEN
            order_clause := order_clause || 'e.date_sent ' || sort_order;
        WHEN 'subject' THEN
            order_clause := order_clause || 'e.subject ' || sort_order;
        WHEN 'from_address' THEN
            order_clause := order_clause || 'e.from_address ' || sort_order;
        WHEN 'size_bytes' THEN
            order_clause := order_clause || 'e.size_bytes ' || sort_order;
        ELSE
            order_clause := order_clause || 'e.date_received ' || sort_order;
    END CASE;
    
    -- Execute dynamic query
    RETURN QUERY EXECUTE format('
        SELECT 
            e.id as email_id,
            e.subject,
            e.from_address,
            e.to_addresses,
            e.date_received,
            e.date_sent,
            e.mailbox_id,
            e.is_read,
            e.is_flagged,
            e.size_bytes,
            jsonb_array_length(e.attachments) as attachment_count,
            CASE 
                WHEN %L IS NOT NULL THEN ts_headline(''english'', e.body_text, %L, ''MaxWords=50,MinWords=10'')
                ELSE LEFT(e.body_text, 200)
            END as snippet,
            CASE 
                WHEN %L IS NOT NULL THEN ts_rank(es.search_vector, %L)
                ELSE 0
            END as rank
        FROM emails e
        LEFT JOIN email_search es ON e.id = es.email_id
        WHERE %s
        %s
        LIMIT %s OFFSET %s',
        search_text, search_tsquery, search_text, search_tsquery, 
        where_clause, order_clause, result_limit, result_offset
    );
END;
$$ LANGUAGE plpgsql;

-- Create function for email thread analysis
CREATE OR REPLACE FUNCTION get_email_thread_analysis(thread_id_param TEXT)
RETURNS TABLE(
    thread_id TEXT,
    subject TEXT,
    message_count INTEGER,
    unread_count INTEGER,
    participants JSONB,
    date_range JSONB,
    size_bytes BIGINT,
    first_message_date TIMESTAMPTZ,
    last_message_date TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        e.thread_id,
        e.subject,
        COUNT(*)::INTEGER as message_count,
        COUNT(*) FILTER (WHERE e.is_read = false)::INTEGER as unread_count,
        jsonb_agg(DISTINCT jsonb_build_object('email', e.from_address, 'name', e.from_address)) as participants,
        jsonb_build_object(
            'start', MIN(e.date_received),
            'end', MAX(e.date_received),
            'duration_days', EXTRACT(EPOCH FROM (MAX(e.date_received) - MIN(e.date_received))) / 86400
        ) as date_range,
        SUM(e.size_bytes) as size_bytes,
        MIN(e.date_received) as first_message_date,
        MAX(e.date_received) as last_message_date
    FROM emails e
    WHERE e.thread_id = thread_id_param AND e.is_deleted = false
    GROUP BY e.thread_id, e.subject;
END;
$$ LANGUAGE plpgsql;

-- Create function for mailbox statistics
CREATE OR REPLACE FUNCTION get_mailbox_analysis(mailbox_id_param TEXT)
RETURNS TABLE(
    mailbox_id TEXT,
    mailbox_name TEXT,
    total_emails BIGINT,
    unread_emails BIGINT,
    flagged_emails BIGINT,
    total_size_bytes BIGINT,
    avg_size_bytes NUMERIC,
    oldest_email_date TIMESTAMPTZ,
    newest_email_date TIMESTAMPTZ,
    top_senders JSONB,
    emails_by_month JSONB
) AS $$
BEGIN
    RETURN QUERY
    WITH sender_stats AS (
        SELECT 
            e.from_address,
            COUNT(*) as email_count,
            SUM(e.size_bytes) as total_size
        FROM emails e
        WHERE e.mailbox_id = mailbox_id_param AND e.is_deleted = false
        GROUP BY e.from_address
        ORDER BY email_count DESC
        LIMIT 10
    ),
    monthly_stats AS (
        SELECT 
            DATE_TRUNC('month', e.date_received) as month,
            COUNT(*) as email_count
        FROM emails e
        WHERE e.mailbox_id = mailbox_id_param AND e.is_deleted = false AND e.date_received IS NOT NULL
        GROUP BY DATE_TRUNC('month', e.date_received)
        ORDER BY month DESC
    )
    SELECT 
        e.mailbox_id,
        m.name as mailbox_name,
        COUNT(*) as total_emails,
        COUNT(*) FILTER (WHERE e.is_read = false) as unread_emails,
        COUNT(*) FILTER (WHERE e.is_flagged = true) as flagged_emails,
        SUM(e.size_bytes) as total_size_bytes,
        AVG(e.size_bytes) as avg_size_bytes,
        MIN(e.date_received) as oldest_email_date,
        MAX(e.date_received) as newest_email_date,
        COALESCE(jsonb_agg(
            jsonb_build_object(
                'email', ss.from_address,
                'count', ss.email_count,
                'total_size', ss.total_size
            )
        ) FILTER (WHERE ss.from_address IS NOT NULL), '[]'::jsonb) as top_senders,
        COALESCE(jsonb_object_agg(
            TO_CHAR(ms.month, 'YYYY-MM'), 
            ms.email_count
        ) FILTER (WHERE ms.month IS NOT NULL), '{}'::jsonb) as emails_by_month
    FROM emails e
    LEFT JOIN mailboxes m ON e.mailbox_id = m.fastmail_id
    LEFT JOIN sender_stats ss ON true
    LEFT JOIN monthly_stats ms ON true
    WHERE e.mailbox_id = mailbox_id_param AND e.is_deleted = false
    GROUP BY e.mailbox_id, m.name;
END;
$$ LANGUAGE plpgsql;

-- Create function for duplicate email detection
CREATE OR REPLACE FUNCTION find_duplicate_emails()
RETURNS TABLE(
    message_id TEXT,
    duplicate_count BIGINT,
    email_ids UUID[],
    subjects TEXT[],
    from_addresses TEXT[],
    dates TIMESTAMPTZ[]
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        e.message_id,
        COUNT(*) as duplicate_count,
        array_agg(e.id ORDER BY e.date_received) as email_ids,
        array_agg(e.subject ORDER BY e.date_received) as subjects,
        array_agg(e.from_address ORDER BY e.date_received) as from_addresses,
        array_agg(e.date_received ORDER BY e.date_received) as dates
    FROM emails e
    WHERE e.message_id IS NOT NULL AND e.is_deleted = false
    GROUP BY e.message_id
    HAVING COUNT(*) > 1
    ORDER BY duplicate_count DESC;
END;
$$ LANGUAGE plpgsql;

-- Create function for email cleanup
CREATE OR REPLACE FUNCTION cleanup_old_emails(
    days_old INTEGER DEFAULT 365,
    dry_run BOOLEAN DEFAULT true
)
RETURNS TABLE(
    action TEXT,
    email_count BIGINT,
    total_size_bytes BIGINT
) AS $$
DECLARE
    cutoff_date TIMESTAMPTZ;
    deleted_count BIGINT;
    deleted_size BIGINT;
BEGIN
    cutoff_date := NOW() - (days_old || ' days')::INTERVAL;
    
    IF dry_run THEN
        RETURN QUERY
        SELECT 
            'would_delete'::TEXT as action,
            COUNT(*) as email_count,
            SUM(size_bytes) as total_size_bytes
        FROM emails
        WHERE date_received < cutoff_date AND is_deleted = false;
    ELSE
        -- Actually delete old emails
        WITH deleted AS (
            DELETE FROM emails
            WHERE date_received < cutoff_date AND is_deleted = false
            RETURNING size_bytes
        )
        SELECT 
            'deleted'::TEXT as action,
            COUNT(*) as email_count,
            SUM(size_bytes) as total_size_bytes
        INTO deleted_count, deleted_size
        FROM deleted;
        
        RETURN QUERY
        SELECT 'deleted'::TEXT as action, deleted_count, deleted_size;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create view for email dashboard
CREATE OR REPLACE VIEW email_dashboard AS
SELECT 
    m.fastmail_id as mailbox_id,
    m.name as mailbox_name,
    m.role as mailbox_role,
    COUNT(e.id) as total_emails,
    COUNT(e.id) FILTER (WHERE e.is_read = false) as unread_emails,
    COUNT(e.id) FILTER (WHERE e.is_flagged = true) as flagged_emails,
    SUM(e.size_bytes) as total_size_bytes,
    AVG(e.size_bytes) as avg_size_bytes,
    MIN(e.date_received) as oldest_email,
    MAX(e.date_received) as newest_email,
    COUNT(e.id) FILTER (WHERE e.date_received > NOW() - INTERVAL '7 days') as emails_last_week,
    COUNT(e.id) FILTER (WHERE e.date_received > NOW() - INTERVAL '30 days') as emails_last_month
FROM mailboxes m
LEFT JOIN emails e ON m.fastmail_id = e.mailbox_id AND e.is_deleted = false
GROUP BY m.fastmail_id, m.name, m.role, m.sort_order
ORDER BY m.sort_order;

-- Grant permissions on new functions
GRANT EXECUTE ON FUNCTION advanced_email_search TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_email_thread_analysis TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_mailbox_analysis TO anon, authenticated;
GRANT EXECUTE ON FUNCTION find_duplicate_emails TO anon, authenticated;
GRANT EXECUTE ON FUNCTION cleanup_old_emails TO anon, authenticated;
GRANT SELECT ON email_dashboard TO anon, authenticated;
