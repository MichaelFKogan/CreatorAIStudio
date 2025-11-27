import PhotosUI
import SwiftUI

struct PhotoFilters: View {
    @State private var prompt: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showPhotoPicker: Bool = false
    @State private var selectedFilter: InfoPacket? = nil
    @State private var selectedImage: UIImage?
    @State private var navigateToConfirmation: Bool = false

    let filters = AllPhotoFilters.filters

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                ScrollView {
                    PhotoFiltersGrid(
                        filters: filters,
                        selectedFilter: selectedFilter,
                        onSelect: { selectedFilter = $0 }
                    )
                }

                PhotoFiltersBottomBar(
                    showPhotoPicker: $showPhotoPicker,
                    selectedPhotoItem: $selectedPhotoItem,
                    cost: (selectedFilter?.cost as NSDecimalNumber?)?.doubleValue ?? 0.04
                )
            }

            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Photo Filters")
                        .font(
                            .system(size: 28, weight: .bold, design: .rounded)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .teal],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 6) {
                        Image(systemName: "diamond.fill")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.teal, .teal],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .font(.system(size: 8))
                        Text("$5.00")
                            .font(
                                .system(
                                    size: 14, weight: .semibold,
                                    design: .rounded
                                )
                            )
                            .foregroundColor(.white)
                        Text("credits left")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.4))
                            .shadow(
                                color: Color.black.opacity(0.2), radius: 4,
                                x: 0, y: 2
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.mint, .mint],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                }
            }

            NavigationLink(
                destination: destinationView,
                isActive: $navigateToConfirmation,
                label: { EmptyView() }
            )
        }
        .onChange(of: selectedPhotoItem, perform: loadPhoto)
        .onAppear(perform: setDefaultFilter)
    }

    @ViewBuilder
    private var destinationView: some View {
        if let image = selectedImage, let filter = selectedFilter {
            EmptyView() // Replace w/ PhotoConfirmationView
        } else {
            EmptyView()
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        Task {
            guard let data = try? await item?.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else { return }

            await MainActor.run { selectedImage = uiImage }
            try? await Task.sleep(nanoseconds: 100_000_000)

            await MainActor.run { navigateToConfirmation = true }
        }
    }

    private func setDefaultFilter() {
        if selectedFilter == nil { selectedFilter = filters.first }
    }
}
