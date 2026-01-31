-- ============================================
-- DROP PUSH NOTIFICATION TRIGGER (temporary fix)
-- ============================================
-- Run this in Supabase SQL Editor if the push notification trigger
-- is causing webhook-receiver updates to pending_jobs to roll back
-- (so jobs never show as completed in the app).
--
-- After running this, webhook-receiver's UPDATE to pending_jobs will
-- commit normally and images will complete again.
-- You can re-add a safe version of the trigger later.

DROP TRIGGER IF EXISTS on_job_completion_notify ON pending_jobs;
