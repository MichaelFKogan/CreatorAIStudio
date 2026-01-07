# Credit System Implementation Summary

## Overview
A complete credit system has been implemented for the Creator AI Studio app, allowing users to purchase credits, track balances, and automatically deduct credits when generating images and videos.

## What Was Implemented

### 1. Database Tables (Already Created in Supabase)
- **`user_credits`**: Stores current credit balance for each user
- **`credit_transactions`**: Tracks all credit purchases and deductions for audit purposes

### 2. Core Services Created

#### CreditsManager.swift
Location: `Creator AI Studio/API/Supabase/Credits/CreditsManager.swift`

**Key Methods:**
- `fetchCreditBalance(userId:)` - Gets current balance, initializes if doesn't exist
- `addCredits(userId:amount:paymentMethod:paymentTransactionId:description:)` - Adds credits after purchase
- `deductCredits(userId:amount:description:relatedMediaId:)` - Deducts credits for image/video generation
- `setCredits(userId:amount:)` - Sets balance directly (for testing)
- `getTransactionHistory(userId:limit:)` - Fetches transaction history

#### CreditsViewModel.swift
Location: `Creator AI Studio/API/Supabase/Credits/CreditsViewModel.swift`

**Features:**
- Observable view model for UI state management
- `balance: Double` - Published property for reactive updates
- `formattedBalance()` - Returns formatted currency string
- `hasEnoughCredits(requiredAmount:)` - Checks if user has sufficient credits
- `getLowCreditsWarning()` - Returns warning message if credits are low

### 3. UI Components

#### CreditsBadge.swift
- Reusable badge component showing credit balance
- Shows "Sign in" when logged out
- Opens PurchaseCreditsView when tapped
- Customizable colors (diamondColor, borderColor)

#### PurchaseCreditsView.swift
- Credit purchase interface with $5, $10, $20, $50 packages
- Payment method selector (Apple Payment / Credit Card)
- Fee breakdown display
- **Current Balance display added** - Shows user's current balance at top

#### TestCreditsView.swift
- Testing interface for setting credit balances
- Buttons for: $0, $0.05, $5, $10, $20, $50
- Directly updates database for testing purposes

### 4. Integration Points

#### PhotoFilters.swift
- Credit badge in toolbar showing real-time balance
- Automatically fetches balance on appear
- Listens for `CreditsBalanceUpdated` notification to refresh

#### Settings.swift
- "Purchase Credits" section with link to PurchaseCreditsView
- "Test Credits" section with link to TestCreditsView

### 5. Credit Deduction Implementation

#### Image Generation
**ImageGenerationTask.swift** (Polling Mode):
- Deducts credits after successful image generation
- Creates transaction record with related media ID
- Posts `CreditsBalanceUpdated` notification

**JobStatusManager.swift** (Webhook Mode):
- Deducts credits when webhook completes for images
- Same transaction tracking as polling mode

#### Video Generation
**VideoGenerationTask.swift** (Polling Mode):
- Deducts credits after successful video generation
- Creates transaction record with related media ID

**JobStatusManager.swift** (Webhook Mode):
- Deducts credits when webhook completes for videos

### 6. Real-time Updates

**Notification System:**
- `CreditsBalanceUpdated` notification posted after any credit change
- Views listen to this notification and refresh balance automatically
- Implemented in:
  - PhotoFilters.swift
  - PurchaseCreditsView.swift

## Current Status

✅ **Completed:**
- Credit balance fetching and display
- Credit deduction for images (both polling and webhook modes)
- Credit deduction for videos (both polling and webhook modes)
- Purchase credits UI (not yet connected to payment processing)
- Test credits interface
- Real-time balance updates via notifications
- Transaction history tracking

⏳ **Still TODO:**
- Connect PurchaseCreditsView to actual payment processing (Apple Pay / Credit Card)
- Add credit balance checks before allowing generation (disable buttons if insufficient)
- Add low credit warnings in UI
- Display credit balance on other pages (DanceFilterDetailPage, PhotoFilterDetailView, etc.)
- Implement credit refund system (if needed)

## Key Files Modified/Created

### New Files:
1. `Creator AI Studio/API/Supabase/Credits/CreditsManager.swift`
2. `Creator AI Studio/API/Supabase/Credits/CreditsViewModel.swift`
3. `Creator AI Studio/Components/TestCreditsView.swift`

### Modified Files:
1. `Creator AI Studio/Pages/2 Photo Filters/PhotoFilters.swift` - Added credit badge
2. `Creator AI Studio/Components/PurchaseCreditsView.swift` - Added current balance display
3. `Creator AI Studio/Pages/5 Profile/Settings.swift` - Added test credits option
4. `Creator AI Studio/TaskManager/ImageGenerationTask.swift` - Added credit deduction
5. `Creator AI Studio/TaskManager/VideoGenerationTask.swift` - Added credit deduction
6. `Creator AI Studio/TaskManager/JobStatusManager.swift` - Added credit deduction for webhook completions

## How It Works

### Credit Purchase Flow (To Be Implemented):
1. User taps credit package in PurchaseCreditsView
2. Payment processing (Apple Pay / Credit Card) - **TODO**
3. On success, call `CreditsManager.shared.addCredits(...)`
4. Balance updates in database
5. `CreditsBalanceUpdated` notification posted
6. UI refreshes automatically

### Credit Deduction Flow (Implemented):
1. User generates image/video
2. Generation completes successfully
3. Metadata saved to database with cost
4. `CreditsManager.shared.deductCredits(...)` called
5. Balance updated in database
6. Transaction record created
7. `CreditsBalanceUpdated` notification posted
8. UI refreshes automatically

### Testing Flow:
1. Go to Settings → Test Credits
2. Tap any amount button ($0, $0.05, $5, $10, $20, $50)
3. Balance updates immediately in database
4. UI refreshes to show new balance

## Database Schema Reference

### user_credits table:
- `id` (UUID, Primary Key)
- `user_id` (UUID, Foreign Key to auth.users)
- `balance` (DECIMAL(10, 2))
- `created_at` (TIMESTAMP)
- `updated_at` (TIMESTAMP)

### credit_transactions table:
- `id` (UUID, Primary Key)
- `user_id` (UUID, Foreign Key to auth.users)
- `amount` (DECIMAL(10, 2)) - Positive for purchases, negative for deductions
- `transaction_type` (TEXT) - 'purchase', 'deduction', 'refund'
- `description` (TEXT)
- `related_media_id` (UUID, Foreign Key to user_media)
- `payment_method` (TEXT) - 'apple', 'external', 'test', null for deductions
- `payment_transaction_id` (TEXT)
- `created_at` (TIMESTAMP)

## Next Steps

1. **Payment Integration:**
   - Integrate Apple Pay SDK
   - Integrate credit card payment processor (Stripe, etc.)
   - Connect purchase buttons to payment flow
   - Call `CreditsManager.addCredits()` on successful payment

2. **Credit Validation:**
   - Check balance before allowing generation
   - Disable generate buttons if insufficient credits
   - Show error messages when credits are too low

3. **UI Expansion:**
   - Add credit badge to all pages mentioned in original requirements:
     - DanceFilterDetailPage.swift
     - PhotoFilterDetailView.swift
     - PhotoConfirmation.swift
     - ImageModelsPage.swift
     - ImageModelsDetailPage.swift
     - VideoModelsPage.swift
     - VideoModelsDetailPage.swift

4. **Low Credit Warnings:**
   - Implement `getLowCreditsWarning()` in UI
   - Show alerts when credits are low
   - Prompt user to purchase more credits

