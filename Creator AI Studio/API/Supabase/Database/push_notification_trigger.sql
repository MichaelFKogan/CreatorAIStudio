-- ============================================
-- PUSH NOTIFICATION TRIGGER FOR JOB COMPLETION
-- ============================================
-- Run this SQL in your Supabase Dashboard SQL Editor AFTER:
-- 1. Setting up the pending_jobs table (pending_jobs_setup.sql)
-- 2. Deploying the send-push-notification Edge Function
-- 3. Configuring APNs credentials in Supabase secrets
--
-- This trigger calls the send-push-notification Edge Function
-- whenever a pending job's status changes to 'completed' or 'failed'

-- 1. Enable the pg_net extension for HTTP requests
-- (This should already be enabled in most Supabase projects)
CREATE EXTENSION IF NOT EXISTS pg_net;

-- 2. Create the notification function
CREATE OR REPLACE FUNCTION notify_job_completion()
RETURNS TRIGGER AS $$
DECLARE
    edge_function_url TEXT;
    request_body JSONB;
    notification_title TEXT;
    notification_body TEXT;
BEGIN
    -- Only trigger when status changes to completed or failed
    -- and device_token exists and notification hasn't been sent
    IF (NEW.status IN ('completed', 'failed')) 
       AND (OLD.status IS NULL OR OLD.status NOT IN ('completed', 'failed'))
       AND NEW.device_token IS NOT NULL 
       AND (NEW.notification_sent IS NULL OR NEW.notification_sent = FALSE) THEN
        
        -- Build notification content based on job type and status
        IF NEW.status = 'completed' THEN
            IF NEW.job_type = 'video' THEN
                notification_title := 'Video Ready!';
                notification_body := 'Your AI video has been generated. Tap to view.';
            ELSE
                notification_title := 'Image Ready!';
                notification_body := 'Your AI image has been generated. Tap to view.';
            END IF;
        ELSE -- failed
            notification_title := 'Generation Failed';
            notification_body := COALESCE(NEW.error_message, 'Something went wrong. Please try again.');
        END IF;
        
        -- Build the Edge Function URL
        -- Replace with your actual Supabase project URL
        edge_function_url := 'https://inaffymocuppuddsewyq.supabase.co/functions/v1/send-push-notification';
        
        -- Build the request body
        request_body := jsonb_build_object(
            'device_token', NEW.device_token,
            'job_id', NEW.id::TEXT,
            'job_type', NEW.job_type,
            'title', notification_title,
            'body', notification_body,
            'status', NEW.status
        );
        
        -- Call the Edge Function asynchronously
        -- Note: This uses pg_net which sends HTTP requests asynchronously
        PERFORM net.http_post(
            url := edge_function_url,
            body := request_body::TEXT,
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
            )::jsonb
        );
        
        -- Mark notification as sent (to prevent duplicates)
        -- Note: This is done in the same transaction
        NEW.notification_sent := TRUE;
        
        RAISE LOG 'Push notification queued for job %', NEW.id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Create the trigger
DROP TRIGGER IF EXISTS on_job_completion_notify ON pending_jobs;
CREATE TRIGGER on_job_completion_notify
    BEFORE UPDATE ON pending_jobs
    FOR EACH ROW
    EXECUTE FUNCTION notify_job_completion();

-- ============================================
-- ALTERNATIVE: Simpler trigger using Edge Function invoke
-- ============================================
-- If pg_net doesn't work, you can use Supabase Edge Function invocation
-- This requires the supabase_functions extension

-- CREATE OR REPLACE FUNCTION notify_job_completion_simple()
-- RETURNS TRIGGER AS $$
-- BEGIN
--     IF (NEW.status IN ('completed', 'failed')) 
--        AND (OLD.status IS NULL OR OLD.status NOT IN ('completed', 'failed'))
--        AND NEW.device_token IS NOT NULL THEN
--         
--         -- Use Supabase Edge Function invocation
--         PERFORM
--             extensions.http((
--                 'POST',
--                 'https://inaffymocuppuddsewyq.supabase.co/functions/v1/send-push-notification',
--                 ARRAY[http_header('Content-Type', 'application/json')],
--                 'application/json',
--                 json_build_object(
--                     'device_token', NEW.device_token,
--                     'job_id', NEW.id,
--                     'job_type', NEW.job_type,
--                     'status', NEW.status
--                 )::text
--             ));
--         
--         NEW.notification_sent := TRUE;
--     END IF;
--     
--     RETURN NEW;
-- END;
-- $$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- VERIFICATION QUERIES
-- ============================================

-- Check if trigger was created
-- SELECT tgname, tgtype FROM pg_trigger WHERE tgname = 'on_job_completion_notify';

-- Check if function exists
-- SELECT proname FROM pg_proc WHERE proname = 'notify_job_completion';

-- Test the trigger by updating a job status (use a real job ID)
-- UPDATE pending_jobs 
-- SET status = 'completed', result_url = 'https://example.com/test.jpg'
-- WHERE task_id = 'test-task-id';

-- ============================================
-- NOTES
-- ============================================

-- 1. The pg_net extension sends HTTP requests asynchronously, which means:
--    - The trigger won't slow down your database operations
--    - Failures in the HTTP request won't affect the database transaction
--    - You won't get immediate feedback if the push notification fails

-- 2. For production, consider:
--    - Adding retry logic in the Edge Function
--    - Logging failed notifications to a separate table
--    - Implementing a cleanup job for old notification records

-- 3. The SECURITY DEFINER attribute means the function runs with the
--    privileges of the user who created it (typically the service role),
--    which is needed to access the service_role_key setting.
