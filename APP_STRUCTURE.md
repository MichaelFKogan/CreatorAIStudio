# Creator AI Studio - App Structure Documentation

## Overview

Creator AI Studio is an iOS app built with SwiftUI that allows users to generate AI-powered images and videos using various AI models. The app supports photo filters, image generation, and video generation with real-time progress tracking, webhook-based job completion, and cloud storage integration.

## Architecture

- **Framework**: SwiftUI
- **Backend**: Supabase (PostgreSQL database, Storage, Realtime, Edge Functions)
- **API Providers**: Runware API, WaveSpeed API
- **Architecture Pattern**: MVVM with Coordinators
- **Concurrency**: Swift Concurrency (async/await, Task)
- **State Management**: ObservableObject, @Published, @StateObject, @EnvironmentObject

---

## Key Components & Locations

### 1. Database & Data Persistence

**Location**: `Creator AI Studio/API/Supabase/`

#### SupabaseManager.swift

- **Purpose**: Central manager for all Supabase operations
- **Key Features**:
  - Singleton pattern (`SupabaseManager.shared`)
  - Image upload to Supabase Storage (`uploadImage()`)
  - Video upload to Supabase Storage (`uploadVideo()`)
  - Database operations for user images, presets, stats
  - Pending jobs management (create, fetch, update)
  - Storage buckets: `user-generated-images`, `user-generated-videos`

#### Database Tables

- **`user_images`**: Stores generated images/videos with metadata
  - Fields: `id`, `user_id`, `image_url`, `model`, `title`, `cost`, `type`, `endpoint`, `created_at`, `media_type`, `file_extension`, `thumbnail_url`, `prompt`, `aspect_ratio`, `provider`, `is_favorite`
- **`user_presets`**: User-saved presets for quick reuse
  - Fields: `id`, `user_id`, `title`, `model_name`, `prompt`, `created_at`, `updated_at`
  - Migration: `DATABASE_MIGRATION_user_presets.sql`
- **`user_stats`**: Pre-computed user statistics (counts, model usage)
  - Fields: `id`, `user_id`, `favorite_count`, `image_count`, `video_count`, `model_counts` (JSONB), `video_model_counts` (JSONB), `created_at`, `updated_at`
  - Migration: `DATABASE_MIGRATION_user_stats.sql`
- **`pending_jobs`**: Tracks async generation jobs for webhook completion
  - Fields: `id`, `user_id`, `task_id`, `provider`, `job_type`, `status`, `result_url`, `error_message`, `metadata` (JSONB), `device_token`, `notification_sent`, `created_at`, `updated_at`, `completed_at`
  - Migration: `Creator AI Studio/API/Supabase/Database/pending_jobs_setup.sql`

#### Database Migration Files

- `DATABASE_MIGRATION_user_presets.sql`
- `DATABASE_MIGRATION_user_presets_add_display_order.sql`
- `DATABASE_MIGRATION_user_presets_add_image_url.sql`
- `DATABASE_MIGRATION_user_stats.sql`
- `DATABASE_MIGRATION_user_stats_add_counts.sql`
- `Creator AI Studio/API/Supabase/Database/pending_jobs_setup.sql`

---

### 2. API Integration

**Location**: `Creator AI Studio/API/`

#### Runware API

- **File**: `Creator AI Studio/API/Runware/RunwareAPI.swift`
- **Purpose**: Handles image and video generation via Runware API
- **Key Functions**:
  - `submitImageToRunware()`: Submit image generation request
  - `submitVideoToRunware()`: Submit video generation request
  - `fetchRunwareTaskStatus()`: Poll for task status
  - Webhook support for async job completion

#### WaveSpeed API

- **File**: `Creator AI Studio/API/WaveSpeed/WaveSpeedAPI.swift`
- **Purpose**: Handles image generation via WaveSpeed API
- **Key Functions**:
  - `submitImageToWaveSpeed()`: Submit image generation request
  - `submitImageToWaveSpeedWithWebhook()`: Submit with webhook callback
  - `fetchWaveSpeedJobStatus()`: Poll for job status
  - Supports both base64 and URL-based image submission

