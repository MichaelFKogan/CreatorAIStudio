import SwiftUI
import UIKit
import AVKit

struct VideoRowGrid: View {
    let title: String
    let items: [InfoPacket]
    let seeAllDestination: AnyView?

    @Environment(\.scenePhase) private var scenePhase
    @State private var lastOffset: CGFloat = 0
    @State private var feedback: UISelectionFeedbackGenerator?
    @State private var playingVideos: [UUID: AVPlayer] = [:]

    init(title: String, items: [InfoPacket], seeAllDestination: AnyView? = nil) {
        self.title = title
        self.items = items
        self.seeAllDestination = seeAllDestination
    }

    // Layout constants (aligned with CategoryRowGrid / ModelRowGrid)
    private let largeVideoWidth: CGFloat = 175
    private let largeVideoHeight: CGFloat = 245
    private let smallVideoWidth: CGFloat = 84
    private let smallVideoHeight: CGFloat = 119
    private let gridSpacing: CGFloat = 7
    private let itemSpacing: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VideoRowTitle(title: title, items: items, seeAllDestination: seeAllDestination)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: itemSpacing) {
                    ForEach(Array(groupedItems.enumerated()), id: \.offset) { _, group in
                        if group.count == 1 {
                            largeItemView(item: group[0])
                        } else {
                            gridItemView(items: group)
                        }
                    }
                }
                .padding(.horizontal)
                .background(ScrollOffsetReaderVideoGrid { newOffset in
                    handleScrollFeedback(newOffset: newOffset)
                })
            }
            .frame(height: 275)
        }
        .onAppear {
            if feedback == nil {
                feedback = UISelectionFeedbackGenerator()
                feedback?.prepare()
            }
            resumeVideoPlayers()
        }
        .onDisappear {
            pauseVideoPlayers()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                resumeVideoPlayers()
            }
        }
    }

    // Groups items into alternating pattern: 1 item, then 4 items (2x2 grid), then 1, then 4, etc.
    private var groupedItems: [[InfoPacket]] {
        var groups: [[InfoPacket]] = []
        var currentIndex = 0
        var isLargeNext = true

        while currentIndex < items.count {
            if isLargeNext {
                groups.append([items[currentIndex]])
                currentIndex += 1
            } else {
                let endIndex = min(currentIndex + 4, items.count)
                let gridItems = Array(items[currentIndex..<endIndex])
                groups.append(gridItems)
                currentIndex = endIndex
            }
            isLargeNext.toggle()
        }
        return groups
    }

    @ViewBuilder
    private func largeItemView(item: InfoPacket) -> some View {
        NavigationLink(destination: destinationView(for: item)) {
            VStack(spacing: 8) {
                videoView(for: item, width: largeVideoWidth, height: largeVideoHeight)
                    .frame(width: largeVideoWidth, height: largeVideoHeight)
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
                    .font(.custom("Nunito-ExtraBold", size: 12))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .frame(width: largeVideoWidth)
                    .truncationMode(.tail)
            }
        }
    }

    @ViewBuilder
    private func gridItemView(items: [InfoPacket]) -> some View {
        VStack(spacing: 8) {
            // 2x2 grid
            VStack(spacing: gridSpacing) {
                HStack(spacing: gridSpacing) {
                    if items.count > 0 {
                        smallItemView(item: items[0])
                    }
                    if items.count > 1 {
                        smallItemView(item: items[1])
                    } else {
                        Color.clear.frame(width: smallVideoWidth, height: smallVideoHeight)
                    }
                }
                HStack(spacing: gridSpacing) {
                    if items.count > 2 {
                        smallItemView(item: items[2])
                    } else {
                        Color.clear.frame(width: smallVideoWidth, height: smallVideoHeight)
                    }
                    if items.count > 3 {
                        smallItemView(item: items[3])
                    } else {
                        Color.clear.frame(width: smallVideoWidth, height: smallVideoHeight)
                    }
                }
            }

            // Spacing to match height with large items
            Color.clear.frame(height: 16)
        }
    }

    @ViewBuilder
    private func smallItemView(item: InfoPacket) -> some View {
        NavigationLink(destination: destinationView(for: item)) {
            videoView(for: item, width: smallVideoWidth, height: smallVideoHeight)
                .frame(width: smallVideoWidth, height: smallVideoHeight)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .overlay(alignment: .topTrailing) {
                    if let cost = item.resolvedCost {
                        Text(PricingManager.formatPrice(cost))
                            .font(.custom("Nunito-Bold", size: 8))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.8))
                            .clipShape(Capsule())
                            .padding(3)
                    }
                }
        }
    }

    @ViewBuilder
    private func videoView(for item: InfoPacket, width: CGFloat, height: CGFloat) -> some View {
        if let videoURL = getVideoURL(for: item) {
            VideoRowGridPlayerView(item: item, videoURL: videoURL, playingVideos: $playingVideos)
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: height)
                .clipped()
        } else {
            Image(item.display.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: height)
                .clipped()
        }
    }

    private func getVideoURL(for item: InfoPacket) -> URL? {
        let imageName = item.display.imageName
        if imageName.hasPrefix("http://") || imageName.hasPrefix("https://") {
            return URL(string: imageName)
        }
        let videoExtensions = ["mp4", "mov", "m4v", "webm"]
        for ext in videoExtensions {
            if let url = Bundle.main.url(forResource: imageName, withExtension: ext) {
                return url
            }
        }
        for ext in videoExtensions {
            if let url = Bundle.main.url(forResource: imageName, withExtension: ext, subdirectory: "Video Filters") {
                return url
            }
        }
        return nil
    }

    @ViewBuilder
    private func destinationView(for item: InfoPacket) -> some View {
        if item.wavespeedVideoEffectEndpoint != nil {
            WavespeedFilterDetailPage(item: item)
        } else if item.referenceImageName != nil {
            SpookyVideoFilterDetailPage(item: item)
        } else if item.referenceVideoName != nil ||
            item.display.title.lowercased().contains("techno viking") ||
            item.display.title.lowercased().contains("gangnam style") {
            DanceFilterDetailPage(item: item)
        } else if item.display.title.lowercased().contains("yeti") {
            YetiFilterDetailPage(item: item)
        } else {
            Text("Video Filter: \(item.display.title)")
                .font(.title)
                .padding()
        }
    }

    private func pauseVideoPlayers() {
        for (_, player) in playingVideos {
            player.pause()
        }
    }

    private func resumeVideoPlayers() {
        for (_, player) in playingVideos {
            player.play()
        }
    }

    private func handleScrollFeedback(newOffset: CGFloat) {
        guard newOffset.isFinite && !newOffset.isNaN else { return }
        Task { @MainActor in
            let delta = abs(newOffset - lastOffset)
            if delta > 40 {
                feedback?.selectionChanged()
                lastOffset = newOffset
            }
        }
    }
}

