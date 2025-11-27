import AVKit
import Kingfisher
import Photos
import SwiftUI

// MARK: PROFILE

struct Profile: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = ProfileViewModel()

    var body: some View {
        NavigationStack {
            VStack {
                if let user = authViewModel.user {
                    ProfileViewContent(viewModel: viewModel)
                        .environmentObject(authViewModel)
                        .onAppear {
                            if viewModel.userId != user.id.uuidString {
                                viewModel.userId = user.id.uuidString
                            }
                            Task {
                                //                            print("🔄 Profile appeared, fetching images for user: \(user.id.uuidString)")
                                await viewModel.fetchUserImages(
                                    forceRefresh: false)
                                //                            print("📸 Fetched \(viewModel.images.count) images")
                            }
                        }
                } else {
                    Text("Loading user…")
                }
            }

            // MARK: NAVIGATION BAR

            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Profile")
                        .font(
                            .system(size: 28, weight: .bold, design: .rounded)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.gray, .white],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
            }
        }
    }
}

// MARK: STRUCT PROFILEVIEWCONTENT

struct ProfileViewContent: View {
    @ObservedObject var viewModel: ProfileViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var selectedUserImage: UserImage? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // My Creations Section
                    VStack(alignment: .leading, spacing: 12) {
                        if viewModel.isLoading {
                            ProgressView("Loading images…")
                                .padding()
                        } else if viewModel.images.isEmpty
                            && notificationManager.activePlaceholders.isEmpty
                        {
                            LazyVGrid(
                                columns: Array(
                                    repeating: GridItem(
                                        .flexible(), spacing: 4
                                    ), count: 3
                                ),
                                spacing: 4
                            ) {
                                ForEach(0 ..< 9, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.gray.opacity(0.2))
                                        .overlay(
                                            Image(systemName: "photo")
                                                .foregroundColor(.gray)
                                                .font(.title3)
                                        )
                                        .aspectRatio(1 / 1.4, contentMode: .fit) // ✅ portrait ratio (≈0.714)
                                }
                            }
                            .padding(.horizontal)

                        } else {
                            ImageGridView(
                                userImages: viewModel.userImages,
                                placeholders: notificationManager
                                    .activePlaceholders
                            ) { userImage in
                                selectedUserImage = userImage
                            }
                        }
                    }
                }
                .padding(.top, 10)
                //                .navigationTitle("Profile")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(destination: Settings().environmentObject(authViewModel)) {
                            Image(systemName: "gearshape.fill")
                                .font(.headline)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.fetchUserImages(forceRefresh: true)
            }
            .onChange(of: notificationManager.notifications.count) {
                oldCount, newCount in
                // When notification count decreases (notification dismissed), refresh images
                if newCount < oldCount {
                    Task {
                        await viewModel.fetchUserImages(forceRefresh: true)
                    }
                }
            }
            .sheet(item: $selectedUserImage) { userImage in
                FullScreenImageView(
                    userImage: userImage,
                    isPresented: Binding(
                        get: { selectedUserImage != nil },
                        set: { if !$0 { selectedUserImage = nil } }
                    )
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .ignoresSafeArea()
            }
        }
    }

    // MARK: PROFILE HEADER

    private var profileHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 100, height: 100)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                )

            VStack(alignment: .leading, spacing: 12) {
                VStack(spacing: 4) {
                    Text("Your Name")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("@username")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 32) {
                    statView(value: "24", label: "Creations")
                    statView(value: "156", label: "Likes")
                    statView(value: "89", label: "Followers")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top)
        .padding(.horizontal)
    }

    private func statView(value: String, label: String) -> some View {
        VStack {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: IMAGE GRID (3×3 PORTRAIT)

struct ImageGridView: View {
    let userImages: [UserImage]
    let placeholders: [PlaceholderImage]
    let spacing: CGFloat = 2
    var onSelect: (UserImage) -> Void

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: spacing), count: 3)
    }

    var body: some View {
        GeometryReader { proxy in
            let totalSpacing = spacing * 2
            let contentWidth = max(0, proxy.size.width - totalSpacing - 8)
            let itemWidth = max(44, contentWidth / 3) // minimum thumbnail size
            let itemHeight = itemWidth * 1.4

            LazyVGrid(columns: gridColumns, spacing: spacing) {
                // Show placeholders first (in-progress generations)
                ForEach(placeholders) { placeholder in
                    PlaceholderImageCard(
                        placeholder: placeholder,
                        itemWidth: itemWidth,
                        itemHeight: itemHeight
                    )
                }

                // Then show completed images
                ForEach(userImages) { userImage in
                    if let displayUrl = userImage.isVideo
                        ? userImage.thumbnail_url : userImage.image_url,
                        let url = URL(string: displayUrl)
                    {
                        Button {
                            onSelect(userImage)
                        } label: {
                            ZStack {
                                KFImage(url)
                                    .placeholder {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .overlay(ProgressView())
                                    }
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: itemWidth, height: itemHeight)
                                    .clipped()

                                // Video play icon overlay
                                if userImage.isVideo {
                                    ZStack {
                                        Circle()
                                            .fill(Color.black.opacity(0.6))
                                            .frame(width: 40, height: 40)

                                        Image(systemName: "play.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    } else if let url = URL(string: userImage.image_url) {
                        // Fallback for videos without thumbnails
                        Button {
                            onSelect(userImage)
                        } label: {
                            ZStack {
                                KFImage(url)
                                    .placeholder {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .overlay(
                                                Image(systemName: "video.fill")
                                                    .font(.largeTitle)
                                                    .foregroundColor(.gray)
                                            )
                                    }
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: itemWidth, height: itemHeight)
                                    .clipped()

                                if userImage.isVideo {
                                    ZStack {
                                        Circle()
                                            .fill(Color.black.opacity(0.6))
                                            .frame(width: 40, height: 40)

                                        Image(systemName: "play.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(
            height: calculateHeight(for: placeholders.count + userImages.count))
    }

    private func calculateHeight(for count: Int) -> CGFloat {
        let rows = ceil(Double(count) / 3.0)
        let itemWidth = (UIScreen.main.bounds.width - 16) / 3
        return CGFloat(rows) * (itemWidth * 1.8 + spacing)
    }
}

// MARK: PLACEHOLDER Image Card (for in-progress generations)

struct PlaceholderImageCard: View {
    let placeholder: PlaceholderImage
    let itemWidth: CGFloat
    let itemHeight: CGFloat

    @State private var shimmer = false
    @State private var pulseAnimation = false

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
                // Thumbnail or Icon
                if let thumbnail = placeholder.thumbnailImage {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                        .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                } else {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .blue.opacity(0.3),
                                        .purple.opacity(0.3),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)

                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 22))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
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

                // Progress Bar or Error Message
                if placeholder.state == .failed {
                    if let errorMsg = placeholder.errorMessage {
                        Text(errorMsg)
                            .font(.custom("Nunito-Regular", size: 8))
                            .foregroundColor(.red.opacity(0.8))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
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
                    }
                }
            }
            .padding(.vertical, 12)
        }
        .frame(width: itemWidth, height: itemHeight)
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
}

// MARK: - URL Identifiable

extension URL: Identifiable {
    public var id: String { absoluteString }
}
