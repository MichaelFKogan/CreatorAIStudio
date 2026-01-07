# Credit System Documentation

## Overview

The Creator AI Studio app uses a credit-based payment system where users purchase credits and use them to generate images and videos. Credits are stored in a Supabase database and automatically deducted when media is generated.

## Architecture

### Database Structure

#### `user_credits` Table
Stores the current credit balance for each user.

```sql
CREATE TABLE user_credits (
    id UUID PRIMARY KEY,
    user_id UUID UNIQUE REFERENCES auth.users(id),
    balance DECIMAL(10, 2) DEFAULT 0.00,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);
```

**Key Features:**
- One record per user (enforced by UNIQUE constraint)
- Balance stored as DECIMAL for precision
- Auto-updates `updated_at` timestamp on changes

#### `credit_transactions` Table
Audit log of all credit transactions (purchases and deductions).

```sql
CREATE TABLE credit_transactions (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id),
    amount DECIMAL(10, 2),  -- Positive for purchases, negative for deductions
    transaction_type TEXT,  -- 'purchase', 'deduction', 'refund'
    description TEXT,
    related_media_id UUID REFERENCES user_media(id),
    payment_method TEXT,  -- 'apple', 'external', 'test', null
    payment_transaction_id TEXT,
    created_at TIMESTAMP
);
```

**Transaction Types:**
- `purchase`: User buys credits
- `deduction`: Credits used for generation
- `refund`: Credits returned (future feature)

## Core Components

### CreditsManager

**Location:** `Creator AI Studio/API/Supabase/Credits/CreditsManager.swift`

Singleton service that handles all credit operations with the database.

#### Key Methods

##### `fetchCreditBalance(userId: UUID) async throws -> Double`
Fetches the current credit balance for a user. If no record exists, creates one with 0 balance.

```swift
let balance = try await CreditsManager.shared.fetchCreditBalance(userId: userId)
```

##### `addCredits(userId:amount:paymentMethod:paymentTransactionId:description:) async throws -> Double`
Adds credits to a user's account after a purchase.

**Parameters:**
- `userId`: User's UUID
- `amount`: Credits to add (positive value)
- `paymentMethod`: 'apple' or 'external'
- `paymentTransactionId`: Transaction ID from payment provider
- `description`: Optional description

**Returns:** New balance after adding credits

```swift
let newBalance = try await CreditsManager.shared.addCredits(
    userId: userId,
    amount: 10.00,
    paymentMethod: "apple",
    paymentTransactionId: "txn_123",
    description: "Credit purchase - $10.00"
)
```

##### `deductCredits(userId:amount:description:relatedMediaId:) async throws -> Double`
Deducts credits from a user's account for media generation.

**Parameters:**
- `userId`: User's UUID
- `amount`: Credits to deduct (positive value)
- `description`: Description of what credits were used for
- `relatedMediaId`: Optional UUID of generated media item

**Returns:** New balance after deduction

**Throws:** Error if insufficient credits

```swift
let newBalance = try await CreditsManager.shared.deductCredits(
    userId: userId,
    amount: 0.04,
    description: "Image generation - Model XYZ",
    relatedMediaId: mediaId
)
```

##### `setCredits(userId:amount:) async throws -> Double`
Directly sets credit balance (for testing purposes only).

```swift
let balance = try await CreditsManager.shared.setCredits(userId: userId, amount: 50.00)
```

##### `getTransactionHistory(userId:limit:) async throws -> [CreditTransaction]`
Fetches transaction history for a user.

```swift
let transactions = try await CreditsManager.shared.getTransactionHistory(userId: userId, limit: 50)
```

### CreditsViewModel

**Location:** `Creator AI Studio/API/Supabase/Credits/CreditsViewModel.swift`

Observable view model for managing credit state in the UI.

#### Published Properties

```swift
@Published var balance: Double = 0.00
@Published var isLoading: Bool = false
@Published var errorMessage: String? = nil
```

#### Key Methods

##### `fetchBalance(userId:) async`
Fetches and updates the current credit balance.

```swift
await creditsViewModel.fetchBalance(userId: userId)
```

##### `formattedBalance() -> String`
Returns the balance formatted as currency (e.g., "$10.00").

```swift
let formatted = creditsViewModel.formattedBalance()  // "$10.00"
```

##### `hasEnoughCredits(requiredAmount:) -> Bool`
Checks if user has sufficient credits for a transaction.

```swift
if creditsViewModel.hasEnoughCredits(requiredAmount: 0.04) {
    // Proceed with generation
}
```

##### `getLowCreditsWarning() -> String?`
Returns a warning message if credits are low or zero.

```swift
if let warning = creditsViewModel.getLowCreditsWarning() {
    // Show warning to user
}
```

## UI Components

### CreditsBadge

**Location:** `Creator AI Studio/Components/CreditsBadge.swift`

Reusable badge component that displays credit balance or "Sign in" button.

**Usage:**
```swift
CreditsBadge(
    diamondColor: .teal,
    borderColor: .mint,
    creditsAmount: creditsViewModel.formattedBalance()
)
```

**Features:**
- Shows "Sign in" when user is logged out
- Displays credit balance when logged in
- Opens PurchaseCreditsView when tapped
- Customizable colors

### PurchaseCreditsView

**Location:** `Creator AI Studio/Components/PurchaseCreditsView.swift`

Full-screen sheet for purchasing credits.

**Features:**
- Current balance display at top
- Payment method selector (Apple Payment / Credit Card)
- Credit packages: $5, $10, $20, $50
- Fee breakdown (processor fees + app fees)
- Shows approximate number of images/videos per package

