-- ============================================
-- SERVER-SIDE CLEANUP FOR TIMED-OUT JOBS
-- ============================================
-- Run this SQL in your Supabase Dashboard SQL Editor
-- Dashboard > SQL Editor > New Query > Paste and Run
--
-- This sets up automatic cleanup of timed-out pending jobs:
-- - Saves failed jobs to user_media for tracking in UsageView
-- - Deletes timed-out jobs from pending_jobs
-- - Runs automatically every 5 minutes via pg_cron

-- 1. Enable pg_cron extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 2. Create function to save timed-out jobs to user_media and delete from pending_jobs
CREATE OR REPLACE FUNCTION cleanup_timed_out_jobs()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER := 0;
    image_cutoff TIMESTAMPTZ;
    video_cutoff TIMESTAMPTZ;
    job_record RECORD;
BEGIN
    -- Calculate cutoff times: 5 minutes for images, 10 minutes for videos
    image_cutoff := NOW() - INTERVAL '5 minutes';
    video_cutoff := NOW() - INTERVAL '10 minutes';
    
    -- Process stuck image jobs
    FOR job_record IN
        SELECT 
            id,
            user_id,
            task_id,
            provider,
            job_type,
            metadata,
            created_at
        FROM pending_jobs
        WHERE job_type = 'image'
        AND status IN ('pending', 'processing')
        AND created_at < image_cutoff
    LOOP
        -- Save to user_media for tracking in UsageView
        INSERT INTO user_media (
            user_id,
            image_url,
            model,
            title,
            cost,
            type,
            endpoint,
            prompt,
            aspect_ratio,
            provider,
            status,
            error_message,
            created_at
        )
        VALUES (
            job_record.user_id,
            '', -- Empty for failed attempts
            (job_record.metadata->>'model'),
            (job_record.metadata->>'title'),
            CASE 
                WHEN (job_record.metadata->>'cost') IS NOT NULL 
                THEN (job_record.metadata->>'cost')::double precision 
                ELSE NULL 
            END, -- Include cost since payment was taken
            (job_record.metadata->>'type'),
            (job_record.metadata->>'endpoint'),
            (job_record.metadata->>'prompt'),
            (job_record.metadata->>'aspect_ratio'),
            job_record.provider,
            'failed',
            'Job timed out after 5 minutes',
            job_record.created_at -- Preserve original creation time
        )
        ON CONFLICT DO NOTHING; -- Prevent duplicates if function runs multiple times
        
        -- Delete from pending_jobs
        DELETE FROM pending_jobs WHERE id = job_record.id;
        deleted_count := deleted_count + 1;
    END LOOP;
    
    -- Process stuck video jobs
    FOR job_record IN
        SELECT 
            id,
            user_id,
            task_id,
            provider,
            job_type,
            metadata,
            created_at
        FROM pending_jobs
        WHERE job_type = 'video'
        AND status IN ('pending', 'processing')
        AND created_at < video_cutoff
    LOOP
        -- Save to user_media for tracking in UsageView
        INSERT INTO user_media (
            user_id,
            image_url, -- Using image_url column for video URL (empty for failed)
            model,
            title,
            cost,
            type,
            endpoint,
            media_type,
            file_extension,
            prompt,
            aspect_ratio,
            duration,
            resolution,
            provider,
            status,
            error_message,
            created_at
        )
        VALUES (
            job_record.user_id,
            '', -- Empty for failed attempts
            (job_record.metadata->>'model'),
            (job_record.metadata->>'title'),
            CASE 
                WHEN (job_record.metadata->>'cost') IS NOT NULL 
                THEN (job_record.metadata->>'cost')::double precision 
                ELSE NULL 
            END, -- Include cost since payment was taken
            (job_record.metadata->>'type'),
            (job_record.metadata->>'endpoint'),
            'video',
            'mp4',
            (job_record.metadata->>'prompt'),
            (job_record.metadata->>'aspect_ratio'),
            CASE 
                WHEN (job_record.metadata->>'duration') IS NOT NULL 
                THEN (job_record.metadata->>'duration')::double precision 
                ELSE NULL 
            END,
            (job_record.metadata->>'resolution'),
            job_record.provider,
            'failed',
            'Job timed out after 10 minutes',
            job_record.created_at -- Preserve original creation time
        )
        ON CONFLICT DO NOTHING; -- Prevent duplicates if function runs multiple times
        
        -- Delete from pending_jobs
        DELETE FROM pending_jobs WHERE id = job_record.id;
        deleted_count := deleted_count + 1;
    END LOOP;
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Schedule the function to run every 5 minutes
-- Note: If a schedule already exists, this will fail - you may need to unschedule first
SELECT cron.unschedule('cleanup-timed-out-jobs') WHERE EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'cleanup-timed-out-jobs'
);

SELECT cron.schedule(
    'cleanup-timed-out-jobs',
    '*/5 * * * *',  -- Every 5 minutes
    $$SELECT cleanup_timed_out_jobs();$$
);

-- ============================================
-- VERIFICATION QUERIES (run after setup)
-- ============================================

-- Check function was created
-- SELECT routine_name, routine_type 
-- FROM information_schema.routines 
-- WHERE routine_name = 'cleanup_timed_out_jobs';

-- Check cron job was scheduled
-- SELECT jobid, schedule, command, nodename, nodeport, database, username, active
-- FROM cron.job 
-- WHERE jobname = 'cleanup-timed-out-jobs';

-- Test the function manually (optional)
-- SELECT cleanup_timed_out_jobs();

-- ============================================
-- MANUAL CLEANUP (if needed)
-- ============================================

-- To manually run the cleanup:
-- SELECT cleanup_timed_out_jobs();

-- To unschedule the cron job:
-- SELECT cron.unschedule('cleanup-timed-out-jobs');

-- To reschedule with different interval (e.g., every 10 minutes):
-- SELECT cron.unschedule('cleanup-timed-out-jobs');
-- SELECT cron.schedule(
--     'cleanup-timed-out-jobs',
--     '*/10 * * * *',
--     $$SELECT cleanup_timed_out_jobs();$$
-- );

