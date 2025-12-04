import SwiftUI

// MARK: - Image Models Row

struct ImageModelsRow: View {
    let imageModels: [InfoPacket]
    let selectedModel: InfoPacket?
    let onSelect: (InfoPacket) -> Void
    let onShowAll: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // "See All" button
                Button {
                    onShowAll()
                } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.purple.opacity(0.3), Color.pink.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 70, height: 70)

                            Image(systemName: "chevron.up")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )

                        Text("See All")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .frame(width: 70)
                    }
                }

                // Image model thumbnails
                ForEach(imageModels) { model in
                    FilterThumbnailCompact(
                        title: model.display.title,
                        imageName: model.display.imageName,
                        isSelected: selectedModel?.id == model.id
                    )
                    .onTapGesture {
                        onSelect(model)
                    }
                }
            }
            .padding(.horizontal, 12)
        }
    }
}