#### Supabase Edge Functions

- **Location**: `Creator AI Studio/API/Supabase/EdgeFunctions/`
- **Files**:
  - `webhook-receiver.ts`: Receives webhooks from Runware/WaveSpeed, updates `pending_jobs` table
  - `send-push-notification.ts`: Sends push notifications when jobs complete

---

### 3. Pricing System

**Location**: `Creator AI Studio/TaskManager/PricingManager.swift`

#### PricingManager

- **Pattern**: Singleton (`PricingManager.shared`)
- **Purpose**: Centralized pricing for all AI models
- **Features**:
  - Fixed pricing for image models (stored in `prices` dictionary)
  - Variable pricing for video models (stored in `variableVideoPricing` dictionary)
  - Default video configurations for display pricing (`defaultVideoConfigs`)
  - Methods:
    - `price(for item: InfoPacket) -> Decimal?`: Get price for a model
    - `variablePrice(for modelName: String, aspectRatio: String, resolution: String, duration: Double) -> Decimal?`: Get variable price for video models

#### Pricing Structure

- **Image Models**: Fixed prices (e.g., "GPT Image 1.5": 0.034)
- **Video Models**: Variable pricing based on aspect ratio, resolution, and duration
  - Example: `"Sora 2": VideoPricingConfiguration(pricing: ["16:9": ["720p": [4.0: 0.4, 8.0: 0.8, 12.0: 1.2]]])`

---

### 4. Task Management

**Location**: `Creator AI Studio/TaskManager/`

#### ImageGenerationCoordinator

- **File**: `Creator AI Studio/TaskManager/ImageGenerationCoordinator.swift`
- **Pattern**: Singleton (`ImageGenerationCoordinator.shared`)
- **Purpose**: Manages all image generation tasks
- **Key Features**:
  - `startImageGeneration()`: Start a new image generation task
  - `startImageGenerationWithWebhook()`: Start with webhook support
  - Tracks task progress, updates notifications
  - Handles completion, errors, and cleanup
  - Stores background tasks for cancellation

#### VideoGenerationCoordinator

- **File**: `Creator AI Studio/TaskManager/VideoGenerationCoordinator.swift`
- **Pattern**: Singleton (`VideoGenerationCoordinator.shared`)
- **Purpose**: Manages all video generation tasks
- **Key Features**:
  - `startVideoGeneration()`: Start a new video generation task
  - Similar structure to ImageGenerationCoordinator

#### ImageGenerationTask

- **File**: `Creator AI Studio/TaskManager/ImageGenerationTask.swift`
- **Purpose**: Executes individual image generation tasks
- **Features**:
  - Supports both sync and webhook modes
  - Progress callbacks
  - Error handling
  - API provider abstraction (Runware vs WaveSpeed)

#### VideoGenerationTask

- **File**: `Creator AI Studio/TaskManager/VideoGenerationTask.swift`
- **Purpose**: Executes individual video generation tasks
- **Features**: Similar to ImageGenerationTask but for video

#### JobStatusManager

- **File**: `Creator AI Studio/TaskManager/JobStatusManager.swift`
- **Pattern**: Singleton (`JobStatusManager.shared`)
- **Purpose**: Manages Supabase Realtime subscriptions for pending job updates
- **Key Features**:
  - `startListening(userId:)`: Start listening for job updates via Realtime
  - `stopListening()`: Stop listening
  - Handles job completion by downloading results and uploading to storage
  - Updates notifications when jobs complete
  - Maps webhook task IDs to notification IDs

#### ModelConfigurationManager

- **File**: `Creator AI Studio/TaskManager/ModelConfigurationManager.swift`
- **Purpose**: Manages model-specific API configurations
- **Features**:
  - Maps model names to API endpoints, providers, aspect ratios, resolutions
  - Centralized configuration to avoid duplication

#### CategoryConfigurationManager

