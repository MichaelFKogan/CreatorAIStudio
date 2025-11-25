import SwiftUI

// MARK: FILTER PILL

struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .font(.system(size: 11))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .foregroundColor(isSelected ? .black : color)
                .background(isSelected ? color : color.opacity(0.12))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? Color.clear : color.opacity(0.6),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}
