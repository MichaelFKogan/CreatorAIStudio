// Required: 
    // Title 
    // ImageName
    // Provider
    // Endpoint


import SwiftUI

struct InfoPacket: Codable, Identifiable {
    var id: UUID = UUID()
    var display: DisplayInfo
    var apiConfig: APIConfiguration
    var prompt: String?
    var cost: Decimal?
    var type: String?
    var capabilities: [String]?

    
    // Tell the decoder to ignore 'id'
    enum CodingKeys: String, CodingKey {
        case display, apiConfig, prompt, cost, type, capabilities
        // Notice: 'id' is NOT listed here
    }
}

struct DisplayInfo: Codable {
    var title: String
    var imageName: String
    var imageNameOriginal: String?
    var description: String?
    var modelName: String?
    var modelDescription: String?
    var modelImageName: String?
    var exampleImages: [String]?
}

struct APIConfiguration: Codable {
    var provider: APIProvider
    var endpoint: String
    var runwareModel: String?
    
    var outputFormat: String?
    var enableSyncMode: Bool?
    var enableBase64Output: Bool?
    var aspectRatio: String?
}

enum APIProvider: String, Codable {
    case wavespeed
    case runware
}

