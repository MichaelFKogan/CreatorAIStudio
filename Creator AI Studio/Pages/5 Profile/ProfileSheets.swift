import SwiftUI

// MARK: - IMAGE MODELS SHEET

struct ImageModelsSheet: View {
    let models: [(model: String, count: Int, imageName: String)]
    @Binding var selectedModel: String?
    @Binding var selectedVideoModel: String?
    @Binding var selectedTab: ProfileViewContent.GalleryTab
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(models, id: \.model) { modelData in
                        Button {
                            selectedTab = .imageModels
                            selectedModel = modelData.model
                            selectedVideoModel = nil  // Clear video model selection
                            isPresented = false
                        } label: {
                            HStack(spacing: 12) {
                                // Model image with fallback
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 65, height: 65)

                                    Image(modelData.imageName)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 65, height: 65)
                                        .clipShape(
                                            RoundedRectangle(cornerRadius: 8))
                                }
                                .frame(width: 65, height: 65)

                                // Model name and count
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(modelData.model)
                                        .font(
                                            .system(
                                                size: 15, weight: .bold,
                                                design: .rounded)
                                        )
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(2)

                                    Text(
                                        "\(modelData.count) image\(modelData.count == 1 ? "" : "s")"
                                    )
                                    .font(
                                        .system(
                                            size: 12, weight: .medium,
                                            design: .rounded)
                                    )
                                    .foregroundColor(.blue)
                                }

                                Spacer()

                                // Checkmark if selected
                                if selectedTab == .imageModels
                                    && selectedModel == modelData.model
                                {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(12)
                            .background(
                                selectedTab == .imageModels
                                    && selectedModel == modelData.model
                                    ? Color.blue.opacity(0.08)
                                    : Color.gray.opacity(0.06)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        selectedTab == .imageModels
                                            && selectedModel == modelData.model
                                            ? Color.blue.opacity(0.3)
                                            : Color.gray.opacity(0.2),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Image Models")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - VIDEO MODELS SHEET

struct VideoModelsSheet: View {
    let models: [(model: String, count: Int, imageName: String)]
    @Binding var selectedModel: String?
    @Binding var selectedVideoModel: String?
    @Binding var selectedTab: ProfileViewContent.GalleryTab
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(models, id: \.model) { modelData in
                        Button {
                            selectedTab = .videoModels
                            selectedVideoModel = modelData.model
                            selectedModel = nil  // Clear image model selection
                            isPresented = false
                        } label: {
                            HStack(spacing: 12) {
                                // Model image with fallback
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 65, height: 65)

                                    Image(modelData.imageName)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 65, height: 65)
                                        .clipShape(
                                            RoundedRectangle(cornerRadius: 8))
                                }
                                .frame(width: 65, height: 65)

                                // Model name and count
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(modelData.model)
                                        .font(
                                            .system(
                                                size: 15, weight: .bold,
                                                design: .rounded)
                                        )
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(2)

                                    Text(
                                        "\(modelData.count) video\(modelData.count == 1 ? "" : "s")"
                                    )
                                    .font(
                                        .system(
                                            size: 12, weight: .medium,
                                            design: .rounded)
                                    )
                                    .foregroundColor(.purple)
                                }

                                Spacer()

                                // Checkmark if selected
                                if selectedTab == .videoModels
                                    && selectedVideoModel == modelData.model
                                {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.purple)
                                }
                            }
                            .padding(12)
                            .background(
                                selectedTab == .videoModels
                                    && selectedVideoModel == modelData.model
                                    ? Color.purple.opacity(0.08)
                                    : Color.gray.opacity(0.06)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        selectedTab == .videoModels
                                            && selectedVideoModel
                                                == modelData.model
                                            ? Color.purple.opacity(0.3)
                                            : Color.gray.opacity(0.2),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Video Models")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

