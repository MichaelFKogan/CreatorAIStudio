import SwiftUI

struct Home: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var authViewModel: AuthViewModel
    let resetTrigger: UUID

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Banner Carousel
                    BannerCarousel()
                        .padding(.top, 8)
                    
                    // Rest of content can go here
                    VStack {
                        // Placeholder for future content
                    }
                }
            }
            .navigationTitle("")
            .toolbar {

                    // MARK: Leading Title
                    ToolbarItem(placement: .navigationBarLeading) {
                        HStack(spacing: 8) {
                            Image("logo-image")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 46, height: 46)  // adjust size as needed

                            Text("RunSpeed AI")
                                .italic()
                                    .font(.system(size: 28, weight: .bold))
                                    .italic()
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: titleGradient,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                    }

                    // MARK: Credits Badge and Settings
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 16) {
                            // Credits Badge
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

                                Text("$10.00")
                                    .font(
                                        .system(
                                            size: 14, weight: .semibold,
                                            design: .rounded)
                                    )
                                    .foregroundColor(.primary)

                                // Text("credits")
                                //     .font(.caption2)
                                //     .foregroundColor(.secondary)
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
                                        LinearGradient(
                                            colors: [.purple, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing),
                                        lineWidth: 1.5
                                    )
                            )
                            
                            // Settings Gear Icon
                            NavigationLink(
                                destination: Settings(profileViewModel: nil)
                                    .environmentObject(authViewModel)
                            ) {
                                Image(systemName: "gearshape")
                                    .font(.body)
                                    .foregroundColor(.gray)
                            }
                        }
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
