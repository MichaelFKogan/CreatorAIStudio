# Runspeed AI - Web MVP: Authentication & Credit Purchases

## Overview

This document outlines a minimal web application that provides:
1. **User Authentication** (Sign In / Create Account)
2. **Credit Purchases** via Stripe

The web app shares the same Supabase database as the iOS app, so users can:
- Create an account on web, log in on iOS (and vice versa)
- Purchase credits on web, use them on iOS (and vice versa)

---

## Scope

### In Scope
- Email/Password authentication (sign up, sign in, password reset)
- Google OAuth sign-in
- Apple OAuth sign-in (optional for web)
- Credit balance display
- Credit purchase via Stripe Checkout
- Transaction history display

### Out of Scope (Future Phases)
- Image/video generation
- Gallery/media viewing
- Photo filters
- AI model selection

---

## Shared Infrastructure

### Supabase Project
Uses the **existing** Supabase project from the iOS app:
- **Auth**: Same user accounts
- **Database**: Same tables (`user_credits`, `credit_transactions`)
- **RLS Policies**: Already configured

### Database Tables (Already Exist)

#### `user_credits`
```sql
- id: UUID (Primary Key)
- user_id: UUID (Foreign Key → auth.users, Unique)
- balance: DOUBLE (default 0.00)
- created_at: TIMESTAMPTZ
- updated_at: TIMESTAMPTZ
```

#### `credit_transactions`
```sql
- id: UUID (Primary Key)
- user_id: UUID (Foreign Key → auth.users)
- amount: DOUBLE (positive for purchases, negative for deductions)
- transaction_type: TEXT ('purchase', 'deduction', 'refund')
- description: TEXT
- related_media_id: UUID (nullable)
- payment_method: TEXT ('stripe', 'apple', 'paypal', etc.)
- payment_transaction_id: TEXT (external payment ID)
- created_at: TIMESTAMPTZ
```

---

## Authentication

### Methods to Implement

1. **Email/Password**
   - Sign up with email confirmation
   - Sign in
   - Password reset via email

2. **Google OAuth**
   - Uses Supabase OAuth flow
   - Redirect-based authentication

3. **Apple OAuth** (Optional)
   - More complex on web
   - Can defer to later phase

### Supabase Auth Setup

The iOS app already has Supabase Auth configured. For web:

1. **Enable Web OAuth Redirect URLs** in Supabase Dashboard:
   - `http://localhost:3000/auth/callback` (development)
   - `https://runspeed.ai/auth/callback` (production)

2. **Google OAuth**:
   - Add web client ID to existing Google Cloud project
   - Add authorized redirect URI for web

3. **Apple OAuth** (if implementing):
   - Configure Services ID for web domain

---

## Credit Packages & Pricing

### iOS Pricing (via StoreKit)
| Package | Credits | iOS Price |
|---------|---------|-----------|
| Test Pack | $1.00 | $2.99 |
| Starter Pack | $5.00 | $7.99 |
| Pro Pack | $10.00 | $15.99 |
| Mega Pack | $20.00 | $29.99 |
| Ultra Pack | $50.00 | $72.99 |

### Web Pricing (30% Discount)
| Package | Credits | Web Price | Stripe Price ID |
|---------|---------|-----------|-----------------|
| Test Pack | $1.00 | $1.99 | `price_test_xxx` |
| Starter Pack | $5.00 | $4.99 | `price_starter_xxx` |
| Pro Pack | $10.00 | $9.99 | `price_pro_xxx` |
| Mega Pack | $20.00 | $19.99 | `price_mega_xxx` |
| Ultra Pack | $50.00 | $49.99 | `price_ultra_xxx` |

*Note: Actual Stripe Price IDs will be created during setup.*

---

## Stripe Integration

### Setup Steps

1. **Create Stripe Account** (if not already)
2. **Create Products & Prices**:
   - One product per credit package
   - One-time payment prices (not subscription)
3. **Configure Webhook Endpoint**:
   - `https://runspeed.ai/api/webhooks/stripe`
   - Events to listen for:
     - `checkout.session.completed`
     - `payment_intent.succeeded`

### Payment Flow

```
User clicks "Buy Credits"
    ↓
Frontend creates Stripe Checkout Session (via API route)
    ↓
User redirected to Stripe Checkout
    ↓
User completes payment
    ↓
Stripe sends webhook to /api/webhooks/stripe
    ↓
Webhook handler:
  1. Verifies webhook signature
  2. Extracts user_id and credit_amount from metadata
  3. Calls addCredits() to update user_credits
  4. Creates credit_transaction record
    ↓
User redirected to success page
    ↓
Frontend fetches updated balance
```

### Stripe Checkout Session Creation

