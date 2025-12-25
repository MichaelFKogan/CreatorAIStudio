import SwiftUI

// MARK: - Cost Badge

struct CostBadge: View {
    let cost: Decimal

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Generation Cost")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 4) {
                    Text("1 filter")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Text("×")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    PriceDisplayView(
                        price: cost,
                        font: .subheadline,
                        fontWeight: .semibold,
                        foregroundColor: .teal
                    )
                }
            }
            Spacer()
            PriceDisplayView(
                price: cost,
                font: .system(size: 16, weight: .semibold, design: .rounded),
                fontWeight: .bold,
                foregroundColor: .teal
            )
        }
        .padding()
        .background(Color.teal.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.teal.opacity(0.2), lineWidth: 1)
        )
    }
}
