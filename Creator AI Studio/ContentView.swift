import SwiftUI
import UIKit

/// Tracks the selected main tab (0=Home, 1=Photo Filters, 2=Post, 3=Models, 4=Profile).
/// Video filter detail pages observe this and stop playback when the user switches away from Home.
final class MainTabState: ObservableObject {
    @Published var selectedTabIndex: Int
    init(initialTab: Int = 0) {
        self.selectedTabIndex = initialTab
    }
}

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var pushNotificationManager = PushNotificationManager.shared
    @StateObject private var mainTabState = MainTabState(initialTab: 0)
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedTab = 0
    @State private var homeResetTrigger = UUID()

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                Home(resetTrigger: homeResetTrigger)
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(0)

                PhotoFilters()
                    .environmentObject(authViewModel)
                    .tabItem {
                        Label("Photo Filters", systemImage: "camera.filters")
                    }
                    .tag(1)

                Post()
                    .environmentObject(authViewModel)
                    .tabItem {
                        Label("Post", systemImage: "camera.fill")
                    }
                    .tag(2)

                ModelsPageContainer()
                    .tabItem {
                        Label("AI Models", systemImage: "cpu")
                    }
                    .tag(3)

                Profile()
                    .environmentObject(authViewModel)
                    .tabItem {
                        Label("Gallery", systemImage: "photo.on.rectangle.angled")
                    }
                    .tag(4)
                    .badge(galleryBadgeCount)
            }
            .environmentObject(notificationManager)
            .environmentObject(mainTabState)
            .onChange(of: selectedTab) { _, newIndex in
                mainTabState.selectedTabIndex = newIndex
                if newIndex == 4 {
                    notificationManager.clearBadges()
                }
            }

            // Notification bar above stock tab bar
            NotificationBar(notificationManager: notificationManager)
                .padding(.bottom, 50)
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
                mainTabState.selectedTabIndex = 4
                selectedTab = 4
                notificationManager.clearBadges()
                pushNotificationManager.shouldNavigateToGallery = false
            }
        }
    }

    /// Badge count for Gallery tab; 0 is hidden by the system.
    private var galleryBadgeCount: Int {
        notificationManager.newCompletedCount + notificationManager.newFailedCount
    }
}
