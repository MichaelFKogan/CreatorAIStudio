import AVFoundation
import SwiftUI
import UIKit

// MARK: - CameraSheetView
// A simplified camera view that can be presented as a sheet and returns captured image via callback
struct CameraSheetView: View {
    @StateObject private var cameraService = CameraService()
    @Environment(\.dismiss) var dismiss
    @State private var showLibraryPicker = false
    
    let onImageCaptured: (UIImage) -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                // Black background
                Color.black.ignoresSafeArea()
                
                if let captured = cameraService.capturedImage {
                    // Show captured photo fullscreen with accept/cancel buttons
                    ZStack {
                        Image(uiImage: captured)
                            .resizable()
                            .scaledToFill()
                            .ignoresSafeArea()
                        
                        VStack {
                            Spacer()
                            
                            HStack(spacing: 24) {
                                // Cancel button
                                Button {
                                    cameraService.capturedImage = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(.white)
                                        .background(Circle().fill(Color.black.opacity(0.3)))
                                }
                                
                                Spacer()
                                
                                // Accept button
                                Button {
                                    onImageCaptured(captured)
                                    dismiss()
                                } label: {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(.white)
                                        .background(Circle().fill(Color.black.opacity(0.3)))
                                }
                            }
                            .padding(.horizontal, 40)
                            .padding(.bottom, 60)
                        }
                    }
                } else {
                    // Live camera preview
                    CameraPreview(session: cameraService.session, position: cameraService.cameraPosition)
                    
                    // Camera controls
                    VStack {
                        Spacer()
                        
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
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 0)
                        
                        // Bottom spacing
                        Color.clear.frame(height: 60)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .sheet(isPresented: $showLibraryPicker) {
                PhotoLibraryPickerView(isPresented: $showLibraryPicker, selectedImage: $cameraService.capturedImage)
            }
        }
        .onAppear {
            cameraService.startSession()
        }
        .onDisappear {
            cameraService.stopSession()
        }
    }
}

