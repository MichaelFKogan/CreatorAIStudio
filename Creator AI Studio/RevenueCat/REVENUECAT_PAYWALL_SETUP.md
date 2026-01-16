# RevenueCat Paywall Integration Setup Guide

This guide explains how to set up and configure RevenueCat Paywalls for consumable credit packs in Creator AI Studio.

## Overview

The app uses RevenueCat Paywalls (RevenueCatUI) to display and handle purchases of consumable credit packs. The paywall is implemented in `CreditPackPaywallView.swift` and integrated into `PurchaseCreditsView.swift`.

## Prerequisites

1. **RevenueCatUI Package**: Make sure RevenueCatUI is added to your Xcode project
   - Go to Project Settings → Package Dependencies
   - Ensure `RevenueCatUI` product is included from the `purchases-ios-spm` package
   - Minimum version: 5.16.0+ (for Paywalls support)

2. **RevenueCat Dashboard Configuration**:
   - Create an Offering in RevenueCat dashboard for credit packs
   - Configure consumable products in App Store Connect
   - Map products to packages in RevenueCat

## Setup Steps

### 1. Add RevenueCatUI to Your Project

If RevenueCatUI is not already added:

1. Open your project in Xcode
2. Go to **File → Add Packages...**
3. If you already have `purchases-ios-spm`, go to **Project Settings → Package Dependencies**
4. Select your project target
5. Go to **Frameworks, Libraries, and Embedded Content**
6. Add `RevenueCatUI` if it's not already there

### 2. Configure Products in App Store Connect

Create consumable in-app purchase products for each credit pack:

- Test Pack: $1.00 credits
- Starter Pack: $5.00 credits  
- Pro Pack: $10.00 credits
- Mega Pack: $20.00 credits
- Ultra Pack: $50.00 credits

**Important**: Note the Product IDs you create (e.g., `com.yourapp.credits.test`)

### 3. Configure RevenueCat Dashboard

1. **Create an Offering**:
   - Go to RevenueCat Dashboard → Offerings
   - Create a new Offering (e.g., "Credit Packs")
   - Set it as the "Current" offering

2. **Add Packages**:
   - For each credit pack product, create a Package
   - Link each package to the corresponding App Store Connect product ID

### 4. Update Product ID Mapping

In `CreditPackPaywallView.swift`, update the `getCreditAmountForProduct` function with your actual product IDs:

```swift
private func getCreditAmountForProduct(_ productId: String) -> Double? {
    let creditMapping: [String: Double] = [
        "com.yourapp.credits.test": 1.00,      // Replace with your actual product ID
        "com.yourapp.credits.starter": 5.00,   // Replace with your actual product ID
        "com.yourapp.credits.pro": 10.00,      // Replace with your actual product ID
        "com.yourapp.credits.mega": 20.00,     // Replace with your actual product ID
        "com.yourapp.credits.ultra": 50.00     // Replace with your actual product ID
    ]
    
    return creditMapping[productId]
}
```

### 5. Configure Offering Identifier (Optional)

If you want to use a specific offering (not the current one), update `PurchaseCreditsView.swift`:

```swift
.sheet(isPresented: $showPaywallView) {
    CreditPackPaywallView(offeringIdentifier: "your_offering_id")
        .presentationDragIndicator(.visible)
}
```

## How It Works

1. **User taps to purchase credits**: `PurchaseCreditsView` shows a sheet with `CreditPackPaywallView`

2. **Paywall displays**: RevenueCat PaywallView automatically:
   - Fetches the current offering
   - Displays all available packages
   - Handles the purchase flow

3. **Purchase completion**: When a purchase completes:
   - `onPurchaseCompleted` callback fires
   - The app extracts the product ID from the transaction
   - Maps product ID to credit amount
   - Adds credits to user's Supabase account via `CreditsManager`
   - Refreshes the credit balance UI

4. **Webhook alternative**: For production, consider using RevenueCat webhooks to process purchases server-side for better reliability

## Testing

1. **Sandbox Testing**:
   - Use a sandbox Apple ID in Settings → App Store
   - Test purchases will use sandbox products
   - Credits will be added to your test account

2. **Verify Credit Addition**:
   - Check Supabase `user_credits` table for balance updates
   - Check `credit_transactions` table for transaction records

## Troubleshooting

### Paywall doesn't show
- Check that RevenueCatUI is properly imported
- Verify offering exists in RevenueCat dashboard
- Check that offering is set as "Current"

### Purchase completes but credits not added
- Verify product ID mapping in `getCreditAmountForProduct`
- Check that `CreditsManager.addCredits` is being called
- Review console logs for errors
- Consider implementing webhook processing for production

### Callbacks not firing
- Known issue in some RevenueCat SDK versions
- The implementation includes a fallback using `onRequestedDismissal`
- Check customer info after dismissal to detect purchases

## Production Considerations

1. **Webhooks**: Set up RevenueCat webhooks to process purchases server-side
   - More reliable than client-side processing
   - Prevents duplicate credit additions
   - Better for handling edge cases

2. **Error Handling**: The current implementation includes basic error handling
   - Consider adding user-facing error messages
   - Log errors for debugging

3. **Analytics**: Consider tracking purchase events
   - RevenueCat provides analytics in dashboard
   - Track conversion rates
   - Monitor failed purchases

## Additional Resources

- [RevenueCat Paywalls Documentation](https://www.revenuecat.com/docs/tools/paywalls)
- [RevenueCat iOS SDK Reference](https://www.revenuecat.com/docs/ios)
- [App Store Connect In-App Purchase Guide](https://developer.apple.com/in-app-purchase/)
