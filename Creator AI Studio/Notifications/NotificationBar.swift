import SwiftUI

// MARK: - Helper Function to Find Model Image Name

private func findModelImageName(for modelName: String?, isVideo: Bool = false) -> String? {
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

// MARK: - Notification Bar
struct NotificationBar: View {
    @ObservedObject var notificationManager: NotificationManager
    
    var body: some View {
        let visibleNotifications = notificationManager.notifications.filter { !$0.isHiddenFromBar }
        if !visibleNotifications.isEmpty && notificationManager.isNotificationBarVisible {
            VStack(spacing: 8) {
                ForEach(visibleNotifications) { notification in
                    NotificationCard(
                        notification: notification,
                        onDismiss: {
                            notificationManager.hideNotificationFromBar(id: notification.id)
                        },
                        onCancel: {
                            notificationManager.cancelTask(notificationId: notification.id)
                        }
                    )
                }
            }
            .padding(.horizontal, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// MARK: - Individual Notification Card
struct NotificationCard: View {
    let notification: NotificationData
    let onDismiss: () -> Void
    let onCancel: () -> Void
    
    @State private var shimmer = false
    @State private var pulseAnimation = false
    @State private var showDetailsSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Chevron down button to hide this individual notification - aligned right
            HStack {
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 24)
                        .background(Color.gray.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
            
            HStack(spacing: 12) {
                Button(action: {
                    showDetailsSheet = true
                }) {
                    HStack(spacing: 12) {
                        NotificationThumbnail(
                            image: notification.thumbnailImage,
                            modelName: notification.modelName,
                            isVideo: notification.title.contains("Video") || notification.title.contains("video"),
                            pulseAnimation: $pulseAnimation
                        )
                        NotificationTextContent(notification: notification, shimmer: $shimmer)
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                NotificationCancelButton(
                    state: notification.state,
                    notificationId: notification.id,
                    createdAt: notification.createdAt,
                    onCancel: onCancel
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    Color.clear.background(.ultraThinMaterial)
                    LinearGradient(
                        gradient: Gradient(colors: backgroundGradient),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: 1)
            )
            .sheet(isPresented: $showDetailsSheet) {
                GenerationDetailsSheet(
                    placeholder: PlaceholderImage(from: notification),
                    isPresented: $showDetailsSheet
                )
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .scale(scale: 0.8).combined(with: .opacity)
        ))
        .onAppear {
            pulseAnimation = true
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmer = true
            }
        }
    }
    
    // MARK: - Computed Properties
    private var backgroundGradient: [Color] {
        switch notification.state {
        case .failed: return [Color.red.opacity(0.08), Color.red.opacity(0.08)]
        case .completed: return [Color.green.opacity(0.05), Color.green.opacity(0.05)]
        default: return [Color.blue.opacity(0.05), Color.purple.opacity(0.05)]
        }
    }
    
    private var borderColor: Color {
        switch notification.state {
        case .failed: return Color.red.opacity(0.3)
        case .completed: return Color.green.opacity(0.3)
        default: return Color.gray.opacity(0.15)
        }
    }
}

// MARK: - Thumbnail View
struct NotificationThumbnail: View {
    let image: UIImage?
    let modelName: String?
    let isVideo: Bool
    @Binding var pulseAnimation: Bool
    
    // Helper to check if image is a placeholder (very small, like 1x1)
    private var isValidImage: Bool {
        guard let image = image else { return false }
        let size = image.size
        // Consider images smaller than 10x10 as placeholders
        return size.width >= 10 && size.height >= 10
    }
    
    var body: some View {
        if let image = image, isValidImage {
            // Show the source image for image-to-image transformations
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 2
                        )
                )
                .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
                .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulseAnimation)
        } else if let modelImageName = findModelImageName(for: modelName, isVideo: isVideo) {
            // Show the model image for text-to-image/video generation
            Image(modelImageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 2
                        )
                )
                .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
                .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulseAnimation)
        } else {
            // Fallback: Show an AI/magic icon if no model image found
            ZStack {
                // Animated gradient background
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.4, green: 0.6, blue: 1.0),
                                Color(red: 0.6, green: 0.4, blue: 1.0),
                                Color(red: 0.8, green: 0.5, blue: 1.0)
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
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
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
            .shadow(color: Color.purple.opacity(0.4), radius: 6, x: 0, y: 2)
            .scaleEffect(pulseAnimation ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulseAnimation)
        }
    }
}

// MARK: - Text Content View
struct NotificationTextContent: View {
    let notification: NotificationData
    @Binding var shimmer: Bool
    @State private var dynamicMessage: String = ""
    @State private var timeoutMessage: String = ""
    @State private var showTimeoutMessage: Bool = false
    @State private var messageUpdateTimer: Timer?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(notification.title)
                .font(.custom("Nunito-Bold", size: 14))
                .foregroundColor(.primary)
            
            // Timeout message (shown initially)
            if showTimeoutMessage && !timeoutMessage.isEmpty {
                Text(timeoutMessage)
                    .font(.custom("Nunito-Regular", size: 10))
                    .foregroundColor(.orange.opacity(0.9))
                    .lineLimit(2)
            }
            
            // Dynamic message - show "Failed" when state is failed, otherwise show dynamic message
            if notification.state == .failed {
                Text("Failed")
                    .font(.custom("Nunito-Regular", size: 12))
                    .foregroundColor(.red)
                    .lineLimit(2)
            } else {
                Text(dynamicMessage.isEmpty ? notification.message : dynamicMessage)
                    .font(.custom("Nunito-Regular", size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // Error message details (if available and failed)
            if notification.state == .failed, let errorMsg = notification.errorMessage, !errorMsg.isEmpty {
                Text(errorMsg)
                    .font(.custom("Nunito-Regular", size: 10))
                    .foregroundColor(.red.opacity(0.8))
                    .lineLimit(3)
            }
            
            if notification.state != .failed {
                NotificationProgressBar(progress: notification.progress, state: notification.state, shimmer: $shimmer)
                HStack(spacing: 4) {
                    Text(notification.state == .completed
                         ? "100% • View in Profile"
                         : "\(Int(notification.progress * 100))% • View in Profile when complete")
                        .font(.custom("Nunito-Regular", size: 10))
                        .foregroundColor(.secondary)
                    Text("• Tap To View")
                        .font(.custom("Nunito-Regular", size: 10))
                        .foregroundColor(.blue)
                }
            }
        }
        .onAppear {
            updateMessages()
            // Only set up timer if notification is still in progress
            if notification.state == .inProgress {
                // Update every 10 seconds to keep messages in sync and catch time-based changes
                messageUpdateTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
                    updateMessages()
                }
            }
        }
        .onChange(of: notification.state) { oldState, newState in
            // Stop timer when notification is completed or failed
            if newState != .inProgress {
                messageUpdateTimer?.invalidate()
                messageUpdateTimer = nil
            }
            // Update messages immediately when state changes
            updateMessages()
            // Force UI update when state changes to failed
            if newState == .failed {
                dynamicMessage = "Failed"
            }
        }
        .onDisappear {
            messageUpdateTimer?.invalidate()
            messageUpdateTimer = nil
        }
    }
    
    private func updateMessages() {
        // Stop timer if notification is completed or failed
        if notification.state == .completed || notification.state == .failed {
            messageUpdateTimer?.invalidate()
            messageUpdateTimer = nil
            // Set dynamic message to "Failed" immediately when failed
            if notification.state == .failed {
                dynamicMessage = "Failed"
            }
            showTimeoutMessage = false
            timeoutMessage = ""
            return
        }
        
        let elapsed = Date().timeIntervalSince(notification.createdAt)
        let isVideo = notification.title.contains("Video") || notification.title.contains("video")
        let elapsedMinutes = Int(elapsed / 60)
        
        // Update dynamic message (handles all states including failed and completed)
        dynamicMessage = GenerationMessageHelper.getDynamicMessage(
            elapsedSeconds: elapsed,
            isVideo: isVideo,
            baseMessage: notification.message,
            state: notification.state
        )
        
        // Show timeout message in two scenarios:
        // 1. Initial timeout warning (2-3 minutes)
        // 2. Countdown timeout warning (3-5 minutes) - shown in dynamicMessage, not timeoutMessage
        if elapsedMinutes >= 2 && elapsedMinutes < 3 {
            // Initial timeout message (2-3 minutes)
            showTimeoutMessage = true
            timeoutMessage = GenerationMessageHelper.getTimeoutMessage(isVideo: isVideo)
        } else {
            // No separate timeout message to show (3-5 minute countdown is in dynamicMessage)
            showTimeoutMessage = false
            timeoutMessage = ""
        }
    }
}

// MARK: - Cancel Button View
struct NotificationCancelButton: View {
    let state: NotificationState
    let notificationId: UUID
    let createdAt: Date
    let onCancel: () -> Void
    
    @State private var showCancel: Bool = false
    @State private var updateTimer: Timer?
    
    var body: some View {
        Group {
            if state == .inProgress && showCancel {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.custom("Nunito-Bold", size: 13))
                        .foregroundColor(.red)
                }
            }
        }
        .onAppear {
            updateCancelButtonVisibility()
            // Update every 10 seconds to catch the 2-minute mark
            updateTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
                updateCancelButtonVisibility()
            }
        }
        .onChange(of: state) { newState in
            if newState != .inProgress {
                updateTimer?.invalidate()
                showCancel = false
            } else {
                updateCancelButtonVisibility()
            }
        }
        .onDisappear {
            updateTimer?.invalidate()
        }
    }
    
    private func updateCancelButtonVisibility() {
        guard state == .inProgress else {
            showCancel = false
            updateTimer?.invalidate()
            return
        }
        
        let elapsed = Date().timeIntervalSince(createdAt)
        let elapsedMinutes = Int(elapsed / 60)
        let canCancel = ImageGenerationCoordinator.shared.canCancelTask(notificationId: notificationId) ||
                       VideoGenerationCoordinator.shared.canCancelTask(notificationId: notificationId)
        
        let shouldShow = elapsedMinutes >= 2 && canCancel
        print("🔍 [NotificationBar] Cancel button check: elapsedMinutes=\(elapsedMinutes), canCancel=\(canCancel), shouldShow=\(shouldShow), state=\(state)")
        showCancel = shouldShow
    }
}

// MARK: - Progress Bar View
struct NotificationProgressBar: View {
    let progress: CGFloat
    let state: NotificationState
    @Binding var shimmer: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 6)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        state == .completed
                            ? LinearGradient(colors: [Color.green, Color.green], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: geometry.size.width * progress, height: 6)
                    .overlay(
                        state == .inProgress ?
                        LinearGradient(colors: [Color.white.opacity(0), Color.white.opacity(0.6), Color.white.opacity(0)],
                                       startPoint: .leading,
                                       endPoint: .trailing)
                        .rotationEffect(.degrees(20))
                        .offset(x: shimmer ? 200 : -200)
                        .mask(RoundedRectangle(cornerRadius: 4))
                        : nil
                    )
            }
        }
        .frame(height: 6)
    }
}
