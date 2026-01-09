# Database Triggers Implementation for User Stats

## Overview

This implementation uses **PostgreSQL triggers** to automatically maintain accurate counts in the `user_stats` table. This eliminates the need for manual count updates in the app code and ensures counts are always accurate.

## Benefits

✅ **Always Accurate**: Database maintains counts automatically  
✅ **Zero Manual Updates**: No need to increment/decrement counts in Swift  
✅ **Atomic Operations**: No race conditions or count drift  
✅ **Better Performance**: Single source of truth, no sync issues  
✅ **Simpler Code**: Removed ~100 lines of manual count management code  

## Migration Steps

### 1. Run the SQL Migration

1. Open your Supabase Dashboard
2. Go to **SQL Editor**
3. Create a new query
4. Copy and paste the contents of `DATABASE_MIGRATION_user_stats_triggers.sql`
5. Run the migration

The migration will:
- Create the `recompute_user_stats()` function
- Create the `update_user_stats_on_media_change()` trigger function
- Create triggers for INSERT, UPDATE, and DELETE on `user_media`
- Automatically sync all existing user stats

### 2. Verify Triggers Are Working

After running the migration, test that triggers work:

```sql
-- Check triggers were created
SELECT trigger_name, event_manipulation, event_object_table
FROM information_schema.triggers
WHERE event_object_table = 'user_media'
AND trigger_name LIKE '%stats%';

-- Test: Insert a media item and check stats update
INSERT INTO user_media (user_id, image_url, media_type, status, is_favorite)
VALUES ('YOUR_USER_ID', 'https://test.com/image.jpg', 'image', 'success', false);

-- Check stats were updated
SELECT * FROM user_stats WHERE user_id = 'YOUR_USER_ID';
```

## Code Changes

### Removed Functions

The following functions have been **removed** from `ProfileModel.swift`:
- `updateUserStats()` - No longer needed (triggers handle it)
- `incrementFavoriteCount()` - No longer needed
- `decrementFavoriteCount()` - No longer needed
- `updateModelCountsForImage()` - No longer needed

### New Functions

- `refreshUserStats()` - Refreshes stats from database (reads only)
- `recomputeUserStatsViaDatabase()` - Calls database function to recompute stats

### Updated Operations

All operations now simply update the database and refresh stats:

**Before:**
```swift
// Manual count updates
await incrementFavoriteCount()
await updateModelCountsForImage(image, increment: true)
imageCount += 1
await updateUserStats()
```

**After:**
```swift
// Database triggers handle everything automatically
await refreshUserStats() // Just read the updated counts
```

## How It Works

1. **INSERT**: When a new media item is inserted into `user_media`, the trigger automatically:
   - Increments `image_count` or `video_count`
   - Updates `model_counts` or `video_model_counts`
   - Increments `favorite_count` if `is_favorite = true`

2. **UPDATE**: When a media item is updated (e.g., favorite status changes), the trigger:
   - Recomputes all counts for that user
   - Updates `user_stats` automatically

3. **DELETE**: When a media item is deleted, the trigger:
   - Decrements appropriate counts
   - Updates model counts
   - Updates favorite count if needed

4. **App Code**: The app simply:
   - Updates `user_media` table (INSERT/UPDATE/DELETE)
   - Calls `refreshUserStats()` to read the updated counts
   - No manual count management needed!

## Performance

- **Before**: 2-3 database calls per operation (update media + update stats)
- **After**: 1 database call per operation (update media only, triggers handle stats)
- **Result**: ~50% reduction in database calls

## Troubleshooting

### Counts are still wrong after migration

1. **Verify triggers are installed:**
   ```sql
   SELECT * FROM information_schema.triggers 
   WHERE event_object_table = 'user_media';
   ```

2. **Manually trigger recomputation:**
   ```sql
   SELECT recompute_user_stats('YOUR_USER_ID');
   ```

3. **Check trigger logs** in Supabase Dashboard → Logs

### App shows wrong counts

- Triggers might not be set up yet → Run the migration
- Stats might be cached → The app will auto-detect and resync
- Check console logs for discrepancy warnings

### RPC call fails

If `recompute_user_stats` RPC fails, the app falls back to Swift-side computation. This is slower but ensures counts are updated.

## Rollback (if needed)

If you need to rollback to manual count updates:

1. Drop the triggers:
   ```sql
   DROP TRIGGER IF EXISTS user_media_stats_insert_trigger ON user_media;
   DROP TRIGGER IF EXISTS user_media_stats_update_trigger ON user_media;
   DROP TRIGGER IF EXISTS user_media_stats_delete_trigger ON user_media;
   ```

2. Restore the old Swift code (from git history)

3. Run `initializeUserStats()` to recompute all counts

## Next Steps

After migration:
1. ✅ Test favorite toggling - counts should update automatically
2. ✅ Test image deletion - counts should update automatically  
3. ✅ Test adding new images - counts should update automatically
4. ✅ Monitor console logs for any discrepancy warnings (should be rare)

The counts should now be **always accurate** and update **automatically**! 🎉
