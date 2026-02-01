-- ============================================
-- One-time migration: Rename model to "Nano Banana"
-- ============================================
-- Run this once in Supabase SQL Editor after deploying the app change that renames
-- "Google Gemini Flash 2.5 (Nano Banana)" to "Nano Banana" everywhere in code/JSON.
-- Idempotent-safe: safe to run multiple times (no double-counting or corruption).

-- 1. user_presets: update model_name
UPDATE user_presets
SET model_name = 'Nano Banana'
WHERE model_name = 'Google Gemini Flash 2.5 (Nano Banana)';

-- 2. user_media: update model column
UPDATE user_media
SET model = 'Nano Banana'
WHERE model = 'Google Gemini Flash 2.5 (Nano Banana)';

-- 3. user_stats: rename key in model_counts and merge counts
UPDATE user_stats
SET model_counts = jsonb_set(
    model_counts - 'Google Gemini Flash 2.5 (Nano Banana)',
    '{Nano Banana}',
    to_jsonb(
        COALESCE((model_counts->>'Nano Banana')::int, 0)
        + COALESCE((model_counts->>'Google Gemini Flash 2.5 (Nano Banana)')::int, 0)
    )
)
WHERE model_counts ? 'Google Gemini Flash 2.5 (Nano Banana)';

-- 4. user_stats: rename key in video_model_counts and merge counts
UPDATE user_stats
SET video_model_counts = jsonb_set(
    video_model_counts - 'Google Gemini Flash 2.5 (Nano Banana)',
    '{Nano Banana}',
    to_jsonb(
        COALESCE((video_model_counts->>'Nano Banana')::int, 0)
        + COALESCE((video_model_counts->>'Google Gemini Flash 2.5 (Nano Banana)')::int, 0)
    )
)
WHERE video_model_counts ? 'Google Gemini Flash 2.5 (Nano Banana)';

-- 5. pending_jobs: update metadata.model where it equals the old name
UPDATE pending_jobs
SET metadata = jsonb_set(metadata - 'model', '{model}', '"Nano Banana"')
WHERE metadata->>'model' = 'Google Gemini Flash 2.5 (Nano Banana)';
