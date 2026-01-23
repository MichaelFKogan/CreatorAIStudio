# Web Version MVP - Background Information

This document provides essential background information for building the initial web version of Runspeed AI, focusing on **authentication** and **credit purchase functionality**. This is a focused guide for implementing the MVP features that will integrate seamlessly with the existing iOS app.

---

## Overview

**Runspeed AI** (formerly Creator AI Studio) is an AI-powered image and video generation platform. The web version will share the same Supabase backend as the iOS app, ensuring users can seamlessly switch between platforms with the same account and credits.

### MVP Scope
- ✅ User authentication (Sign In, Create Account)
- ✅ Credit purchase via Stripe
- ✅ Credit balance display
- ✅ Transaction history

### Shared Infrastructure
- **Database**: Supabase PostgreSQL (shared with iOS app)
- **Authentication**: Supabase Auth (shared with iOS app)
- **Storage**: Supabase Storage (shared with iOS app)
- **Real-time**: Supabase Realtime (for future features)

---

## Authentication System

### How It Works in iOS

The iOS app uses Supabase Auth with the following methods:
1. **Email/Password** - Standard sign-up and sign-in
2. **Google Sign-In** - OAuth with Google
3. **Apple Sign-In** - OAuth with Apple

### Key iOS Implementation Details

**File**: `Creator AI Studio/API/Supabase/Auth/AuthViewModel.swift`

```swift
// Email Sign Up
func signUpWithEmail(email: String, password: String) async {
    let result = try await client.auth.signUp(
        email: email,
        password: password
    )
    // Session created immediately if email confirmation not required
}

// Email Sign In
func signInWithEmail(email: String, password: String) async {
    let session = try await client.auth.signIn(
        email: email,
        password: password
    )
    self.user = session.user
    self.isSignedIn = true
}

// Google Sign In
func signInWithGoogle(idToken: String, accessToken: String, rawNonce: String?) async {
    let credentials = OpenIDConnectCredentials(
        provider: .google,
        idToken: idToken,
        accessToken: accessToken,
        nonce: rawNonce
    )
    let session = try await client.auth.signInWithIdToken(credentials: credentials)
}

// Apple Sign In
func signInWithApple(idToken: String) async {
    let session = try await client.auth.signInWithIdToken(
        credentials: .init(provider: .apple, idToken: idToken, accessToken: nil)
    )
}

// Password Reset
func resetPassword(email: String) async {
    try await client.auth.resetPasswordForEmail(
        email,
        redirectTo: URL(string: "yourapp://reset-password")
    )
}
```

### Web Implementation Requirements

**Supabase Client Setup:**
```typescript
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!

export const supabase = createClient(supabaseUrl, supabaseAnonKey)
```

**Key Features to Implement:**
1. Email/password sign-up form
2. Email/password sign-in form
3. Google OAuth button (redirects to Supabase OAuth)
4. Apple OAuth button (redirects to Supabase OAuth)
5. Password reset flow
6. Session persistence (Supabase handles this automatically)
7. Protected routes (redirect to sign-in if not authenticated)
8. Session restoration on page load

**OAuth Redirect URLs:**
- Configure in Supabase Dashboard → Authentication → URL Configuration
- Add your web app URL to allowed redirect URLs
- Example: `https://yourdomain.com/auth/callback`

**Session Management:**
- Supabase automatically stores session in localStorage
- Use `supabase.auth.getSession()` to check on page load
- Listen to `supabase.auth.onAuthStateChange()` for real-time updates

---

## Credit System

### Database Schema

#### `user_credits` Table
Stores the current credit balance per user.

**Columns:**
- `id` (UUID, Primary Key)
- `user_id` (UUID, Foreign Key → auth.users, Unique)
- `balance` (DOUBLE, default 0.00) - **Stored as dollars, not credits**
- `created_at` (TIMESTAMPTZ)
- `updated_at` (TIMESTAMPTZ)

**RLS Policies:**
- Users can only SELECT and UPDATE their own credits
- Users cannot INSERT (handled by trigger or server-side)

