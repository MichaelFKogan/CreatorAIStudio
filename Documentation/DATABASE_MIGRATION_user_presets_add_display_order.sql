-- Migration script to add display_order column to user_presets table
-- Run this in your Supabase SQL Editor if you've already created the table

-- Add display_order column to existing table
ALTER TABLE user_presets 
ADD COLUMN IF NOT EXISTS display_order INTEGER DEFAULT 0;

-- Create index on display_order for faster sorting
CREATE INDEX IF NOT EXISTS idx_user_presets_display_order ON user_presets(user_id, display_order);

-- Update existing presets to have a display_order based on created_at
-- This ensures existing presets have a valid order
UPDATE user_presets
SET display_order = subquery.row_number
FROM (
    SELECT id, ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at DESC) as row_number
    FROM user_presets
) AS subquery
WHERE user_presets.id = subquery.id;

-- Add comment to document the column
COMMENT ON COLUMN user_presets.display_order IS 'Custom display order for presets (lower numbers appear first)';
