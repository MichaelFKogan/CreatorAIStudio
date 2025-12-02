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
        init(_ build: @autoclosure @escaping () -> Content) { self.build = build }
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
                    LazyView(PhotoFilters())
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
                    LazyView(Post())
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
                    .padding(.bottom, 55) // add space above tab bar
            }

            // Tab Bar
            VStack {
                Spacer()
                HStack(spacing: 0) {
                    tabButton(icon: "house.fill", title: "Home", index: 0)
                    tabButton(icon: "camera.filters", title: "Photo Filters", index: 1)
                    tabButton(icon: "camera.fill", title: "Create", index: 2)

                    tabButton(icon: "cpu", title: "AI Models", index: 3)
                    // tabButton(icon: "video.fill", title: "Video", index: 3)
                    tabButton(icon: "photo.on.rectangle.angled", title: "Gallery", index: 4)
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
    private func tabButton(icon: String, title: String, index: Int) -> some View {
        TabBarButton(
            icon: icon,
            title: title,
            isSelected: selectedTab == index,
            hasSpecialStyling: index == 20
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
//                            .stroke(isSelected ? Color.pink : Color.clear, lineWidth: 2)
                            .fill(isSelected ? Color.clear : Color.pink)
                            .frame(width: 60, height: 60)
                        Image(systemName: icon)
                            .font(.system(size: 22))
                            .foregroundColor(isSelected ? .pink : .black)
                    }
                    .offset(y: 5)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 22))
                }
                Text(title)
                    .font(.caption)
                    .foregroundColor(isSelected ? .pink : .gray)
            }
            .foregroundColor(hasSpecialStyling ? .clear : (isSelected ? .pink : .gray))
            .frame(maxWidth: .infinity)
        }
    }
}
