import AVFoundation
import Kingfisher
import SwiftUI
import UIKit

struct Post: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var cameraService = CameraService()
    @State private var selectedUIImage: UIImage?
    @State private var showLibraryPicker = false
    @State private var navigateToPhotoReview = false
    @State private var isViewActive = true
    @State private var shouldShowCapturedImage = false

    @StateObject private var filtersViewModel = PhotoFiltersViewModel()
    @State private var selectedFilter: InfoPacket?
    @State private var showFilterCategorySheet = false
    @State private var centeredFilter: InfoPacket?
    @State private var isScrollingActive = false

    // Image Model mode state
    @StateObject private var imageModelsViewModel = ImageModelsViewModel()
    @State private var selectedImageModel: InfoPacket?

    // Presets state
    //    @StateObject private var presetViewModel = PresetViewModel()

    //    // Convert presets to InfoPacket format
    //    private var presetInfoPackets: [InfoPacket] {
    //        let allModels = imageModelsViewModel.filteredAndSortedImageModels
    //        return presetViewModel.presets.compactMap { preset in
    //            preset.toInfoPacket(allModels: allModels)
    //        }
    //    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Black background
                Color.black.ignoresSafeArea()

                // Only show captured photo when explicitly allowed
                if shouldShowCapturedImage,
                    let captured = cameraService.capturedImage
                {
                    // Show captured photo fullscreen
                    GeometryReader { geometry in
                        Image(uiImage: captured)
                            .resizable()
                            .scaledToFill()
                            .frame(
                                width: geometry.size.width,
                                height: geometry.size.height
                            )
                            .clipped()
                    }
                    .ignoresSafeArea()
                    .transaction { transaction in
                        transaction.animation = nil
                    }

                } else {
                    // Live camera preview
                    CameraPreview(
                        session: cameraService.session,
                        position: cameraService.cameraPosition
                    )
                }

                // MARK: MAIN STACK
                VStack {
                    Spacer()

                    // MARK: BOTTOM ROW
                    VStack(spacing: 12) {
                        Spacer()

                        HStack {

                            // Right side: Photo library and switch camera buttons
                            VStack {
                                Spacer()

                                VStack(spacing: 24) {
                                    // MARK: HIDDEN
                                    Button {
                                        // cameraService.switchCamera()
                                    } label: {
                                        Image(
                                            systemName:
                                                "arrow.triangle.2.circlepath"
                                        )
                                        .font(.system(size: 25))
                                        .foregroundColor(.white).opacity(0)
                                        .clipShape(Circle())
                                        .shadow(radius: 3)
                                    }
                                    .accessibilityLabel("Switch camera")

                                    // MARK: HIDDEN
                                    Button {
                                        // showLibraryPicker = true
                                    } label: {
                                        Image(
                                            systemName:
                                                "photo.on.rectangle.angled"
                                        )
                                        .font(.system(size: 25))
                                        .foregroundColor(.white).opacity(0)
                                        .cornerRadius(8)
                                        .shadow(radius: 3)
                                    }

                                    // MARK: HIDDEN
                                    Button {
                                        // showFilterCategorySheet = true
                                    } label: {
                                        VStack(spacing: 4) {
                                            Image(
                                                systemName:
                                                    "square.grid.2x2.fill"
                                            )
                                            .font(
                                                .system(
                                                    size: 22,
                                                    weight: .medium)
                                            )
                                            .foregroundColor(.white)
                                            .opacity(0)
                                            Text("Menu")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                                .opacity(0)
                                        }
                                    }
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0))
                                )
                            }

                            Spacer()

                            VStack(spacing: 0) {
                                Spacer()

                                // MARK: LARGE IMG

                                // Show larger preview image of the centered/selected filter or model
                                // Only visible while scrolling, fades out when scrolling stops
                                // When scrolling, always show the nearest item (left or right) even if over a gap
                                // When not scrolling, show selected filter/model if available
                                let displayFilter: InfoPacket? =
                                    isScrollingActive
                                    ? centeredFilter  // While scrolling, always shows nearest item (left or right of gap)
                                    : (centeredFilter ?? selectedFilter
                                        ?? selectedImageModel)  // When not scrolling, show selected

                                if let displayFilter = displayFilter {
                                    VStack(spacing: 12) {

                                        // Category title above the image
                                        Text(
                                            categoryTitle(
                                                for: displayFilter)
                                        )
                                        .font(
                                            .system(
                                                size: 18, weight: .medium,
                                                design: .rounded)
                                        )
                                        .foregroundColor(
                                            .white.opacity(0.8)
                                        )
                                        .textCase(.uppercase)
                                        .tracking(1.2)
                                        .opacity(
                                            isScrollingActive ? 1.0 : 0
                                        )
                                        .animation(
                                            .easeOut(duration: 0.3),
                                            value: isScrollingActive
                                        )
                                        .shadow(
                                            color: .black.opacity(1),
                                            radius: 4,
                                            x: 0,
                                            y: 2)

                                        // Filter title above the image
                                        Text(displayFilter.display.title)
                                            .font(
                                                .system(
                                                    size: 18,
                                                    weight: .semibold,
                                                    design: .rounded)
                                            )
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                            .frame(maxWidth: 300)
                                            .opacity(
                                                isScrollingActive ? 1.0 : 0
                                            )
                                            .animation(
                                                .easeOut(duration: 0.3),
                                                value: isScrollingActive
                                            )
                                            .shadow(
                                                color: .black.opacity(1),
                                                radius: 4,
                                                x: 0,
                                                y: 2)

                                        // Preview image
                                        // Check if imageName is a URL (for presets)
                                        Group {
                                            if displayFilter.display
                                                .imageName
                                                .hasPrefix("http://")
                                                || displayFilter.display
                                                    .imageName.hasPrefix(
                                                        "https://"),
                                                let url = URL(
                                                    string: displayFilter
                                                        .display.imageName)
                                            {
                                                KFImage(url)
                                                    .placeholder {
                                                        Rectangle()
                                                            .fill(
                                                                Color.gray
                                                                    .opacity(
                                                                        0.2)
                                                            )
                                                            .overlay(
                                                                ProgressView()
                                                            )
                                                    }
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(
                                                        width: 250,
                                                        height: 300
                                                    )
                                                    .clipShape(
                                                        RoundedRectangle(
                                                            cornerRadius: 16
                                                        )
                                                    )
                                                    .opacity(
                                                        isScrollingActive
                                                            ? 0.8 : 0
                                                    )
                                                    .shadow(
                                                        color: .black
                                                            .opacity(
                                                                0.5),
                                                        radius: 20,
                                                        x: 0,
                                                        y: 0
                                                    )
                                            } else {
                                                Image(
                                                    displayFilter.display
                                                        .imageName
                                                )
                                                .resizable()
                                                .scaledToFill()
                                                .frame(
                                                    width: 250, height: 300
                                                )
                                                .clipShape(
                                                    RoundedRectangle(
                                                        cornerRadius: 16)
                                                )
                                                .opacity(
                                                    isScrollingActive
                                                        ? 0.8 : 0
                                                )
                                                .shadow(
                                                    color: .black.opacity(
                                                        0.5),
                                                    radius: 20,
                                                    x: 0,
                                                    y: 0
                                                )
                                            }
                                        }
                                        .overlay(
                                            // Cost badge in top right
                                            Group {
                                                if let cost = displayFilter
                                                    .resolvedCost
                                                {
                                                    // Text( "$\(NSDecimalNumber(decimal: cost).stringValue)")
                                                    Text("\(cost.credits)")
                                                        .font(
                                                            .system(
                                                                size: 13,
                                                                weight:
                                                                    .semibold,
                                                                design:
                                                                    .rounded
                                                            )
                                                        )
                                                        .foregroundColor(
                                                            .white
                                                        )
                                                        .padding(
                                                            .horizontal, 10
                                                        )
                                                        .padding(
                                                            .vertical, 5
                                                        )
                                                        .background(
                                                            Capsule()
                                                                .fill(
                                                                    Color
                                                                        .black
                                                                        .opacity(
                                                                            0.75
                                                                        )
                                                                )
                                                        )
                                                        .shadow(
                                                            color: .black
                                                                .opacity(
                                                                    0.4),
                                                            radius: 4, x: 0,
                                                            y: 2
                                                        )
                                                        .padding(12)
                                                        .opacity(
                                                            isScrollingActive
                                                                ? 1.0 : 0
                                                        )
                                                        .animation(
                                                            .easeOut(
                                                                duration:
                                                                    0.3),
                                                            value:
                                                                isScrollingActive
                                                        )
                                                }
                                            },
                                            alignment: .bottomTrailing
                                        )
                                    }
                                    .allowsHitTesting(false)
                                    .padding(.bottom, 24)
                                }

                                VStack(spacing: 12) {
                                    // // Category title
                                    // if let displayFilter =
                                    //     centeredFilter
                                    //     ?? selectedFilter
                                    //     ?? selectedImageModel
                                    // {
                                    //     Text(
                                    //         categoryTitle(
                                    //             for: displayFilter)
                                    //     )
                                    //     .font(
                                    //         .system(
                                    //             size: 16, weight: .medium,
                                    //             design: .rounded)
                                    //     )
                                    //     .foregroundColor(
                                    //         .white.opacity(0.7)
                                    //     )
                                    //     .textCase(.uppercase)
                                    //     .tracking(1.2)
                                    //     .opacity(
                                    //         isScrollingActive ? 1.0 : 0
                                    //     )
                                    //     .animation(
                                    //         .easeOut(duration: 0.3),
                                    //         value: isScrollingActive
                                    //     )
                                    //     .shadow(
                                    //         color: .black.opacity(0.6),
                                    //         radius: 2,
                                    //         x: 0,
                                    //         y: 1)
                                    // }

                                    // MARK: FILTER TITLE
                                    Button {
                                        showFilterCategorySheet = true
                                    } label: {
                                        Group {
                                            HStack {
                                                // Show centered filter while scrolling, otherwise show selected filter or model
                                                if let displayFilter =
                                                    centeredFilter
                                                    ?? selectedFilter
                                                    ?? selectedImageModel
                                                {
                                                    // Text(
                                                    //     displayFilter.display
                                                    //         .title
                                                    // )
                                                    // .font(
                                                    //     .system(
                                                    //         size: 14,
                                                    //         weight: .medium,
                                                    //         design: .rounded)
                                                    // )
                                                    // .foregroundColor(.white)
                                                    // .lineLimit(1)
                                                    // .truncationMode(.tail)
                                                    // .fixedSize(
                                                    //     horizontal: true,
                                                    //     vertical: false
                                                    // )
                                                    // .padding(.horizontal, 16)
                                                    // .padding(.vertical, 8)
                                                    // .background(
                                                    //     RoundedRectangle(
                                                    //         cornerRadius: 12
                                                    //     )
                                                    //     .fill(
                                                    //         Color.black.opacity(
                                                    //             0.5)
                                                    //     )
                                                    // )
                                                } else {
                                                    Text(
                                                        "Select an AI Model or Photo Filter"
                                                    )
                                                    .font(
                                                        .system(
                                                            size: 14,
                                                            weight: .medium,
                                                            design: .rounded)
                                                    )
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 8)
                                                    .background(
                                                        RoundedRectangle(
                                                            cornerRadius: 12
                                                        )
                                                        .fill(
                                                            Color.black.opacity(
                                                                0.5)
                                                        )
                                                    )
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Spacer()

                            // Right side: Photo library and switch camera buttons
                            VStack {
                                Spacer()

                                VStack(spacing: 16) {
                                    // MARK: ✅ ❌
                                    // X (retake) and checkmark (confirm) buttons - visible only when photo is captured AND filter is selected
                                    if shouldShowCapturedImage,
                                        cameraService.capturedImage != nil,
                                        isFilterOrModelSelected
                                    {
                                        // X Button - Retake photo
                                        Button {
                                            // Clear the captured image and return to camera preview
                                            shouldShowCapturedImage = false
                                            cameraService.capturedImage = nil
                                            // Ensure camera session is running when returning to preview
                                            // Restart session to ensure it's active
                                            DispatchQueue.main.asyncAfter(
                                                deadline: .now() + 0.1
                                            ) {
                                                self.cameraService
                                                    .startSession()
                                            }
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(
                                                    .system(
                                                        size: 20, weight: .bold)
                                                )
                                                .foregroundColor(.red)
                                        }
                                        .frame(width: 55, height: 55)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14)
                                                .fill(.ultraThinMaterial)
                                                .environment(
                                                    \.colorScheme, .dark)
                                        )

                                        // Checkmark Button - Confirm and proceed
                                        Button {
                                            // Navigate to the next screen
                                            navigateToPhotoReview = true
                                        } label: {
                                            Image(systemName: "checkmark")
                                                .font(
                                                    .system(
                                                        size: 20, weight: .bold)
                                                )
                                                .foregroundColor(.green)
                                        }
                                        .frame(width: 55, height: 55)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14)
                                                .fill(.ultraThinMaterial)
                                                .environment(
                                                    \.colorScheme, .dark)
                                        )
                                    }

                                    // MARK: MENU
                                    Button {
                                        showFilterCategorySheet = true
                                    } label: {
                                        Image(
                                            systemName:
                                                "square.grid.2x2.fill"
                                        )
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                    }
                                    .frame(width: 55, height: 55)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(.ultraThinMaterial)
                                            .environment(\.colorScheme, .dark)
                                    )

                                    // // MARK: LIBRARY
                                    // Button {
                                    //     showLibraryPicker = true
                                    // } label: {
                                    //     Image(
                                    //         systemName:
                                    //             "photo.on.rectangle.angled"
                                    //     )
                                    //     .font(.system(size: 25))
                                    //     .foregroundColor(.white).opacity(0.8)
                                    //     .cornerRadius(8)
                                    //     .shadow(radius: 3)
                                    // }

                                    // // MARK: MENU
                                    // Button {
                                    //     showFilterCategorySheet = true
                                    // } label: {
                                    //     VStack(spacing: 4) {
                                    //         Image(
                                    //             systemName:
                                    //                 "square.grid.2x2.fill"
                                    //         )
                                    //         .font(
                                    //             .system(
                                    //                 size: 22,
                                    //                 weight: .medium)
                                    //         )
                                    //         .foregroundColor(.white)
                                    //         .opacity(0.9)
                                    //         Text("Menu")
                                    //             .font(.caption2)
                                    //             .foregroundColor(.secondary)
                                    //     }
                                    // }
                                }
                            }

                        }
                        .padding(.horizontal)

                        // MARK: FILTER ROW
                        HStack {
                            Spacer()
                            FilterScrollRow(
                                //                                presets: presetInfoPackets,
                                imageModels: imageToImageModels,
                                filters: filtersViewModel.filters,
                                selectedFilter: selectedFilter,
                                selectedImageModel: selectedImageModel,
                                onSelect: { item in
                                    //                                    // Check if the item is a preset
                                    //                                    if presetInfoPackets.contains(where: {
                                    //                                        $0.id == item.id
                                    //                                    }) {
                                    //                                        // It's a preset - treat as a filter
                                    //                                        selectedFilter = item
                                    //                                        selectedImageModel = nil
                                    //                                    }
                                    // Check if the item is an image model or a filter
                                    if imageToImageModels.contains(
                                        where: { $0.id == item.id })
                                    {
                                        // It's an image model
                                        selectedImageModel = item
                                        selectedFilter = nil  // Clear filter when model is selected
                                    } else {
                                        // It's a filter
                                        selectedFilter = item
                                        selectedImageModel = nil  // Clear model when filter is selected
                                    }
                                    // Don't clear centeredFilter here - it causes a flicker
                                    // The displayFilter fallback will use selectedFilter when scrolling stops
                                },
                                onCenteredFilterChanged: { filter in
                                    centeredFilter = filter
                                },
                                onScrollingStateChanged: { isScrolling in
                                    isScrollingActive = isScrolling
                                },
                                onCapture: {
                                    cameraService.capturePhoto()
                                },
                                isCaptureEnabled: isFilterOrModelSelected)
                            Spacer()
                        }
                        .padding(.bottom, 20)

                        HStack(spacing: 50) {
                            // MARK: 🖼️ LIBRARY
                            Button {
                                showLibraryPicker = true
                            } label: {
                                Image(
                                    systemName:
                                        "photo.on.rectangle.angled"
                                )
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            }
                            .frame(width: 55, height: 55)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(.ultraThinMaterial)
                                    .environment(\.colorScheme, .dark)
                            )

                            // MARK: CAPTURE
                            Button {
                                // Explicitly hide the large image preview when capturing
                                isScrollingActive = false
                                cameraService.capturePhoto()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(
                                            shouldShowCapturedImage
                                                ? Color.gray.opacity(0.3)
                                                : Color.white
                                        )
                                        .frame(width: 72, height: 72)

                                    Circle()
                                        .stroke(
                                            shouldShowCapturedImage
                                                ? Color.gray.opacity(0.5)
                                                : Color.white,
                                            lineWidth: 4
                                        )
                                        .frame(width: 80, height: 80)
                                }
                            }
                            .disabled(shouldShowCapturedImage)

                            // MARK: 🔄 SWITCH
                            Button {
                                cameraService.switchCamera()
                            } label: {
                                Image(
                                    systemName:
                                        "arrow.triangle.2.circlepath"
                                )
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            }
                            .frame(width: 55, height: 55)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(.ultraThinMaterial)
                                    .environment(\.colorScheme, .dark)
                            )
                            .accessibilityLabel("Switch camera")
                        }
                        .padding(.horizontal, 20)

                    }
                    .safeAreaInset(edge: .bottom) {
                        Color.clear.frame(height: 75)
                    }
                }
            }
            // MARK: TOOLBAR
            .onAppear {
                isViewActive = true
                // Keep captured image if it exists (user navigated back from confirmation)
                // Only show it if there's actually a captured image
                if cameraService.capturedImage != nil {
                    shouldShowCapturedImage = true
                }
                // Ensure session is running when view appears
                cameraService.startSession()

                //                // Load presets if user is signed in
                //                if let userId = authViewModel.user?.id.uuidString {
                //                    presetViewModel.userId = userId
                //                    Task {
                //                        await presetViewModel.fetchPresets()
                //                    }
                //                }
            }
            .onDisappear {
                isViewActive = false
                // Don't stop session when navigating to child views
                // The session will continue running and restart if needed
            }
            .onChange(of: navigateToPhotoReview) { isNavigating in
                if !isNavigating {
                    // Keep the captured image when returning from navigation
                    // User can clear it by pressing the X button
                    // Just ensure the camera session is ready if needed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if !self.cameraService.session.isRunning {
                            self.cameraService.startSession()
                        }
                    }
                }
            }
            .onChange(of: cameraService.capturedImage) { newImage in
                if newImage != nil {
                    // Show the captured image on screen (don't navigate yet)
                    shouldShowCapturedImage = true
                } else {
                    // Hide the image when it's cleared
                    shouldShowCapturedImage = false
                }
            }
            .background(
                NavigationLink(
                    destination: photoReviewDestination,
                    isActive: $navigateToPhotoReview
                ) {
                    EmptyView()
                }
            )
            .sheet(isPresented: $showLibraryPicker) {
                PhotoLibraryPickerView(
                    isPresented: $showLibraryPicker,
                    selectedImage: $cameraService.capturedImage
                )
            }
            .sheet(isPresented: $showFilterCategorySheet) {
                FilterCategorySheet(
                    isPresented: $showFilterCategorySheet,
                    categorizedFilters: filtersViewModel.categorizedFilters,
                    allFilters: filtersViewModel.filters,
                    imageModels: imageModelsViewModel
                        .filteredAndSortedImageModels,
                    selectedFilter: $selectedFilter,
                    selectedImageModel: $selectedImageModel,
                    onSelect: { filter in
                        // Check if it's a preset
                        //                        if presetInfoPackets.contains(where: {
                        //                            $0.id == filter.id
                        //                        }) {
                        //                            selectedFilter = filter
                        //                            selectedImageModel = nil
                        //                        } else {
                        selectedFilter = filter
                        selectedImageModel = nil  // Clear model when filter is selected
                        //                        }
                    },
                    onSelectModel: { model in
                        selectedImageModel = model
                        selectedFilter = nil  // Clear filter when model is selected
                    }
                )
                .environmentObject(authViewModel)
            }
        }
    }

    // MARK: COMPUTED PROPERTIES

    private var isFilterOrModelSelected: Bool {
        selectedFilter != nil || selectedImageModel != nil
    }

    /// Image models filtered to only include those with "Image to Image" capability
    private var imageToImageModels: [InfoPacket] {
        imageModelsViewModel.filteredAndSortedImageModels.filter { model in
            model.resolvedCapabilities?.contains("Image to Image") == true
        }
    }

    // Helper function to get category title for an item
    private func categoryTitle(for item: InfoPacket) -> String {
        //        // Check if it's a preset first
        //        if presetInfoPackets.contains(where: { $0.id == item.id }) {
        //            return "Presets"
        //        }

        // Check if it's an image model (using filtered list to match what's shown)
        if imageToImageModels.contains(where: {
            $0.id == item.id
        }) {
            return "AI Models"
        }

        // Use the category field directly from JSON
        if let category = item.category, !category.isEmpty {
            return category
        }

        // If it doesn't have a category, it's in "Popular"
        return "Popular"
    }

    @ViewBuilder
    private var photoReviewDestination: some View {
        Group {
            if let capturedImage = cameraService.capturedImage {
                if let selectedFilter = selectedFilter {
                    PhotoConfirmationView(
                        item: selectedFilter,
                        image: capturedImage
                    )
                } else if let model = selectedImageModel {
                    ImageModelDetailPage(
                        item: model,
                        capturedImage: capturedImage
                    )
                } else {
                    // If no filter or model selected, show a message or go back
                    VStack {
                        Text("Please select a Filter or Image Model first")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                    .onAppear {
                        // Auto-dismiss after a moment if nothing selected
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            navigateToPhotoReview = false
                        }
                    }
                }
            }
        }
    }
}
