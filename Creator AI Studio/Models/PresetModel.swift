import Foundation

// MARK: - Preset Model (for app use, similar to InfoPacket)
struct Preset: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let modelName: String?
    let prompt: String?
    let imageUrl: String?
    let created_at: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case modelName = "model_name"
        case prompt
        case imageUrl = "image_url"
        case created_at
    }
    
    init(id: String, title: String, modelName: String?, prompt: String?, imageUrl: String?, created_at: String?) {
        self.id = id
        self.title = title
        self.modelName = modelName
        self.prompt = prompt
        self.imageUrl = imageUrl
        self.created_at = created_at
    }
}

// MARK: - Preset Metadata for Database
struct PresetMetadata: Encodable {
    let user_id: String
    let title: String
    let model_name: String?
    let prompt: String?
    let image_url: String?
    
    init(userId: String, title: String, modelName: String? = nil, prompt: String? = nil, imageUrl: String? = nil) {
        self.user_id = userId
        self.title = title
        self.model_name = modelName
        self.prompt = prompt
        self.image_url = imageUrl
    }
}

// MARK: - Preset Update Metadata for Database
struct PresetUpdateMetadata: Encodable {
    let title: String
    let model_name: String?
    let prompt: String?
    let image_url: String?
    
    init(title: String, modelName: String? = nil, prompt: String? = nil, imageUrl: String? = nil) {
        self.title = title
        self.model_name = modelName
        self.prompt = prompt
        self.image_url = imageUrl
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
        
        // Create a new InfoPacket with the preset's prompt, title, and image
        var infoPacket = matchingModel
        infoPacket.prompt = prompt
        infoPacket.display.title = title // Use preset title instead of model title
        // Use a stable ID based on the preset's ID to ensure selection tracking works
        // Preset IDs from Supabase are UUIDs, so convert the string to UUID
        if let presetUUID = UUID(uuidString: id) {
            infoPacket.id = presetUUID
        } else {
            // Fallback: create a deterministic UUID from the preset ID string hash
            // This ensures the same preset always gets the same UUID for selection tracking
            var hash = id.hashValue
            let uuidString = String(format: "%08x-%04x-%04x-%04x-%012x",
                UInt32(truncatingIfNeeded: hash),
                UInt16(truncatingIfNeeded: hash >> 16),
                UInt16(truncatingIfNeeded: (hash >> 32) & 0xFFFF),
                UInt16(truncatingIfNeeded: ((hash >> 48) & 0x0FFF) | 0x4000),
                UInt64(abs(hash)) % 1000000000000
            )
            infoPacket.id = UUID(uuidString: uuidString) ?? UUID()
        }
        
        // Use the saved user-generated image URL if available, otherwise use model's default image
        if let imageUrl = imageUrl, !imageUrl.isEmpty {
            // Store the image URL in the imageName field so FilterThumbnail can detect it's a URL
            infoPacket.display.imageName = imageUrl
        }
        
        return infoPacket
    }
}
