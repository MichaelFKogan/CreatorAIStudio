import Foundation

// MARK: - Preset Model (for app use, similar to InfoPacket)
struct Preset: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let modelName: String?
    let prompt: String?
    let created_at: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case modelName = "model_name"
        case prompt
        case created_at
    }
}

// MARK: - Preset Metadata for Database
struct PresetMetadata: Encodable {
    let user_id: String
    let title: String
    let model_name: String?
    let prompt: String?
    
    init(userId: String, title: String, modelName: String? = nil, prompt: String? = nil) {
        self.user_id = userId
        self.title = title
        self.model_name = modelName
        self.prompt = prompt
    }
}

// MARK: - Preset to InfoPacket Conversion
extension Preset {
    /// Converts a Preset to InfoPacket format for use with existing filter system
    /// - Parameter allModels: Array of all available image models
    /// - Returns: InfoPacket if matching model is found, nil otherwise
    func toInfoPacket(allModels: [InfoPacket]) -> InfoPacket? {
        guard let modelName = modelName, !modelName.isEmpty else {
            return nil
        }
        
        // Find the matching image model
        guard let matchingModel = allModels.first(where: { $0.display.title == modelName }) else {
            print("⚠️ [Preset] Could not find matching model for preset '\(title)' with model name '\(modelName)'")
            return nil
        }
        
        // Create a new InfoPacket with the preset's prompt and title
        var infoPacket = matchingModel
        infoPacket.prompt = prompt
        infoPacket.display.title = title // Use preset title instead of model title
        infoPacket.id = UUID() // Generate new ID so it's unique
        
        return infoPacket
    }
}
