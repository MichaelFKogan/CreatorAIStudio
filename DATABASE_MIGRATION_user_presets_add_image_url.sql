-- Migration script to add image_url column to user_presets table
-- Run this in your Supabase SQL Editor if you've already created the table

-- Add image_url column to existing table
ALTER TABLE user_presets 
ADD COLUMN IF NOT EXISTS image_url TEXT;

-- Add comment to document the column
COMMENT ON COLUMN user_presets.image_url IS 'URL of the user-generated image associated with this preset';
