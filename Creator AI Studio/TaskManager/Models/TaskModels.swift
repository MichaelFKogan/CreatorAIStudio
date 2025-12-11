import SwiftUI

// MARK: - Generation Task Info
/// Tracks information about an active generation task
struct GenerationTaskInfo {
    let taskId: UUID
    let notificationId: UUID
    var generatedImage: UIImage?
    let item: InfoPacket? // Stored for retry functionality
    let originalImage: UIImage? // Stored for retry functionality
    let userId: String? // Stored for retry functionality
}

// MARK: - Task Result
/// Result of a media generation task
enum TaskResult {
    case imageSuccess(UIImage, url: String)
    case videoSuccess(videoUrl: String)
    case failure(Error)
}

// MARK: - Task Progress
/// Progress update information
struct TaskProgress {
    let progress: Double  // 0.0 to 1.0
    let message: String
}

