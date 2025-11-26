//import Combine
//import SwiftUI
//
//class ImageModelsViewModel: ObservableObject {
//    // MARK: - Published properties
//
//    @Published var imageFilterIndex: Int = 0 {
//        didSet { updateModels() }
//    }
//
//    @Published var sortOrder: Int = 0 { // 0 = default, 1 = low->high, 2 = high->low
//        didSet { updateModels() }
//    }
//
//    @Published private(set) var filteredAndSortedImageModels: [InfoPacket] = []
//
//    // MARK: - Data source
//
//    private let allModels: [InfoPacket]
//
//    // MARK: - Init
//
//    init(models: [InfoPacket]) {
//        allModels = models
//        updateModels() // 👈 CRITICAL! Make sure initial list goes through filters & sorting
//    }
//
//    // MARK: - Filtering & Sorting
//
//    private func imageCapabilities(for model: InfoPacket) -> [String] {
//        model.capabilities
//    }
//
//    func updateModels() {
//        var models = allModels
//
//        // Apply category filter
//        switch imageFilterIndex {
//        case 1:
//            models = models.filter { imageCapabilities(for: $0).contains("Text to Image") }
//        case 2:
//            models = models.filter { imageCapabilities(for: $0).contains("Image to Image") }
//        default:
//            break
//        }
//
//        // Apply sort
//        switch sortOrder {
//        case 1:
//            models.sort { $0.cost < $1.cost }
//        case 2:
//            models.sort { $0.cost > $1.cost }
//        default:
//            break
//        }
//
//        filteredAndSortedImageModels = models
//    }
//
//    func clearFilters() {
//        imageFilterIndex = 0
//        sortOrder = 0
//    }
//}
