import SwiftUI
import UIKit

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

            VStack(spacing: 8) {
                // Tappable area for image and title/message
                Button(action: {
                    showDetailsSheet = true
                }) {
                    VStack(spacing: 8) {
                        // Thumbnail or Icon
                        if let thumbnail = placeholder.thumbnailImage, isValidImage {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                                .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                        } else {
                            // Show an AI/magic icon for text-to-image generation (matches NotificationBar)
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
                        VStack(spacing: 4) {
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
                            Text(errorMsg)
                                .font(.custom("Nunito-Regular", size: 8))
                                .foregroundColor(.red.opacity(0.8))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
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

                        // Cancel button for in-progress tasks (only show if task can still be cancelled)
                        // For fast models like Z-Image-Turbo, the API request may complete before user can cancel
                        if placeholder.state == .inProgress && ImageGenerationCoordinator.shared.canCancelTask(notificationId: placeholder.id) {
                            Button(action: {
                                notificationManager.cancelTask(
                                    notificationId: placeholder.id)
                            }) {
                                Text("Cancel")
                                    .font(.custom("Nunito-Bold", size: 10))
                                    .foregroundColor(.red)
                            }
                            .padding(.top, 2)
                        }
                        
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
            .padding(.vertical, 12)
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

}