// MARK: - Video player view for grid (mirrors VideoRow's player behavior)
private struct VideoRowGridPlayerView: View {
    let item: InfoPacket
    let videoURL: URL
    @Binding var playingVideos: [UUID: AVPlayer]
    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player = player {
                FillVideoPlayerView(player: player)
                    .onAppear {
                        player.play()
                    }
            } else {
                Color.clear
                    .onAppear {
                        setupPlayer()
                    }
            }
        }
    }

    private func setupPlayer() {
        if let existingPlayer = playingVideos[item.id] {
            player = existingPlayer
            existingPlayer.play()
            return
        }
        let newPlayer = AVPlayer(url: videoURL)
        newPlayer.isMuted = true
        newPlayer.actionAtItemEnd = .none
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: newPlayer.currentItem,
            queue: .main
        ) { _ in
            Task { @MainActor in
                newPlayer.seek(to: .zero)
                newPlayer.play()
            }
        }
        Task { @MainActor in
            playingVideos[item.id] = newPlayer
            player = newPlayer
            newPlayer.play()
        }
    }
}

// MARK: - Scroll offset reader for grid
private struct ScrollOffsetReaderVideoGrid: View {
    var onChange: (CGFloat) -> Void

    var body: some View {
        GeometryReader { geo in
            let minX = geo.frame(in: .global).minX
            Color.clear
                .preference(key: ScrollOffsetKeyVideoGrid.self, value: minX.isFinite && !minX.isNaN ? minX : 0)
        }
        .onPreferenceChange(ScrollOffsetKeyVideoGrid.self, perform: onChange)
    }
}

private struct ScrollOffsetKeyVideoGrid: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
