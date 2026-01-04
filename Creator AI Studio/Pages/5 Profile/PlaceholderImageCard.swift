import SwiftUI
import UIKit

// MARK: - Helper Function to Find Model Image Name

private func findModelImageNameForPlaceholder(for modelName: String?, isVideo: Bool = false) -> String? {
    guard let modelName = modelName, !modelName.isEmpty else { return nil }
    
    // Cache models to avoid repeated loading
    struct ModelCache {
        static var imageModels: [InfoPacket]?
        static var videoModels: [InfoPacket]?
    }
    
    if isVideo {
        if ModelCache.videoModels == nil {
            ModelCache.videoModels = VideoModelsViewModel.loadVideoModels()
        }
        if let modelInfo = ModelCache.videoModels?.first(where: { $0.display.modelName == modelName || $0.display.title == modelName }) {
            return modelInfo.display.imageName
        }
    } else {
        if ModelCache.imageModels == nil {
            ModelCache.imageModels = ImageModelsViewModel.loadImageModels()
        }
        if let modelInfo = ModelCache.imageModels?.first(where: { $0.display.modelName == modelName || $0.display.title == modelName }) {
            return modelInfo.display.imageName
        }
    }
    
    return nil
}

// MARK: PLACEHOLDER Image Card (for in-progress generations)

struct PlaceholderImageCard: View {
    let placeholder: PlaceholderImage
    let itemWidth: CGFloat
    let itemHeight: CGFloat

    @State private var shimmer = false
    @State private var pulseAnimation = false
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var isRetrying = false
    @State private var showCopiedConfirmation = false
    @State private var showDetailsSheet = false
    @State private var dynamicMessage: String = ""
    @State private var timeoutMessage: String = ""
    @State private var showTimeoutMessage: Bool = false
    @State private var showCancelButton: Bool = false
    
    // Timer to update messages every minute
    @State private var messageUpdateTimer: Timer?

