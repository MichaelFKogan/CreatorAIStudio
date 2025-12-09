import PhotosUI
import SwiftUI

// MARK: REFERENCE IMAGE STRUCT

struct ReferenceImagesSection: View {
    @Binding var referenceImages: [UIImage]
    @Binding var selectedPhotoItems: [PhotosPickerItem]
    @Binding var showCameraSheet: Bool
    let color: Color

    @State private var showActionSheet: Bool = false

    private let columns: [GridItem] = Array(
        repeating: GridItem(.fixed(115), spacing: 12), count: 3
    )

    var body: some View {
        let gridWidth =
            CGFloat(columns.count) * 115 + CGFloat(columns.count - 1) * 12

        VStack(alignment: .leading, spacing: 8) {
            if referenceImages.isEmpty {
                // Single line button when no images
                Button {
                    showActionSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                        Text("Add Image")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        Text("(Optional)")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.7))
                        Spacer()
                    }
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // Header section when images exist
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle")
                            .foregroundColor(color)
                        Text("Your Photo")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        Spacer()
                    }

                    HStack {
                        Text("Add a prompt to transform your photo.")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.8))
                            .padding(.bottom, 8)

                        Spacer()
                    }
                }
                .padding(.top, -4)

                // Grid layout when images exist
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        LazyVGrid(columns: columns, spacing: 12) {
                            // Existing selected reference images
                            ForEach(referenceImages.indices, id: \.self) {
                                index in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: referenceImages[index])
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 115, height: 160)
                                        .clipShape(
                                            RoundedRectangle(cornerRadius: 6)
                                        )
                                        .clipped()
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(
                                                    color.opacity(0.6),
                                                    lineWidth: 1
                                                )
                                        )

                                    Button(action: {
                                        referenceImages.remove(at: index)
                                    }) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.gray)
                                                .frame(width: 20, height: 20)

                                            Image(systemName: "xmark")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .padding(4)
                                    .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 1)
                                }
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
                            //     .frame(width: 115, height: 160)
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
                        .frame(width: gridWidth, alignment: .leading)

                        Spacer()
                    }
                }
            }
        }
        .padding(.horizontal)
        .sheet(isPresented: $showActionSheet) {
            ImageSourceSelectionSheet(
                showCameraSheet: $showCameraSheet,
                selectedPhotoItems: $selectedPhotoItems,
                showActionSheet: $showActionSheet,
                referenceImages: $referenceImages
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
                            .foregroundColor(.blue)
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
                    maxSelectionCount: 10,
                    matching: .images
                ) {
                    HStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
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
                            var newlyAdded: [UIImage] = []
                            for item in newItems {
                                if let data =
                                    try? await item.loadTransferable(
                                        type: Data.self),
                                    let image = UIImage(data: data)
                                {
                                    newlyAdded.append(image)
                                }
                            }
                            referenceImages.append(contentsOf: newlyAdded)
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