- **File**: `Creator AI Studio/TaskManager/CategoryConfigurationManager.swift`
- **Purpose**: Manages category-specific configurations for photo filters

---

### 5. Notification System

**Location**: `Creator AI Studio/Notifications/`

#### NotificationManager

- **File**: `Creator AI Studio/Notifications/Managers/NotificationManager.swift`
- **Pattern**: Singleton (`NotificationManager.shared`)
- **Purpose**: Manages in-app notifications for generation progress
- **Key Features**:
  - `showNotification()`: Create and show a new notification
  - `updateProgress()`: Update progress for a notification
  - `updateMessage()`: Update message for a notification
  - `markAsCompleted()`: Mark notification as completed
  - `markAsFailed()`: Mark notification as failed
  - `activePlaceholders`: Computed property for Profile page placeholders
  - Published properties: `notifications`, `newCompletedCount`, `newFailedCount`, `isNotificationBarVisible`

#### PushNotificationManager

- **File**: `Creator AI Studio/Notifications/PushNotificationManager.swift`
- **Pattern**: Singleton (`PushNotificationManager.shared`)
- **Purpose**: Manages push notifications for job completion
- **Key Features**:
  - `requestPermissions()`: Request push notification permissions
  - `registerForRemoteNotifications()`: Register with APNs
  - `didRegisterForRemoteNotifications(deviceToken:)`: Handle device token
  - `handleForegroundNotification()`: Handle notifications in foreground
  - `handleNotificationResponse()`: Handle notification taps
  - **Note**: Currently a stub implementation - requires APNs setup

#### NotificationBar

- **File**: `Creator AI Studio/Notifications/NotificationBar.swift`
- **Purpose**: UI component displaying active notifications at bottom of screen

#### NotificationModels

- **File**: `Creator AI Studio/Notifications/Models/NotificationModels.swift`
- **Models**:
  - `NotificationState`: Enum (`.inProgress`, `.completed`, `.failed`)
  - `NotificationData`: Main notification model with progress, state, metadata

---

### 6. Authentication

**Location**: `Creator AI Studio/API/Supabase/Auth/`

#### AuthViewModel

- **File**: `Creator AI Studio/API/Supabase/Auth/AuthViewModel.swift`
- **Purpose**: Manages user authentication
- **Key Features**:
  - `checkSession()`: Check for existing session
  - `signUpWithEmail()`: Email sign-up
  - `signInWithEmail()`: Email sign-in
  - `signInWithApple()`: Apple Sign-In
  - `signInWithGoogle()`: Google Sign-In
  - `signOut()`: Sign out user
  - Starts `JobStatusManager` listening on sign-in
  - **Note**: Currently authentication is bypassed in `Creator_AI_StudioApp.swift` (commented out)

#### SignInView

- **File**: `Creator AI Studio/API/Supabase/Auth/SignInView.swift`
- **Purpose**: UI for sign-in/sign-up

---

### 7. App Entry Point & Navigation

#### Creator_AI_StudioApp.swift

- **Location**: `Creator AI Studio/Creator_AI_StudioApp.swift`
- **Purpose**: Main app entry point
- **Key Features**:
  - Initializes `ThemeManager` and `AuthViewModel`
  - Shows splash screen (`SplashScreenView`)
  - Sets `WebhookConfig.useWebhooks = true` in `init()`
  - **Note**: Authentication flow is currently bypassed (goes directly to `ContentView`)

#### ContentView.swift

- **Location**: `Creator AI Studio/ContentView.swift`
- **Purpose**: Main navigation container with tab bar
- **Tabs**: 0. Home (`Home`)
  1. Photo Filters (`PhotoFilters`)
  2. Post/Camera (`Post`)
  3. AI Models (`ModelsPageContainer`)
  4. Gallery/Profile (`Profile`)
- **Features**:
  - Tab bar with custom styling
  - Notification bar overlay
  - Gallery tab shows progress ring and badges for active/completed jobs
  - Lazy loading of views for performance

---

### 8. Pages

**Location**: `Creator AI Studio/Pages/`

