# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Runspeed AI** (formerly Creator AI Studio) is an iOS app for AI-powered image and video generation. Users purchase credits to generate media using various AI models (Runware, WaveSpeed APIs), with results stored in Supabase.

## Build & Run

This is an Xcode project (no SPM at root level). Open in Xcode:
```bash
open "Creator AI Studio.xcodeproj"
```

Build and run via Xcode (⌘+R) targeting iOS Simulator or device.

### Initial Setup

1. Copy `Creator-AI-Studio-Info.plist.template` to `Creator-AI-Studio-Info.plist`
2. Fill in required keys: `GOOGLE_CLIENT_ID`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `WEBHOOK_SECRET`
3. Configure Supabase Edge Function secrets (see `Documentation/SETUP.md`)

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
- `NotificationManager.shared` - In-app generation progress notifications
- `JobStatusManager.shared` - Supabase Realtime subscriptions for webhook job completion
- `CreditsManager.shared` - Credit balance and transaction operations
- `ImageGenerationCoordinator.shared` / `VideoGenerationCoordinator.shared` - Task lifecycle management

### Generation Flow

1. User initiates generation → Coordinator creates task
2. Task submits to API (Runware/WaveSpeed) with webhook URL
3. Job stored in `pending_jobs` table
4. Webhook callback → Edge Function updates `pending_jobs`
5. `JobStatusManager` receives Realtime update → downloads result → uploads to Supabase Storage
6. Credits deducted, notification updated

### Data Model

- `InfoPacket` - Unified model representation (display info, API config resolved from `ModelConfigurationManager`, pricing from `PricingManager`)
- `UserImage` - Generated media metadata in `user_images` table
- `PendingJob` - Async job tracking for webhook completion

## File Structure

```
Creator AI Studio/
├── Creator_AI_StudioApp.swift     # App entry, sets WebhookConfig.useWebhooks = true
├── ContentView.swift              # Tab-based navigation (Home, Filters, Camera, Models, Gallery)
├── API/
│   ├── Runware/RunwareAPI.swift   # Runware image/video generation
│   ├── WaveSpeed/WaveSpeedAPI.swift
│   └── Supabase/
│       ├── SupabaseManager.swift  # Database & storage operations
│       ├── Auth/AuthViewModel.swift
│       ├── Credits/CreditsManager.swift, CreditsViewModel.swift
│       └── EdgeFunctions/         # webhook-receiver.ts, send-push-notification.ts
├── TaskManager/
│   ├── ModelConfigurationManager.swift  # Central config: API, capabilities, sizes, durations
│   ├── PricingManager.swift             # All model pricing
│   ├── Image/VideoGenerationCoordinator.swift
│   ├── Image/VideoGenerationTask.swift
│   └── JobStatusManager.swift           # Realtime subscription for webhooks
├── Notifications/
│   └── Managers/NotificationManager.swift
├── Models/
│   └── InfoPacketModel.swift      # Main model config struct
└── Pages/
    ├── 4 Image/Data/ImageModelData.json
    └── 4 Video/Data/VideoModelData.json
```

## Adding New Models

### Image Model
1. Add to `Pages/4 Image/Data/ImageModelData.json`
2. Add pricing to `PricingManager.swift` → `prices` dictionary
3. Add API config to `ModelConfigurationManager.swift`
4. Add image asset to `Assets.xcassets/Image Models/`

### Video Model
See `Documentation/VIDEO_MODEL_ADDITION_GUIDE.md`. Update 4 files:
1. `ModelConfigurationManager.swift` - 7 sections: apiConfigurations, capabilitiesMap, modelDescriptions, modelImageNames, allowedDurationsMap, allowedAspectRatiosMap, allowedResolutionsMap
2. `PricingManager.swift` - defaultVideoConfigs + variableVideoPricing
3. `VideoModelData.json`
4. `RunwareAPI.swift` - provider settings if needed (e.g., Alibaba, Google providers)

**Critical**: Model name strings must match exactly across all files.

## Database

Tables: `user_images`, `user_presets`, `user_stats`, `user_credits`, `credit_transactions`, `pending_jobs`

Migrations in `API/Supabase/Database/` - run via Supabase SQL Editor. All tables use RLS.

## Dependencies (Swift Package Manager)

- Supabase (Auth, PostgREST, Storage, Realtime)
- GoogleSignIn / GoogleSignInSwift
- Kingfisher (image loading)
- StoreKit (in-app purchases)
