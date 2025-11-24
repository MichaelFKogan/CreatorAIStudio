import SwiftUI

struct AspectRatioOption: Identifiable {
    let id: String
    let label: String
    let width: CGFloat
    let height: CGFloat
    let platforms: [String]
}

// MARK: ASPECT RATIO STRUCT

struct AspectRatioSelector: View {
    let options: [AspectRatioOption]
    @Binding var selectedIndex: Int
    let color: Color // Add color parameter

    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(options.indices, id: \.self) { idx in
                let option = options[idx]
                let isSelected = idx == selectedIndex
                Button {
                    selectedIndex = idx
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.08))
                            // Preview shape maintaining aspect ratio
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isSelected ? color : Color.gray.opacity(0.5), lineWidth: isSelected ? 2 : 1) // Use color parameter
                                .aspectRatio(option.width / option.height, contentMode: .fit)
                                .frame(height: 36)
                                .padding(8)
                        }
                        .frame(height: 60)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(option.label)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(color) // Use color parameter
                                }
                            }
                            .padding(.horizontal, 5)

                            // Platform recommendations (first 1 shown)
                            if !option.platforms.isEmpty {
                                HStack(spacing: 4) {
                                    ForEach(option.platforms.prefix(1), id: \.self) { platform in
                                        Text(platform)
                                            .font(.caption2)
                                            .foregroundColor(color) // Use color parameter
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(color.opacity(0.12)) // Use color parameter
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.bottom, 6)
                    }
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? color : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1) // Use color parameter
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
