import SwiftUI

// MARK: - Cost Badge

struct CostBadge: View {
    let cost: Double

    // Helper function to format cost with full precision
    private func formatCost(_ cost: Double) -> String {
        // Use NumberFormatter to show all significant digits
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 10 // Allow up to 10 decimal places for precision
        formatter.minimumFractionDigits = 0 // Don't force trailing zeros
        return formatter.string(from: NSNumber(value: cost)) ?? "$\(cost)"
    }

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
                    Text(formatCost(cost))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green).opacity(0.9)
                }
            }
            Spacer()
            Text(formatCost(cost))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.green).opacity(0.9)
        }
        .padding()
        .background(Color.green.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.2), lineWidth: 1)
        )
    }
}
