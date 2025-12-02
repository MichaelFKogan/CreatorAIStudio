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

                        // Top-right switch camera button
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

                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 0)
                    
                    VStack{
                        HStack{
                            Text("Filter")
                                .font(.caption)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 4)
                        
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
                    
                    // Bottom spacing
                    Color.clear.frame(height: 44)
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
                PhotoReviewView(capturedImage: capturedImage)
                    .onDisappear {
                        // Reset the captured image when the review page is dismissed
                        cameraService.capturedImage = nil
                    }
            }
        }
    }
}
