import PhotosUI
import SwiftUI

// MARK: - Filter Category

enum FilterCategory: String, CaseIterable, Identifiable {
    case artistic = "Artistic"
    case gaming = "Gaming"
    case creative = "Creative"
    case photography = "Photography"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .artistic: return "paintbrush.fill"
        case .gaming: return "gamecontroller.fill"
        case .creative: return "sparkles"
        case .photography: return "camera.fill"
        }
    }
    
    func matches(_ filter: InfoPacket) -> Bool {
        let title = filter.display.title.lowercased()
        switch self {
        case .artistic:
            return title.contains("anime") || title.contains("watercolor") || title.contains("vangogh") || title.contains("van gogh")
        case .gaming:
            return title.contains("blocky") || title.contains("cyberpunk") || title.contains("futuristic") || title.contains("minecraft")
        case .creative:
            return title.contains("snow globe") || title.contains("felt") || title.contains("polaroid") || title.contains("plastic") || title.contains("bubble") || title.contains("micro landscape") || title.contains("designer toy")
        case .photography:
            return title.contains("low-key") || title.contains("lighting") || title.contains("photography")
        }
    }
}

@MainActor
class PhotoFiltersViewModel: ObservableObject {
    @Published var filters: [InfoPacket] = []
    
    // Quick filters (most popular/common ones)
    var quickFilters: [InfoPacket] {
        let quickFilterTitles = ["Anime", "Watercolor", "Blocky Aesthetic", "Cyberpunk"]
        return filters.filter { quickFilterTitles.contains($0.display.title) }
    }
    
    // Categorized filters
    var categorizedFilters: [FilterCategory: [InfoPacket]] {
        var result: [FilterCategory: [InfoPacket]] = [:]
        for category in FilterCategory.allCases {
            result[category] = filters.filter { category.matches($0) }
        }
        return result
    }

    init() {
        loadFiltersJSON()
    }

    private func loadFiltersJSON() {
        guard let url = Bundle.main.url(forResource: "AllPhotoFilters", withExtension: "json") else {
            print("AllPhotoFilters.json not found in bundle")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([InfoPacket].self, from: data)
            self.filters = decoded
        } catch {
            print("Failed to decode AllPhotoFilters.json: \(error)")
        }
    }
}


struct PhotoFilters: View {
    @StateObject private var viewModel = PhotoFiltersViewModel()
    @State private var selectedFilter: InfoPacket? = nil
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var navigateToConfirmation: Bool = false
    @State private var showPhotoPicker: Bool = false
    @State private var prompt: String = ""

   var body: some View {
       NavigationStack {
           VStack(spacing: 0) {

               ScrollView {
                   PhotoFiltersGrid(
                       filters: viewModel.filters,
                       selectedFilter: selectedFilter,
                       onSelect: { selectedFilter = $0 }
                   )
               }

//               PhotoFiltersBottomBar(
//                   showPhotoPicker: $showPhotoPicker,
//                   selectedPhotoItem: $selectedPhotoItem,
//                   cost: (selectedFilter?.cost as NSDecimalNumber?)?.doubleValue ?? 0.04
//               )
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
                        .fill(Color.secondary.opacity(0.1))
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
       if selectedFilter == nil { selectedFilter = viewModel.filters.first }
   }
}
