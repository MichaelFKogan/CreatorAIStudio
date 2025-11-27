import SwiftUI

// MARK: - Cost Badge

struct CostBadge: View {
    let cost: Double

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
                    Text("$\(cost, specifier: "%.2f")")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green).opacity(0.9)
                }
            }
            Spacer()
            Text("$\(cost, specifier: "%.2f")")
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
