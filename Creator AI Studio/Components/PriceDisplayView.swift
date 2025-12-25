import SwiftUI

// MARK: - PRICE DISPLAY VIEW

/// A reusable view component for displaying prices consistently across the app
struct PriceDisplayView: View {
    let price: Decimal?
    let showUnit: Bool
    let font: Font?
    let fontWeight: Font.Weight?
    let foregroundColor: Color?
    
    init(
        price: Decimal?,
        showUnit: Bool = false,
        font: Font? = nil,
        fontWeight: Font.Weight? = nil,
        foregroundColor: Color? = nil
    ) {
        self.price = price
        self.showUnit = showUnit
        self.font = font
        self.fontWeight = fontWeight
        self.foregroundColor = foregroundColor
    }
    
    var body: some View {
        let formattedPrice = showUnit
            ? PricingManager.formatPriceWithUnit(price ?? 0)
            : PricingManager.formatPrice(price ?? 0)
        
        Text(formattedPrice)
            .font(font)
            .fontWeight(fontWeight)
            .foregroundColor(foregroundColor)
    }
}

// MARK: - PRICE BADGE

/// A compact price badge view with optional diamond icon for credits
struct PriceBadge: View {
    let price: Decimal?
    
    var body: some View {
        HStack(spacing: 4) {
            if PricingManager.displayMode == .credits {
                Image(systemName: "diamond.fill")
                    .font(.caption2)
            }
            PriceDisplayView(price: price, showUnit: false)
        }
        .font(.system(size: 13, weight: .semibold, design: .rounded))
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.75))
        )
        .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
    }
}

