-- Sync Functions Migration
-- Creates functions for email synchronization and monitoring

-- Create function to initialize sync state
CREATE OR REPLACE FUNCTION initialize_sync_state(
    account_id_param TEXT,
    initial_sync_token TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    sync_state_id UUID;
BEGIN
    INSERT INTO sync_state (
        account_id,
        last_sync_token,
        last_sync_date,
        total_emails_synced,
        sync_status
    ) VALUES (
        account_id_param,
        initial_sync_token,
        NOW(),
        0,
        'idle'
    )
    ON CONFLICT (account_id) DO UPDATE SET
        last_sync_token = COALESCE(EXCLUDED.last_sync_token, sync_state.last_sync_token),
        last_sync_date = NOW(),
        sync_status = 'idle',
        last_error = NULL,
        updated_at = NOW()
    RETURNING id INTO sync_state_id;
    
    RETURN sync_state_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to update sync progress
CREATE OR REPLACE FUNCTION update_sync_progress(
    account_id_param TEXT,
    sync_token TEXT,
    emails_synced INTEGER DEFAULT 0,
    sync_status_param TEXT DEFAULT 'syncing'
)
RETURNS VOID AS $$
BEGIN
    UPDATE sync_state SET
        last_sync_token = sync_token,
        last_sync_date = NOW(),
        total_emails_synced = total_emails_synced + emails_synced,
        sync_status = sync_status_param,
        last_error = NULL,
        updated_at = NOW()
    WHERE account_id = account_id_param;
    
    IF NOT FOUND THEN
        -- Create new sync state if it doesn't exist
        INSERT INTO sync_state (
            account_id,
            last_sync_token,
            last_sync_date,
            total_emails_synced,
            sync_status
        ) VALUES (
            account_id_param,
            sync_token,
            NOW(),
            emails_synced,
            sync_status_param
        );
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create function to record sync error
CREATE OR REPLACE FUNCTION record_sync_error(
    account_id_param TEXT,
    error_message TEXT
)
RETURNS VOID AS $$
BEGIN
    UPDATE sync_state SET
        last_error = error_message,
        sync_status = 'error',
        updated_at = NOW()
    WHERE account_id = account_id_param;
    
    IF NOT FOUND THEN
        -- Create new sync state with error
        INSERT INTO sync_state (
            account_id,
            last_error,
            sync_status
        ) VALUES (
            account_id_param,
            error_message,
            'error'
        );
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create function to get sync status
CREATE OR REPLACE FUNCTION get_sync_status(account_id_param TEXT)
RETURNS TABLE(
    account_id TEXT,
    last_sync_token TEXT,
    last_sync_date TIMESTAMPTZ,
    total_emails_synced INTEGER,
    last_error TEXT,
    sync_status TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.account_id,
        s.last_sync_token,
        s.last_sync_date,
        s.total_emails_synced,
        s.last_error,
        s.sync_status,
        s.created_at,
        s.updated_at
    FROM sync_state s
    WHERE s.account_id = account_id_param;
END;
$$ LANGUAGE plpgsql;

-- Create function to get all sync states
CREATE OR REPLACE FUNCTION get_all_sync_status()
RETURNS TABLE(
    account_id TEXT,
    last_sync_token TEXT,
    last_sync_date TIMESTAMPTZ,
    total_emails_synced INTEGER,
    last_error TEXT,
    sync_status TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.account_id,
        s.last_sync_token,
        s.last_sync_date,
        s.total_emails_synced,
        s.last_error,
        s.sync_status,
        s.created_at,
        s.updated_at
    FROM sync_state s
    ORDER BY s.updated_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Create function to clean up old sync states
CREATE OR REPLACE FUNCTION cleanup_old_sync_states(
    days_old INTEGER DEFAULT 30
)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
    cutoff_date TIMESTAMPTZ;
BEGIN
    cutoff_date := NOW() - (days_old || ' days')::INTERVAL;
    
    DELETE FROM sync_state 
    WHERE updated_at < cutoff_date 
    AND sync_status = 'completed';
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Create function to get sync statistics
CREATE OR REPLACE FUNCTION get_sync_statistics()
RETURNS TABLE(
    total_accounts BIGINT,
    active_syncs BIGINT,
    completed_syncs BIGINT,
    failed_syncs BIGINT,
    total_emails_synced BIGINT,
    last_sync_date TIMESTAMPTZ,
    oldest_sync_date TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_accounts,
        COUNT(*) FILTER (WHERE sync_status = 'syncing') as active_syncs,
        COUNT(*) FILTER (WHERE sync_status = 'completed') as completed_syncs,
        COUNT(*) FILTER (WHERE sync_status = 'error') as failed_syncs,
        SUM(total_emails_synced) as total_emails_synced,
        MAX(last_sync_date) as last_sync_date,
        MIN(created_at) as oldest_sync_date
    FROM sync_state;
END;
$$ LANGUAGE plpgsql;

-- Create function to validate email data integrity
CREATE OR REPLACE FUNCTION validate_email_integrity()
RETURNS TABLE(
    check_name TEXT,
    check_result TEXT,
    issue_count BIGINT,
    details JSONB
) AS $$
BEGIN
    -- Check for emails without mailboxes
    RETURN QUERY
    SELECT 
        'emails_without_mailboxes'::TEXT as check_name,
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END as check_result,
        COUNT(*) as issue_count,
        jsonb_agg(DISTINCT e.mailbox_id) as details
    FROM emails e
    LEFT JOIN mailboxes m ON e.mailbox_id = m.fastmail_id
    WHERE m.fastmail_id IS NULL AND e.is_deleted = false;
    
    -- Check for duplicate Fastmail IDs
    RETURN QUERY
    SELECT 
        'duplicate_fastmail_ids'::TEXT as check_name,
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END as check_result,
        COUNT(*) as issue_count,
        jsonb_agg(fastmail_id) as details
    FROM (
        SELECT fastmail_id, COUNT(*) as cnt
        FROM emails
        GROUP BY fastmail_id
        HAVING COUNT(*) > 1
    ) duplicates;
    
    -- Check for orphaned search entries
    RETURN QUERY
    SELECT 
        'orphaned_search_entries'::TEXT as check_name,
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END as check_result,
        COUNT(*) as issue_count,
        NULL::jsonb as details
    FROM email_search es
    LEFT JOIN emails e ON es.email_id = e.id
    WHERE e.id IS NULL;
    
    -- Check for missing search entries
    RETURN QUERY
    SELECT 
        'missing_search_entries'::TEXT as check_name,
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END as check_result,
        COUNT(*) as issue_count,
        NULL::jsonb as details
    FROM emails e
    LEFT JOIN email_search es ON e.id = es.email_id
    WHERE es.email_id IS NULL AND e.is_deleted = false;
    
    -- Check for invalid JSON in address fields
    RETURN QUERY
    SELECT 
        'invalid_json_addresses'::TEXT as check_name,
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END as check_result,
        COUNT(*) as issue_count,
        jsonb_agg(id) as details
    FROM emails
    WHERE NOT (to_addresses::text ~ '^\[.*\]$' OR to_addresses::text = '[]')
       OR NOT (cc_addresses::text ~ '^\[.*\]$' OR cc_addresses::text = '[]')
       OR NOT (bcc_addresses::text ~ '^\[.*\]$' OR bcc_addresses::text = '[]')
       OR NOT (reply_to_addresses::text ~ '^\[.*\]$' OR reply_to_addresses::text = '[]');
END;
$$ LANGUAGE plpgsql;

-- Create function to repair data integrity issues
CREATE OR REPLACE FUNCTION repair_data_integrity()
RETURNS TABLE(
    repair_action TEXT,
    items_affected BIGINT,
    details TEXT
) AS $$
DECLARE
    orphaned_count BIGINT;
    missing_count BIGINT;
BEGIN
    -- Remove orphaned search entries
    DELETE FROM email_search 
    WHERE email_id NOT IN (SELECT id FROM emails);
    
    GET DIAGNOSTICS orphaned_count = ROW_COUNT;
    
    RETURN QUERY
    SELECT 
        'removed_orphaned_search_entries'::TEXT as repair_action,
        orphaned_count as items_affected,
        'Removed search entries for non-existent emails'::TEXT as details;
    
    -- Create missing search entries
    INSERT INTO email_search (email_id, search_vector, content_hash)
    SELECT 
        e.id,
        to_tsvector('english', 
            COALESCE(e.subject, '') || ' ' ||
            COALESCE(e.from_address, '') || ' ' ||
            COALESCE(e.body_text, '') || ' ' ||
            COALESCE(e.body_html, '')
        ),
        md5(
            COALESCE(e.subject, '') || ' ' ||
            COALESCE(e.from_address, '') || ' ' ||
            COALESCE(e.body_text, '') || ' ' ||
            COALESCE(e.body_html, '')
        )
    FROM emails e
    LEFT JOIN email_search es ON e.id = es.email_id
    WHERE es.email_id IS NULL AND e.is_deleted = false;
    
    GET DIAGNOSTICS missing_count = ROW_COUNT;
    
    RETURN QUERY
    SELECT 
        'created_missing_search_entries'::TEXT as repair_action,
        missing_count as items_affected,
        'Created search entries for emails without them'::TEXT as details;
    
    -- Update mailbox statistics
    PERFORM update_mailbox_stats();
    
    RETURN QUERY
    SELECT 
        'updated_mailbox_statistics'::TEXT as repair_action,
        0::BIGINT as items_affected,
        'Updated mailbox email counts and statistics'::TEXT as details;
END;
$$ LANGUAGE plpgsql;

-- Create function to get sync health status
CREATE OR REPLACE FUNCTION get_sync_health_status()
RETURNS TABLE(
    status TEXT,
    message TEXT,
    details JSONB
) AS $$
DECLARE
    error_count BIGINT;
    stale_count BIGINT;
    total_accounts BIGINT;
    last_sync_age INTERVAL;
BEGIN
    -- Count accounts with errors
    SELECT COUNT(*) INTO error_count
    FROM sync_state
    WHERE sync_status = 'error';
    
    -- Count stale syncs (no activity in 24 hours)
    SELECT COUNT(*) INTO stale_count
    FROM sync_state
    WHERE last_sync_date < NOW() - INTERVAL '24 hours'
    AND sync_status IN ('syncing', 'completed');
    
    -- Get total accounts
    SELECT COUNT(*) INTO total_accounts
    FROM sync_state;
    
    -- Get age of most recent sync
    SELECT MAX(last_sync_date) - NOW() INTO last_sync_age
    FROM sync_state;
    
    -- Determine overall health status
    IF error_count > 0 THEN
        RETURN QUERY
        SELECT 
            'ERROR'::TEXT as status,
            'Some accounts have sync errors'::TEXT as message,
            jsonb_build_object(
                'error_count', error_count,
                'total_accounts', total_accounts,
                'stale_count', stale_count
            ) as details;
    ELSIF stale_count > 0 THEN
        RETURN QUERY
        SELECT 
            'WARNING'::TEXT as status,
            'Some accounts have stale sync data'::TEXT as message,
            jsonb_build_object(
                'stale_count', stale_count,
                'total_accounts', total_accounts,
                'last_sync_age_hours', EXTRACT(EPOCH FROM last_sync_age) / 3600
            ) as details;
    ELSE
        RETURN QUERY
        SELECT 
            'HEALTHY'::TEXT as status,
            'All sync operations are healthy'::TEXT as message,
            jsonb_build_object(
                'total_accounts', total_accounts,
                'last_sync_age_hours', EXTRACT(EPOCH FROM last_sync_age) / 3600
            ) as details;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create function to force sync reset
CREATE OR REPLACE FUNCTION reset_sync_state(
    account_id_param TEXT,
    reset_token TEXT DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    UPDATE sync_state SET
        last_sync_token = reset_token,
        last_sync_date = NULL,
        total_emails_synced = 0,
        last_error = NULL,
        sync_status = 'idle',
        updated_at = NOW()
    WHERE account_id = account_id_param;
    
    IF NOT FOUND THEN
        -- Create new sync state
        INSERT INTO sync_state (
            account_id,
            last_sync_token,
            sync_status
        ) VALUES (
            account_id_param,
            reset_token,
            'idle'
        );
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create function to get sync performance metrics
CREATE OR REPLACE FUNCTION get_sync_performance_metrics(
    hours_back INTEGER DEFAULT 24
)
RETURNS TABLE(
    metric_name TEXT,
    metric_value NUMERIC,
    metric_unit TEXT,
    details JSONB
) AS $$
BEGIN
    -- Average emails per sync
    RETURN QUERY
    SELECT 
        'avg_emails_per_sync'::TEXT as metric_name,
        AVG(total_emails_synced)::NUMERIC as metric_value,
        'emails'::TEXT as metric_unit,
        jsonb_build_object(
            'min', MIN(total_emails_synced),
            'max', MAX(total_emails_synced),
            'stddev', STDDEV(total_emails_synced)
        ) as details
    FROM sync_state
    WHERE last_sync_date > NOW() - (hours_back || ' hours')::INTERVAL
    AND sync_status = 'completed';
    
    -- Sync frequency
    RETURN QUERY
    SELECT 
        'sync_frequency'::TEXT as metric_name,
        COUNT(*)::NUMERIC / (hours_back / 24.0) as metric_value,
        'syncs_per_day'::TEXT as metric_unit,
        jsonb_build_object(
            'total_syncs', COUNT(*),
            'hours_analyzed', hours_back
        ) as details
    FROM sync_state
    WHERE last_sync_date > NOW() - (hours_back || ' hours')::INTERVAL;
    
    -- Error rate
    RETURN QUERY
    SELECT 
        'error_rate'::TEXT as metric_name,
        (COUNT(*) FILTER (WHERE sync_status = 'error')::NUMERIC / NULLIF(COUNT(*), 0)) * 100 as metric_value,
        'percent'::TEXT as metric_unit,
        jsonb_build_object(
            'error_count', COUNT(*) FILTER (WHERE sync_status = 'error'),
            'total_syncs', COUNT(*)
        ) as details
    FROM sync_state
    WHERE last_sync_date > NOW() - (hours_back || ' hours')::INTERVAL;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions on sync functions
GRANT EXECUTE ON FUNCTION initialize_sync_state TO anon, authenticated;
GRANT EXECUTE ON FUNCTION update_sync_progress TO anon, authenticated;
GRANT EXECUTE ON FUNCTION record_sync_error TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_sync_status TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_all_sync_status TO anon, authenticated;
GRANT EXECUTE ON FUNCTION cleanup_old_sync_states TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_sync_statistics TO anon, authenticated;
GRANT EXECUTE ON FUNCTION validate_email_integrity TO anon, authenticated;
GRANT EXECUTE ON FUNCTION repair_data_integrity TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_sync_health_status TO anon, authenticated;
GRANT EXECUTE ON FUNCTION reset_sync_state TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_sync_performance_metrics TO anon, authenticated;