**Important Notes:**
- Balance is stored in **dollars** (e.g., 5.00 = $5.00)
- Credits are calculated using `PricingManager.dollarsToCredits()` function
- If no record exists for a user, balance is 0.00

#### `credit_transactions` Table
Stores all credit transactions (purchases and deductions).

**Columns:**
- `id` (UUID, Primary Key)
- `user_id` (UUID, Foreign Key → auth.users)
- `amount` (DOUBLE) - **Positive for purchases, negative for deductions**
- `transaction_type` (TEXT) - "purchase" or "deduction"
- `description` (TEXT) - Human-readable description
- `related_media_id` (UUID, nullable) - Links to user_media if deduction
- `payment_method` (TEXT, nullable) - "stripe", "apple", "external", etc.
- `payment_transaction_id` (TEXT, nullable) - External payment ID (Stripe payment intent ID, Apple transaction ID, etc.)
- `created_at` (TIMESTAMPTZ)

**RLS Policies:**
- Users can only SELECT their own transactions

**Indexes:**
- `user_id`
- `created_at DESC`

### Credit Operations (iOS Reference)

**File**: `Creator AI Studio/API/Supabase/Credits/CreditsManager.swift`

#### Fetch Credit Balance
```swift
func fetchCreditBalance(userId: UUID) async throws -> Double {
    let response: [UserCredits] = try await client.database
        .from("user_credits")
        .select()
        .eq("user_id", value: userId.uuidString)
        .limit(1)
        .execute()
        .value
    
    if let credits = response.first {
        return credits.balance
    } else {
        // No record exists, create one with 0 balance
        try await initializeUserCredits(userId: userId)
        return 0.00
    }
}
```

#### Add Credits (Purchase)
```swift
func addCredits(
    userId: UUID,
    amount: Double,  // Amount in dollars
    paymentMethod: String,  // "stripe", "apple", etc.
    paymentTransactionId: String?,
    description: String? = nil
) async throws -> Double {
    // 1. Get current balance
    let currentBalance = try await fetchCreditBalance(userId: userId)
    
    // 2. Calculate new balance
    let newBalance = currentBalance + amount
    
    // 3. Update user_credits table
    let update = BalanceUpdate(
        balance: newBalance,
        updated_at: ISO8601DateFormatter().string(from: Date())
    )
    try await client.database
        .from("user_credits")
        .update(update)
        .eq("user_id", value: userId.uuidString)
        .execute()
    
    // 4. Create transaction record
    let transaction = CreditTransaction(
        id: UUID(),
        user_id: userId,
        amount: amount,  // Positive for purchase
        transaction_type: "purchase",
        description: description ?? "Credit purchase - $\(String(format: "%.2f", amount))",
        related_media_id: nil,
        payment_method: paymentMethod,
        payment_transaction_id: paymentTransactionId,
        created_at: Date()
    )
    try await client.database
        .from("credit_transactions")
        .insert(transaction)
        .execute()
    
    return newBalance
}
```

#### Get Transaction History
```swift
func getTransactionHistory(userId: UUID, limit: Int = 50) async throws -> [CreditTransaction] {
    let transactions: [CreditTransaction] = try await client.database
        .from("credit_transactions")
        .select()
        .eq("user_id", value: userId.uuidString)
        .order("created_at", ascending: false)
        .limit(limit)
        .execute()
        .value
    
    return transactions
}
```

### Credit Packages (iOS Reference)

**File**: `Creator AI Studio/Components/PurchaseCreditsView.swift`

The iOS app offers these credit packages:
- **Test Pack**: $2.99 → 1.00 credits ($1.00)
- **Starter Pack**: $7.99 → 5.00 credits ($5.00)
- **Pro Pack**: $15.99 → 10.00 credits ($10.00)
- **Mega Pack**: $29.99 → 20.00 credits ($20.00)
- **Ultra Pack**: $72.99 → 50.00 credits ($50.00)

**Note**: The app mentions "Save 30% on all credit packs by purchasing directly through our website" - this suggests web prices should be 30% lower than iOS prices.

