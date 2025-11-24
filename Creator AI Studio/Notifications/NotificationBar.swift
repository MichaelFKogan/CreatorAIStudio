import SwiftUI

// MARK: - Notification Bar
struct NotificationBar: View {
    @ObservedObject var notificationManager: NotificationManager
    
    var body: some View {
        if !notificationManager.notifications.isEmpty {
            VStack(spacing: 8) {
                ForEach(notificationManager.notifications) { notification in
                    NotificationCard(
                        notification: notification,
                        onDismiss: {
                            notificationManager.dismissNotification(id: notification.id)
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
    
    @State private var shimmer = false
    @State private var pulseAnimation = false
    
    var body: some View {
        HStack(spacing: 12) {
            NotificationThumbnail(image: notification.thumbnailImage, pulseAnimation: $pulseAnimation)
            NotificationTextContent(notification: notification, shimmer: $shimmer)
            NotificationCloseButton(onDismiss: onDismiss)
        }
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
    @Binding var pulseAnimation: Bool
    
    var body: some View {
        if let image = image {
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
        } else {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 22))
                    .foregroundStyle(
                        LinearGradient(colors: [.blue, .purple],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing)
                    )
            }
            .scaleEffect(pulseAnimation ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulseAnimation)
        }
    }
}

// MARK: - Text Content View
struct NotificationTextContent: View {
    let notification: NotificationData
    @Binding var shimmer: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(notification.title)
                .font(.custom("Nunito-Bold", size: 14))
                .foregroundColor(.primary)
            
            Text(notification.message)
                .font(.custom("Nunito-Regular", size: 12))
                .foregroundColor(notification.state == .failed ? .red : .secondary)
                .lineLimit(2)
            
            if notification.state == .failed, let errorMsg = notification.errorMessage {
                Text(errorMsg)
                    .font(.custom("Nunito-Regular", size: 10))
                    .foregroundColor(.red.opacity(0.8))
                    .lineLimit(3)
            }
            
            if notification.state != .failed {
                NotificationProgressBar(progress: notification.progress, state: notification.state, shimmer: $shimmer)
                Text(notification.state == .completed
                     ? "100% • View in Profile"
                     : "\(Int(notification.progress * 100))% • View in Profile when complete")
                    .font(.custom("Nunito-Regular", size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Close Button View
struct NotificationCloseButton: View {
    let onDismiss: () -> Void
    
    var body: some View {
        Button(action: onDismiss) {
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 28, height: 28)
                
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
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
