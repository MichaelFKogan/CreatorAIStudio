import SwiftUI

// MARK: - Media Generation Task Protocol
/// Protocol defining the interface for all media generation tasks
protocol MediaGenerationTask {
    /// Execute the generation task
    /// - Parameters:
    ///   - notificationId: The notification ID to update progress
    ///   - onProgress: Callback for progress updates
    ///   - onComplete: Callback when task completes
    func execute(
        notificationId: UUID,
        onProgress: @escaping (TaskProgress) async -> Void,
        onComplete: @escaping (TaskResult) async -> Void
    ) async
}

