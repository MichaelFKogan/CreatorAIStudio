//
//  InfoPacketModel.swift
//  Creator AI Studio
//
//  Created by Mike K on 11/24/25.
//

import SwiftUI

struct InfoPacket: Identifiable {
    let id = UUID()

    // Organized by purpose
    var display: DisplayInfo
    var apiConfig: APIConfiguration

    var prompt: String = ""
    var cost: Decimal
    var type: String?
    var capabilities: [String] = []
}

struct DisplayInfo {
    var title: String
    var imageName: String

    var imageNameOriginal: String?
    var description: String = ""
    var modelName: String = ""
    var modelDescription: String = ""
    var modelImageName: String = ""
    var exampleImages: [String] = []
    var moreStyles: [[InfoPacket]] = []
}

struct APIConfiguration {
    var endpoint: String
    var outputFormat: String = ""
    var enableSyncMode: Bool = false
    var enableBase64Output: Bool = false
    var aspectRatio: String?
}
