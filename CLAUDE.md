# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Runspeed AI** (formerly Creator AI Studio) is an iOS app for AI-powered image and video generation. Users purchase credits to generate media using various AI models (Runware, WaveSpeed, Fal.ai APIs), with results stored in Supabase.

**Project Scale**: 103 Swift files, production-ready webhook architecture with Supabase Realtime, 9 image models, 6 video models, 18+ photo filter categories.

## Build & Run

This is an Xcode project (no SPM at root level). Open in Xcode:

```bash
open "Creator AI Studio.xcodeproj"
```

Build and run via Xcode (⌘+R) targeting iOS Simulator or device.

### Initial Setup

1. Copy `Creator-AI-Studio-Info.plist.template` to `Creator-AI-Studio-Info.plist`
2. Fill in required keys: `GOOGLE_CLIENT_ID`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_PROJECT_ID`, `WEBHOOK_SECRET`
3. Configure Supabase Edge Function secrets (see `Documentation/SETUP_INSTRUCTIONS.md` in `API/Supabase/EdgeFunctions/`)
4. Configure StoreKit product IDs in App Store Connect: `com.runspeedai.credits.{test, starter, pro, mega, ultra}`

## Testing

Tests use Swift Testing framework (not XCTest). Run via Xcode Test Navigator or:

```bash
xcodebuild test -scheme "Creator AI Studio" -destination "platform=iOS Simulator,name=iPhone 16"
```

## Architecture

**Pattern**: MVVM with Coordinators
**UI**: SwiftUI
**Backend**: Supabase (Auth, PostgreSQL, Storage, Realtime, Edge Functions)
**State**: ObservableObject with @Published, Swift Concurrency (async/await)

### Key Singletons

- `SupabaseManager.shared` - Database, storage, auth operations
- `PricingManager.shared` - Centralized model pricing (fixed for images, variable for videos)
- `ModelConfigurationManager.shared` - API configs, capabilities, aspect ratios, resolutions, durations
- `CategoryConfigurationManager.shared` - Photo filter category configurations
- `NotificationManager.shared` - In-app generation progress notifications
- `JobStatusManager.shared` - Supabase Realtime subscriptions for webhook job completion (48KB, most complex)
- `CreditsManager.shared` - Credit balance and transaction operations
- `ImageGenerationCoordinator.shared` / `VideoGenerationCoordinator.shared` - Task lifecycle management

### Generation Flow

1. User initiates generation → Coordinator creates task
2. Task submits to API (Runware/WaveSpeed/Fal.ai) with webhook URL
3. Job stored in `pending_jobs` table with provider info
4. Webhook callback → Edge Function updates `pending_jobs` status
5. `JobStatusManager` receives Realtime update → downloads result → uploads to Supabase Storage
6. Credits deducted, notification updated, user notified

**Webhook Architecture**: Production-ready, enabled by default (`WebhookConfig.useWebhooks = true` in `Creator_AI_StudioApp.swift`)

### Data Model

- `InfoPacket` - Unified model representation (display info, API config resolved from `ModelConfigurationManager`, pricing from `PricingManager`)
- `UserImage` - Generated media metadata in `user_images` table
- `PendingJob` - Async job tracking for webhook completion

## File Structure

```
Creator AI Studio/
├── Creator_AI_StudioApp.swift     # App entry, sets WebhookConfig.useWebhooks = true
├── ContentView.swift              # Tab-based navigation (5 tabs: Home, Filters, Camera, Models, Gallery)
├── API/
│   ├── Runware/RunwareAPI.swift   # Runware image/video generation
│   ├── WaveSpeed/WaveSpeedAPI.swift
│   ├── FalAI/FalAIAPI.swift       # Fal.ai motion control video (uses edge function proxy)
│   └── Supabase/
│       ├── SupabaseManager.swift  # Database & storage operations
│       ├── Auth/AuthViewModel.swift
│       ├── Credits/CreditsManager.swift, CreditsViewModel.swift
│       ├── Database/               # SQL migrations (user_presets, user_stats, pending_jobs, etc.)
│       └── EdgeFunctions/         # webhook-receiver.ts, send-push-notification.ts
├── TaskManager/
│   ├── ModelConfigurationManager.swift  # Central config: API, capabilities, sizes, durations
│   ├── CategoryConfigurationManager.swift  # Photo filter category configs
│   ├── PricingManager.swift             # All model pricing (fixed image, variable video)
│   ├── Image/VideoGenerationCoordinator.swift
│   ├── Image/VideoGenerationTask.swift  # 33KB, 30KB respectively
│   ├── JobStatusManager.swift           # 48KB - Realtime subscription for webhooks
│   └── Models/                          # PendingJob, TaskModels
├── Components/
│   ├── PurchaseCreditsView.swift        # 46KB - StoreKit 2 purchase UI, web promotion
│   ├── AuthAwareCostCard.swift          # Unified sign-in/cost/insufficient funds card
│   ├── GoogleLogoView.swift             # Google logo for sign-in
│   ├── CreditsBadge.swift, PriceDisplayView.swift
│   └── VideoPlayerWithMuteButton.swift
├── Notifications/
│   ├── Managers/NotificationManager.swift
│   ├── PushNotificationManager.swift    # Stub - APNs not configured yet
│   └── Models/NotificationModels.swift
├── Models/
│   ├── InfoPacketModel.swift      # Main model config struct
│   ├── PresetModel.swift          # User-saved presets
│   └── MediaMetadata.swift
└── Pages/
    ├── 1 Home/                    # Landing page with banners
    ├── 2 Photo Filters/           # 18+ filter categories (Anime, Art, BackInTime, etc.)
    ├── 3 Post/                    # Camera/photo upload, filter selection
    ├── 4 Image/                   # Image model selection (9 models)
    │   └── Data/ImageModelData.json
    ├── 4 Video/                   # Video model selection (6 models)
    │   └── Data/VideoModelData.json
    └── 5 Profile/                 # Gallery, user stats, presets, settings (Profile.swift: 2755 lines)