#### 1 Home

- **Files**: `Home.swift`, `HomeOne.swift`
- **Components**: `BannerCarousel.swift`
- **Purpose**: Home screen with featured content

#### 2 Photo Filters

- **Files**:
  - `PhotoFilters.swift`: Main photo filters page
  - `PhotoFilterDetailView.swift`: Detail view for a filter
  - `PhotoFiltersGrid.swift`: Grid display
  - `PhotoFiltersBottomBar.swift`: Bottom bar UI
- **Components**:
  - `CostBadge.swift`: Price display
  - `FilterThumbnails.swift`: Thumbnail grid
  - `SpinningPlusButton.swift`: Add button
- **Data**: JSON files for filter categories (Anime.json, Art.json, etc.)

#### 3 Post

- **Files**:
  - `Post.swift`: Main post/camera page
  - `CameraPreview.swift`: Camera preview
  - `CameraService.swift`: Camera functionality
  - `PhotoLibraryPickerView.swift`: Photo picker
  - `PhotoConfirmationView.swift`: Confirmation screen
  - `PhotoReviewView.swift`: Review screen
- **Components**:
  - `FilterCategorySheet.swift`: Category selection
  - `FilterModelSelectionView.swift`: Model selection
  - `FilterScrollRow.swift`: Filter row
  - `FilterThumbnailTwo.swift`: Thumbnail component
  - `ImageModelSelectionSheet.swift`: Image model selection
  - `ImageModelsRow.swift`: Image models row
  - `QuickFiltersRow.swift`: Quick filters row

#### 4 Image

- **Files**:
  - `ImageModelsPage.swift`: Main image models page
  - `ImageModelDetailPage.swift`: Detail page for image model
  - `ModelsPageContainer.swift`: Container for models (images + videos)
- **Components**:
  - `ExamplePromptsSheet.swift`: Example prompts
- **Shared**:
  - `AspectRatioSelector.swift`: Aspect ratio selection
  - `ReferenceImagesStruct.swift`: Reference images handling
  - `SimpleCameraPicker.swift`: Camera picker
  - `TextRecognitionService.swift`: Text recognition
- **Data**: `ImageModelData.json`, `UnusedImageModels.json`

#### 4 Video

- **Files**:
  - `VideoModelsPage.swift`: Main video models page
  - `VideoModelDetailPage.swift`: Detail page for video model
- **Shared**:
  - `DurationSelector.swift`: Duration selection
  - `ResolutionSelector.swift`: Resolution selection
- **Data**: `VideoModelData.json`, `unusedvideomodels.json`

#### 5 Profile

- **Files**:
  - `Profile.swift`: Main profile/gallery page (2755 lines - complex)
  - `FullScreenImageView.swift`: Full screen image viewer
  - `Settings.swift`: Settings page
  - `Developer.swift`: Developer tools
  - `VideoCacheManager.swift`: Video caching
- **ViewModels**:
  - `PresetViewModel.swift`: Manages user presets
- **Models**:
  - `ProfileModel.swift`: Contains `UserImage`, `UserStats` models

---

### 9. Models

**Location**: `Creator AI Studio/Models/`

#### InfoPacketModel.swift

- **Model**: `InfoPacket`
- **Purpose**: Represents an AI model configuration (image or video)
- **Key Properties**:
  - `display`: Display information (name, image, etc.)
  - `apiConfig`: API configuration (optional, resolved from `ModelConfigurationManager`)
  - `prompt`: Default prompt
  - `cost`: Price (optional, resolved from `PricingManager`)
  - `type`: Model type
  - `capabilities`: Array of capabilities
  - `category`: Category name
- **Computed Properties**:
  - `resolvedCost`: Gets price from `PricingManager`
  - `resolvedAPIConfig`: Gets API config from `ModelConfigurationManager`

#### PresetModel.swift

- **Models**: `Preset`, `PresetMetadata`
- **Purpose**: User-saved presets for quick reuse

#### MediaMetadata.swift

- **Purpose**: Metadata for generated media

