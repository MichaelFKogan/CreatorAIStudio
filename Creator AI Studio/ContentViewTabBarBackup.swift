import SwiftUI
import UIKit

// MARK: - Backup: Custom tab bar implementation
// To use this instead of the stock TabView, in Creator_AI_StudioApp.swift
// replace ContentView() with ContentViewTabBarBackup().

struct ContentViewTabBarBackup: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var pushNotificationManager = PushNotificationManager.shared
    @StateObject private var mainTabState = MainTabState(initialTab: 0)
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) private var scenePhase

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
                    LazyView(ModelsPageContainer())
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(
                                    with: .move(edge: currentTransitionEdge)),
                                removal: .opacity.combined(
                                    with: .move(
                                        edge: currentTransitionEdge == .leading
                                            ? .trailing : .leading))
                            ))
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
            .environmentObject(mainTabState)

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
                    galleryTabButton()
                }
                .padding(.horizontal)
                .padding(.top, 8)
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
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            let uid = authViewModel.user?.id.uuidString
            Task { await JobStatusManager.shared.refreshPendingJobsIfNeeded(userId: uid) }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                let uid = authViewModel.user?.id.uuidString
                Task { await JobStatusManager.shared.refreshPendingJobsIfNeeded(userId: uid) }
            }
        }
        .onChange(of: pushNotificationManager.shouldNavigateToGallery) { _, shouldNavigate in
            if shouldNavigate {
                currentTransitionEdge = 4 > selectedTab ? .trailing : .leading
                previousTab = selectedTab
                mainTabState.selectedTabIndex = 4
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectedTab = 4
                }
                notificationManager.clearBadges()
                pushNotificationManager.shouldNavigateToGallery = false
            }
        }
    }

    private var tabBarGradient: [Color] {
        colorScheme == .dark
            ? [Color.black.opacity(0.7), Color.black.opacity(0.7)]
            : [Color.white.opacity(0.7), Color.white.opacity(0.7)]
    }

    private func tabButton(icon: String, title: String, index: Int) -> some View
    {
        TabBarButton(
            icon: icon,
            title: title,
            isSelected: selectedTab == index,
            hasSpecialStyling: index == 2
        ) {
            if index == 0 && selectedTab == 0 {
                homeResetTrigger = UUID()
            }

            let edge: Edge = index < selectedTab ? .leading : .trailing
            currentTransitionEdge = edge
            previousTab = selectedTab
            mainTabState.selectedTabIndex = index
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedTab = index
            }
        }
    }

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
            mainTabState.selectedTabIndex = 4
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedTab = 4
            }
            notificationManager.clearBadges()
        }) {
            VStack(spacing: 4) {
                ZStack {
                    if hasActiveGeneration {
                        SpinningProgressRing()
                    }

                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 22))

                    if failedCount > 0 {
                        BadgeView(content: "✕", backgroundColor: .red)
                    } else if completedCount > 0 {
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
                            .fill(
                                isSelected
                                    ? Color.clear : Color.white)
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
