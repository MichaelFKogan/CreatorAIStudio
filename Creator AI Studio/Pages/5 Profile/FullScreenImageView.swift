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

struct CreditsDataCard: View {
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

            HStack(spacing: 4) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(2)
                Text("credits")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.7))
            }
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
                    .aspectRatio(
                        aspectDimensions.width / aspectDimensions.height,
                        contentMode: .fit
                    )
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
    // MARK: - Properties

    let userImage: UserImage
    @Binding var isPresented: Bool
    var viewModel: ProfileViewModel?
    @EnvironmentObject var authViewModel: AuthViewModel
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
    @State private var showCreatePresetSheet = false
    @State private var showDeletePresetAlert = false
//    @StateObject private var presetViewModel = PresetViewModel()
    @State private var isSharing = false
    @State private var shareItem: URL?

    // MARK: - Computed Properties

    // Cache image models to avoid repeated JSON loading
    static var cachedImageModels: [InfoPacket]?
    private var allImageModels: [InfoPacket] {
        if let cached = Self.cachedImageModels {
            return cached
        }
        let models = ImageModelsViewModel.loadImageModels()
        Self.cachedImageModels = models
        return models
    }

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

    // Find matching image model based on title - now uses cached models
    private var matchingImageModel: InfoPacket? {
        guard let title = userImage.title, !title.isEmpty else { return nil }
        return allImageModels.first { $0.display.title == title }
    }