#### TaskManager/Models/

- **PendingJob.swift**: Model for pending jobs table
- **TaskModels.swift**: Task-related models

---

### 10. Theme Management

**Location**: `Creator AI Studio/ThemeManager.swift`

#### ThemeManager

- **Pattern**: ObservableObject
- **Purpose**: Manages app theme (dark/light mode)
- **Features**:
  - `isDarkMode`: Published property
  - `toggleTheme()`: Toggle between dark/light
  - `colorScheme`: Computed property for SwiftUI
  - Persists preference in UserDefaults

---

## Key Features

### Webhook System

- **Configuration**: `WebhookConfig.useWebhooks = true` (set in app init)
- **Flow**:
  1. User starts generation → Task created with webhook URL
  2. Job stored in `pending_jobs` table
  3. API provider (Runware/WaveSpeed) processes job
  4. Webhook callback received by Supabase Edge Function (`webhook-receiver.ts`)
  5. Edge Function updates `pending_jobs` table
  6. `JobStatusManager` listens via Realtime subscription
  7. On update, downloads result and uploads to Supabase Storage
  8. Notification updated, user sees completed result

### Real-time Updates

- Uses Supabase Realtime to listen for `pending_jobs` table changes
- `JobStatusManager` subscribes to changes for current user
- Automatically handles job completion without polling

### Progress Tracking

- `NotificationManager` tracks progress for each generation task
- Progress updates shown in notification bar
- Profile page shows placeholders for active generations

### Storage

- Images stored in Supabase Storage bucket: `user-generated-images`
- Videos stored in Supabase Storage bucket: `user-generated-videos`
- File naming: `{userId}/{timestamp}_{modelName}.{ext}`

---

## Important Configuration Files

### Supabase Configuration

- **URL**: `https://inaffymocuppuddsewyq.supabase.co`
- **Anon Key**: Stored in `SupabaseManager.swift` (should be moved to environment variables)

### API Keys

- Runware API key: Should be in environment variables
- WaveSpeed API key: Should be in environment variables

---

## File Structure Summary

```
Creator AI Studio/
├── Creator_AI_StudioApp.swift          # App entry point
├── ContentView.swift                   # Main navigation
├── ThemeManager.swift                  # Theme management
├── SplashScreenView.swift              # Splash screen
│
├── API/
│   ├── Runware/
│   │   ├── RunwareAPI.swift           # Runware API client
│   │   └── RunwareModelSizes.swift    # Model size configs
│   ├── Supabase/
│   │   ├── SupabaseManager.swift      # Supabase client & storage
│   │   ├── Auth/
│   │   │   ├── AuthViewModel.swift    # Authentication
│   │   │   └── SignInView.swift        # Sign-in UI
│   │   ├── Database/
│   │   │   └── *.sql                  # Database migrations
│   │   └── EdgeFunctions/
│   │       ├── webhook-receiver.ts    # Webhook handler
│   │       └── send-push-notification.ts
│   └── WaveSpeed/
│       └── WaveSpeedAPI.swift         # WaveSpeed API client
│
├── TaskManager/
│   ├── ImageGenerationCoordinator.swift
│   ├── VideoGenerationCoordinator.swift
│   ├── ImageGenerationTask.swift
│   ├── VideoGenerationTask.swift
│   ├── JobStatusManager.swift         # Realtime job tracking
│   ├── PricingManager.swift           # Centralized pricing
│   ├── ModelConfigurationManager.swift
│   ├── CategoryConfigurationManager.swift
│   └── Models/
│       ├── PendingJob.swift
│       └── TaskModels.swift
│
├── Notifications/
│   ├── Managers/
│   │   └── NotificationManager.swift  # In-app notifications
│   ├── PushNotificationManager.swift  # Push notifications
│   ├── NotificationBar.swift           # Notification UI
│   ├── Models/
│   │   └── NotificationModels.swift
│   └── Helpers/
│       └── TimeoutHelper.swift
│
├── Models/
│   ├── InfoPacketModel.swift          # Main model config
│   ├── PresetModel.swift              # User presets
│   └── MediaMetadata.swift
│
└── Pages/
    ├── 1 Home/
    ├── 2 Photo Filters/
    ├── 3 Post/
    ├── 4 Image/
    ├── 4 Video/
    └── 5 Profile/
```

