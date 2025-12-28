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
                                .frame(width: 40, height: 40)  // adjust size as needed

                            Text("RunSpeed AI")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                // .foregroundStyle(
                                //     LinearGradient(
                                //         colors: titleGradient,
                                //         startPoint: .leading,
                                //         endPoint: .trailing
                                //     )
                                // )
                        }
                    }

                    // MARK: Credits Badge and Settings
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 8) {
                            // // Credits Badge (or Sign in when logged out)
                            // CreditsBadge(
                            //     diamondColor: .purple,
                            //     borderColor: .purple,
                            //     creditsAmount: "$10.00"
                            // )
                            
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