**Web Pricing (30% discount):**
- **Test Pack**: $2.09 → 1.00 credits ($1.00)
- **Starter Pack**: $5.59 → 5.00 credits ($5.00)
- **Pro Pack**: $11.19 → 10.00 credits ($10.00)
- **Mega Pack**: $20.99 → 20.00 credits ($20.00)
- **Ultra Pack**: $51.09 → 50.00 credits ($50.00)

**Important**: The `amount` stored in `user_credits.balance` and `credit_transactions.amount` is the **credit value in dollars**, not the purchase price. For example, if a user buys the "Starter Pack" for $5.59, the `amount` stored is `5.00` (the credit value), not `5.59` (the purchase price).

---

## Stripe Integration

### Recommended Approach: Stripe Checkout

Use **Stripe Checkout** for the simplest integration:
1. Create a Stripe Checkout session on your server
2. Redirect user to Stripe-hosted checkout page
3. Handle webhook callback when payment succeeds
4. Add credits to user's account via Supabase

### Implementation Flow

#### 1. Create Checkout Session (Server-Side)

**API Route**: `/api/stripe/create-checkout-session`

```typescript
import Stripe from 'stripe'
import { createClient } from '@supabase/supabase-js'

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!)
const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!  // Use service role key for server-side
)

export async function POST(request: Request) {
  const { userId, creditPackage } = await request.json()
  
  // Credit package mapping
  const packages = {
    'test': { price: 209, credits: 1.00 },      // $2.09 → $1.00 credits
    'starter': { price: 559, credits: 5.00 },     // $5.59 → $5.00 credits
    'pro': { price: 1119, credits: 10.00 },      // $11.19 → $10.00 credits
    'mega': { price: 2099, credits: 20.00 },      // $20.99 → $20.00 credits
    'ultra': { price: 5109, credits: 50.00 }      // $51.09 → $50.00 credits
  }
  
  const pkg = packages[creditPackage]
  if (!pkg) return new Response('Invalid package', { status: 400 })
  
  // Create Stripe Checkout session
  const session = await stripe.checkout.sessions.create({
    payment_method_types: ['card'],
    line_items: [{
      price_data: {
        currency: 'usd',
        product_data: {
          name: `${creditPackage} Pack`,
          description: `$${pkg.credits.toFixed(2)} in credits`,
        },
        unit_amount: pkg.price,  // Price in cents
      },
      quantity: 1,
    }],
    mode: 'payment',
    success_url: `${process.env.NEXT_PUBLIC_APP_URL}/purchase/success?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${process.env.NEXT_PUBLIC_APP_URL}/purchase/cancel`,
    metadata: {
      userId,
      creditAmount: pkg.credits.toString(),
      packageName: creditPackage,
    },
  })
  
  return Response.json({ sessionId: session.id, url: session.url })
}
```

#### 2. Webhook Handler (Server-Side)

**API Route**: `/api/stripe/webhook`