---

## Development Notes

### Adding a New Image Model

1. Add model data to `Pages/4 Image/Data/ImageModelData.json`
2. Add pricing to `PricingManager.swift` → `prices` dictionary
3. Add API config to `ModelConfigurationManager.swift`
4. Add model image to `Assets.xcassets/Image Models/`

### Adding a New Video Model

1. Add model data to `Pages/4 Video/Data/VideoModelData.json`
2. Add pricing to `PricingManager.swift`:
   - Add to `defaultVideoConfigs` dictionary
   - Add to `variableVideoPricing` dictionary
3. Add API config to `ModelConfigurationManager.swift`
4. Add model image to `Assets.xcassets/Video Models/`
5. See `VIDEO_MODEL_ADDITION_GUIDE.md` for detailed instructions

### Adding a New Photo Filter

1. Add filter data to `Pages/2 Photo Filters/Data/{Category}.json`
2. Add filter images to `Assets.xcassets/Photo Filters/{Category}/`
3. Filter pricing is handled via `InfoPacket.cost` or `PricingManager`

### Database Migrations

- All SQL migration files are in root directory or `API/Supabase/Database/`
- Run migrations in Supabase SQL Editor
- Migrations include RLS (Row Level Security) policies

### Webhook Configuration

- Webhooks are enabled by default (`WebhookConfig.useWebhooks = true`)
- Webhook URL points to Supabase Edge Function: `webhook-receiver.ts`
- Edge Function validates HMAC signature and updates `pending_jobs` table

---

## Key Design Patterns

1. **Singleton Pattern**: Used for managers (PricingManager, NotificationManager, JobStatusManager, etc.)
2. **MVVM**: ViewModels manage state and business logic
3. **Coordinator Pattern**: Generation coordinators manage task lifecycle
4. **Repository Pattern**: SupabaseManager acts as repository for data access
5. **Observer Pattern**: SwiftUI's `@Published` and `ObservableObject`

---

## Environment Setup

### Required Environment Variables

- Supabase URL (currently hardcoded in `SupabaseManager.swift`)
- Supabase Anon Key (currently hardcoded)
- Runware API Key
- WaveSpeed API Key

### Capabilities Required

- Push Notifications (for APNs - currently stub)
- Camera (for photo capture)
- Photo Library (for photo selection)

---

## Testing & Debugging

### Key Debug Points

- `SupabaseManager`: Check upload/download logs
- `JobStatusManager`: Check Realtime subscription status
- `NotificationManager`: Check notification state updates
- `ImageGenerationCoordinator` / `VideoGenerationCoordinator`: Check task execution

### Common Issues

1. **Webhook not firing**: Check Edge Function logs, verify HMAC signature
2. **Realtime not updating**: Check subscription status, verify user authentication
3. **Upload failures**: Check retry logic, verify storage bucket permissions
4. **Pricing not showing**: Verify model name matches `PricingManager` keys exactly

---

## Future Improvements

1. **Authentication**: Re-enable authentication flow (currently bypassed)
2. **Push Notifications**: Complete APNs integration
3. **Error Handling**: Enhanced error messages and retry logic
4. **Caching**: Implement better caching for images/videos
5. **Offline Support**: Add offline queue for generations
6. **Analytics**: Add usage analytics and tracking

---

## Documentation Files

- `PRESETS_IMPLEMENTATION.md`: Guide for presets feature
- `VIDEO_MODEL_ADDITION_GUIDE.md`: Guide for adding video models
- `ADD_VIDEO_MODEL_TEMPLATE.md`: Template for video models
- `APP_STRUCTURE.md`: This file

---

_Last Updated: Based on codebase analysis_
_Use this file to reprompt Cursor for better context understanding_


