import SwiftUI
import UIKit
import AVKit

struct VideoRow: View {
    let title: String
    let items: [InfoPacket]
    let seeAllDestination: AnyView?
    
    @State private var lastOffset: CGFloat = 0
    @State private var feedback: UISelectionFeedbackGenerator?
    @State private var playingVideos: [UUID: AVPlayer] = [:]
    
    init(title: String, items: [InfoPacket], seeAllDestination: AnyView? = nil) {
        self.title = title
        self.items = items
        self.seeAllDestination = seeAllDestination
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VideoRowTitle(title: title, items: items, seeAllDestination: seeAllDestination)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(items) { item in
                        NavigationLink(destination: destinationView(for: item)) {
                            VStack(spacing: 8) {
                                // Video display
                                videoView(for: item)
                                    .frame(width: 140, height: 196)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                                    .overlay(alignment: .bottom) {
                                        Text("Try This")
                                            .font(.custom("Nunito-ExtraBold", size: 12))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 5)
                                            .background(Color.black.opacity(0.8))
                                            .clipShape(Capsule())
                                            .padding(.bottom, 6)
                                    }
                                    .overlay(alignment: .topTrailing) {
                                        if let cost = item.resolvedCost {
                                            Text(PricingManager.formatPrice(cost))
                                                .font(.custom("Nunito-Bold", size: 11))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(Color.black.opacity(0.8))
                                                .clipShape(Capsule())
                                                .padding(6)
                                        }
                                    }
                                
                                Text(item.display.title)
                                    .font(.custom("Nunito-ExtraBold", size: 11))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.primary)
                                    .frame(width: 140)
                                    .truncationMode(.tail)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .background(ScrollOffsetReader { newOffset in
                    handleScrollFeedback(newOffset: newOffset)
                })
            }
            .frame(height: 220)
        }
        .onAppear {
            if feedback == nil {
                feedback = UISelectionFeedbackGenerator()
                feedback?.prepare()
            }
            // Setup video players for items
            setupVideoPlayers()
        }
        .onDisappear {
            // Clean up video players
            cleanupVideoPlayers()
        }
    }
    
    @ViewBuilder
    private func videoView(for item: InfoPacket) -> some View {
        // Try to get video URL from display.imageName
        // This could be a bundle resource name or a URL string
        if let videoURL = getVideoURL(for: item) {
            VideoPlayer(player: getOrCreatePlayer(for: item, url: videoURL))
                .aspectRatio(contentMode: .fill)
                .frame(width: 140, height: 196)
                .clipped()
        } else {
            // Fallback to thumbnail image if video not available
            Image(item.display.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 140, height: 196)
                .clipped()
        }
    }
    
    private func getVideoURL(for item: InfoPacket) -> URL? {
        let imageName = item.display.imageName
        
        // Check if it's a URL string
        if imageName.hasPrefix("http://") || imageName.hasPrefix("https://") {
            return URL(string: imageName)
        }
        
        // Check if it's a video file in the bundle
        // Try common video extensions
        let videoExtensions = ["mp4", "mov", "m4v", "webm"]
        for ext in videoExtensions {
            if let url = Bundle.main.url(forResource: imageName, withExtension: ext) {
                return url
            }
        }
        
        // Check in Video Filters subdirectory
        for ext in videoExtensions {
            if let url = Bundle.main.url(forResource: imageName, withExtension: ext, subdirectory: "Video Filters") {
                return url
            }
        }
        
        return nil
    }
    
    private func getOrCreatePlayer(for item: InfoPacket, url: URL) -> AVPlayer {
        if let existingPlayer = playingVideos[item.id] {
            return existingPlayer
        }
        
        let player = AVPlayer(url: url)
        player.isMuted = true // Mute by default for autoplay
        player.actionAtItemEnd = .none // Don't pause at end
        
        // Loop the video
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
        
        playingVideos[item.id] = player
        player.play()
        
        return player
    }
    
    private func setupVideoPlayers() {
        // Pre-setup players for first few items for better performance
        for item in items.prefix(3) {
            if let videoURL = getVideoURL(for: item) {
                _ = getOrCreatePlayer(for: item, url: videoURL)
            }
        }
    }
    
    private func cleanupVideoPlayers() {
        for (_, player) in playingVideos {
            player.pause()
            NotificationCenter.default.removeObserver(
                self,
                name: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem
            )
        }
        playingVideos.removeAll()
    }
    
    @ViewBuilder
    private func destinationView(for item: InfoPacket) -> some View {
        // Navigate to specific filter template pages
        if item.display.title.lowercased().contains("techno viking") {
            TechnoVikingFilterDetailPage(item: item)
        } else if item.display.title.lowercased().contains("yeti") {
            YetiFilterDetailPage(item: item)
        } else {
            // Default placeholder for other filters
            Text("Video Filter: \(item.display.title)")
                .font(.title)
                .padding()
        }
    }
    
    private func handleScrollFeedback(newOffset: CGFloat) {
        let delta = abs(newOffset - lastOffset)
        if delta > 40 {
            feedback?.selectionChanged()
            lastOffset = newOffset
        }
    }
}

// MARK: - Video Row Title Component
struct VideoRowTitle: View {
    let title: String
    let items: [InfoPacket]
    let seeAllDestination: AnyView?
    
    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            Spacer()
            if let destination = seeAllDestination {
                NavigationLink(destination: destination) {
                    HStack(spacing: 8) {
                        Text("See All")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Helper View to detect horizontal scroll offset (reused from CategoryRow)
private struct ScrollOffsetReader: View {
    var onChange: (CGFloat) -> Void
    
    var body: some View {
        GeometryReader { geo in
            Color.clear
                .preference(key: ScrollOffsetKey.self, value: geo.frame(in: .global).minX)
        }
        .onPreferenceChange(ScrollOffsetKey.self, perform: onChange)
    }
}

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

