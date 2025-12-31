-- ============================================
-- MIGRATION: Add duration and resolution to user_media
-- ============================================
-- Run this SQL in your Supabase Dashboard SQL Editor
-- Dashboard > SQL Editor > New Query > Paste and Run
--
-- This migration adds video-specific fields:
-- - duration: Video duration in seconds (for videos only)
-- - resolution: Video resolution (e.g., "720p", "1080p") (for videos only)

-- 1. Add duration column (nullable, only for videos)
ALTER TABLE user_media 
ADD COLUMN IF NOT EXISTS duration DOUBLE PRECISION;

-- 2. Add resolution column (nullable, only for videos)
ALTER TABLE user_media 
ADD COLUMN IF NOT EXISTS resolution TEXT;

-- 3. Create index for video queries (optional, for performance)
CREATE INDEX IF NOT EXISTS idx_user_media_video_fields 
ON user_media(user_id, media_type) 
WHERE media_type = 'video';

-- 4. Add comments to document the new columns
COMMENT ON COLUMN user_media.duration IS 'Video duration in seconds (for videos only)';
COMMENT ON COLUMN user_media.resolution IS 'Video resolution (e.g., "720p", "1080p") (for videos only)';

-- ============================================
-- VERIFICATION QUERIES (run after migration)
-- ============================================

-- Check columns were added
-- SELECT column_name, data_type, is_nullable 
-- FROM information_schema.columns 
-- WHERE table_name = 'user_media' 
-- AND column_name IN ('duration', 'resolution');

-- Check index was created
-- SELECT indexname, indexdef 
-- FROM pg_indexes 
-- WHERE tablename = 'user_media' 
-- AND indexname = 'idx_user_media_video_fields';