When creating a checkout session, include metadata:
```typescript
{
  mode: 'payment',
  payment_method_types: ['card'],
  line_items: [{
    price: 'price_xxx', // Stripe Price ID
    quantity: 1,
  }],
  metadata: {
    user_id: 'uuid-xxx',      // Supabase user ID
    credit_amount: '5.00',    // Credits to add
    package_name: 'Starter Pack'
  },
  success_url: 'https://runspeed.ai/purchase/success?session_id={CHECKOUT_SESSION_ID}',
  cancel_url: 'https://runspeed.ai/purchase/cancel',
}
```

### Webhook Handler (API Route)

```typescript
// /api/webhooks/stripe/route.ts
export async function POST(req: Request) {
  const body = await req.text()
  const signature = req.headers.get('stripe-signature')

  // Verify webhook signature
  const event = stripe.webhooks.constructEvent(
    body,
    signature,
    process.env.STRIPE_WEBHOOK_SECRET
  )

  if (event.type === 'checkout.session.completed') {
    const session = event.data.object
    const { user_id, credit_amount, package_name } = session.metadata

    // Add credits to user's balance
    await addCredits(
      user_id,
      parseFloat(credit_amount),
      'stripe',
      session.payment_intent,
      `Credit purchase - ${package_name}`
    )
  }

  return new Response('OK', { status: 200 })
}
```

---

## Tech Stack

### Recommended
- **Framework**: Next.js 14+ (App Router)
- **Auth**: Supabase Auth (@supabase/ssr)
- **Payments**: Stripe Checkout + Webhooks
- **Styling**: Tailwind CSS + shadcn/ui
- **Deployment**: Vercel

### Environment Variables
```bash
# Supabase (same as iOS app)
NEXT_PUBLIC_SUPABASE_URL=https://xxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_ROLE_KEY=eyJ...  # Server-side only

# Stripe
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_live_xxx
STRIPE_SECRET_KEY=sk_live_xxx
STRIPE_WEBHOOK_SECRET=whsec_xxx
```

---

## File Structure

```
web-app/
├── src/
│   ├── app/
│   │   ├── page.tsx                    # Landing/home page
│   │   ├── layout.tsx                  # Root layout with auth provider
│   │   ├── (auth)/
│   │   │   ├── sign-in/page.tsx        # Sign in page
│   │   │   ├── sign-up/page.tsx        # Sign up page
│   │   │   ├── forgot-password/page.tsx
│   │   │   └── auth/callback/route.ts  # OAuth callback handler
│   │   ├── (dashboard)/
│   │   │   ├── layout.tsx              # Protected layout
│   │   │   ├── dashboard/page.tsx      # User dashboard (balance display)
│   │   │   └── purchase/
│   │   │       ├── page.tsx            # Credit packages page
│   │   │       ├── success/page.tsx    # Post-purchase success
│   │   │       └── cancel/page.tsx     # Purchase cancelled
│   │   └── api/
│   │       ├── checkout/route.ts       # Create Stripe checkout session
│   │       └── webhooks/
│   │           └── stripe/route.ts     # Stripe webhook handler
│   ├── components/
│   │   ├── auth/
│   │   │   ├── sign-in-form.tsx
│   │   │   ├── sign-up-form.tsx
│   │   │   ├── google-sign-in-button.tsx
│   │   │   └── apple-sign-in-button.tsx
│   │   ├── credits/
│   │   │   ├── credit-balance.tsx      # Balance display component
│   │   │   ├── credit-package-card.tsx # Purchase option card
│   │   │   └── transaction-history.tsx # List of transactions
│   │   └── ui/                         # shadcn/ui components
│   ├── lib/
│   │   ├── supabase/
│   │   │   ├── client.ts               # Browser client
│   │   │   ├── server.ts               # Server client
│   │   │   └── middleware.ts           # Auth middleware
│   │   ├── stripe.ts                   # Stripe client setup
│   │   └── credits.ts                  # Credit operations
│   └── types/
│       └── database.ts                 # TypeScript types
├── .env.local
├── package.json
└── tailwind.config.js
```

---

## Implementation Steps

### Phase 1: Project Setup
1. Create Next.js project with TypeScript
2. Install dependencies:
   ```bash
   npm install @supabase/supabase-js @supabase/ssr stripe @stripe/stripe-js
   npm install -D tailwindcss postcss autoprefixer
   npx shadcn@latest init
   ```
3. Configure environment variables
4. Set up Tailwind CSS

### Phase 2: Authentication
1. Set up Supabase client (browser + server)
2. Create auth middleware for protected routes
3. Build sign-in page with email/password
4. Build sign-up page with email/password
5. Add forgot password flow
6. Add Google OAuth button
7. Create OAuth callback handler
8. Test auth flow end-to-end

### Phase 3: Credit Display
1. Create credit balance component
2. Fetch balance from `user_credits` table
3. Create dashboard page showing balance
4. Add transaction history component
5. Test balance updates after iOS purchases

