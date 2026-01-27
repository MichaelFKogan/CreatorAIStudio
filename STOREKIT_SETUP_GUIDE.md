# StoreKit In-App Purchase Setup & Testing Guide

## ✅ What's Been Implemented

1. **StoreKitPurchaseManager.swift** - Complete StoreKit 2 purchase manager
   - Loads products from App Store Connect
   - Handles purchases and transactions
   - Maps product IDs to credit amounts
   - Transaction verification and completion

2. **PurchaseCreditsView.swift** - Updated to use StoreKit 2
   - Displays real prices from App Store Connect
   - Handles purchase flow with proper error handling
   - Shows loading states and success messages
   - Restore purchases functionality

## 📋 Product ID Mapping

The following product IDs are configured and mapped to credit amounts:

| Product ID | Credit Amount | Display Name |
|------------|---------------|--------------|
| `com.runspeedai.credits.test` | 1.00 credits | Test Pack |
| `com.runspeedai.credits.starter` | 5.00 credits | Starter Pack |
| `com.runspeedai.credits.pro` | 10.00 credits | Pro Pack |
| `com.runspeedai.credits.mega` | 20.00 credits | Mega Pack |
| `com.runspeedai.credits.ultra` | 50.00 credits | Ultra Pack |

## 🧪 Testing Setup

### Step 1: Submit Products for Review (Required for Testing)

Since these are your **first in-app purchases**, you must:

1. **Create a new app version** in App Store Connect
2. **Add the in-app purchases** to that version:
   - Go to your app's version page
   - Scroll to "In-App Purchases and Subscriptions"
   - Click "+" and select each of your 5 consumable products
3. **Submit the version** (even if it's just for testing)
   - You can submit with "Ready to Submit" status
   - Apple will review the IAPs along with the app

### Step 2: Configure Sandbox Testing

1. **Create Sandbox Test Account**:
   - Go to App Store Connect → Users and Access → Sandbox Testers
   - Create a test account (use a real email you can access)
   - Note: Sandbox accounts are separate from regular Apple IDs

2. **Sign Out of App Store on Test Device**:
   - Settings → [Your Name] → Media & Purchases → Sign Out
   - This ensures you use the sandbox environment

### Step 3: Test in App

1. **Build and Run** the app on a physical device (required for StoreKit testing)
   - Simulator can work but physical device is recommended
   - Make sure you're signed in to your app (Supabase auth)

2. **Navigate to Purchase Credits View**:
   - The app should automatically load products from App Store Connect
   - You should see real prices displayed (from your App Store Connect configuration)

3. **Test Purchase Flow**:
   - Tap a credit pack
   - When prompted, sign in with your **Sandbox Test Account**
   - Complete the purchase
   - Credits should be added to your account automatically
   - Check your balance updates correctly

4. **Test Error Handling**:
   - Cancel a purchase (should not show error)
   - Try purchasing without being signed in (should show error)

### Step 4: Verify Credits Were Added

1. Check the credit balance updates in the UI
2. Check Supabase database:
   - `user_credits` table - balance should increase
   - `credit_transactions` table - should have new transaction with:
     - `payment_method`: "apple"
     - `payment_transaction_id`: StoreKit transaction ID
     - `amount`: Credit amount purchased

## 🚀 Production Readiness

### Before Going Live

1. **Submit Products for Review** (if not already done)
   - All 5 products must be approved by Apple
   - This happens during app review

2. **Set Final Prices** in App Store Connect:
   - Make sure prices match your intended pricing
   - Prices are set per territory in App Store Connect

3. **Test with Real Account** (optional):
   - After products are approved, you can test with a real Apple ID
   - Use a small test purchase to verify end-to-end flow

4. **Monitor Transactions**:
   - Check `credit_transactions` table for all purchases
   - Verify transaction IDs are being stored correctly

## 🔍 Troubleshooting

### Products Not Loading

**Issue**: Products show as "not available" or loading spinner never stops

**Solutions**:
- Verify product IDs match exactly in App Store Connect
- Check that products are in "Ready to Submit" or "Approved" status
- Ensure you're testing on a physical device (not simulator)
- Check Xcode console for StoreKit errors

### Purchase Fails

**Issue**: Purchase button doesn't work or shows error

**Solutions**:
- Verify user is signed in (check `authViewModel.user?.id`)
- Check that Sandbox Test Account is set up correctly
- Verify network connection
- Check Xcode console for detailed error messages

### Credits Not Added

**Issue**: Purchase succeeds but credits don't appear

**Solutions**:
- Check Supabase connection
- Verify `CreditsManager.shared.addCredits()` is being called
- Check Xcode console for database errors
- Verify user has valid UUID in Supabase

### Transaction Verification Fails

**Issue**: Purchase completes but transaction verification fails

**Solutions**:
- This is rare but can happen with network issues
- Check that StoreKit transaction listener is running
- Verify app is properly signed with correct bundle ID

## 📝 Code Structure

### StoreKitPurchaseManager

- **Singleton**: `StoreKitPurchaseManager.shared`
- **Key Methods**:
  - `loadProducts()` - Loads products from App Store Connect
  - `purchase(_:userId:)` - Handles purchase flow
  - `restorePurchases(userId:)` - Restores purchases (for consumables, mainly handles pending transactions)
  - `getProduct(for:)` - Gets product by ID
  - `getCreditAmount(for:)` - Gets credit amount for product ID

### PurchaseCreditsView

- **State Management**: Uses `@StateObject` for `StoreKitPurchaseManager`
- **Product Display**: Dynamically loads and displays products from StoreKit
- **Purchase Flow**: Calls `purchaseManager.purchase()` and handles results
- **Error Handling**: Shows user-friendly error messages

## 🔐 Security Notes

- All transactions are verified using StoreKit 2's built-in verification
- Transaction IDs are stored in database for audit trail
- Credits are added server-side via Supabase (not client-side)
- Payment method is recorded as "apple" for all StoreKit purchases

## 📚 Additional Resources

- [Apple StoreKit 2 Documentation](https://developer.apple.com/documentation/storekit)
- [App Store Connect In-App Purchase Guide](https://developer.apple.com/app-store/in-app-purchases/)
- [Testing In-App Purchases](https://developer.apple.com/documentation/storekit/in-app_purchase/testing_in-app_purchases_with_sandbox)

## ✅ Checklist for Production

- [ ] All 5 products submitted and approved in App Store Connect
- [ ] Tested purchases with Sandbox account
- [ ] Verified credits are added correctly to database
- [ ] Tested error handling (cancellation, network errors)
- [ ] Verified transaction IDs are stored correctly
- [ ] Tested restore purchases flow
- [ ] Confirmed prices match intended pricing in all territories
- [ ] Ready to submit app version with IAPs for App Review
