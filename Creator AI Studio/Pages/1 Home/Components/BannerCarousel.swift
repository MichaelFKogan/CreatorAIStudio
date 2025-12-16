import SwiftUI

struct BannerCarousel: View {
    @State private var currentIndex: Int = 0
    
    // Dummy banner data
    let banners: [BannerData] = [
        BannerData(
            title: "New AI Models",
            subtitle: "Try our latest image generation models",
            gradientColors: [.pink, .purple]
        ),
        BannerData(
            title: "Special Promotion",
            subtitle: "Get 50% off premium plans",
            gradientColors: [.yellow, .pink]
        ),
        BannerData(
            title: "Photo Filters",
            subtitle: "Try our latest image generation models",
            gradientColors: [.green, .mint]
        ),
        BannerData(
            title: "New AI Models",
            subtitle: "Try our latest image generation models",
            gradientColors: [.blue, .cyan]
        ),
        BannerData(
            title: "Video Generation",
            subtitle: "Create stunning videos with AI",
            gradientColors: [.purple, .pink]
        ),
        BannerData(
            title: "Special Promotion",
            subtitle: "Get 50% off premium plans",
            gradientColors: [.red, .orange]
        ),
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentIndex) {
                ForEach(0..<banners.count, id: \.self) { index in
                    BannerCard(banner: banners[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 200)
            
            // Dot indicators
            HStack(spacing: 8) {
                ForEach(0..<banners.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentIndex ? Color.primary : Color.secondary.opacity(0.3))
                        .frame(width: index == currentIndex ? 8 : 6, height: index == currentIndex ? 8 : 6)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentIndex)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
    }
}

struct BannerCard: View {
    let banner: BannerData
    
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: banner.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .cornerRadius(16)
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text(banner.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text(banner.subtitle)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .padding(.horizontal, 16)
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

struct BannerData {
    let title: String
    let subtitle: String
    let gradientColors: [Color]
}
