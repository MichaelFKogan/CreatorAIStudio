import PhotosUI
import SwiftUI

// MARK: REFERENCE IMAGE STRUCT

struct ReferenceImagesSection: View {
    @Binding var referenceImages: [UIImage]
    @Binding var selectedPhotoItems: [PhotosPickerItem]
    @Binding var showCameraSheet: Bool
    let color: Color
    var disclaimer: String? = nil  // Optional disclaimer text

    @State private var showActionSheet: Bool = false

    private let columns: [GridItem] = Array(
        repeating: GridItem(.flexible(), spacing: 12), count: 3
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if referenceImages.isEmpty {
                // Square button with dashed border when no images
                // Calculate square size to match grid items (3 columns with spacing)
                let screenWidth = UIScreen.main.bounds.width
                let horizontalPadding: CGFloat = 16
                let gridSpacing: CGFloat = 12
                let availableWidth = screenWidth - (horizontalPadding * 2)
                let squareSize = (availableWidth - (gridSpacing * 2)) / 3
                
                HStack(alignment: .top, spacing: 12) {
                    // Add Image button on the left
                    Button {
                        showActionSheet = true
                    } label: {
                        VStack(spacing: 12) {
                            Image(systemName: "camera")
                                .font(.system(size: 28))
                                .foregroundColor(.gray.opacity(0.5))
                            VStack(spacing: 4) {
                                Text("Add Image")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.gray)
                                // Text("(Optional)")
                                //     .font(.caption2)
                                //     .foregroundColor(.gray.opacity(0.7))
                            }
                        }
                        .frame(width: squareSize, height: squareSize)
                        .background(Color.gray.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    style: StrokeStyle(lineWidth: 3.5, dash: [6, 4])
                                )
                                .foregroundColor(.gray.opacity(0.4))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Disclaimer on the right if provided
                    if let disclaimer = disclaimer {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.orange)
                                .padding(.top, 2) // Align icon to top
                            Text(disclaimer)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    } else {
                        // Spacer to push Add Image button to the left when no disclaimer
                        Spacer()
                    }
                }
            } else {
                // // Header section when images exist
                // VStack(spacing: 8) {
                //     HStack(spacing: 6) {
                //         Image(systemName: "photo.on.rectangle")
                //             .foregroundColor(color)
                //         Text("Your Photo")
                //             .font(.subheadline)
                //             .fontWeight(.semibold)
                //             .foregroundColor(.secondary)

                //         Spacer()
                //     }

                //     HStack {
                //         Text("Add a prompt to transform your photo.")
                //             .font(.caption)
                //             .foregroundColor(.secondary.opacity(0.8))
                //             .padding(.bottom, 8)

                //         Spacer()
                //     }
                // }
                // .padding(.top, -4)

                // Grid layout when images exist - responsive to screen width
                LazyVGrid(columns: columns, spacing: 12) {
                    // Existing selected reference images
                    ForEach(referenceImages.indices, id: \.self) { index in
                        GeometryReader { geometry in
                            let squareSize = geometry.size.width
                            
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: referenceImages[index])
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: squareSize, height: squareSize)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(color.opacity(0.6), lineWidth: 1)
                                    )

                                Button(action: { referenceImages.remove(at: index) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.white)
                                        .background(Circle().fill(Color.red))
                                }
                                .padding(6)
                            }
                        }
                        .aspectRatio(1, contentMode: .fit)
                    }

                    // // Grid-sized add button
                    // Button {
                    //     showActionSheet = true
                    // } label: {
                    //     VStack(spacing: 8) {
                    //         Image(systemName: "camera")
                    //             .font(.system(size: 26))
                    //             .foregroundColor(.gray.opacity(0.6))
                    //         Text("Add Images")
                    //             .font(.subheadline)
                    //             .fontWeight(.medium)
                    //             .foregroundColor(.gray)
                    //         Text("Camera or Gallery")
                    //             .font(.caption)
                    //             .foregroundColor(.gray.opacity(0.7))
                    //     }
                    //     .frame(maxWidth: .infinity)
                    //     .aspectRatio(115.0 / 160.0, contentMode: .fit)
                    //     .background(Color.gray.opacity(0.03))
                    //     .clipShape(RoundedRectangle(cornerRadius: 6))
                    //     .overlay(
                    //         RoundedRectangle(cornerRadius: 6)
                    //             .strokeBorder(
                    //                 style: StrokeStyle(
                    //                     lineWidth: 3.5, dash: [6, 4]
                    //                 )
                    //             )
                    //             .foregroundColor(.gray.opacity(0.4))
                    //     )
                    // }
                    // .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.horizontal)
        .sheet(isPresented: $showActionSheet) {
            ImageSourceSelectionSheet(
                showCameraSheet: $showCameraSheet,
                selectedPhotoItems: $selectedPhotoItems,
                showActionSheet: $showActionSheet,
                referenceImages: $referenceImages,
                color: color
            )
        }
    }
}

// MARK: - Image Source Selection Sheet

struct ImageSourceSelectionSheet: View {
    @Binding var showCameraSheet: Bool
    @Binding var selectedPhotoItems: [PhotosPickerItem]
    @Binding var showActionSheet: Bool
    @Binding var referenceImages: [UIImage]
    let color: Color
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Button {
                    showActionSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showCameraSheet = true
                    }
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 24))
                            .foregroundColor(color)
                            .frame(width: 40)
                        Text("Camera")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PlainButtonStyle())

                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 1,
                    matching: .images
                ) {
                    HStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 24))
                            .foregroundColor(color)
                            .frame(width: 40)
                        Text("Gallery")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PlainButtonStyle())
                .onChange(of: selectedPhotoItems) { newItems in
                    if !newItems.isEmpty {
                        Task {
                            // Only take the first image (limit to 1)
                            if let firstItem = newItems.first,
                               let data = try? await firstItem.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                // Replace existing images with the new one (limit to 1)
                                referenceImages = [image]
                            }
                            selectedPhotoItems.removeAll()
                            showActionSheet = false
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Add Images")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        showActionSheet = false
                    }
                }
            }
        }
        .presentationDetents([.height(250)])
    }
}
