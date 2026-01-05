-- ============================================
-- PENDING JOBS TABLE FOR WEBHOOK INTEGRATION
-- ============================================
-- Run this SQL in your Supabase Dashboard SQL Editor
-- Dashboard > SQL Editor > New Query > Paste and Run

-- 1. Create the pending_jobs table
CREATE TABLE IF NOT EXISTS pending_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    task_id TEXT NOT NULL UNIQUE,  -- Runware taskUUID or WaveSpeed job ID
    provider TEXT NOT NULL CHECK (provider IN ('runware', 'wavespeed', 'falai')),
    job_type TEXT NOT NULL CHECK (job_type IN ('image', 'video')),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    result_url TEXT,                -- URL returned by webhook (temporary API URL)
    error_message TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,  -- Store prompt, aspect ratio, model, etc.
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    
    -- For push notifications
    device_token TEXT,              -- APNs device token for this user/job
    notification_sent BOOLEAN DEFAULT FALSE
);

-- 2. Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_pending_jobs_user_id ON pending_jobs(user_id);
CREATE INDEX IF NOT EXISTS idx_pending_jobs_task_id ON pending_jobs(task_id);
CREATE INDEX IF NOT EXISTS idx_pending_jobs_status ON pending_jobs(status);
CREATE INDEX IF NOT EXISTS idx_pending_jobs_created_at ON pending_jobs(created_at DESC);

-- 3. Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Apply trigger to pending_jobs
DROP TRIGGER IF EXISTS update_pending_jobs_updated_at ON pending_jobs;
CREATE TRIGGER update_pending_jobs_updated_at
    BEFORE UPDATE ON pending_jobs
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 5. Enable Row Level Security
ALTER TABLE pending_jobs ENABLE ROW LEVEL SECURITY;

-- 6. Create RLS Policies

-- Users can view their own jobs
CREATE POLICY "Users can view own pending jobs"
    ON pending_jobs
    FOR SELECT
    USING (auth.uid() = user_id);

-- Users can insert their own jobs
CREATE POLICY "Users can create own pending jobs"
    ON pending_jobs
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Users can update their own jobs (for cleanup/cancellation)
CREATE POLICY "Users can update own pending jobs"
    ON pending_jobs
    FOR UPDATE
    USING (auth.uid() = user_id);

-- Users can delete their own jobs
CREATE POLICY "Users can delete own pending jobs"
    ON pending_jobs
    FOR DELETE
    USING (auth.uid() = user_id);

-- Service role can do anything (for Edge Functions)
-- Note: Service role bypasses RLS by default, so no policy needed

-- 7. Enable Realtime for this table
-- This allows iOS app to subscribe to changes
ALTER PUBLICATION supabase_realtime ADD TABLE pending_jobs;

-- 8. Create a function to clean up old completed/failed jobs (optional)
-- Run this periodically to prevent table bloat
CREATE OR REPLACE FUNCTION cleanup_old_pending_jobs()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM pending_jobs
    WHERE status IN ('completed', 'failed')
    AND completed_at < NOW() - INTERVAL '7 days';
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- VERIFICATION QUERIES (run after setup)
-- ============================================

-- Check table was created
-- SELECT * FROM pending_jobs LIMIT 1;

-- Check RLS is enabled
-- SELECT relname, relrowsecurity FROM pg_class WHERE relname = 'pending_jobs';

-- Check policies exist
-- SELECT policyname FROM pg_policies WHERE tablename = 'pending_jobs';

-- Check Realtime is enabled
-- SELECT * FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'pending_jobs';
