import PhotosUI
import SwiftUI

// MARK: REFERENCE IMAGE STRUCT

struct ReferenceImagesSection: View {
    @Binding var referenceImages: [UIImage]
    @Binding var selectedPhotoItems: [PhotosPickerItem]
    let color: Color // Add color parameter

    private let columns: [GridItem] = Array(repeating: GridItem(.fixed(100), spacing: 12), count: 3)

    var body: some View {
        let gridWidth = CGFloat(columns.count) * 100 + CGFloat(columns.count - 1) * 12
        
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "photo.on.rectangle")
                    .foregroundColor(color) // Use the color parameter
                Text("Image(s)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }

            Text("Upload an image to transform it, or use as reference with your prompt")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 4)

            LazyVGrid(columns: columns, spacing: 12) {
                // Existing selected reference images
                ForEach(referenceImages.indices, id: \.self) { index in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: referenceImages[index])
                            .resizable()
                            .aspectRatio(contentMode: .fill) // fills the square without warping
                            .frame(width: 100, height: 100) // fixed square size
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .clipped() // crop overflow
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


                // Add images tile
                PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 10, matching: .images) {
                    VStack(spacing: 12) {
                        ZStack(alignment: .bottomTrailing) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 28))
                                .foregroundColor(.gray.opacity(0.5))
                        }
                        VStack(spacing: 4) {
                            Text("Add Images")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.gray)
                            Text("Up to 10")
                                .font(.caption2)
                                .foregroundColor(.gray.opacity(0.7))
                        }
                    }
                    .frame(width: 100, height: 100)
                    .background(Color.gray.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(style: StrokeStyle(lineWidth: 3.5, dash: [6, 4]))
                            .foregroundColor(.gray.opacity(0.4))
                    )
                }
                .onChange(of: selectedPhotoItems) { newItems in
                    Task {
                        var newlyAdded: [UIImage] = []
                        for item in newItems {
                            if let data = try? await item.loadTransferable(type: Data.self),
                               let image = UIImage(data: data)
                            {
                                newlyAdded.append(image)
                            }
                        }
                        referenceImages.append(contentsOf: newlyAdded)
                        selectedPhotoItems.removeAll()
                    }
                }
            }
            .frame(width: gridWidth, alignment: .leading)
        }
        .padding(.horizontal)
    }
}