    // Helper to check if image is a placeholder (very small, like 1x1)
    private var isValidImage: Bool {
        guard let image = placeholder.thumbnailImage else { return false }
        let size = image.size
        // Consider images smaller than 10x10 as placeholders
        return size.width >= 10 && size.height >= 10
    }

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(borderColor, lineWidth: 2)
                )

            VStack(spacing: 6) {
                // Tappable area for image and title/message
                Button(action: {
                    showDetailsSheet = true
                }) {
                    VStack(spacing: 6) {
                        // Thumbnail or Icon
                        if let thumbnail = placeholder.thumbnailImage, isValidImage {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                                .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                        } else if let modelImageName = findModelImageNameForPlaceholder(
                            for: placeholder.modelName,
                            isVideo: placeholder.title.contains("Video") || placeholder.title.contains("video")
                        ) {
                            // Show the model image for text-to-image/video generation
                            Image(modelImageName)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [.blue, .purple],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 2
                                        )
                                )
                                .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
                                .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                        } else {
                            // Fallback: Show an AI/magic icon if no model image found (matches NotificationBar)
                            ZStack {
                                // Animated gradient background
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.4, green: 0.6, blue: 1.0),
                                                Color(red: 0.6, green: 0.4, blue: 1.0),
                                                Color(red: 0.8, green: 0.5, blue: 1.0),
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 50, height: 50)
                                    .opacity(0.8)

                                // Sparkles/magic wand icon to represent AI text-to-image
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundColor(.white)
                                    .shadow(
                                        color: .black.opacity(0.2), radius: 2, x: 0,
                                        y: 1)
                            }
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [.blue, .purple, .pink],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                            .shadow(
                                color: Color.purple.opacity(0.4), radius: 6, x: 0, y: 2
                            )
                            .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                        }

                        // Title and Message
                        VStack(spacing: 3) {
                            Text(placeholder.title)
                                .font(.custom("Nunito-Bold", size: 11))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .multilineTextAlignment(.center)

                            Text(placeholder.message)
                                .font(.custom("Nunito-Regular", size: 9))
                                .foregroundColor(
                                    placeholder.state == .failed ? .red : .secondary
                                )
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 8)
                    }
                }
                .buttonStyle(PlainButtonStyle())

                // Progress Bar or Error Message
                if placeholder.state == .failed {
                    VStack(spacing: 6) {
                        if let errorMsg = placeholder.errorMessage {
                            Button(action: {
                                showDetailsSheet = true
                            }) {
                                VStack(spacing: 2) {
                                    Text(errorMsg)
                                        .font(.custom("Nunito-Regular", size: 8))
                                        .foregroundColor(.red.opacity(0.8))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                    
                                    // Show indicator if text might be truncated
                                    if errorMsg.count > 60 {
                                        Text("Tap for full message")
                                            .font(.custom("Nunito-Regular", size: 7))
                                            .foregroundColor(.red.opacity(0.6))
                                    }
                                }
                                .padding(.horizontal, 8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                        // Retry button
                        Button(action: {
                            retryGeneration()
                        }) {
                            HStack(spacing: 4) {
                                if isRetrying {
                                    ProgressView()
                                        .progressViewStyle(
                                            CircularProgressViewStyle(
                                                tint: .white)
                                        )
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                        .font(
                                            .system(size: 10, weight: .semibold)
                                        )
                                }
                                Text("Retry")
                                    .font(.custom("Nunito-Bold", size: 10))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.gray)
                            .clipShape(Capsule())
                        }
                        .disabled(isRetrying)
                        .padding(.top, 4)

                        // Tap To View button
                        Button(action: {
                            showDetailsSheet = true
                        }) {
                            Text("Tap To View")
                                .font(.custom("Nunito-Regular", size: 9))
                                .foregroundColor(.blue)
                        }
                        .padding(.top, 2)
                    }
                } else {
                    VStack(spacing: 4) {
                        // Timeout message (shown initially)
                        if showTimeoutMessage && !timeoutMessage.isEmpty {
                            Button(action: {
                                showDetailsSheet = true
                            }) {
                                VStack(spacing: 2) {
                                    Text(timeoutMessage)
                                        .font(.custom("Nunito-Regular", size: 8))
                                        .foregroundColor(.orange.opacity(0.9))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                    
                                    // Show indicator if text might be truncated
                                    if timeoutMessage.count > 60 {
                                        Text("Tap for full message")
                                            .font(.custom("Nunito-Regular", size: 7))
                                            .foregroundColor(.orange.opacity(0.7))
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.bottom, 2)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // Dynamic message
                        if !dynamicMessage.isEmpty {
                            Button(action: {
                                showDetailsSheet = true
                            }) {
                                VStack(spacing: 2) {
                                    Text(dynamicMessage)
                                        .font(.custom("Nunito-Regular", size: 9))
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                    
                                    // Show indicator if text might be truncated
                                    if dynamicMessage.count > 60 {
                                        Text("Tap for full message")
                                            .font(.custom("Nunito-Regular", size: 7))
                                            .foregroundColor(.secondary.opacity(0.7))
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.bottom, 2)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // Progress Bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 4)

                                RoundedRectangle(cornerRadius: 2)
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(
                                        width: geometry.size.width
                                            * placeholder.progress, height: 4
                                    )
                                    .overlay(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0),
                                                Color.white.opacity(0.6),
                                                Color.white.opacity(0),
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                        .rotationEffect(.degrees(20))
                                        .offset(x: shimmer ? 100 : -100)
                                        .mask(RoundedRectangle(cornerRadius: 2))
                                    )
                            }
                        }
                        .frame(height: 4)
                        .padding(.horizontal, 8)

                        Text("\(Int(placeholder.progress * 100))%")
                            .font(.custom("Nunito-Regular", size: 9))
                            .foregroundColor(.secondary)
                        
                        // Tap To View button (for in-progress items too)
                        Button(action: {
                            showDetailsSheet = true
                        }) {
                            Text("Tap To View")
                                .font(.custom("Nunito-Regular", size: 9))
                                .foregroundColor(.blue)
                        }
                        .padding(.top, 2)
                    }
                }
            }
            .padding(.vertical, 10)
        }
        .frame(width: itemWidth, height: itemHeight)
        .overlay(alignment: .topTrailing) {
            // Close button for failed image generations
            if placeholder.state == .failed {
                Button(action: {
                    notificationManager.dismissNotification(id: placeholder.id)
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.2))
                            .frame(width: 24, height: 24)

                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.red)
                    }
                }
                .padding(6)
            }
        }
        .onAppear {
            pulseAnimation = true
            withAnimation(
                .linear(duration: 1.5).repeatForever(autoreverses: false)
            ) {
                shimmer = true
            }
            
            // Initialize messages
            updateMessages()
            
            // Set up timer to update messages every 10 seconds to keep in sync with notification bar
            messageUpdateTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
                updateMessages()
            }
        }
        .onDisappear {
            messageUpdateTimer?.invalidate()
        }
        .animation(
            .easeInOut(duration: 1).repeatForever(autoreverses: true),
            value: pulseAnimation
        )
        .sheet(isPresented: $showDetailsSheet) {
            GenerationDetailsSheet(
                placeholder: placeholder,
                isPresented: $showDetailsSheet
            )
        }
    }

    private var backgroundGradient: LinearGradient {
        switch placeholder.state {
        case .failed:
            return LinearGradient(
                colors: [Color.red.opacity(0.1), Color.red.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .completed:
            return LinearGradient(
                colors: [Color.green.opacity(0.1), Color.green.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [Color.blue.opacity(0.08), Color.purple.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var borderColor: Color {
        switch placeholder.state {
        case .failed: return Color.red.opacity(0.4)
        case .completed: return Color.green.opacity(0.4)
        default: return Color.gray.opacity(0.3)
        }
    }

    private func retryGeneration() {
        guard !isRetrying else { return }
        isRetrying = true

        Task {
            let success = ImageGenerationCoordinator.shared
                .retryImageGeneration(
                    notificationId: placeholder.id,
                    onImageGenerated: { _ in
                        isRetrying = false
                    },
                    onError: { _ in
                        isRetrying = false
                    }
                )

            if !success {
                isRetrying = false
            }
        }
    }
    
    private func updateMessages() {
        // Handle failed state - don't show timeout messages
        if placeholder.state == .failed {
            showTimeoutMessage = false
            timeoutMessage = ""
            showCancelButton = false
            return
        }
        
        // Don't show timeout messages if generation is completed
        if placeholder.state == .completed {
            dynamicMessage = GenerationMessageHelper.getDynamicMessage(
                elapsedSeconds: 0,
                isVideo: false,
                baseMessage: placeholder.message,
                state: placeholder.state
            )
            showTimeoutMessage = false
            timeoutMessage = ""
            showCancelButton = false
            return
        }
        
        let elapsed = Date().timeIntervalSince(placeholder.createdAt)
        let isVideo = placeholder.title.contains("Video") || placeholder.title.contains("video")
        let elapsedMinutes = Int(elapsed / 60)
        print("🔍 [PlaceholderImageCard] updateMessages: elapsed=\(elapsed)s (\(elapsedMinutes)min), state=\(placeholder.state), id=\(placeholder.id)")
        
        // Update dynamic message
        dynamicMessage = GenerationMessageHelper.getDynamicMessage(
            elapsedSeconds: elapsed,
            isVideo: isVideo,
            baseMessage: placeholder.message,
            state: placeholder.state
        )
        
        // Cancel button disabled - users cannot cancel generations
        showCancelButton = false
        
        // Show timeout message in two scenarios:
        // 1. Initial timeout warning (5-6 minutes)
        // 2. Countdown timeout warning (5-10 minutes) - shown in dynamicMessage, not timeoutMessage
        if elapsedMinutes >= 5 && elapsedMinutes < 6 {
            // Initial timeout message (5-6 minutes)
            showTimeoutMessage = true
            timeoutMessage = GenerationMessageHelper.getTimeoutMessage(isVideo: isVideo)
        } else {
            // No separate timeout message to show (5-10 minute countdown is in dynamicMessage)
            showTimeoutMessage = false
            timeoutMessage = ""
        }
    }

}

