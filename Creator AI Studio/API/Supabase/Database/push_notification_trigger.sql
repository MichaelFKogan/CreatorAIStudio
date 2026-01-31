-- ============================================
-- PUSH NOTIFICATION TRIGGER FOR JOB COMPLETION
-- ============================================
-- Run this SQL in your Supabase Dashboard SQL Editor AFTER:
-- 1. Setting up the pending_jobs table (pending_jobs_setup.sql)
-- 2. Deploying the send-push-notification Edge Function
-- 3. Configuring APNs credentials in Supabase secrets
--
-- This trigger sets notification_sent when status changes to 'completed' or 'failed'.
-- Push is sent from the webhook-receiver Edge Function (not from this trigger).

-- 1. Create the notification function
-- IMPORTANT: This trigger only sets notification_sent so the webhook-receiver's
-- UPDATE to pending_jobs always commits. We do NOT call pg_net here because
-- pg_net/extension/settings can fail and roll back the whole transaction.
-- To send push notifications, call send-push-notification from your
-- webhook-receiver Edge Function AFTER it updates pending_jobs (see SETUP_INSTRUCTIONS).
CREATE OR REPLACE FUNCTION notify_job_completion()
RETURNS TRIGGER AS $$
BEGIN
    -- When status changes to completed or failed and we have a device token,
    -- mark notification_sent so the column is set. No HTTP call in trigger.
    IF (NEW.status IN ('completed', 'failed')) 
       AND (OLD.status IS NULL OR OLD.status NOT IN ('completed', 'failed'))
       AND NEW.device_token IS NOT NULL 
       AND (NEW.notification_sent IS NULL OR NEW.notification_sent = FALSE) THEN
        NEW.notification_sent := TRUE;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Create the trigger
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
