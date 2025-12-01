import SwiftUI

struct Home: View {
    @Environment(\.colorScheme) var colorScheme
    let resetTrigger: UUID

    var body: some View {
        NavigationStack {
            ScrollView { VStack {} }
                .navigationTitle("")
                .toolbar {

                    // MARK: Leading Title
                    ToolbarItem(placement: .navigationBarLeading) {
                        Text("RunSpeed AI")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: titleGradient,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }

                    // MARK: Credits Badge
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 6) {
                            Image(systemName: "diamond.fill")
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.purple, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .font(.system(size: 8))

                            Text("$5.00")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)

                            Text("credits left")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.secondary.opacity(0.1))
                                .shadow(
                                    color: Color.black.opacity(0.2), radius: 4,
                                    x: 0, y: 2
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(
                                    LinearGradient(colors: [.purple, .purple],
                                                   startPoint: .leading,
                                                   endPoint: .trailing),
                                    lineWidth: 1.5
                                )
                        )
                    }
                }
        }
    }

    private var titleGradient: [Color] {
        colorScheme == .dark
        ? [.pink, .purple]
        : [.pink, .purple]
    }
}
