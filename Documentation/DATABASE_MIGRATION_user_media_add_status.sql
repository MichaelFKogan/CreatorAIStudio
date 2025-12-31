-- ============================================
-- MIGRATION: Add status and error_message to user_media
-- ============================================
-- Run this SQL in your Supabase Dashboard SQL Editor
-- Dashboard > SQL Editor > New Query > Paste and Run
--
-- This migration adds tracking for failed generations:
-- - status: 'success' (default) or 'failed'
-- - error_message: Stores error details for failed attempts

-- 1. Add status column with default 'success' for existing records
ALTER TABLE user_media 
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'success' 
CHECK (status IN ('success', 'failed'));

-- 2. Add error_message column for storing failure details
ALTER TABLE user_media 
ADD COLUMN IF NOT EXISTS error_message TEXT;

-- 3. Create index for efficient filtering by status
CREATE INDEX IF NOT EXISTS idx_user_media_status 
ON user_media(user_id, status, created_at DESC);

-- 4. Add comment to document the new columns
COMMENT ON COLUMN user_media.status IS 'Generation status: "success" for completed generations, "failed" for failed attempts';
COMMENT ON COLUMN user_media.error_message IS 'Error message for failed generations';

-- ============================================
-- VERIFICATION QUERIES (run after migration)
-- ============================================

-- Check columns were added
-- SELECT column_name, data_type, column_default 
-- FROM information_schema.columns 
-- WHERE table_name = 'user_media' 
-- AND column_name IN ('status', 'error_message');

-- Check index was created
-- SELECT indexname, indexdef 
-- FROM pg_indexes 
-- WHERE tablename = 'user_media' 
-- AND indexname = 'idx_user_media_status';

-- Check existing records have status = 'success'
-- SELECT status, COUNT(*) 
-- FROM user_media 
-- GROUP BY status;