**Payment Packages:**
- Starter Pack: $5.00 credits
- Pro Pack: $10.00 credits
- Mega Pack: $20.00 credits (Best Value)
- Ultra Pack: $50.00 credits

### TestCreditsView

**Location:** `Creator AI Studio/Components/TestCreditsView.swift`

Testing interface for setting credit balances directly.

**Test Amounts:**
- $0.00
- $0.05
- $5.00
- $10.00
- $20.00
- $50.00

**Access:** Settings → Test Credits

## Integration Points

### Image Generation

Credits are automatically deducted when images are generated successfully.

#### Polling Mode
**File:** `ImageGenerationTask.swift`

After saving image metadata:
```swift
if let cost = metadata.cost, cost > 0 {
    let _ = try await CreditsManager.shared.deductCredits(
        userId: userIdUUID,
        amount: cost,
        description: "Image generation - \(modelName)",
        relatedMediaId: mediaId
    )
    // Post CreditsBalanceUpdated notification
}
```

#### Webhook Mode
**File:** `JobStatusManager.swift`

When webhook completes successfully:
```swift
// Same deduction logic as polling mode
```

### Video Generation

Same pattern as image generation, with video-specific descriptions.

#### Polling Mode
**File:** `VideoGenerationTask.swift`

#### Webhook Mode
**File:** `JobStatusManager.swift`

## Real-time Updates

### Notification System

The system uses `NotificationCenter` to notify views when credits change.

**Notification Name:** `CreditsBalanceUpdated`

**UserInfo:**
```swift
["userId": userId]
```

**Posting:**
```swift
NotificationCenter.default.post(
    name: NSNotification.Name("CreditsBalanceUpdated"),
    object: nil,
    userInfo: ["userId": userId]
)
```

**Listening:**
```swift
.onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CreditsBalanceUpdated"))) { notification in
    if let userId = authViewModel.user?.id {
        Task {
            await creditsViewModel.fetchBalance(userId: userId)
        }
    }
}
```

## Credit Costs

### Image Generation
- Standard cost: $0.04 per image
- Varies by model and settings

### Video Generation
- Cost range: $0.30 to $1.10 per video
- Depends on duration, resolution, and model

## Error Handling

### Insufficient Credits

When a user tries to generate media without enough credits:

```swift
guard currentBalance >= amount else {
    throw NSError(
        domain: "CreditsError",
        code: -2,
        userInfo: [NSLocalizedDescriptionKey: "Insufficient credits..."]
    )
}
```

**Note:** Currently, credit checks happen during deduction. Future implementation should check before starting generation.

### Credit Deduction Failures

If credit deduction fails after generation:
- Error is logged
- Generation still succeeds (cost is recorded in metadata)
- User can manually adjust if needed

## Security Considerations

### Row Level Security (RLS)

Both tables have RLS enabled:
- Users can only view/update their own credits
- Users can only insert their own transactions
- Enforced at database level

### Transaction Integrity

- All credit changes create transaction records
- Transactions are immutable (no updates/deletes)
- Full audit trail for all credit movements

## Testing

### Test Credits Interface

Access via: Settings → Test Credits

**Features:**
- Directly sets balance in database
- Creates test transaction records
- Useful for development and QA

**Note:** Test transactions are marked with `payment_method: "test"` for easy filtering.

## Future Enhancements

### Planned Features

1. **Pre-generation Validation**
   - Check credits before allowing generation
   - Disable generate buttons if insufficient
   - Show clear error messages

2. **Low Credit Warnings**
   - Alert when balance < $1.00
   - Prompt to purchase more credits
   - Show warnings in UI

3. **Credit Refunds**
   - Handle failed generations
   - Refund credits for errors
   - Manual refund system

4. **Credit Packages**
   - Special offers and discounts
   - Subscription plans
   - Bulk purchase discounts

5. **Usage Analytics**
   - Show credit usage over time
   - Breakdown by image/video
   - Cost per generation type

## API Reference

### CreditsManager Methods

| Method | Description | Returns |
|--------|-------------|---------|
| `fetchCreditBalance(userId:)` | Get current balance | `Double` |
| `addCredits(...)` | Add credits after purchase | `Double` |
| `deductCredits(...)` | Deduct credits for generation | `Double` |
| `setCredits(userId:amount:)` | Set balance (testing) | `Double` |
| `getTransactionHistory(...)` | Get transaction history | `[CreditTransaction]` |

### CreditsViewModel Methods

| Method | Description | Returns |
|--------|-------------|---------|
| `fetchBalance(userId:)` | Fetch and update balance | `async` |
| `formattedBalance()` | Get formatted balance string | `String` |
| `hasEnoughCredits(amount:)` | Check if sufficient credits | `Bool` |
| `getLowCreditsWarning()` | Get low credit warning | `String?` |

## Troubleshooting

### Balance Not Updating

1. Check if `CreditsBalanceUpdated` notification is being posted
2. Verify view is listening to notification
3. Check database for actual balance
4. Verify user is signed in

### Credits Not Deducting

1. Check if `deductCredits()` is being called
2. Verify cost is set in metadata
3. Check for error logs
4. Verify user has sufficient credits

### Transaction Not Created

1. Check database connection
2. Verify RLS policies allow insertion
3. Check for error logs
4. Verify transaction data is valid

## Support

For issues or questions about the credit system:
1. Check error logs in Xcode console
2. Verify database tables exist and have correct schema
3. Check RLS policies are correctly configured
4. Review transaction history in Supabase dashboard

