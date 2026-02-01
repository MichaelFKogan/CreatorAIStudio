-- ============================================================================
-- User Playlists Setup
-- Custom playlists for organizing user-generated media
-- ============================================================================

-- Drop existing tables if they exist (for clean migration)
DROP TABLE IF EXISTS user_playlist_items CASCADE;
DROP TABLE IF EXISTS user_playlists CASCADE;

-- ============================================================================
-- user_playlists: Stores user-created playlists
-- ============================================================================
CREATE TABLE user_playlists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- user_playlist_items: Junction table linking playlists to media
-- ============================================================================
CREATE TABLE user_playlist_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    playlist_id UUID NOT NULL REFERENCES user_playlists(id) ON DELETE CASCADE,
    image_id UUID NOT NULL REFERENCES user_media(id) ON DELETE CASCADE,
    added_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(playlist_id, image_id)  -- Prevent duplicates
);

-- ============================================================================
-- Indexes for performance
-- ============================================================================
CREATE INDEX idx_user_playlists_user_id ON user_playlists(user_id);
CREATE INDEX idx_user_playlists_created_at ON user_playlists(created_at DESC);
CREATE INDEX idx_user_playlist_items_playlist_id ON user_playlist_items(playlist_id);
CREATE INDEX idx_user_playlist_items_image_id ON user_playlist_items(image_id);
CREATE INDEX idx_user_playlist_items_added_at ON user_playlist_items(added_at DESC);

-- ============================================================================
-- Row Level Security (RLS) Policies
-- ============================================================================

-- Enable RLS on both tables
ALTER TABLE user_playlists ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_playlist_items ENABLE ROW LEVEL SECURITY;

-- Policies for user_playlists table
CREATE POLICY "Users can view own playlists" 
    ON user_playlists
    FOR SELECT 
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own playlists" 
    ON user_playlists
    FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own playlists" 
    ON user_playlists
    FOR UPDATE 
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own playlists" 
    ON user_playlists
    FOR DELETE 
    USING (auth.uid() = user_id);

-- Policies for user_playlist_items table
-- Users can only access items in their own playlists
CREATE POLICY "Users can view own playlist items" 
    ON user_playlist_items
    FOR SELECT 
    USING (EXISTS (
        SELECT 1 FROM user_playlists 
        WHERE id = playlist_id AND user_id = auth.uid()
    ));

CREATE POLICY "Users can insert own playlist items" 
    ON user_playlist_items
    FOR INSERT 
    WITH CHECK (EXISTS (
        SELECT 1 FROM user_playlists 
        WHERE id = playlist_id AND user_id = auth.uid()
    ));

CREATE POLICY "Users can delete own playlist items" 
    ON user_playlist_items
    FOR DELETE 
    USING (EXISTS (
        SELECT 1 FROM user_playlists 
        WHERE id = playlist_id AND user_id = auth.uid()
    ));

-- ============================================================================
-- Trigger to auto-update updated_at timestamp
-- ============================================================================
CREATE OR REPLACE FUNCTION update_user_playlists_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_user_playlists_updated_at
    BEFORE UPDATE ON user_playlists
    FOR EACH ROW
    EXECUTE FUNCTION update_user_playlists_updated_at();

-- ============================================================================
-- Grant permissions for authenticated users
-- ============================================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON user_playlists TO authenticated;
GRANT SELECT, INSERT, DELETE ON user_playlist_items TO authenticated;