### Phase 4: Stripe Integration
1. Create Stripe account and products
2. Build credit packages page (matching iOS UI)
3. Create checkout API route
4. Create Stripe webhook handler
5. Test purchase flow end-to-end
6. Verify credits appear in iOS app

### Phase 5: Polish
1. Add loading states
2. Add error handling
3. Responsive design
4. Add app download links/prompts
5. Deploy to Vercel

---

## Key Code Snippets

### Supabase Browser Client
```typescript
// lib/supabase/client.ts
import { createBrowserClient } from '@supabase/ssr'

export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  )
}
```

### Supabase Server Client
```typescript
// lib/supabase/server.ts
import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'

export async function createClient() {
  const cookieStore = await cookies()

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll()
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value, options }) => {
            cookieStore.set(name, value, options)
          })
        },
      },
    }
  )
}
```

### Add Credits Function
```typescript
// lib/credits.ts
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY! // Use service role for webhook
)

export async function addCredits(
  userId: string,
  amount: number,
  paymentMethod: string,
  paymentTransactionId: string,
  description: string
): Promise<number> {
  // Get current balance
  const { data: credits } = await supabase
    .from('user_credits')
    .select('balance')
    .eq('user_id', userId)
    .single()

  const currentBalance = credits?.balance ?? 0
  const newBalance = currentBalance + amount

  // Update balance
  await supabase
    .from('user_credits')
    .upsert({
      user_id: userId,
      balance: newBalance,
      updated_at: new Date().toISOString()
    })

  // Create transaction record
  await supabase
    .from('credit_transactions')
    .insert({
      user_id: userId,
      amount: amount,
      transaction_type: 'purchase',
      description: description,
      payment_method: paymentMethod,
      payment_transaction_id: paymentTransactionId,
    })

  return newBalance
}
```

### Credit Package Card Component
```tsx
// components/credits/credit-package-card.tsx
interface CreditPackageCardProps {
  title: string
  credits: number
  price: number
  description: string
  badge?: string
  stripePriceId: string
}

export function CreditPackageCard({
  title,
  credits,
  price,
  description,
  badge,
  stripePriceId
}: CreditPackageCardProps) {
  const handlePurchase = async () => {
    const response = await fetch('/api/checkout', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        priceId: stripePriceId,
        credits: credits,
        packageName: title
      })
    })

    const { url } = await response.json()
    window.location.href = url
  }

  return (
    <div className="border rounded-xl p-6 hover:border-blue-500 transition-colors">
      <div className="flex justify-between items-start">
        <div>
          <h3 className="text-lg font-bold">{title}</h3>
          {badge && (
            <span className="bg-blue-500 text-white text-xs px-2 py-1 rounded-full">
              {badge}
            </span>
          )}
        </div>
        <div className="text-right">
          <p className="text-2xl font-bold">${price.toFixed(2)}</p>
        </div>
      </div>
      <p className="text-gray-500 mt-2">{credits * 100} credits</p>
      <p className="text-sm text-gray-400 mt-1">{description}</p>
      <button
        onClick={handlePurchase}
        className="w-full mt-4 bg-blue-600 text-white py-3 rounded-lg font-medium hover:bg-blue-700"
      >
        Purchase
      </button>
    </div>
  )
}
```

---

## Testing Checklist

### Authentication
- [ ] Sign up with email creates user in Supabase
- [ ] Sign in with email works
- [ ] Password reset sends email
- [ ] Google OAuth creates/signs in user
- [ ] Session persists across page refreshes
- [ ] Sign out clears session
- [ ] iOS user can sign in on web
- [ ] Web user can sign in on iOS

### Credits
- [ ] Balance displays correctly
- [ ] Balance matches iOS app
- [ ] Transaction history loads

### Stripe Payments
- [ ] Checkout session creates successfully
- [ ] Stripe Checkout loads
- [ ] Test payment completes
- [ ] Webhook receives event
- [ ] Credits added to database
- [ ] New balance shows on web
- [ ] New balance shows on iOS
- [ ] Transaction appears in history

---

## Deployment

### Vercel Configuration
1. Connect GitHub repository
2. Set environment variables in Vercel dashboard
3. Configure custom domain (runspeed.ai)
4. Set up Stripe webhook with production URL

### Domain Setup
- `runspeed.ai` - Main website
- `runspeed.ai/purchase` - Credit purchase page (linked from iOS app)

### Post-Deployment
1. Update iOS app to link to `https://runspeed.ai/purchase`
2. Test full flow: iOS → Web purchase → Credits appear in iOS
3. Monitor Stripe dashboard for successful payments

---

## Future Enhancements

After MVP launch, consider:
1. Add PayPal as payment option
2. Add Apple Pay / Google Pay via Stripe
3. Promo codes / discounts
4. Referral program
5. Email receipts
6. Usage analytics
