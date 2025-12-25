-- Migration script to add image_count and video_count to user_stats table
-- Run this in your Supabase SQL Editor after the initial user_stats table is created

-- Add image_count and video_count columns
ALTER TABLE user_stats 
ADD COLUMN IF NOT EXISTS image_count INTEGER DEFAULT 0 NOT NULL,
ADD COLUMN IF NOT EXISTS video_count INTEGER DEFAULT 0 NOT NULL;

-- Add comments to document the new columns
COMMENT ON COLUMN user_stats.image_count IS 'Total number of images (media_type = "image" or NULL)';
COMMENT ON COLUMN user_stats.video_count IS 'Total number of videos (media_type = "video")';
