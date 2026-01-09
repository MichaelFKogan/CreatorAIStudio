-- ============================================
-- MIGRATION: Auto-update user_stats with Database Triggers
-- ============================================
-- Run this SQL in your Supabase Dashboard SQL Editor
-- Dashboard > SQL Editor > New Query > Paste and Run
--
-- This migration creates triggers that automatically update user_stats
-- whenever user_media is inserted, updated, or deleted.
-- This eliminates the need for manual count updates in the app code.
--
-- IMPORTANT: After running this migration, you can remove manual count
-- update code from ProfileViewModel.swift (incrementFavoriteCount, 
-- decrementFavoriteCount, updateModelCountsForImage, etc.)

-- ============================================
-- FUNCTION: Recompute user_stats from user_media
-- ============================================

CREATE OR REPLACE FUNCTION recompute_user_stats(target_user_id UUID)
RETURNS void AS $$
DECLARE
    computed_favorite_count INTEGER;
    computed_image_count INTEGER;
    computed_video_count INTEGER;
    computed_model_counts JSONB;
    computed_video_model_counts JSONB;
BEGIN
    -- Count favorites (only successful items)
    SELECT COUNT(*) INTO computed_favorite_count
    FROM user_media
    WHERE user_id = target_user_id
      AND is_favorite = true
      AND (status = 'success' OR status IS NULL);
    
    -- Count images (media_type = 'image' or NULL, only successful)
    SELECT COUNT(*) INTO computed_image_count
    FROM user_media
    WHERE user_id = target_user_id
      AND (media_type = 'image' OR media_type IS NULL)
      AND (status = 'success' OR status IS NULL);
    
    -- Count videos (media_type = 'video', only successful)
    SELECT COUNT(*) INTO computed_video_count
    FROM user_media
    WHERE user_id = target_user_id
      AND media_type = 'video'
      AND (status = 'success' OR status IS NULL);
    
    -- Compute model counts for images (only successful items with non-null models)
    SELECT COALESCE(
        jsonb_object_agg(model, count) FILTER (WHERE model IS NOT NULL AND model != ''),
        '{}'::jsonb
    ) INTO computed_model_counts
    FROM (
        SELECT model, COUNT(*) as count
        FROM user_media
        WHERE user_id = target_user_id
          AND (media_type = 'image' OR media_type IS NULL)
          AND (status = 'success' OR status IS NULL)
          AND model IS NOT NULL
          AND model != ''
        GROUP BY model
    ) AS image_models;
    
    -- Compute model counts for videos (only successful items with non-null models)
    SELECT COALESCE(
        jsonb_object_agg(model, count) FILTER (WHERE model IS NOT NULL AND model != ''),
        '{}'::jsonb
    ) INTO computed_video_model_counts
    FROM (
        SELECT model, COUNT(*) as count
        FROM user_media
        WHERE user_id = target_user_id
          AND media_type = 'video'
          AND (status = 'success' OR status IS NULL)
          AND model IS NOT NULL
          AND model != ''
        GROUP BY model
    ) AS video_models;
    
    -- Insert or update user_stats
    INSERT INTO user_stats (
        user_id,
        favorite_count,
        image_count,
        video_count,
        model_counts,
        video_model_counts,
        updated_at
    ) VALUES (
        target_user_id,
        computed_favorite_count,
        computed_image_count,
        computed_video_count,
        computed_model_counts,
        computed_video_model_counts,
        TIMEZONE('utc', NOW())
    )
    ON CONFLICT (user_id) 
    DO UPDATE SET
        favorite_count = EXCLUDED.favorite_count,
        image_count = EXCLUDED.image_count,
        video_count = EXCLUDED.video_count,
        model_counts = EXCLUDED.model_counts,
        video_model_counts = EXCLUDED.video_model_counts,
        updated_at = TIMEZONE('utc', NOW());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- TRIGGER FUNCTION: Update stats on user_media changes
-- ============================================

CREATE OR REPLACE FUNCTION update_user_stats_on_media_change()
RETURNS TRIGGER AS $$
DECLARE
    affected_user_id UUID;
BEGIN
    -- Determine which user_id was affected
    IF TG_OP = 'DELETE' THEN
        affected_user_id := OLD.user_id;
    ELSE
        affected_user_id := NEW.user_id;
    END IF;
    
    -- Recompute stats for the affected user
    PERFORM recompute_user_stats(affected_user_id);
    
    -- Return appropriate value based on operation
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- CREATE TRIGGERS
-- ============================================

-- Drop existing triggers if they exist (for re-running migration)
DROP TRIGGER IF EXISTS user_media_stats_insert_trigger ON user_media;
DROP TRIGGER IF EXISTS user_media_stats_update_trigger ON user_media;
DROP TRIGGER IF EXISTS user_media_stats_delete_trigger ON user_media;

-- Trigger for INSERT operations
CREATE TRIGGER user_media_stats_insert_trigger
    AFTER INSERT ON user_media
    FOR EACH ROW
    WHEN (NEW.status = 'success' OR NEW.status IS NULL)
    EXECUTE FUNCTION update_user_stats_on_media_change();

-- Trigger for UPDATE operations (only when relevant fields change)
CREATE TRIGGER user_media_stats_update_trigger
    AFTER UPDATE ON user_media
    FOR EACH ROW
    WHEN (
        -- Only trigger if relevant fields changed
        (OLD.is_favorite IS DISTINCT FROM NEW.is_favorite) OR
        (OLD.media_type IS DISTINCT FROM NEW.media_type) OR
        (OLD.model IS DISTINCT FROM NEW.model) OR
        (OLD.status IS DISTINCT FROM NEW.status) OR
        (OLD.user_id IS DISTINCT FROM NEW.user_id)
    )
    EXECUTE FUNCTION update_user_stats_on_media_change();

-- Trigger for DELETE operations
CREATE TRIGGER user_media_stats_delete_trigger
    AFTER DELETE ON user_media
    FOR EACH ROW
    EXECUTE FUNCTION update_user_stats_on_media_change();

-- ============================================
-- INITIAL SYNC: Recompute all existing stats
-- ============================================
-- This ensures all existing user_stats are accurate after migration

DO $$
DECLARE
    user_record RECORD;
BEGIN
    -- Loop through all users who have media
    FOR user_record IN 
        SELECT DISTINCT user_id 
        FROM user_media
    LOOP
        PERFORM recompute_user_stats(user_record.user_id);
    END LOOP;
    
    RAISE NOTICE 'Initial stats sync completed for all users';
END $$;

-- ============================================
-- VERIFICATION QUERIES (run after migration)
-- ============================================

-- Check triggers were created
-- SELECT trigger_name, event_manipulation, event_object_table
-- FROM information_schema.triggers
-- WHERE event_object_table = 'user_media'
-- AND trigger_name LIKE '%stats%';

-- Test: Insert a new media item and check if stats update
-- (Replace with actual user_id and test data)
-- INSERT INTO user_media (user_id, image_url, media_type, status, is_favorite)
-- VALUES ('YOUR_USER_ID', 'https://test.com/image.jpg', 'image', 'success', false);
-- 
-- SELECT * FROM user_stats WHERE user_id = 'YOUR_USER_ID';

-- Test: Update favorite status and check if stats update
-- UPDATE user_media SET is_favorite = true WHERE id = 'SOME_ID';
-- SELECT favorite_count FROM user_stats WHERE user_id = 'YOUR_USER_ID';

-- Test: Delete a media item and check if stats update
-- DELETE FROM user_media WHERE id = 'SOME_ID';
-- SELECT * FROM user_stats WHERE user_id = 'YOUR_USER_ID';
