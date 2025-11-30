import AVFoundation
import SwiftUI
import UIKit

// MARK: - CameraButtonView

struct Post: View {
    @StateObject private var cameraService = CameraService()
    @State private var selectedUIImage: UIImage?
    @State private var showLibraryPicker = false
    @State private var navigateToPhotoReview = false

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
                    
                    // Bottom spacing
                    Color.clear.frame(height: 60)
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

// MARK: - StyleSelectionButton Component

struct StyleSelectionButtonTwo: View {
    let title: String
    let icon: String
    let description: String
    let backgroundImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        VStack {
            Button(action: action) {
                ZStack(alignment: .topTrailing) {
                    // Background image - no extra container
                    Image(backgroundImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipped()

                    // Clean content layout
                    VStack(alignment: .leading, spacing: 6) {
                        // Checkmark in top left
                        if isSelected {
                            HStack {
                                ZStack {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.accentColor)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            Spacer()
                        }
                    }
                    .padding(2)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            isSelected ? Color.accentColor : Color.gray.opacity(0.3),
                            lineWidth: isSelected ? 3 : 1
                        )
                )
                .shadow(color: isSelected ? .accentColor.opacity(0.3) : .black.opacity(0.1), radius: isSelected ? 8 : 4, x: 0, y: 2)
                .animation(.easeInOut(duration: 0.2), value: isSelected)
            }
            .padding(.vertical, 2)
            .buttonStyle(PlainButtonStyle())

            // Clean content layout
            VStack(alignment: .leading) {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.primary.opacity(0.95))
                    .lineLimit(2)
            }
        }
    }
}