```typescript
import Stripe from 'stripe'
import { createClient } from '@supabase/supabase-js'

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!)
const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
)

export async function POST(request: Request) {
  const body = await request.text()
  const signature = request.headers.get('stripe-signature')!
  
  let event: Stripe.Event
  
  try {
    event = stripe.webhooks.constructEvent(
      body,
      signature,
      process.env.STRIPE_WEBHOOK_SECRET!
    )
  } catch (err) {
    return new Response(`Webhook Error: ${err.message}`, { status: 400 })
  }
  
  // Handle successful payment
  if (event.type === 'checkout.session.completed') {
    const session = event.data.object as Stripe.Checkout.Session
    const userId = session.metadata?.userId
    const creditAmount = parseFloat(session.metadata?.creditAmount || '0')
    const paymentIntentId = session.payment_intent as string
    
    if (!userId || !creditAmount) {
      console.error('Missing metadata in Stripe session')
      return new Response('Missing metadata', { status: 400 })
    }
    
    // Add credits to user's account
    await addCreditsToUser(userId, creditAmount, paymentIntentId)
  }
  
  return new Response(JSON.stringify({ received: true }))
}

async function addCreditsToUser(
  userId: string,
  amount: number,
  paymentTransactionId: string
) {
  // 1. Get current balance
  const { data: credits, error: fetchError } = await supabase
    .from('user_credits')
    .select('balance')
    .eq('user_id', userId)
    .single()
  
  if (fetchError && fetchError.code !== 'PGRST116') {  // PGRST116 = no rows
    throw fetchError
  }
  
  const currentBalance = credits?.balance || 0.00
  const newBalance = currentBalance + amount
  
  // 2. Update or insert user_credits
  const { error: updateError } = await supabase
    .from('user_credits')
    .upsert({
      user_id: userId,
      balance: newBalance,
      updated_at: new Date().toISOString(),
    }, {
      onConflict: 'user_id'
    })
  
  if (updateError) throw updateError
  
  // 3. Create transaction record
  const { error: transactionError } = await supabase
    .from('credit_transactions')
    .insert({
      user_id: userId,
      amount: amount,  // Positive for purchase
      transaction_type: 'purchase',
      description: `Credit purchase - $${amount.toFixed(2)}`,
      payment_method: 'stripe',
      payment_transaction_id: paymentTransactionId,
    })
  
  if (transactionError) throw transactionError
  
  console.log(`✅ Added ${amount} credits to user ${userId}. New balance: ${newBalance}`)
}
```

#### 3. Frontend Purchase Flow

```typescript
// Purchase button handler
async function handlePurchase(creditPackage: string) {
  const { data: { session } } = await supabase.auth.getSession()
  if (!session) {
    // Redirect to sign-in
    router.push('/sign-in')
    return
  }
  
  // Create checkout session
  const response = await fetch('/api/stripe/create-checkout-session', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      userId: session.user.id,
      creditPackage,
    }),
  })
  
  const { url } = await response.json()
  
  // Redirect to Stripe Checkout
  window.location.href = url
}
```

#### 4. Success Page

After successful payment, Stripe redirects to your success page. You can verify the payment and show confirmation:

```typescript
// /purchase/success page
useEffect(() => {
  const sessionId = new URLSearchParams(window.location.search).get('session_id')
  
  if (sessionId) {
    // Verify payment (optional - webhook already handled it)
    fetch(`/api/stripe/verify-session?session_id=${sessionId}`)
      .then(() => {
        // Refresh credit balance
        refreshCredits()
      })
  }
}, [])
```

### Stripe Setup Requirements

1. **Create Stripe Account**: https://stripe.com
2. **Get API Keys**:
   - Publishable key (for frontend)
   - Secret key (for server-side)
   - Webhook secret (for webhook verification)
3. **Configure Webhook**:
   - In Stripe Dashboard → Developers → Webhooks
   - Add endpoint: `https://yourdomain.com/api/stripe/webhook`
   - Select event: `checkout.session.completed`
   - Copy webhook signing secret to environment variables
4. **Environment Variables**:
   ```
   STRIPE_SECRET_KEY=sk_test_...
   STRIPE_PUBLISHABLE_KEY=pk_test_...
   STRIPE_WEBHOOK_SECRET=whsec_...
   ```

---

## Environment Variables

### Required for Web App

```env
# Supabase
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key

# Supabase (Server-Side Only - for webhooks)
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# Stripe
STRIPE_SECRET_KEY=sk_test_...  # or sk_live_... for production
STRIPE_PUBLISHABLE_KEY=pk_test_...  # or pk_live_... for production
STRIPE_WEBHOOK_SECRET=whsec_...

# App URL
NEXT_PUBLIC_APP_URL=https://yourdomain.com
```

### Where to Find Supabase Keys

1. Go to Supabase Dashboard → Your Project
2. Settings → API
3. **Project URL** → `NEXT_PUBLIC_SUPABASE_URL`
4. **anon/public key** → `NEXT_PUBLIC_SUPABASE_ANON_KEY`
5. **service_role key** → `SUPABASE_SERVICE_ROLE_KEY` (⚠️ Keep secret, server-side only!)

---

## Data Models (TypeScript)

