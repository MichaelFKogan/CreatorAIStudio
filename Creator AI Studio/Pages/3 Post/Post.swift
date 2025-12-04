import AVFoundation
import SwiftUI
import UIKit

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
    @StateObject private var imageModelsViewModel = ImageModelsViewModel()
    @State private var selectedImageModel: InfoPacket?

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
                    CameraPreview(
                        session: cameraService.session,
                        position: cameraService.cameraPosition
                    )
                }

                // Camera controls
                VStack {
                    Spacer()

                    // Control buttons row
                    HStack {
                        // Left side: Filter button
                        HStack {
                            Spacer()

                            // MARK: FILTER/MODEL SELECTION BUTTON

                            Button {
                                showFilterCategorySheet = true
                            } label: {
                                Group {
                                    if let selectedFilter = selectedFilter {
                                        // Show selected filter thumbnail
                                        Image(selectedFilter.display.imageName)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 65, height: 65)
                                            .clipped()
                                            .cornerRadius(10)
                                            .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 0)
                                    } else if let selectedModel = selectedImageModel {
                                        // Show selected model thumbnail
                                        Image(selectedModel.display.imageName)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 65, height: 65)
                                            .clipped()
                                            .cornerRadius(10)
                                            .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 0)
                                    } else {
                                        // Placeholder when nothing is selected
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [Color.purple.opacity(0.3), Color.pink.opacity(0.3)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 55, height: 55)

                                            Image(systemName: "square.grid.2x2")
                                                .font(.system(size: 22, weight: .medium))
                                                .foregroundColor(.white)
                                        }
                                        .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 0)
                                    }
                                }
                            }
                            .frame(width: 65, height: 65)
                            .padding(.trailing, 24)
                        }
                        .frame(maxWidth: .infinity)

                        // Center: Capture button
                        // MARK: CAPTURE BUTTON

                        Button {
                            cameraService.capturePhoto()
                        } label: {
                            Circle()
                                .stroke(Color.white, lineWidth: 5)
                                .frame(width: 80, height: 80)
                        }

                        // Right side: Photo library and switch camera buttons
                        HStack {
                            // MARK: PHOTO LIBRARY BUTTON

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
                            .frame(width: 50, height: 50)
                            .padding(.leading, 12)

                            // MARK: SWITCH CAMERA BUTTON

                            Button {
                                cameraService.switchCamera()
                            } label: {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 25))
                                    .padding(12)
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
                    .padding(.trailing, 8)
                    .safeAreaInset(edge: .bottom) {
                        Color.clear.frame(height: 57) // 12 + 45 for tab bar
                    }
                    .padding(.bottom, 12)
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
                    imageModels: imageModelsViewModel.filteredAndSortedImageModels,
                    selectedFilter: $selectedFilter,
                    selectedImageModel: $selectedImageModel,
                    onSelect: { filter in
                        selectedFilter = filter
                        selectedImageModel = nil // Clear model when filter is selected
                    },
                    onSelectModel: { model in
                        selectedImageModel = model
                        selectedFilter = nil // Clear filter when model is selected
                    }
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
                if let selectedFilter = selectedFilter {
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