```

## Currently Supported Models

### Image Models (9)

- Nano Banana
- GPT Image 1.5
- Wan2.5-Preview
- Z-Image-Turbo
- Seedream 4.5 / 4.0
- FLUX.1 Kontext (pro/max)
- FLUX.2 [dev]

### Video Models (6)

- Sora 2
- Google Veo 3.1 Fast
- Seedance 1.0 Pro Fast
- KlingAI 2.5 Turbo Pro
- Kling VIDEO 2.6 Pro
- Wan2.6

### Photo Filter Categories (18+)

Anime, Art, BackInTime, Celebrity, Character, Chibi, Fashion, Fitness, Instagram, JustForFun, LinkedIn Headshots, Luxury, Mens, Photobooth, Photography, and more

Each category has JSON data in `Pages/2 Photo Filters/Data/`, asset images, and configurations in `CategoryConfigurationManager`.

## Adding New Models

### Image Model

1. Add to `Pages/4 Image/Data/ImageModelData.json`
2. Add pricing to `PricingManager.swift` → `prices` dictionary
3. Add API config to `ModelConfigurationManager.swift`
4. Add image asset to `Assets.xcassets/Image Models/`

### Video Model

See `Documentation/VIDEO_MODEL_ADDITION_GUIDE.md`. Update 4-5 files:

1. `ModelConfigurationManager.swift` - 7 sections: apiConfigurations, capabilitiesMap, modelDescriptions, modelImageNames, allowedDurationsMap, allowedAspectRatiosMap, allowedResolutionsMap
2. `PricingManager.swift` - defaultVideoConfigs + variableVideoPricing
3. `VideoModelData.json`
4. `RunwareAPI.swift` - provider settings if needed (e.g., Alibaba, Google providers)
5. `FalAIAPI.swift` - if using Fal.ai provider (requires edge function proxy for API key security)

**Critical**: Model name strings must match exactly across all files.

### Photo Filter Category

1. Add category JSON data to `Pages/2 Photo Filters/Data/`
2. Add to `CategoryConfigurationManager.swift`
3. Add category image assets to `Assets.xcassets/Photo Filters/`

## Database

Tables: `user_images`, `user_presets`, `user_stats`, `user_credits`, `credit_transactions`, `pending_jobs`

Migrations in `API/Supabase/Database/` - run via Supabase SQL Editor. All tables use RLS.

## Dependencies (Swift Package Manager)

- **Supabase Swift** (2.37.0) - Auth, PostgREST, Storage, Realtime
- **GoogleSignIn-iOS** (9.0.0) - Google OAuth
- **Kingfisher** (8.6.2) - Image loading/caching
- **StoreKit** - Native framework for in-app purchases
- Supporting: AppAuth, GTMAppAuth, swift-crypto, swift-http-types

## Recent Changes & Current State

### Major Updates (Last Month)

1. **Project Renamed**: "Creator AI Studio" → "Runspeed AI" (bundle ID, entitlements, signing)
2. **StoreKit Integration**: Added `PurchaseCreditsView.swift` (46KB) with StoreKit 2
   - Product IDs: `com.runspeedai.credits.{test, starter, pro, mega, ultra}`
   - Web purchase promotion: "Save 30%" banner → https://www.runspeedai.store
   - Restore purchases functionality
3. **Fal.ai Integration**: Added motion control video generation via `FalAIAPI.swift`
   - Uses edge function proxy for API key security
   - Database migration: `DATABASE_MIGRATION_add_falai_provider.sql`
4. **Credits Terminology**: Changed "dollars" → "credits" throughout app
5. **Security Improvements**: Moved Supabase keys to Info.plist, Runware keys to Supabase storage

### Production-Ready Features ✅

- Webhook-based async generation (enabled by default)
- Supabase Realtime for job status updates
- Credit system fully functional
- User presets with database persistence
- 18+ photo filter categories

### Incomplete Features ⚠️

1. **Authentication**: Currently bypassed in `Creator_AI_StudioApp.swift` line 45 (development mode)
2. **Push Notifications**: `PushNotificationManager` is stub, APNs not configured
3. **StoreKit Products**: Product IDs defined but need App Store Connect configuration

### Security Notes 🔒

- Webhook secret required in Info.plist
- RLS (Row Level Security) enabled on all database tables
- API keys moved from hardcoded to secure storage
- Fal.ai uses edge function proxy to hide API keys

## Documentation

Comprehensive guides in `/Documentation`:

- **APP_STRUCTURE.md** (22KB) - Complete architecture reference
- **VIDEO_MODEL_ADDITION_GUIDE.md** (14KB) - Step-by-step model addition guide
- **PRESETS_IMPLEMENTATION.md** (5KB) - User presets feature guide
- **DATABASE_TRIGGERS_IMPLEMENTATION.md** (5KB) - Database triggers documentation
- **SETUP_INSTRUCTIONS.md** - Edge function setup (in `API/Supabase/EdgeFunctions/`)

## Development Workflows & Best Practices

### When Adding Features

1. **Read existing code first** - Never propose changes without understanding current implementation
2. **Check multiple managers** - Features often span PricingManager, ModelConfigurationManager, Coordinators
3. **Maintain consistency** - Model names must match exactly across all files
4. **Update all touchpoints**:
   - JSON data files (ImageModelData.json, VideoModelData.json)
   - Manager configurations (Pricing, ModelConfiguration)
   - Asset catalogs (image assets for models/filters)
   - API implementations (Runware, WaveSpeed, Fal.ai)

### When Modifying Pricing

1. **Image pricing**: Fixed rates in `PricingManager.swift` → `prices` dictionary
2. **Video pricing**: Variable by duration/resolution in `variableVideoPricing`
3. **Always update**: Both `PricingManager` AND the model's JSON data file
4. **Test credit deductions**: Verify `CreditsManager` deducts correct amounts

### When Debugging Generation

1. **Check webhook flow**:
   - Task submission → API → pending_jobs → webhook → JobStatusManager → download → upload
2. **Common issues**:
   - Webhook secret mismatch (Info.plist vs Edge Function)
   - Realtime subscription not active (check `JobStatusManager`)
   - API provider timeouts (check provider-specific timeout settings in APIs)
   - Storage permissions (check Supabase RLS policies)
3. **Key files**:
   - `JobStatusManager.swift` (48KB) - Realtime subscriptions
   - `ImageGenerationTask.swift` (33KB) / `VideoGenerationTask.swift` (30KB)
   - Edge function: `webhook-receiver.ts`

### Code Organization Rules

1. **Singletons**: Use `.shared` pattern for managers (already established for 8+ managers)
2. **State management**: ObservableObject + @Published for ViewModels
3. **Async operations**: Swift concurrency (async/await), NOT completion handlers
4. **API calls**: Always include webhook URL for async job processing
5. **Error handling**: Surface errors to user via notifications, log to console

### Database Operations

1. **All tables use RLS** - Respect row-level security policies
2. **Migrations**: Add SQL files to `API/Supabase/Database/`, run via Supabase SQL Editor
3. **Testing**: Test with different auth states (signed in/out, different users)
4. **Schema changes**: Document in migration files, update relevant Swift models

### Testing Practices

- Framework: Swift Testing (NOT XCTest)
- Run: Xcode Test Navigator or `xcodebuild test -scheme "Creator AI Studio" -destination "platform=iOS Simulator,name=iPhone 16"`
- Current coverage: Minimal (333 byte test file) - needs expansion
- Priority: Test generation flows, credit deductions, webhook handling

### Common Pitfalls

1. **Don't hardcode API keys** - Use Info.plist or Supabase storage
2. **Don't skip webhook architecture** - Required for production async processing
3. **Don't forget RLS policies** - Database operations will fail without proper policies
4. **Don't assume auth state** - Check `SupabaseManager.shared.currentUser` before operations
5. **Don't create new patterns** - Follow existing singleton/MVVM/coordinator patterns

### File Complexity Notes

- **Largest files**: PurchaseCreditsView (46KB), JobStatusManager (48KB), ImageGenerationTask (33KB)
- **Most complex**: Profile.swift (2755 lines) - consider refactoring if making changes
- **Most critical**: JobStatusManager, ModelConfigurationManager, PricingManager (core system)
