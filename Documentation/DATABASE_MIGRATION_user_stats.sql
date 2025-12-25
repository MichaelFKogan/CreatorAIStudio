-- Migration script to create user_stats table in Supabase
-- Run this in your Supabase SQL Editor
-- This table stores pre-computed counts to avoid expensive queries

-- Create the user_stats table
CREATE TABLE IF NOT EXISTS user_stats (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    favorite_count INTEGER DEFAULT 0 NOT NULL,
    model_counts JSONB DEFAULT '{}'::jsonb NOT NULL,  -- {"model_name": count, ...}
    video_model_counts JSONB DEFAULT '{}'::jsonb NOT NULL,  -- {"model_name": count, ...}
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

-- Create index on user_id for faster queries (UNIQUE constraint already creates an index, but being explicit)
CREATE INDEX IF NOT EXISTS idx_user_stats_user_id ON user_stats(user_id);

-- Create index on updated_at for sorting
CREATE INDEX IF NOT EXISTS idx_user_stats_updated_at ON user_stats(updated_at DESC);

-- Enable Row Level Security (RLS)
ALTER TABLE user_stats ENABLE ROW LEVEL SECURITY;

-- Create policy: Users can only see their own stats
CREATE POLICY "Users can view their own stats"
    ON user_stats
    FOR SELECT
    USING (auth.uid() = user_id);

-- Create policy: Users can only insert their own stats
CREATE POLICY "Users can insert their own stats"
    ON user_stats
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Create policy: Users can only update their own stats
CREATE POLICY "Users can update their own stats"
    ON user_stats
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Create policy: Users can only delete their own stats
CREATE POLICY "Users can delete their own stats"
    ON user_stats
    FOR DELETE
    USING (auth.uid() = user_id);

-- Create function to automatically update updated_at timestamp
-- (Reusing the existing function if it exists, or creating it)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc', NOW());
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to automatically update updated_at
CREATE TRIGGER update_user_stats_updated_at
    BEFORE UPDATE ON user_stats
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Add comments to document the columns
COMMENT ON TABLE user_stats IS 'Pre-computed statistics for users to avoid expensive queries';
COMMENT ON COLUMN user_stats.favorite_count IS 'Total number of favorited images/videos';
COMMENT ON COLUMN user_stats.model_counts IS 'JSON object mapping model names to image counts: {"model_name": count}';
COMMENT ON COLUMN user_stats.video_model_counts IS 'JSON object mapping model names to video counts: {"model_name": count}';
