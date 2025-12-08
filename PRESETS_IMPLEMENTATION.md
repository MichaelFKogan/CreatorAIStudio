# Presets Implementation Guide

## Overview

This implementation adds the ability to save and retrieve presets from Supabase. Presets save the current image model and prompt settings so users can quickly reuse them later.

## What Was Implemented

### 1. Models (`PresetModel.swift`)

- **Preset**: The main model representing a preset (similar to `InfoPacket` for photo filters)
- **PresetMetadata**: Struct for saving presets to the database

### 2. ViewModel (`PresetViewModel.swift`)

- Manages loading presets from Supabase
- Handles saving new presets
- Handles deleting presets
- Caches presets locally using `@AppStorage`
- Automatically loads cached presets on initialization

### 3. Updated `CreatePresetSheet`

- Now saves presets to Supabase when "Save" is pressed
- Saves:
  - Preset title (user input)
  - Model name (from `userImage.title`)
  - Prompt text (from `userImage.prompt`)
- Shows loading state while saving
- Shows error alerts if saving fails

### 4. Database Setup

- SQL migration script provided: `DATABASE_MIGRATION_user_presets.sql`
- Table: `user_presets`
- Row Level Security (RLS) enabled
- Users can only access their own presets

## Database Setup Instructions

1. Open your Supabase dashboard
2. Go to SQL Editor
3. Run the migration script: `DATABASE_MIGRATION_user_presets.sql`
4. This will create:
   - The `user_presets` table
   - Indexes for performance
   - RLS policies for security
   - Auto-update trigger for `updated_at`

## How to Use Presets

### Saving a Preset

1. Open an image in full screen view
2. Tap the "Preset" button
3. Enter a name for the preset
4. Tap "Save"
5. The preset is saved to Supabase with the current model and prompt

### Loading Presets (for future use)

```swift
// In any view that needs presets:
@StateObject private var presetViewModel = PresetViewModel()
@EnvironmentObject var authViewModel: AuthViewModel

// In onAppear or similar:
.onAppear {
    if let userId = authViewModel.user?.id.uuidString {
        presetViewModel.userId = userId
    }
    Task {
        await presetViewModel.fetchPresets()
    }
}

// Access presets:
presetViewModel.presets
```

### Converting Presets to InfoPacket (for use with existing filter system)

To use presets similar to photo filters, you can convert them:

```swift
func convertPresetToInfoPacket(_ preset: Preset) -> InfoPacket? {
    // Find the matching image model
    let allModels = ImageModelsViewModel.loadImageModels()
    guard let matchingModel = allModels.first(where: { $0.display.title == preset.modelName }) else {
        return nil
    }

    // Create a new InfoPacket with the preset's prompt
    var infoPacket = matchingModel
    infoPacket.prompt = preset.prompt
    return infoPacket
}
```

## Next Steps (Optional)

To display presets in other parts of the app (similar to photo filters):

1. Create a `PresetsView` similar to `PhotoFilters.swift`
2. Load presets using `PresetViewModel`
3. Convert presets to `InfoPacket` format for compatibility
4. Display them in a grid or list
5. Allow users to select a preset to apply its settings

## Files Created/Modified

### Created:

- `Creator AI Studio/Models/PresetModel.swift`
- `Creator AI Studio/Pages/5 Profile/ViewModels/PresetViewModel.swift`
- `DATABASE_MIGRATION_user_presets.sql`
- `PRESETS_IMPLEMENTATION.md`

### Modified:

- `Creator AI Studio/Pages/5 Profile/FullScreenImageView.swift`
  - Added `CreatePresetSheet` save functionality
  - Added `AuthViewModel` environment object
- `Creator AI Studio/Pages/3 Image/ImageModelDetailPage.swift`
  - Added `AuthViewModel` environment object to `FullScreenImageView`

## Testing

1. **Test Saving:**

   - Open an image with a model and prompt
   - Create a preset
   - Verify it appears in Supabase database

2. **Test Loading:**

   - Restart the app
   - Verify presets are loaded from cache immediately
   - Verify presets are fetched from database

3. **Test Error Handling:**
   - Try saving without being signed in
   - Verify error message appears
