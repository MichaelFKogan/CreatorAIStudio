import AVFoundation
import SwiftUI
import UIKit

// MARK: - Processing Mode

enum ProcessingMode {
    case photoFilter
    case imageModel
}

// MARK: - CameraButtonView

struct Post: View {
    @StateObject private var cameraService = CameraService()
    @State private var selectedUIImage: UIImage?
    @State private var showLibraryPicker = false
    @State private var navigateToPhotoReview = false

    @StateObject private var filtersViewModel = PhotoFiltersViewModel()
    @State private var selectedFilter: InfoPacket?
    @State private var showFilterCategorySheet = false

    // Image Model mode state
    @State private var selectedMode: ProcessingMode = .photoFilter
    @State private var selectedImageModel: InfoPacket?
    @State private var showImageModelSelectionSheet = false

    var body: some View {
        NavigationView {
            ZStack {
                // Black background
                Color.black.ignoresSafeArea()

                if let captured = cameraService.capturedImage {
                    // Show captured photo fullscreen
                    Image(uiImage: captured)
                        .resizable()
                        .scaledToFill()

                } else {
                    // Live camera preview
                    CameraPreview(session: cameraService.session, position: cameraService.cameraPosition)
                }

                // Camera controls (your existing VStack with ❌ / ✅ or capture button)
                VStack {
                    Spacer()

//                    if cameraService.capturedImage == nil {
                    // Library + capture button
                    HStack(spacing: 24) {
                        Spacer()

                        // Photo Library Picker
                        Button {
                            showLibraryPicker = true
                        } label: {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 25))
                                .padding(12)
                                .foregroundColor(.white).opacity(0.8)
                                .cornerRadius(8)
                                .shadow(radius: 3)
                        }

                        // Capture Photo Button
                        Button {
                            cameraService.capturePhoto()
                        } label: {
                            Circle()
                                .stroke(Color.white, lineWidth: 5)
                                .frame(width: 80, height: 80)
                        }

                        // Switch camera button and vertical mode switcher
                        HStack(spacing: 12) {
                            // Switch camera button
                            Button {
                                cameraService.switchCamera()
                            } label: {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 26))
                                    .padding(12)
                                    .foregroundColor(.white)
                                    .opacity(0.7)
                                    .clipShape(Circle())
                                    .shadow(radius: 3)
                            }
                            .accessibilityLabel("Switch camera")

                            // Vertical mode switcher
                            VStack(spacing: 8) {
                                // Photo Filter button
                                Button {
                                    selectedMode = .photoFilter
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: "camera.filters")
                                            .font(.system(size: 20))
                                        Text("Filter")
                                            .font(.system(size: 10, weight: .medium))
                                    }
                                    .foregroundColor(selectedMode == .photoFilter ? .white : .white.opacity(0.6))
                                    .frame(width: 50, height: 50)
                                    .background(
                                        selectedMode == .photoFilter
                                            ? Color.white.opacity(0.25)
                                            : Color.white.opacity(0.1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(
                                                selectedMode == .photoFilter
                                                    ? Color.white.opacity(0.5)
                                                    : Color.white.opacity(0.2),
                                                lineWidth: selectedMode == .photoFilter ? 2 : 1
                                            )
                                    )
                                }

                                // Image Model button
                                Button {
                                    selectedMode = .imageModel
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: "cpu")
                                            .font(.system(size: 20))
                                        Text("Model")
                                            .font(.system(size: 10, weight: .medium))
                                    }
                                    .foregroundColor(selectedMode == .imageModel ? .white : .white.opacity(0.6))
                                    .frame(width: 50, height: 50)
                                    .background(
                                        selectedMode == .imageModel
                                            ? Color.white.opacity(0.25)
                                            : Color.white.opacity(0.1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(
                                                selectedMode == .imageModel
                                                    ? Color.white.opacity(0.5)
                                                    : Color.white.opacity(0.2),
                                                lineWidth: selectedMode == .imageModel ? 2 : 1
                                            )
                                    )
                                }
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 0)

                    // Conditional bottom section based on mode
                    if selectedMode == .photoFilter {
                        VStack {
                            HStack {
                                Text("Filter")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal)

                            // Quick filters row with "See All" button
                            QuickFiltersRow(
                                quickFilters: filtersViewModel.quickFilters,
                                selectedFilter: selectedFilter,
                                onSelect: { selectedFilter = $0 },
                                onShowAll: { showFilterCategorySheet = true }
                            )
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 18)
                        .background(Color.black)
                    } else {
                        // Image Model selection
                        VStack {
                            HStack {
                                Text("Image Model")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal)

                            Button {
                                showImageModelSelectionSheet = true
                            } label: {
                                HStack(spacing: 12) {
                                    if let selectedModel = selectedImageModel {
                                        Image(selectedModel.display.imageName)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 50, height: 50)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))

                                        Text(selectedModel.display.title)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                    } else {
                                        Image(systemName: "square.grid.2x2")
                                            .font(.system(size: 24, weight: .medium))
                                            .foregroundColor(.white.opacity(0.8))

                                        Text("Select Model")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .padding(.horizontal, 12)
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 18)
                        .background(Color.black)
                    }

                    // Bottom spacing
                    Color.clear.frame(height: 70)
                }
            }

            .onAppear {
                cameraService.startSession()
            }
            .onDisappear {
                cameraService.stopSession()
            }
            .onChange(of: cameraService.capturedImage) { newImage in
                if newImage != nil {
                    navigateToPhotoReview = true
                }
            }
            .sheet(isPresented: $showLibraryPicker) {
                PhotoLibraryPickerView(isPresented: $showLibraryPicker, selectedImage: $cameraService.capturedImage)
            }
            .sheet(isPresented: $showFilterCategorySheet) {
                FilterCategorySheet(
                    isPresented: $showFilterCategorySheet,
                    categorizedFilters: filtersViewModel.categorizedFilters,
                    allFilters: filtersViewModel.filters,
                    selectedFilter: $selectedFilter,
                    onSelect: { selectedFilter = $0 }
                )
            }
            .sheet(isPresented: $showImageModelSelectionSheet) {
                ImageModelSelectionSheet(
                    isPresented: $showImageModelSelectionSheet,
                    selectedModel: $selectedImageModel
                )
            }
            .background(
                photoReviewNavigationLink
            )
        }
    }

    // MARK: - Computed Properties

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
                if selectedMode == .photoFilter {
                    PhotoReviewView(capturedImage: capturedImage)
                        .onDisappear {
                            // Reset the captured image when the review page is dismissed
                            cameraService.capturedImage = nil
                        }
                } else if let model = selectedImageModel {
                    ImageModelDetailPageWithPhoto(
                        item: model,
                        capturedImage: capturedImage
                    )
                    .onDisappear {
                        // Reset the captured image when the review page is dismissed
                        cameraService.capturedImage = nil
                    }
                } else {
                    // If no model selected, show a message or go back
                    VStack {
                        Text("Please select an Image Model first")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                    .onAppear {
                        // Auto-dismiss after a moment if no model selected
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
