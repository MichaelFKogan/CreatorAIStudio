//
//  FullScreenImageView.swift
//  AI Photo Generation
//
//  Created by Mike K on 11/8/25.
//

import AVKit
import Kingfisher
import Photos
import SwiftUI

// MARK: - Reusable Components

struct MetadataRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                Text(label)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MetadataCard: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}

struct AspectRatioCard: View {
    let aspectRatio: String

    // Map aspect ratios to their platform names
    private var platformName: String {
        switch aspectRatio {
        case "3:4": return "Portrait"
        case "9:16": return "TikTok • Reels"
        case "1:1": return "Instagram"
        case "4:3": return "Landscape"
        case "16:9": return "YouTube"
        default: return ""
        }
    }

    // Calculate aspect ratio dimensions for visual representation
    private var aspectDimensions: (width: CGFloat, height: CGFloat) {
        let components = aspectRatio.split(separator: ":")
        guard components.count == 2,
              let width = Double(components[0]),
              let height = Double(components[1])
        else {
            return (1, 1)
        }
        return (CGFloat(width), CGFloat(height))
    }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "aspectratio")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                    Text("Aspect Ratio")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }

                HStack(spacing: 4) {
                    Text(aspectRatio)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)

                    if !platformName.isEmpty {
                        Text(platformName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 4)

            // Visual representation of aspect ratio
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 32, height: 32)

                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
                    .aspectRatio(aspectDimensions.width / aspectDimensions.height, contentMode: .fit)
                    .frame(height: 20)
                    .padding(4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Full Screen Image View

struct FullScreenImageView: View {
    let userImage: UserImage
    @Binding var isPresented: Bool
    @State private var zoom: CGFloat = 1.0
    @State private var lastZoom: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var lastPanOffset: CGSize = .zero
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var isDownloading = false
    @State private var showDownloadSuccess = false
    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""
    @State private var player: AVPlayer?
    @State private var showCopySuccess = false
    @State private var showDownloadError = false
    @State private var downloadErrorMessage = ""
    @State private var isImmersiveMode = false
    @State private var isFavorited = false

    var mediaURL: URL? {
        URL(string: userImage.image_url)
    }

    var thumbnailURL: URL? {
        if let thumbnail = userImage.thumbnail_url {
            return URL(string: thumbnail)
        }
        return nil
    }

    var isVideo: Bool {
        userImage.isVideo
    }

    var isPhotoFilter: Bool {
        userImage.type == "Photo Filter"
    }

    var isVideoFilter: Bool {
        userImage.type == "Video Filter"
    }

    var isImageModel: Bool {
        userImage.type == "Image Model"
    }

    var isVideoModel: Bool {
        userImage.type == "Video Model"
    }

    // Find matching image model based on title
    private var matchingImageModel: InfoPacket? {
        guard let title = userImage.title, !title.isEmpty else { return nil }
        let allModels = ImageModelsViewModel.loadImageModels()
        return allModels.first { $0.display.title == title }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isImmersiveMode {
                // Immersive full-screen mode - only media
                ZStack {
                    if isVideo {
                        // Video player
                        if let url = mediaURL {
                            VideoPlayer(player: player)
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .onAppear {
                                    player = AVPlayer(url: url)
                                    player?.play()
                                }
                                .onDisappear {
                                    player?.pause()
                                    player = nil
                                }
                                .onTapGesture {
                                    // Tap to exit immersive mode
                                    withAnimation {
                                        isImmersiveMode = false
                                    }
                                }
                        }
                    } else {
                        // Image viewer
                        if let url = mediaURL {
                            KFImage(url)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .scaleEffect(zoom)
                                .offset(panOffset)
                                .gesture(
                                    SimultaneousGesture(
                                        MagnificationGesture()
                                            .onChanged { value in
                                                zoom = lastZoom * value
                                            }
                                            .onEnded { _ in
                                                lastZoom = zoom
                                                // Limit zoom range
                                                if lastZoom < 1.0 {
                                                    withAnimation {
                                                        lastZoom = 1.0
                                                        zoom = 1.0
                                                        panOffset = .zero
                                                        lastPanOffset = .zero
                                                    }
                                                } else if lastZoom > 5.0 {
                                                    withAnimation {
                                                        lastZoom = 5.0
                                                        zoom = 5.0
                                                    }
                                                }
                                            },
                                        DragGesture()
                                            .onChanged { value in
                                                if zoom > 1.0 {
                                                    panOffset = CGSize(
                                                        width: lastPanOffset.width + value.translation.width,
                                                        height: lastPanOffset.height + value.translation.height
                                                    )
                                                }
                                            }
                                            .onEnded { _ in
                                                if zoom > 1.0 {
                                                    lastPanOffset = panOffset
                                                } else {
                                                    panOffset = .zero
                                                    lastPanOffset = .zero
                                                }
                                            }
                                    )
                                )
                                .simultaneousGesture(
                                    TapGesture(count: 2)
                                        .onEnded {
                                            // Double-tap to reset zoom
                                            withAnimation(.spring()) {
                                                zoom = 1.0
                                                lastZoom = 1.0
                                                panOffset = .zero
                                                lastPanOffset = .zero
                                            }
                                        }
                                )
                                .onTapGesture {
                                    // Single tap to exit immersive mode
                                    withAnimation {
                                        isImmersiveMode = false
                                    }
                                }
                        }
                    }

                    // Exit button in immersive mode
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                withAnimation {
                                    isImmersiveMode = false
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white.opacity(0.8))
                                    .background(Color.black.opacity(0.3))
                                    .clipShape(Circle())
                            }
                            .padding()
                        }
                        Spacer()
                    }
                }
            } else {
                // Normal mode with metadata
                ScrollView {
                    VStack(spacing: 0) {
                        // Media section (image or video)
                        ZStack(alignment: .topTrailing) {
                            if isVideo {
                                // Video player
                                if let url = mediaURL {
                                    VideoPlayer(player: player)
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxWidth: .infinity)
                                        .onAppear {
                                            player = AVPlayer(url: url)
                                            player?.play()
                                        }
                                        .onDisappear {
                                            player?.pause()
                                            player = nil
                                        }
                                }
                            } else {
                                // Image viewer
                                if let url = mediaURL {
                                    KFImage(url)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(maxWidth: .infinity)
                                        .clipped()
                                        .scaleEffect(zoom)
                                        .gesture(
                                            MagnificationGesture()
                                                .onChanged { value in
                                                    zoom = lastZoom * value
                                                }
                                                .onEnded { _ in
                                                    lastZoom = zoom
                                                    // Limit zoom range
                                                    if lastZoom < 1.0 {
                                                        withAnimation {
                                                            lastZoom = 1.0
                                                            zoom = 1.0
                                                        }
                                                    } else if lastZoom > 5.0 {
                                                        withAnimation {
                                                            lastZoom = 5.0
                                                            zoom = 5.0
                                                        }
                                                    }
                                                }
                                        )
                                        .onTapGesture(count: 2) {
                                            // Double-tap to reset zoom
                                            withAnimation(.spring()) {
                                                zoom = 1.0
                                                lastZoom = 1.0
                                            }
                                        }
                                        .onTapGesture {
                                            // Single-tap to open immersive mode
                                            withAnimation {
                                                isImmersiveMode = true
                                                panOffset = .zero
                                                lastPanOffset = .zero
                                            }
                                        }
                                }
                            }

                            // Full-screen icon button
                            Button(action: {
                                withAnimation {
                                    isImmersiveMode = true
                                    panOffset = .zero
                                    lastPanOffset = .zero
                                }
                            }) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                            .padding(12)
                        }

                        // Action buttons (Like, Share, Save, Delete)
                        HStack(spacing: 36) {
                            // Like button
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    isFavorited.toggle()
                                }
                            }) {
                                VStack(spacing: 6) {
                                    Image(systemName: isFavorited ? "heart.fill" : "heart")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(isFavorited ? .red : .white)
                                        .opacity(0.8)
                                        .scaleEffect(isFavorited ? 1.2 : 1.0)
                                    Text("Like")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .buttonStyle(.plain)

                            // Share button
                            if let url = mediaURL {
                                ShareLink(item: url) {
                                    VStack(spacing: 6) {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundColor(.white)
                                            .opacity(0.8)
                                        Text("Share")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(isDeleting || isDownloading)
                            }

                            // Save button
                            Button(action: {
                                Task {
                                    await downloadImage()
                                }
                            }) {
                                VStack(spacing: 6) {
                                    if isDownloading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else if showDownloadSuccess {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundColor(.green)
                                    } else {
                                        Image(systemName: "arrow.down.circle")
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundColor(.white)
                                            .opacity(0.8)
                                    }
                                    Text(showDownloadSuccess ? "Saved" : "Save")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(isDeleting || isDownloading || showDownloadSuccess)

                            // Delete button
                            Button(action: {
                                showDeleteAlert = true
                            }) {
                                VStack(spacing: 6) {
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(.red)
                                        .opacity(0.8)
                                    Text("Delete")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(isDeleting)
                        }
                        .padding(.top, 8)
                        .padding(.horizontal)

                        Divider()
                            .background(Color.gray.opacity(0.3))
                            .padding(.top, 8)

                        // Info section below image
                        VStack(alignment: .leading, spacing: 16) {
                            // Display media type badge
                            HStack {
                                HStack(spacing: 4) {
                                    Image(systemName: isVideo ? "video.fill" : "photo.fill")
                                        .font(.caption)
                                    Text(isVideo ? "Video" : "Image")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(isVideo ? Color.purple.opacity(0.3) : Color.blue.opacity(0.3))
                                )

                                if let ext = userImage.file_extension {
                                    Text(ext.uppercased())
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }

                                Spacer()
                            }
                            .padding(.bottom, 4)

                            // Display Photo Filter or Video Filter information
                            if isPhotoFilter || isVideoFilter {
                                // Title - prominent display
                                if let title = userImage.title, !title.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "camera.filters")
                                                .font(.caption2)
                                                .foregroundColor(.white.opacity(0.8))
                                            Text("Filter Name")
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                        }
                                        Text(title)
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                    }
                                    .padding(.bottom, 8)
                                }

                                // Grid layout for metadata
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                ], spacing: 10) {
                                    if let type = userImage.type {
                                        MetadataCard(icon: "tag.fill", label: "Type", value: type)
                                    }

                                    if let cost = userImage.cost {
                                        MetadataCard(icon: "dollarsign.circle.fill", label: "Cost", value: String(format: "$%.2f", cost))
                                    }

                                    if let aspectRatio = userImage.aspect_ratio, !aspectRatio.isEmpty {
                                        AspectRatioCard(aspectRatio: aspectRatio)
                                    }
                                }
                            }

                            else if isImageModel || isVideoModel {
                                // Title - prominent display with model image
                                if let title = userImage.title, !title.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "cpu")
                                                .font(.caption2)
                                                .foregroundColor(.white.opacity(0.8))
                                            Text("AI Model")
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                        }

                                        HStack(spacing: 12) {
                                            // Display model image if available
                                            if let model = matchingImageModel {
                                                Image(model.display.imageName)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 60, height: 60)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                                    )
                                            }

                                            Text(title)
                                                .font(.title3)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.white)
                                        }
                                    }
                                }

                                // Prompt (if exists) - special prominent display
                                if let prompt = userImage.prompt, !prompt.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: "text.alignleft")
                                                .font(.caption2)
                                                .foregroundColor(.white.opacity(0.8))
                                            Text("Prompt")
                                                .font(.caption2)
                                                .foregroundColor(.gray)

                                            Spacer()

                                            Button(action: {
                                                copyPromptToClipboard(prompt)
                                            }) {
                                                HStack(spacing: 4) {
                                                    Image(systemName: showCopySuccess ? "checkmark.circle.fill" : "doc.on.doc")
                                                        .foregroundColor(showCopySuccess ? .green : .white.opacity(0.8))
                                                        .font(.system(size: 14, weight: .regular))
                                                    if showCopySuccess {
                                                        Text("Copied")
                                                            .font(.caption2)
                                                            .foregroundColor(.green)
                                                    }
                                                }
                                            }
                                        }

                                        ScrollView {
                                            Text(prompt)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(.white)
                                                .fixedSize(horizontal: false, vertical: true)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .frame(maxHeight: 200)
                                        .padding(12)
                                        .background(Color.white.opacity(0.05))
                                        .cornerRadius(8)
                                    }
                                }

                                // Grid layout for metadata
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                ], spacing: 10) {
                                    if let type = userImage.type {
                                        MetadataCard(icon: "tag.fill", label: "Type", value: type)
                                    }

                                    if let cost = userImage.cost {
                                        MetadataCard(icon: "dollarsign.circle.fill", label: "Cost", value: String(format: "$%.2f", cost))
                                    }

                                    if let model = userImage.model, !model.isEmpty {
                                        MetadataCard(icon: "cpu.fill", label: "Model", value: model)
                                    }

                                    if let aspectRatio = userImage.aspect_ratio, !aspectRatio.isEmpty {
                                        AspectRatioCard(aspectRatio: aspectRatio)
                                    }
                                }
                            }

                            else {
                                // For other types, show generic info
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "sparkles")
                                            .foregroundColor(.white.opacity(0.6))
                                        Text("AI Generated")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }

                                    if let model = userImage.model, !model.isEmpty {
                                        MetadataCard(icon: "cpu.fill", label: "Model", value: model)
                                    }
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.8))

                        Spacer()
                    }
                    // Bottom spacing
                    Color.clear.frame(height: 80)
                }
            }
        }
        .alert("Delete Image?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await deleteImage()
                }
            }
        } message: {
            Text("This will permanently delete this \(isVideo ? "video" : "image"). This action cannot be undone.")
        }
        .alert("Delete Failed", isPresented: $showDeleteError) {
            Button("OK", role: .cancel) {}
            Button("Retry") {
                Task {
                    await deleteImage()
                }
            }
        } message: {
            Text(deleteErrorMessage)
        }
        .alert("Download Failed", isPresented: $showDownloadError) {
            Button("OK", role: .cancel) {}
            Button("Retry") {
                Task {
                    await downloadImage()
                }
            }
        } message: {
            Text(downloadErrorMessage)
        }
    }

    // MARK: - Download Media (Image or Video)

    private func downloadImage() async {
        guard let url = mediaURL else {
            await MainActor.run {
                downloadErrorMessage = "Invalid media URL. Please try again."
                showDownloadError = true
            }
            return
        }

        await MainActor.run {
            isDownloading = true
            showDownloadSuccess = false
        }

        do {
            // Download the media data
            let (data, _) = try await URLSession.shared.data(from: url)

            // Request photo library permission and save
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)

            guard status == .authorized || status == .limited else {
                await MainActor.run {
                    isDownloading = false
                    downloadErrorMessage = "Photo library access denied. Please enable photo library access in Settings."
                    showDownloadError = true
                }
                return
            }

            if isVideo {
                // Save video to photo library
                // Write to temporary file first
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(userImage.file_extension ?? "mp4")

                try data.write(to: tempURL)

                // Save to photo library
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: tempURL)
                }

                // Clean up temp file
                try? FileManager.default.removeItem(at: tempURL)

                print("✅ Video saved to photo library successfully")
            } else {
                // Save image to photo library
                guard let image = UIImage(data: data) else {
                    throw NSError(domain: "DownloadError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create image from data"])
                }

                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetCreationRequest.creationRequestForAsset(from: image)
                }

                print("✅ Image saved to photo library successfully")
            }

            await MainActor.run {
                isDownloading = false
                showDownloadSuccess = true

                // Reset success state after 3 seconds
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    await MainActor.run {
                        showDownloadSuccess = false
                    }
                }
            }

        } catch {
            print("❌ Failed to download media: \(error)")
            await MainActor.run {
                isDownloading = false
                if let urlError = error as? URLError {
                    downloadErrorMessage = "Network error: \(urlError.localizedDescription)"
                } else {
                    downloadErrorMessage = "Failed to download: \(error.localizedDescription)"
                }
                showDownloadError = true
            }
        }
    }

    // MARK: - Delete Image with Retry

    private func deleteImage() async {
        await MainActor.run {
            isDeleting = true
        }

        let maxRetries = 3
        var lastError: Error?

        for attempt in 1 ... maxRetries {
            do {
                let imageUrl = userImage.image_url
                print("🔍 Deletion attempt \(attempt)/\(maxRetries) - Full image URL: \(imageUrl)")

                // Delete from database first (with retry)
                try await retryOperation(maxAttempts: 2) {
                    try await SupabaseManager.shared.client.database
                        .from("user_media")
                        .delete()
                        .eq("id", value: userImage.id)
                        .execute()
                }

                print("✅ Image record deleted from database")

                // Determine which storage bucket to use
                let bucketName = isVideo ? "user-generated-videos" : "user-generated-images"
                let bucketPath = isVideo ? "/user-generated-videos/" : "/user-generated-images/"

                // Extract the storage path from the URL
                var storagePath: String?

                // Method 1: Look for bucket path
                if let bucketIndex = imageUrl.range(of: bucketPath) {
                    storagePath = String(imageUrl[bucketIndex.upperBound...])
                }
                // Method 2: Look for /public/bucket/
                else if let publicIndex = imageUrl.range(of: "/public\(bucketPath)") {
                    storagePath = String(imageUrl[publicIndex.upperBound...])
                }
                // Method 3: Parse URL components
                else if let url = URL(string: imageUrl) {
                    print("🔍 URL components: \(url.pathComponents)")
                    let bucketComponent = isVideo ? "user-generated-videos" : "user-generated-images"
                    if let bucketIdx = url.pathComponents.firstIndex(of: bucketComponent) {
                        let pathAfterBucket = url.pathComponents.dropFirst(bucketIdx + 1)
                        storagePath = pathAfterBucket.joined(separator: "/")
                    }
                }

                // Delete thumbnail if it's a video (non-critical, don't fail if this fails)
                if isVideo, let thumbnailUrl = userImage.thumbnail_url {
                    print("🗑️ Also deleting video thumbnail: \(thumbnailUrl)")

                    var thumbnailPath: String?
                    if let bucketIndex = thumbnailUrl.range(of: "/user-generated-images/") {
                        thumbnailPath = String(thumbnailUrl[bucketIndex.upperBound...])
                    }

                    if let thumbnailPath = thumbnailPath {
                        do {
                            try await retryOperation(maxAttempts: 2) {
                                _ = try await SupabaseManager.shared.client.storage
                                    .from("user-generated-images")
                                    .remove(paths: [thumbnailPath])
                            }
                            print("✅ Thumbnail deleted successfully")
                        } catch {
                            print("⚠️ Thumbnail deletion failed (non-critical): \(error)")
                        }
                    }
                }

                // Delete main storage file (with retry)
                if let storagePath = storagePath {
                    print("🗑️ Extracted storage path: '\(storagePath)' from bucket: \(bucketName)")

                    do {
                        try await retryOperation(maxAttempts: 2) {
                            _ = try await SupabaseManager.shared.client.storage
                                .from(bucketName)
                                .remove(paths: [storagePath])
                        }
                        print("✅ \(isVideo ? "Video" : "Image") file deleted from storage successfully")
                    } catch {
                        print("⚠️ Storage deletion failed (non-critical): \(error)")
                    }
                } else {
                    print("⚠️ Could not extract storage path from URL: \(imageUrl)")
                }

                // Success - close the view
                print("✅ Deletion completed successfully")
                await MainActor.run {
                    isDeleting = false
                    isPresented = false
                }
                return

            } catch {
                lastError = error
                print("❌ Deletion attempt \(attempt) failed: \(error.localizedDescription)")

                if attempt < maxRetries {
                    // Wait before retrying (exponential backoff)
                    let delaySeconds = Double(attempt) * 0.5
                    print("⏳ Retrying in \(delaySeconds) seconds...")
                    try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                }
            }
        }

        // All retries failed
        await MainActor.run {
            isDeleting = false
            if let error = lastError as NSError? {
                if error.domain == NSURLErrorDomain {
                    deleteErrorMessage = "Network connection lost. Please check your internet connection and try again."
                } else {
                    deleteErrorMessage = "Failed to delete: \(error.localizedDescription)"
                }
            } else {
                deleteErrorMessage = "Failed to delete. Please try again."
            }
            showDeleteError = true
        }
    }

    // MARK: - Copy Prompt to Clipboard

    private func copyPromptToClipboard(_ prompt: String) {
        UIPasteboard.general.string = prompt
        showCopySuccess = true

        // Reset success state after 2 seconds
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                showCopySuccess = false
            }
        }
    }

    // MARK: - Retry Helper

    private func retryOperation<T>(maxAttempts: Int, operation: () async throws -> T) async throws -> T {
        var lastError: Error?

        for attempt in 1 ... maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                if attempt < maxAttempts {
                    let delay = 0.3 * Double(attempt)
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        throw lastError ?? NSError(domain: "RetryError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation failed after \(maxAttempts) attempts"])
    }
}
