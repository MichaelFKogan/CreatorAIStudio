import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var notificationManager = NotificationManager.shared
    @Environment(\.colorScheme) var colorScheme

    @State private var sortOrder = 0
    @State private var selectedTab = 0
    @State private var previousTab = 0
    @State private var currentTransitionEdge: Edge = .trailing
    @State private var homeResetTrigger = UUID()

    struct LazyView<Content: View>: View {
        let build: () -> Content
        init(_ build: @autoclosure @escaping () -> Content) {
            self.build = build
        }
        var body: some View { build() }
    }

    var body: some View {
        ZStack {
            Group {
                switch selectedTab {
                case 0:
                    LazyView(Home(resetTrigger: homeResetTrigger))
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(
                                    with: .move(edge: .leading)),
                                removal: .opacity.combined(
                                    with: .move(edge: .leading))
                            ))
                case 1:
                    LazyView(PhotoFilters().environmentObject(authViewModel))
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(
                                    with: .move(edge: currentTransitionEdge)),
                                removal: .opacity.combined(
                                    with: .move(
                                        edge: currentTransitionEdge == .leading
                                            ? .trailing : .leading))
                            ))
                case 2:
                    LazyView(Post().environmentObject(authViewModel))
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(
                                    with: .move(edge: currentTransitionEdge)),
                                removal: .opacity.combined(
                                    with: .move(
                                        edge: currentTransitionEdge == .leading
                                            ? .trailing : .leading))
                            ))
                case 3:
                    LazyView(ImageModelsPage())
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(
                                    with: .move(edge: currentTransitionEdge)),
                                removal: .opacity.combined(
                                    with: .move(
                                        edge: currentTransitionEdge == .leading
                                            ? .trailing : .leading))
                            ))
                //    case 3:
                //        LazyView(VideoModelsPage())
                //            .transition(
                //                .asymmetric(
                //                    insertion: .opacity.combined(
                //                        with: .move(edge: currentTransitionEdge)),
                //                    removal: .opacity.combined(
                //                        with: .move(
                //                            edge: currentTransitionEdge == .leading
                //                                ? .trailing : .leading))
                //                ))
                case 4:
                    LazyView(Profile().environmentObject(authViewModel))
                        .environmentObject(authViewModel)
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(
                                    with: .move(edge: currentTransitionEdge)),
                                removal: .opacity.combined(
                                    with: .move(
                                        edge: currentTransitionEdge == .leading
                                            ? .trailing : .leading))
                            ))
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .environmentObject(notificationManager)

            // Notification Bar (above tab bar)
            VStack {
                Spacer()
                NotificationBar(notificationManager: notificationManager)
                    .padding(.bottom, 70)  // add space above tab bar
            }

            // Tab Bar
            VStack {
                Spacer()
                HStack(spacing: 0) {
                    tabButton(icon: "house.fill", title: "Home", index: 0)
                    tabButton(
                        icon: "camera.filters", title: "Photo Filters", index: 1
                    )
                    tabButton(icon: "camera.fill", title: "", index: 2)

                    tabButton(icon: "cpu", title: "AI Models", index: 3)
                    // tabButton(icon: "video.fill", title: "Video", index: 3)
                    galleryTabButton()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                //                .padding(.bottom, -10)
                //                .background(.ultraThinMaterial)
                .background(
                    ZStack {
                        Color.clear.background(.ultraThinMaterial)

                        LinearGradient(
                            colors: tabBarGradient,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                    .ignoresSafeArea(edges: .bottom)
                )
            }
        }
        .ignoresSafeArea(.keyboard)
    }

    private var tabBarGradient: [Color] {
        colorScheme == .dark
            ? [Color.black.opacity(0.7), Color.black.opacity(0.7)]
            : [Color.white.opacity(0.7), Color.white.opacity(0.7)]
    }

    // Tab button helper
    private func tabButton(icon: String, title: String, index: Int) -> some View
    {
        TabBarButton(
            icon: icon,
            title: title,
            isSelected: selectedTab == index,
            hasSpecialStyling: index == 2
        ) {
            // If tapping Home tab while already on Home, reset navigation to root
            if index == 0 && selectedTab == 0 {
                homeResetTrigger = UUID()
            }

            let edge: Edge = index < selectedTab ? .leading : .trailing
            currentTransitionEdge = edge
            previousTab = selectedTab
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedTab = index
            }
        }
    }
    
    // Gallery tab button with circular progress indicator
    private func galleryTabButton() -> some View {
        let activeNotifications = notificationManager.notifications.filter { 
            $0.isActive && $0.state != .completed && $0.state != .failed 
        }
        let hasActiveGeneration = !activeNotifications.isEmpty
        let completedCount = notificationManager.newCompletedCount
        let failedCount = notificationManager.newFailedCount
        
        return Button(action: {
            let edge: Edge = 4 < selectedTab ? .leading : .trailing
            currentTransitionEdge = edge
            previousTab = selectedTab
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedTab = 4
            }
            // Clear badges when entering Gallery
            notificationManager.clearBadges()
        }) {
            VStack(spacing: 4) {
                ZStack {
                    // Spinning circular progress indicator
                    if hasActiveGeneration {
                        SpinningProgressRing()
                    }
                    
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 22))
                    
                    // Badge notification
                    if failedCount > 0 {
                        // Show X for failures
                        BadgeView(content: "✕", backgroundColor: .red)
                    } else if completedCount > 0 {
                        // Show count for completed images
                        BadgeView(content: "\(completedCount)", backgroundColor: .red)
                    }
                }
                
                Text("Gallery")
                    .font(.caption)
                    .foregroundColor(selectedTab == 4 ? .white.opacity(0.9) : .gray)
            }
            .frame(height: 55)
            .offset(y: 5)
            .foregroundColor(selectedTab == 4 ? .white.opacity(0.9) : .gray)
            .frame(maxWidth: .infinity)
        }
    }
}

struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let hasSpecialStyling: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                if hasSpecialStyling {
                    ZStack {
                        Circle()
                            // The stroke modifier draws the border around the shape.
                            // .stroke(isSelected ? Color.white.opacity(0.9) : Color.clear, lineWidth: 2)
                            .fill(
                                isSelected
                                    ? Color.clear : Color.gray)
                        // .frame(width: 60, height: 60)
                        Image(systemName: isSelected ? "camera" : icon)
                            .font(.system(size: 22))
                            .foregroundColor(
                                isSelected ? .white.opacity(0.9) : .black)
                    }
                    .frame(width: 60, height: 60)
                    .offset(y: 5)

                } else {
                    Image(systemName: icon)
                        .font(.system(size: 22))
                }

                Text(title)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.9) : .gray)

            }
            .frame(height: 55)
            .offset(y: 5)
            .foregroundColor(
                hasSpecialStyling
                    ? .clear : (isSelected ? .white.opacity(0.9) : .gray)
            )
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Spinning Progress Ring with Multiple Colors
struct SpinningProgressRing: View {
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: [
                        .blue,
                        .purple,
                        .pink,
                        .orange,
                        .blue
                    ]),
                    center: .center,
                    startAngle: .degrees(0),
                    endAngle: .degrees(360)
                ),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
            )
            .frame(width: 34, height: 34)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Badge View for Notification Count
struct BadgeView: View {
    let content: String
    let backgroundColor: Color
    
    var body: some View {
        Text(content)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .frame(minWidth: 16, minHeight: 16)
            .padding(.horizontal, 4)
            .background(backgroundColor)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.black.opacity(0.2), lineWidth: 1)
            )
            .offset(x: 12, y: -12)
            .transition(.scale.combined(with: .opacity))
    }
}
