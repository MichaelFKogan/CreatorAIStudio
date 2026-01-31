-- ============================================
-- USER DEVICES TABLE FOR PUSH NOTIFICATIONS
-- ============================================
-- Run this SQL in your Supabase Dashboard SQL Editor
-- Dashboard > SQL Editor > New Query > Paste and Run
--
-- Stores APNs device token per user for sending push notifications
-- when image/video generation completes (via send-push-notification Edge Function).

-- 1. Create the user_devices table (one row per user = current device token)
CREATE TABLE IF NOT EXISTS user_devices (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    device_token TEXT NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Ensure update_updated_at_column exists (shared with pending_jobs_setup.sql)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Create updated_at trigger so updates refresh the timestamp
DROP TRIGGER IF EXISTS update_user_devices_updated_at ON user_devices;
CREATE TRIGGER update_user_devices_updated_at
    BEFORE UPDATE ON user_devices
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 4. Enable Row Level Security
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policies: users can only manage their own device row
CREATE POLICY "Users can view own device"
    ON user_devices
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own device"
    ON user_devices
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own device"
    ON user_devices
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- ============================================
-- VERIFICATION (run after setup)
-- ============================================
-- SELECT * FROM user_devices LIMIT 1;
-- SELECT relname, relrowsecurity FROM pg_class WHERE relname = 'user_devices';
-- SELECT policyname FROM pg_policies WHERE tablename = 'user_devices';
