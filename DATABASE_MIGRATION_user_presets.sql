-- Migration script to create user_presets table in Supabase
-- Run this in your Supabase SQL Editor

-- Create the user_presets table
CREATE TABLE IF NOT EXISTS user_presets (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    model_name TEXT,
    prompt TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

-- Create index on user_id for faster queries
CREATE INDEX IF NOT EXISTS idx_user_presets_user_id ON user_presets(user_id);

-- Create index on created_at for sorting
CREATE INDEX IF NOT EXISTS idx_user_presets_created_at ON user_presets(created_at DESC);

-- Enable Row Level Security (RLS)
ALTER TABLE user_presets ENABLE ROW LEVEL SECURITY;

-- Create policy: Users can only see their own presets
CREATE POLICY "Users can view their own presets"
    ON user_presets
    FOR SELECT
    USING (auth.uid() = user_id);

-- Create policy: Users can only insert their own presets
CREATE POLICY "Users can insert their own presets"
    ON user_presets
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Create policy: Users can only update their own presets
CREATE POLICY "Users can update their own presets"
    ON user_presets
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Create policy: Users can only delete their own presets
CREATE POLICY "Users can delete their own presets"
    ON user_presets
    FOR DELETE
    USING (auth.uid() = user_id);

-- Create function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc', NOW());
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to automatically update updated_at
CREATE TRIGGER update_user_presets_updated_at
    BEFORE UPDATE ON user_presets
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