### UserCredits
```typescript
interface UserCredits {
  id: string
  user_id: string
  balance: number  // Stored as dollars (e.g., 5.00 = $5.00)
  created_at: string
  updated_at: string
}
```

### CreditTransaction
```typescript
interface CreditTransaction {
  id: string
  user_id: string
  amount: number  // Positive for purchases, negative for deductions
  transaction_type: 'purchase' | 'deduction'
  description: string | null
  related_media_id: string | null
  payment_method: 'stripe' | 'apple' | 'external' | null
  payment_transaction_id: string | null
  created_at: string
}
```

---

## Key Implementation Notes

### 1. Credit Balance Display

The balance is stored in **dollars**, but you may want to display it as "credits" using the conversion function. However, for the MVP, you can simply display the dollar amount:

```typescript
// Simple display: "$5.00"
const formattedBalance = `$${balance.toFixed(2)}`

// Or as credits (if you implement conversion)
// const credits = dollarsToCredits(balance)
// const formattedBalance = `${credits} credits`
```

### 2. Real-time Balance Updates

For future enhancements, you can use Supabase Realtime to update the balance in real-time:

```typescript
useEffect(() => {
  if (!userId) return
  
  const channel = supabase
    .channel('user_credits')
    .on(
      'postgres_changes',
      {
        event: 'UPDATE',
        schema: 'public',
        table: 'user_credits',
        filter: `user_id=eq.${userId}`,
      },
      (payload) => {
        setBalance(payload.new.balance)
      }
    )
    .subscribe()
  
  return () => {
    supabase.removeChannel(channel)
  }
}, [userId])
```

### 3. Transaction History

Display transaction history in a table:

```typescript
const { data: transactions } = await supabase
  .from('credit_transactions')
  .select('*')
  .eq('user_id', userId)
  .order('created_at', { ascending: false })
  .limit(50)
```

### 4. Error Handling

- **Insufficient credits**: Check balance before allowing purchases/generations
- **Payment failures**: Handle Stripe errors gracefully
- **Network errors**: Retry logic for Supabase operations
- **Session expired**: Redirect to sign-in page

### 5. Security Considerations

- **Never expose service role key** on the client
- **Verify Stripe webhooks** using the webhook secret
- **Use RLS policies** - Supabase handles this automatically
- **Validate user ID** in server-side operations (webhook handler)
- **Sanitize inputs** before database operations

---

## Recommended Tech Stack

### Framework
- **Next.js 14+** (App Router) - Server-side rendering, API routes, easy deployment

### UI
- **Tailwind CSS** - Rapid styling
- **shadcn/ui** - Pre-built accessible components

### State Management
- **React Query (TanStack Query)** - Server state (credits, transactions)
- **Zustand** - Client state (UI state)

### Authentication
- **@supabase/supabase-js** - Supabase client

### Payments
- **stripe** (npm package) - Stripe server-side SDK

---

## Next Steps

1. **Set up Next.js project** with TypeScript
2. **Configure Supabase client** (client-side and server-side)
3. **Implement authentication pages** (sign-in, sign-up, password reset)
4. **Set up Stripe** (create account, get API keys, configure webhook)
5. **Implement credit purchase flow** (checkout session, webhook handler)
6. **Create credit balance display** component
7. **Build transaction history** page
8. **Test end-to-end flow** (sign up → purchase → verify credits)

---

## Questions to Resolve

1. **Design**: Will you reuse iOS design or create new web design?
2. **Mobile**: Desktop-first or mobile-first approach?
3. **Pricing**: Confirm the 30% discount for web purchases
4. **Email**: Do you want transaction confirmation emails?
5. **Analytics**: Which analytics platform? (Google Analytics, etc.)

---

## Support & Reference

- **Supabase Docs**: https://supabase.com/docs
- **Stripe Docs**: https://stripe.com/docs
- **Next.js Docs**: https://nextjs.org/docs
- **iOS App Code**: Reference `Creator AI Studio/API/Supabase/` for implementation patterns

---

**Last Updated**: Based on iOS app code as of current date
**Purpose**: Background information for web MVP development