//    // Check if current image matches an existing preset
//    private var matchingPreset: Preset? {
//        let currentModelName = userImage.title
//        let currentPrompt = userImage.prompt
//
//        return presetViewModel.presets.first { preset in
//            // Compare model names (both can be nil or empty)
//            let modelMatch: Bool
//            if let currentModel = currentModelName, !currentModel.isEmpty {
//                modelMatch = preset.modelName == currentModel
//            } else {
//                // Both are nil/empty - consider it a match
//                modelMatch =
//                    preset.modelName == nil || preset.modelName?.isEmpty == true
//            }
//
//            // Compare prompts (both can be nil or empty)
//            let promptMatch: Bool
//            if let current = currentPrompt, !current.isEmpty {
//                promptMatch = preset.prompt == current
//            } else {
//                // Both are nil/empty - consider it a match
//                promptMatch =
//                    preset.prompt == nil || preset.prompt?.isEmpty == true
//            }
//
//            return modelMatch && promptMatch
//        }
//    }
//
//    // Check if preset button should be filled/colored
//    private var isPresetSaved: Bool {
//        matchingPreset != nil
//    }

    // MARK: - Helper Functions

    // Helper function to format cost with full precision
    private func formatCost(_ cost: Double) -> String {
        // Use NumberFormatter to show all significant digits
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 10  // Allow up to 10 decimal places for precision
        formatter.minimumFractionDigits = 0  // Don't force trailing zeros
        return formatter.string(from: NSNumber(value: cost)) ?? "$\(cost)"
    }

    // Helper function to format credits
    private func formatCredits(_ credits: Int) -> String {
        return "\(credits)"
    }

    // MARK: - View Components

    // MARK: - Immersive Mode Views

    @ViewBuilder
    private var immersiveModeView: some View {
        ZStack {
            if isVideo {
                immersiveVideoPlayer
            } else {
                immersiveImageView
            }
            immersiveExitButton
        }
    }

    @ViewBuilder
    private var immersiveVideoPlayer: some View {
        if let player = player {
            VideoPlayer(player: player)
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    // Ensure video plays when entering immersive mode
                    player.play()
                }
                .onTapGesture {
                    withAnimation {
                        isImmersiveMode = false
                    }
                }
        }
    }

    @ViewBuilder
    private var immersiveImageView: some View {
        if let url = mediaURL {
            KFImage(url)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(zoom)
                .offset(panOffset)
                .gesture(immersiveImageGesture)
                .simultaneousGesture(doubleTapResetGesture)
                .onTapGesture {
                    withAnimation {
                        isImmersiveMode = false
                    }
                }
        }
    }

    private var immersiveImageGesture: some Gesture {
        SimultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    zoom = lastZoom * value
                }
                .onEnded { _ in
                    lastZoom = zoom
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
                            width: lastPanOffset.width
                                + value.translation.width,
                            height: lastPanOffset.height
                                + value.translation.height
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
    }

    private var doubleTapResetGesture: some Gesture {
        TapGesture(count: 2)
            .onEnded {
                withAnimation(.spring()) {
                    zoom = 1.0
                    lastZoom = 1.0
                    panOffset = .zero
                    lastPanOffset = .zero
                }
            }
    }

    private var immersiveExitButton: some View {
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

    // MARK: - Normal Mode Views

    @ViewBuilder
    private var normalModeView: some View {
        ScrollView {
            VStack(spacing: 0) {
                mediaSection
                actionButtons
                Divider()
                    .background(Color.gray.opacity(0.3))
                    .padding(.top, 8)
                metadataSection
                Spacer()
                Color.clear.frame(height: 80)
            }
        }
    }

    @ViewBuilder
    private var mediaSection: some View {
        ZStack(alignment: .topTrailing) {
            if isVideo {
                normalVideoPlayer
            } else {
                normalImageView
            }
            fullScreenButton
        }
    }

    @ViewBuilder
    private var normalVideoPlayer: some View {
        if let player = player {
            VideoPlayer(player: player)
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .onAppear {
                    // Resume playing when returning to normal mode
                    if player.timeControlStatus != .playing {
                        player.play()
                    }
                }
        }
    }

    @ViewBuilder
    private var normalImageView: some View {
        if let url = mediaURL {
            KFImage(url)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipped()
                .scaleEffect(zoom)
                .gesture(normalImageMagnificationGesture)
                .onTapGesture(count: 2) {
                    withAnimation(.spring()) {
                        zoom = 1.0
                        lastZoom = 1.0
                    }
                }
                .onTapGesture {
                    withAnimation {
                        isImmersiveMode = true
                        panOffset = .zero
                        lastPanOffset = .zero
                    }
                }
        }
    }

    private var normalImageMagnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                zoom = lastZoom * value
            }
            .onEnded { _ in
                lastZoom = zoom
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
    }

    private var fullScreenButton: some View {
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

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 36) {
            likeButton
            saveButton
            if mediaURL != nil {
                shareButton
            }
            // presetButton
            deleteButton
        }
        .padding(.top, 8)
        .padding(.horizontal)
    }

    private var likeButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isFavorited.toggle()
            }
            if let viewModel = viewModel {
                Task {
                    await viewModel.toggleFavorite(imageId: userImage.id)
                }
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
    }

    @ViewBuilder
    private var shareButton: some View {
        Button(action: {
            Task {
                await shareImage()
            }
        }) {
            VStack(spacing: 6) {
                if isSharing {
                    ProgressView()
                        .progressViewStyle(
                            CircularProgressViewStyle(tint: .white)
                        )
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                        .opacity(0.8)
                }
                Text("Share")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .buttonStyle(.plain)
        .disabled(isDeleting || isDownloading || isSharing)
        .sheet(item: $shareItem) { url in
            ShareSheet(activityItems: [url])
        }
    }

    private var saveButton: some View {
        Button(action: {
            Task {
                await downloadImage()
            }
        }) {
            VStack(spacing: 6) {
                if isDownloading {
                    ProgressView()
                        .progressViewStyle(
                            CircularProgressViewStyle(tint: .white)
                        )
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
                    .opacity(showDownloadSuccess ? 1.0 : 0.8)
            }
        }
        .buttonStyle(.plain)
        .disabled(isDeleting || isDownloading)
    }

//    private var presetButton: some View {
//        Button(action: {
//            if isPresetSaved {
//                // Show alert to confirm deletion
//                showDeletePresetAlert = true
//            } else {
//                // Show create preset sheet
//                showCreatePresetSheet = true
//            }
//        }) {
//            VStack(spacing: 6) {
//                Image(systemName: isPresetSaved ? "bookmark.fill" : "bookmark")
//                    .font(.system(size: 20, weight: .medium))
//                    .foregroundColor(isPresetSaved ? .blue : .white)
//                    .opacity(isPresetSaved ? 1.0 : 0.8)
//                Text("Preset")
//                    .font(.caption)
//                    .foregroundColor(isPresetSaved ? .blue : .gray)
//            }
//        }
//        .buttonStyle(.plain)
//        .disabled(isDeleting || isDownloading)
//    }

    private var deleteButton: some View {
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

    // MARK: - Metadata Views

    @ViewBuilder
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            mediaTypeBadge
            if isPhotoFilter || isVideoFilter {
                filterMetadata
            } else if isImageModel || isVideoModel {
                modelMetadata
            } else {
                genericMetadata
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.8))
    }

    private var mediaTypeBadge: some View {
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
                    .fill(
                        isVideo
                            ? Color.purple.opacity(0.3)
                            : Color.blue.opacity(0.3))
            )
            if let ext = userImage.file_extension {
                Text(ext.uppercased())
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(.bottom, 4)
    }

    // MARK: IF FILTER

    @ViewBuilder
    private var filterMetadata: some View {
        if let title = userImage.title, !title.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "camera.filters")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                    Text("Filter Name")
                        .font(.body)
                        .foregroundColor(.gray)
                }
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .padding(.bottom, 8)
        }
        let gridColumns: [GridItem] = [
            GridItem(.flexible()),
            GridItem(.flexible()),
        ]
        let isWavespeed = userImage.provider?.lowercased() == "wavespeed"
        LazyVGrid(columns: gridColumns, spacing: 10) {
            if let type = userImage.type {
                MetadataCard(icon: "tag.fill", label: "Type", value: type)
            }
            if let cost = userImage.cost {
                CreditsDataCard(
                    icon: "dollarsign.circle.fill", label: "Credits",
                    value: formatCredits(cost.credits))
            }
            if isWavespeed {
                MetadataCard(
                    icon: "cpu.fill", label: "Model", value: "WaveSpeed")
            } else if let model = userImage.model, !model.isEmpty {
                MetadataCard(icon: "cpu.fill", label: "Model", value: model)
            }
            if isWavespeed {
                AspectRatioCard(aspectRatio: "Auto")
            } else if let aspectRatio = userImage.aspect_ratio,
                !aspectRatio.isEmpty
            {
                AspectRatioCard(aspectRatio: aspectRatio)
            }
        }
        if !isWavespeed, let prompt = userImage.prompt, !prompt.isEmpty {
            promptSection(prompt)
        }
    }

    // MARK: IF MODEL

    @ViewBuilder
    private var modelMetadata: some View {
        if let title = userImage.title, !title.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "cpu")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                    Text("AI Model")
                        .font(.body)
                        .foregroundColor(.gray)
                }
                HStack(spacing: 12) {
                    if let model = matchingImageModel {
                        Image(model.display.imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                    Text(title)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
            }
        }
        let gridColumns: [GridItem] = [
            GridItem(.flexible()),
            GridItem(.flexible()),
        ]
        LazyVGrid(columns: gridColumns, spacing: 10) {
            if let type = userImage.type {
                MetadataCard(icon: "tag.fill", label: "Type", value: type)
            }
            if let cost = userImage.cost {
                CreditsDataCard(
                    icon: "dollarsign.circle.fill", label: "Credits",
                    value: formatCredits(cost.credits))
            }
            if let model = userImage.model, !model.isEmpty {
                MetadataCard(icon: "cpu.fill", label: "Model", value: model)
            }
            if let aspectRatio = userImage.aspect_ratio, !aspectRatio.isEmpty {
                AspectRatioCard(aspectRatio: aspectRatio)
            }
        }
        if let prompt = userImage.prompt, !prompt.isEmpty {
            promptSection(prompt)
        }
    }

    private func promptSection(_ prompt: String) -> some View {
        // Convert literal \n strings to actual line breaks
        let processedPrompt = prompt.replacingOccurrences(of: "\\n", with: "\n")
        
        return VStack(alignment: .leading, spacing: 8) {
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
                        Image(
                            systemName: showCopySuccess
                                ? "checkmark.circle.fill" : "doc.on.doc"
                        )
                        .foregroundColor(
                            showCopySuccess ? .green : .white.opacity(0.8)
                        )
                        .font(.system(size: 14, weight: .regular))
                        if showCopySuccess {
                            Text("Copied")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(processedPrompt)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
        }
    }

    @ViewBuilder
    private var genericMetadata: some View {
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

    // MARK: - Body & Lifecycle

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if isImmersiveMode {
                immersiveModeView
            } else {
                normalModeView
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
            Text(
                "This will permanently delete this \(isVideo ? "video" : "image"). This action cannot be undone."
            )
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
//        .alert("Unsave Preset?", isPresented: $showDeletePresetAlert) {
//            Button("Cancel", role: .cancel) {}
//            Button("Unsave", role: .destructive) {
//                Task {
//                    await deletePreset()
//                }
//            }
//        } message: {
//            if let preset = matchingPreset {
//                Text(
//                    "Are you sure you want to unsave the preset '\(preset.title)'? This action cannot be undone."
//                )
//            } else {
//                Text(
//                    "Are you sure you want to unsave this preset? This action cannot be undone."
//                )
//            }
//        }
        .onAppear {
            // Initialize favorite state from userImage
            isFavorited = userImage.is_favorite ?? false
            
            // Initialize video player once if it's a video
            if isVideo, let url = mediaURL, player == nil {
                player = AVPlayer(url: url)
                player?.play()
            }

//            // Load presets if user is signed in
//            if let userId = authViewModel.user?.id.uuidString {
//                presetViewModel.userId = userId
//                Task {
//                    await presetViewModel.fetchPresets()
//                }
//            }
        }
        .onDisappear {
            // Clean up video player when view is dismissed
            if isVideo {
                player?.pause()
                player = nil
            }
        }
        .onChange(of: isImmersiveMode) { _, newValue in
            // Handle play/pause when switching modes
            if isVideo, let player = player {
                if newValue {
                    // Entering immersive mode - ensure it plays
                    player.play()
                }
                // When exiting immersive mode, let normalVideoPlayer's onAppear handle playback
            }
        }
        .onChange(of: userImage.is_favorite) { _, newValue in
            // Update favorite state if userImage changes
            isFavorited = newValue ?? false
        }
//        .sheet(isPresented: $showCreatePresetSheet) {
//            CreatePresetSheet(
//                isPresented: $showCreatePresetSheet,
//                userImage: userImage,
//                parentPresetViewModel: presetViewModel
//            )
//            .environmentObject(authViewModel)
//        }
//        .onChange(of: presetViewModel.presets) { _, _ in
//            // Update UI when presets change (e.g., after saving)
//        }
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
            let status = await PHPhotoLibrary.requestAuthorization(
                for: .addOnly)

            guard status == .authorized || status == .limited else {
                await MainActor.run {
                    isDownloading = false
                    downloadErrorMessage =
                        "Photo library access denied. Please enable photo library access in Settings."
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
                    PHAssetCreationRequest.creationRequestForAssetFromVideo(
                        atFileURL: tempURL)
                }

                // Clean up temp file
                try? FileManager.default.removeItem(at: tempURL)

                print("✅ Video saved to photo library successfully")
            } else {
                // Save image to photo library
                guard let image = UIImage(data: data) else {
                    throw NSError(
                        domain: "DownloadError", code: -1,
                        userInfo: [
                            NSLocalizedDescriptionKey:
                                "Failed to create image from data"
                        ])
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
                    downloadErrorMessage =
                        "Network error: \(urlError.localizedDescription)"
                } else {
                    downloadErrorMessage =
                        "Failed to download: \(error.localizedDescription)"
                }
                showDownloadError = true
            }
        }
    }

    // MARK: - Share Image

    private func shareImage() async {
        guard let url = mediaURL else {
            return
        }

        await MainActor.run {
            isSharing = true
        }

        do {
            // Download the media data
            let (data, _) = try await URLSession.shared.data(from: url)

            // Create a temporary file
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(isVideo ? (userImage.file_extension ?? "mp4") : (userImage.file_extension ?? "jpg"))

            // Write data to temporary file
            try data.write(to: tempURL)

            // Share the file URL
            await MainActor.run {
                isSharing = false
                shareItem = tempURL
            }

            // Clean up the temporary file after a delay (to allow sharing to complete)
            Task {
                try? await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds
                try? FileManager.default.removeItem(at: tempURL)
            }

        } catch {
            print("❌ Failed to share media: \(error)")
            await MainActor.run {
                isSharing = false
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

        for attempt in 1...maxRetries {
            do {
                let imageUrl = userImage.image_url
                print(
                    "🔍 Deletion attempt \(attempt)/\(maxRetries) - Full image URL: \(imageUrl)"
                )

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
                let bucketName =
                    isVideo ? "user-generated-videos" : "user-generated-images"
                let bucketPath =
                    isVideo
                    ? "/user-generated-videos/" : "/user-generated-images/"

                // Extract the storage path from the URL
                var storagePath: String?

                // Method 1: Look for bucket path
                if let bucketIndex = imageUrl.range(of: bucketPath) {
                    storagePath = String(imageUrl[bucketIndex.upperBound...])
                }
                // Method 2: Look for /public/bucket/
                else if let publicIndex = imageUrl.range(
                    of: "/public\(bucketPath)")
                {
                    storagePath = String(imageUrl[publicIndex.upperBound...])
                }
                // Method 3: Parse URL components
                else if let url = URL(string: imageUrl) {
                    print("🔍 URL components: \(url.pathComponents)")
                    let bucketComponent =
                        isVideo
                        ? "user-generated-videos" : "user-generated-images"
                    if let bucketIdx = url.pathComponents.firstIndex(
                        of: bucketComponent)
                    {
                        let pathAfterBucket = url.pathComponents.dropFirst(
                            bucketIdx + 1)
                        storagePath = pathAfterBucket.joined(separator: "/")
                    }
                }

                // Delete thumbnail if it's a video (non-critical, don't fail if this fails)
                if isVideo, let thumbnailUrl = userImage.thumbnail_url {
                    print("🗑️ Also deleting video thumbnail: \(thumbnailUrl)")

                    var thumbnailPath: String?
                    if let bucketIndex = thumbnailUrl.range(
                        of: "/user-generated-images/")
                    {
                        thumbnailPath = String(
                            thumbnailUrl[bucketIndex.upperBound...])
                    }

                    if let thumbnailPath = thumbnailPath {
                        do {
                            try await retryOperation(maxAttempts: 2) {
                                _ = try await SupabaseManager.shared.client
                                    .storage
                                    .from("user-generated-images")
                                    .remove(paths: [thumbnailPath])
                            }
                            print("✅ Thumbnail deleted successfully")
                        } catch {
                            print(
                                "⚠️ Thumbnail deletion failed (non-critical): \(error)"
                            )
                        }
                    }
                }

                // Delete main storage file (with retry)
                if let storagePath = storagePath {
                    print(
                        "🗑️ Extracted storage path: '\(storagePath)' from bucket: \(bucketName)"
                    )

                    do {
                        try await retryOperation(maxAttempts: 2) {
                            _ = try await SupabaseManager.shared.client.storage
                                .from(bucketName)
                                .remove(paths: [storagePath])
                        }
                        print(
                            "✅ \(isVideo ? "Video" : "Image") file deleted from storage successfully"
                        )
                    } catch {
                        print(
                            "⚠️ Storage deletion failed (non-critical): \(error)"
                        )
                    }
                } else {
                    print(
                        "⚠️ Could not extract storage path from URL: \(imageUrl)"
                    )
                }

                // Success - remove from view model and close the view
                print("✅ Deletion completed successfully")
                await MainActor.run {
                    // Remove the image from the view model's list
                    if let viewModel = viewModel {
                        viewModel.removeImage(imageId: userImage.id)
                    }
                    isDeleting = false
                    isPresented = false
                }
                return

            } catch {
                lastError = error
                print(
                    "❌ Deletion attempt \(attempt) failed: \(error.localizedDescription)"
                )

                if attempt < maxRetries {
                    // Wait before retrying (exponential backoff)
                    let delaySeconds = Double(attempt) * 0.5
                    print("⏳ Retrying in \(delaySeconds) seconds...")
                    try? await Task.sleep(
                        nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                }
            }
        }

        // All retries failed
        await MainActor.run {
            isDeleting = false
            if let error = lastError as NSError? {
                if error.domain == NSURLErrorDomain {
                    deleteErrorMessage =
                        "Network connection lost. Please check your internet connection and try again."
                } else {
                    deleteErrorMessage =
                        "Failed to delete: \(error.localizedDescription)"
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

//    // MARK: - Delete Preset
//
//    private func deletePreset() async {
//        guard let preset = matchingPreset else {
//            print("⚠️ No matching preset found to delete")
//            return
//        }
//
//        do {
//            try await presetViewModel.deletePreset(presetId: preset.id)
//            print("✅ Preset deleted successfully")
//        } catch {
//            print("❌ Failed to delete preset: \(error)")
//            // Optionally show an error alert here if needed
//        }
//    }

    // MARK: - Retry Helper

    private func retryOperation<T>(
        maxAttempts: Int, operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                if attempt < maxAttempts {
                    let delay = 0.3 * Double(attempt)
                    try? await Task.sleep(
                        nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        throw lastError
            ?? NSError(
                domain: "RetryError", code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Operation failed after \(maxAttempts) attempts"
                ])
    }
}

//
//// MARK: - Create Preset Sheet
//
//struct CreatePresetSheet: View {
//    @Binding var isPresented: Bool
//    let userImage: UserImage
//    @EnvironmentObject var authViewModel: AuthViewModel
////    @ObservedObject var parentPresetViewModel: PresetViewModel
////    @StateObject private var presetViewModel = PresetViewModel()
//    @State private var presetTitle: String = ""
//    @FocusState private var isTitleFocused: Bool
//    @State private var isSaving = false
//    @State private var showError = false
//    @State private var errorMessage = ""
//
//    // Cache image models to avoid repeated JSON loading
//    private static var cachedImageModels: [InfoPacket]?
//    private var allImageModels: [InfoPacket] {
//        if let cached = Self.cachedImageModels {
//            return cached
//        }
//        let models = ImageModelsViewModel.loadImageModels()
//        Self.cachedImageModels = models
//        return models
//    }
//
//    // Find matching image model based on title - now uses cached models
//    private var matchingImageModel: InfoPacket? {
//        guard let title = userImage.title, !title.isEmpty else { return nil }
//        return allImageModels.first { $0.display.title == title }
//    }
//
//    // MARK: - Body
//
//    var body: some View {
//        NavigationView {
//            ZStack {
//                Color.black.ignoresSafeArea()
//
//                ScrollView {
//                    VStack(alignment: .leading, spacing: 24) {
//                        // Information section
//                        VStack(alignment: .leading, spacing: 12) {
//                            HStack(spacing: 8) {
//                                Image(systemName: "info.circle.fill")
//                                    .font(.system(size: 20))
//                                    .foregroundColor(.blue)
//                                Text("What is a Preset?")
//                                    .font(.headline)
//                                    .foregroundColor(.white)
//                            }
//
//                            Text(
//                                "A preset saves the current image model and prompt settings. You can quickly reuse these settings later to generate similar images with the same style and configuration."
//                            )
//                            .font(.subheadline)
//                            .foregroundColor(.gray)
//                            .lineSpacing(4)
//                        }
//                        .padding()
//                        .background(Color.white.opacity(0.05))
//                        .cornerRadius(12)
//
//                        // Title input section
//                        VStack(alignment: .leading, spacing: 12) {
//                            Text("Preset Title")
//                                .font(.headline)
//                                .foregroundColor(.white)
//
//                            TextField(
//                                "Enter a name for this preset",
//                                text: $presetTitle
//                            )
//                            .textFieldStyle(.plain)
//                            .font(.body)
//                            .foregroundColor(.white)
//                            .padding(12)
//                            .background(Color.white.opacity(0.1))
//                            .cornerRadius(8)
//                            .focused($isTitleFocused)
//                            .overlay(
//                                RoundedRectangle(cornerRadius: 8)
//                                    .stroke(
//                                        isTitleFocused
//                                            ? Color.blue
//                                            : Color.white.opacity(0.2),
//                                        lineWidth: 1)
//                            )
//
//                            Text(
//                                "Choose a memorable name to easily identify this preset later."
//                            )
//                            .font(.caption)
//                            .foregroundColor(.gray)
//                        }
//                        .padding()
//                        .background(Color.white.opacity(0.05))
//                        .cornerRadius(12)
//
//                        // Preset details preview
//                        VStack(alignment: .leading, spacing: 16) {
//                            Text("Preset Details")
//                                .font(.headline)
//                                .foregroundColor(.white)
//
//                            // AI Model section - matching FullScreenImageView style
//                            if let title = userImage.title, !title.isEmpty {
//                                VStack(alignment: .leading, spacing: 12) {
//                                    HStack(spacing: 4) {
//                                        Image(systemName: "cpu")
//                                            .font(.caption2)
//                                            .foregroundColor(
//                                                .white.opacity(0.8))
//                                        Text("AI Model")
//                                            .font(.caption2)
//                                            .foregroundColor(.gray)
//                                    }
//
//                                    HStack(spacing: 12) {
//                                        // Display model image if available
//                                        if let model = matchingImageModel {
//                                            Image(model.display.imageName)
//                                                .resizable()
//                                                .aspectRatio(contentMode: .fill)
//                                                .frame(width: 60, height: 60)
//                                                .clipShape(
//                                                    RoundedRectangle(
//                                                        cornerRadius: 8)
//                                                )
//                                                .overlay(
//                                                    RoundedRectangle(
//                                                        cornerRadius: 8
//                                                    )
//                                                    .stroke(
//                                                        Color.white.opacity(
//                                                            0.2), lineWidth: 1)
//                                                )
//                                        }
//
//                                        Text(title)
//                                            .font(.title3)
//                                            .fontWeight(.semibold)
//                                            .foregroundColor(.white)
//                                    }
//                                }
//                            }
//
//                            // Prompt section - matching FullScreenImageView style
//                            if let prompt = userImage.prompt, !prompt.isEmpty {
//                                VStack(alignment: .leading, spacing: 8) {
//                                    HStack {
//                                        Image(systemName: "text.alignleft")
//                                            .font(.caption2)
//                                            .foregroundColor(
//                                                .white.opacity(0.8))
//                                        Text("Prompt")
//                                            .font(.caption2)
//                                            .foregroundColor(.gray)
//
//                                        Spacer()
//                                    }
//
//                                    VStack(alignment: .leading, spacing: 4) {
//                                        Text(prompt)
//                                            .font(
//                                                .system(
//                                                    size: 15, weight: .medium)
//                                            )
//                                            .foregroundColor(.white)
//                                            .fixedSize(
//                                                horizontal: false,
//                                                vertical: true
//                                            )
//                                            .frame(
//                                                maxWidth: .infinity,
//                                                alignment: .leading)
//                                    }
//                                    .padding(12)
//                                    .background(Color.white.opacity(0.05))
//                                    .cornerRadius(8)
//                                }
//                            }
//                        }
//                        .frame(maxWidth: .infinity, alignment: .leading)
//                        .padding(.vertical, 16)
//                        .padding(.horizontal, 16)
//                        .background(Color.white.opacity(0.05))
//                        .cornerRadius(12)
//
//                    }
//                    .padding(.horizontal)
//                }
//            }
//            .navigationTitle("Create Preset")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .navigationBarLeading) {
//                    Button("Cancel") {
//                        isPresented = false
//                    }
//                    .foregroundColor(.white)
//                }
//
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    Button("Save") {
//                        Task {
//                            await savePreset()
//                        }
//                    }
//                    .foregroundColor(
//                        presetTitle.isEmpty || isSaving ? .gray : .blue
//                    )
//                    .fontWeight(.semibold)
//                    .disabled(presetTitle.isEmpty || isSaving)
//                }
//
//                ToolbarItemGroup(placement: .keyboard) {
//                    Spacer()
//                    Button("Done") {
//                        isTitleFocused = false
//                    }
//                }
//            }
//        }
//        .preferredColorScheme(.dark)
//        .presentationDetents([.medium, .large])
////        .onAppear {
////            // Set user ID for preset view model
////            if let userId = authViewModel.user?.id.uuidString {
////                presetViewModel.userId = userId
////                // Sync presets from parent view model
////                presetViewModel.presets = parentPresetViewModel.presets
////            }
////        }
//        .alert("Error Saving Preset", isPresented: $showError) {
//            Button("OK", role: .cancel) {}
//        } message: {
//            Text(errorMessage)
//                .fixedSize(horizontal: false, vertical: true)
//        }
//    }
//
//    // MARK: - Save Preset
//    private func savePreset() async {
//        print("🟢 [CreatePresetSheet] Save button pressed")
//        print("🟢 [CreatePresetSheet] Preset title: '\(presetTitle)'")
//
//        guard let userId = authViewModel.user?.id.uuidString else {
//            print("❌ [CreatePresetSheet] User not signed in")
//            errorMessage = "You must be signed in to save presets."
//            showError = true
//            return
//        }
//
//        print("🟢 [CreatePresetSheet] User ID: \(userId)")
//        print("🟢 [CreatePresetSheet] Setting user ID in presetViewModel...")
//
//        // Ensure presetViewModel has the user ID
//        presetViewModel.userId = userId
//
//        isSaving = true
//
//        // Get model name from userImage
//        let modelName = userImage.title
//        print(
//            "🟢 [CreatePresetSheet] Model name from userImage: '\(modelName ?? "nil")'"
//        )
//
//        // Get prompt from userImage
//        let prompt = userImage.prompt
//        print(
//            "🟢 [CreatePresetSheet] Prompt from userImage: '\(prompt?.prefix(50) ?? "nil")...'"
//        )
//
//        // Get image URL from userImage
//        let imageUrl = userImage.image_url
//        print("🟢 [CreatePresetSheet] Image URL from userImage: '\(imageUrl)'")
//
//        do {
//            print("🟢 [CreatePresetSheet] Calling presetViewModel.savePreset...")
//            try await presetViewModel.savePreset(
//                title: presetTitle,
//                modelName: modelName,
//                prompt: prompt,
//                imageUrl: imageUrl
//            )
//
//            print(
//                "✅ [CreatePresetSheet] Preset saved successfully, closing sheet..."
//            )
//
//            // Success - refresh parent view model and close the sheet
//            await MainActor.run {
//                // Sync presets with parent view model
//                parentPresetViewModel.presets = presetViewModel.presets
//                isSaving = false
//                isPresented = false
//            }
//        } catch {
//            print("❌ [CreatePresetSheet] Error saving preset")
//            print("❌ [CreatePresetSheet] Error type: \(type(of: error))")
//            print(
//                "❌ [CreatePresetSheet] Error description: \(error.localizedDescription)"
//            )
//            if let nsError = error as NSError? {
//                print("❌ [CreatePresetSheet] Error domain: \(nsError.domain)")
//                print("❌ [CreatePresetSheet] Error code: \(nsError.code)")
//                print(
//                    "❌ [CreatePresetSheet] Error userInfo: \(nsError.userInfo)")
//            }
//
//            await MainActor.run {
//                isSaving = false
//                errorMessage =
//                    "Failed to save preset: \(error.localizedDescription)"
//                showError = true
//            }
//        }
//    }
//}

// // MARK: - Share Sheet

// struct ShareSheet: UIViewControllerRepresentable {
//     let activityItems: [Any]
//     let applicationActivities: [UIActivity]? = nil

//     func makeUIViewController(context: Context) -> UIActivityViewController {
//         let controller = UIActivityViewController(
//             activityItems: activityItems,
//             applicationActivities: applicationActivities
//         )
//         return controller
//     }

//     func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
// }

// MARK: - Credit Conversion Helper
extension Double {
    /// Converts dollar amount to credits (1 credit = $0.01)
    var credits: Int {
        return Int((self * 100).rounded())
    }
}

extension Optional where Wrapped == Double {
    /// Converts dollar amount to credits, returns 0 if nil
    var credits: Int {
        guard let value = self else { return 0 }
        return value.credits
    }
}
