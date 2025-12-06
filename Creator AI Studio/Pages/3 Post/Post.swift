import AVFoundation
import SwiftUI
import UIKit

struct Post: View {
    @StateObject private var cameraService = CameraService()
    @State private var selectedUIImage: UIImage?
    @State private var showLibraryPicker = false
    @State private var navigateToPhotoReview = false
    @State private var isViewActive = true
    @State private var shouldShowCapturedImage = false

    @StateObject private var filtersViewModel = PhotoFiltersViewModel()
    @State private var selectedFilter: InfoPacket?
    @State private var showFilterCategorySheet = false

    // Image Model mode state
    @StateObject private var imageModelsViewModel = ImageModelsViewModel()
    @State private var selectedImageModel: InfoPacket?

    var body: some View {
        NavigationView {
            ZStack {
                // Black background
                Color.black.ignoresSafeArea()

                // Only show captured photo when explicitly allowed
                // This prevents the photo from appearing when returning from navigation
                if shouldShowCapturedImage,
                    let captured = cameraService.capturedImage
                {
                    // Show captured photo fullscreen
                    Image(uiImage: captured)
                        .resizable()
                        .scaledToFill()

                } else {
                    // Live camera preview
                    CameraPreview(
                        session: cameraService.session,
                        position: cameraService.cameraPosition
                    )
                }

                // MARK: MAIN STACK
                VStack {
                    // MARK: TOP TEXT
                    VStack {
                        Spacer()
                            .frame(height: 20)

                        Button {
                            showFilterCategorySheet = true
                        } label: {
                            Group {
                                if let selectedFilter = selectedFilter {
                                    Text(selectedFilter.display.title)
                                        .font(
                                            .system(
                                                size: 13, weight: .medium,
                                                design: .rounded)
                                        )
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.white.opacity(0.2))
                                                .background(
                                                    RoundedRectangle(
                                                        cornerRadius: 12
                                                    )
                                                    .fill(
                                                        Color.black.opacity(0.8)
                                                    )
                                                )
                                        )
                                } else if let selectedModel = selectedImageModel
                                {
                                    Text(selectedModel.display.title)
                                        .font(
                                            .system(
                                                size: 13, weight: .medium,
                                                design: .rounded)
                                        )
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.white.opacity(0.2))
                                                .background(
                                                    RoundedRectangle(
                                                        cornerRadius: 12
                                                    )
                                                    .fill(
                                                        Color.black.opacity(0.8)
                                                    )
                                                )
                                        )
                                } else {
                                    Text("Select an AI Model or Photo Filter")
                                        .font(
                                            .system(
                                                size: 13, weight: .medium,
                                                design: .rounded)
                                        )
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.white.opacity(0.15))
                                                .background(
                                                    RoundedRectangle(
                                                        cornerRadius: 12
                                                    )
                                                    .fill(
                                                        Color.black.opacity(0.8)
                                                    )
                                                )
                                        )
                                }
                            }
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .top)

                    // MARK: BOTTOM ROW
                    VStack {

                        HStack {
                            Spacer()
                            FilterScrollRow(filters: filtersViewModel.filters, selectedFilter: selectedFilter, onSelect: { filter in
                                selectedFilter = filter
                            })
                            Spacer()
                        }
                        
                        HStack {
                            // Left side: Filter button
                            HStack {
                                Spacer()

                                // MARK: MENU

                                Button {
                                    showFilterCategorySheet = true
                                } label: {
                                    Group {
                                        if let selectedFilter = selectedFilter {
                                            // Show selected filter thumbnail
                                            Image(
                                                selectedFilter.display.imageName
                                            )
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 70, height: 70)
                                            .clipped()
                                            .cornerRadius(10)
                                            .shadow(
                                                color: .black.opacity(0.8),
                                                radius: 4, x: 0, y: 0)
                                        } else if let selectedModel =
                                            selectedImageModel
                                        {
                                            // Show selected model thumbnail
                                            Image(
                                                selectedModel.display.imageName
                                            )
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 70, height: 70)
                                            .clipped()
                                            .cornerRadius(10)
                                            .shadow(
                                                color: .black.opacity(0.8),
                                                radius: 4, x: 0, y: 0)
                                        } else {
                                            // Placeholder when nothing is selected
                                            ZStack {
                                                RoundedRectangle(
                                                    cornerRadius: 10
                                                )
                                                .fill(
                                                    LinearGradient(
                                                        colors: [
                                                            Color.purple
                                                                .opacity(0.6),
                                                            Color.pink.opacity(
                                                                0.6),
                                                        ],
                                                        startPoint: .topLeading,
                                                        endPoint:
                                                            .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 70, height: 70)

                                                Image(systemName: "sparkles")
                                                    .font(
                                                        .system(
                                                            size: 22,
                                                            weight: .medium)
                                                    )
                                                    .foregroundColor(.white)
                                                    .opacity(0.9)
                                            }
                                            .shadow(
                                                color: .black.opacity(0.8),
                                                radius: 4, x: 0, y: 0)
                                        }
                                    }
                                }
                                .frame(width: 70, height: 70)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)

                            // Center: Capture button
                            // MARK: CAPTURE

                            Button {
                                cameraService.capturePhoto()
                            } label: {
                                Circle()
                                    .stroke(
                                        isFilterOrModelSelected
                                            ? Color.white
                                            : Color.gray.opacity(0.5),
                                        lineWidth: 5
                                    )
                                    .frame(width: 80, height: 80)
                            }
                            .disabled(!isFilterOrModelSelected)

                            // Right side: Photo library and switch camera buttons
                            HStack {
                                // MARK: LIBRARY

                                Spacer()
                                Button {
                                    showLibraryPicker = true
                                } label: {
                                    Image(
                                        systemName: "photo.on.rectangle.angled"
                                    )
                                    .font(.system(size: 25))
                                    .foregroundColor(.white).opacity(0.8)
                                    .cornerRadius(8)
                                    .shadow(radius: 3)
                                }
                                .frame(width: 50, height: 50)

                                Spacer()

                                // MARK: SWITCH

                                Button {
                                    cameraService.switchCamera()
                                } label: {
                                    Image(
                                        systemName:
                                            "arrow.triangle.2.circlepath"
                                    )
                                    .font(.system(size: 25))
                                    .foregroundColor(.white).opacity(0.8)
                                    .clipShape(Circle())
                                    .shadow(radius: 3)
                                }
                                .accessibilityLabel("Switch camera")
                                .frame(width: 50, height: 50)

                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .safeAreaInset(edge: .bottom) {
                        Color.clear.frame(height: 65)
                    }
                }
            }
            // MARK: TOOLBAR
            .onAppear {
                isViewActive = true
                // Immediately hide captured image when view appears
                // This prevents the photo from appearing when returning from navigation
                shouldShowCapturedImage = false
                // Ensure session is running when view appears
                cameraService.startSession()
            }
            .onDisappear {
                isViewActive = false
                // Don't stop session when navigating to child views
                // The session will continue running and restart if needed
            }
            .onChange(of: navigateToPhotoReview) { isNavigating in
                if !isNavigating {
                    // Immediately hide the captured image when returning from navigation
                    // Use a transaction to ensure state updates happen atomically
                    var transaction = Transaction(animation: nil)
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        shouldShowCapturedImage = false
                        cameraService.capturedImage = nil
                    }

                    // We've returned from navigation, ensure session is running
                    // Use a small delay to allow navigation animation to complete
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if !self.cameraService.session.isRunning {
                            self.cameraService.startSession()
                        }
                    }
                }
            }
            .onChange(of: cameraService.capturedImage) { newImage in
                if newImage != nil {
                    // Show the image and navigate when a photo is captured
                    shouldShowCapturedImage = true
                    navigateToPhotoReview = true
                } else {
                    // Hide the image when it's cleared
                    shouldShowCapturedImage = false
                }
            }
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
                        selectedFilter = filter
                        selectedImageModel = nil  // Clear model when filter is selected
                    },
                    onSelectModel: { model in
                        selectedImageModel = model
                        selectedFilter = nil  // Clear filter when model is selected
                    }
                )
            }
            .background(
                photoReviewNavigationLink
            )
        }
    }

    // MARK: COMPUTED PROPERTIES

    private var isFilterOrModelSelected: Bool {
        selectedFilter != nil || selectedImageModel != nil
    }

    private var photoReviewNavigationLink: some View {
        NavigationLink(
            destination: photoReviewDestination,
            isActive: $navigateToPhotoReview
        ) {
            EmptyView()
        }
    }

    private var photoReviewDestination: some View {
        Group {
            if let capturedImage = cameraService.capturedImage {
                if let selectedFilter = selectedFilter {
                    PhotoConfirmationView(
                        item: selectedFilter,
                        image: capturedImage
                    )
                    .onDisappear {
                        // Reset the captured image when the review page is dismissed
                        shouldShowCapturedImage = false
                        cameraService.capturedImage = nil
                    }
                } else if let model = selectedImageModel {
                    ImageModelDetailPageWithPhoto(
                        item: model,
                        capturedImage: capturedImage
                    )
                    .onDisappear {
                        // Reset the captured image when the review page is dismissed
                        shouldShowCapturedImage = false
                        cameraService.capturedImage = nil
                    }
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
                            cameraService.capturedImage = nil
                        }
                    }
                }
            }
        }
    }
}
