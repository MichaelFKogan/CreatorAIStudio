import SwiftUI

// MARK: - Coordinator that manages all video generation tasks.

// This acts as a central controller for starting tasks, tracking progress,
// updating notifications, handling results, and cleaning up.
@MainActor
class VideoGenerationCoordinator: ObservableObject {
    // Singleton instance so the entire app uses one shared coordinator.
    static let shared = VideoGenerationCoordinator()

    // Stores metadata about each task (notification ID, generated video, etc.)
    // Used for UI state or worker tracking.
    @Published var generationTasks: [UUID: GenerationTaskInfo] = [:]
    
    // Stores the actual Swift concurrency background tasks so they can be cancelled.
    var backgroundTasks: [UUID: Task<Void, Never>] = [:]

    // Private so outside code cannot create additional coordinators.
    private init() {}

    // MARK: - Starts a video generation request.

    // Creates an ID, shows a notification, runs the generation task in the background,
    // and wires up all callbacks and progress handlers.
    func startVideoGeneration(
        item: InfoPacket,
        image: UIImage?,
        userId: String,
        duration: Double,
        aspectRatio: String,
        resolution: String? = nil,
        generateAudio: Bool? = nil,
        firstFrameImage: UIImage? = nil,
        lastFrameImage: UIImage? = nil,
        onVideoGenerated: @escaping (String) -> Void = { _ in },
        onError: @escaping (Error) -> Void = { _ in }
    ) -> UUID {
        // A unique identifier for this generation job.
        let taskId = UUID()

        // Get model name for notification (use modelName if available, otherwise use title)
        let modelName = item.display.modelName ?? item.display.title
        
        // Use the provided image or create a placeholder
        let thumbnailImage = image ?? createPlaceholderImage()
        
        // Create a notification to show progress to the user.
        let notificationId = NotificationManager.shared.showNotification(
            title: "Creating Your Video",
            message: "Generating your \(item.display.title)...",
            progress: 0.0,
            thumbnailImage: thumbnailImage,
            taskId: taskId,
            modelName: modelName,
            prompt: item.prompt,
            originalImage: thumbnailImage
        )

        // Save initial task state before the process begins (including retry info).
        generationTasks[taskId] = GenerationTaskInfo(
            taskId: taskId,
            notificationId: notificationId,
            generatedImage: nil,
            item: item,
            originalImage: thumbnailImage,
            userId: userId
        )

        // Create the worker that actually performs the API call / processing.
        let task = VideoGenerationTask(
            item: item,
            image: image,
            userId: userId,
            duration: duration,
            aspectRatio: aspectRatio,
            resolution: resolution,
            generateAudio: generateAudio,
            firstFrameImage: firstFrameImage,
            lastFrameImage: lastFrameImage,
            useWebhook: true
        )

        // MARK: Run the worker on a background thread using Swift concurrency.

        // This ensures the UI stays smooth and doesn't block.
        let backgroundTask = Task.detached { [weak self] in
            await task.execute(
                notificationId: notificationId,

                // Called repeatedly while progress updates occur.
                onProgress: { progress in
                    await NotificationManager.shared.updateProgress(progress.progress, for: notificationId)
                    await NotificationManager.shared.updateMessage(progress.message, for: notificationId)
                },

                // Called once the task returns a success or failure.
                onComplete: { result in
                    await self?.handleCompletion(
                        taskId: taskId,
                        notificationId: notificationId,
                        result: result,
                        onVideoGenerated: onVideoGenerated,
                        onError: onError
                    )
                }
            )
        }

        // Store a reference so we can cancel it later if needed.
        backgroundTasks[taskId] = backgroundTask
        return taskId
    }

    // MARK: - Handles the final result of the generation task.

    // Updates state, calls completion handlers, updates the notification,
    // and schedules cleanup.
    private func handleCompletion(
        taskId: UUID,
        notificationId: UUID,
        result: TaskResult,
        onVideoGenerated: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        switch result {
        // MARK: SUCCESS CASE — Video was generated successfully.

        case let .videoSuccess(videoUrl):
            // Send the completed video URL back to the caller.
            onVideoGenerated(videoUrl)

            // Update the notification to show completion.
            NotificationManager.shared.markAsCompleted(id: notificationId)

            // Clean up task tracking (notification stays visible until user dismisses it)
            cleanupTask(taskId: taskId)

        // MARK: FAILURE CASE — Task failed.

        case let .failure(error):
            // Notify UI or parent caller of the error.
            onError(error)

            // Show failure message in the notification UI.
            NotificationManager.shared.markAsFailed(
                id: notificationId,
                errorMessage: "Generation failed: \(error.localizedDescription)"
            )

            // Don't cleanup task info on failure - keep it for retry functionality
            // Only remove the background task reference
            backgroundTasks.removeValue(forKey: taskId)
            
        // MARK: QUEUED CASE — Task was submitted via webhook, waiting for callback.
        case let .queued(webhookTaskId, jobType):
            print("📤 Video generation queued via webhook - taskId: \(webhookTaskId), type: \(jobType)")
            
            // Update notification to show processing status (keep visible!)
            // Note: The actual processing happens in the cloud and can take several minutes
            NotificationManager.shared.updateMessage("Processing in the cloud... This may take a few minutes.", for: notificationId)
            // Set progress to ~50% to indicate we're waiting for remote processing
            NotificationManager.shared.updateProgress(0.50, for: notificationId)
            
            // Register the notification with JobStatusManager so it can update it when complete
            JobStatusManager.shared.registerNotification(taskId: webhookTaskId, notificationId: notificationId)
            
            // For webhook mode, we don't wait - the result comes via Realtime/push notification
            // Keep the task info for potential retry, but cleanup the background task
            backgroundTasks.removeValue(forKey: taskId)
            
            // DON'T dismiss the notification - JobStatusManager will update it when the webhook completes

        // Image success is not expected here, but handle gracefully
        case .imageSuccess:
            break
        }
    }

    // MARK: - Cancels a running task.

    // Cancels the background work and removes associated tracking data.
    func cancelTask(taskId: UUID) {
        backgroundTasks[taskId]?.cancel()
        cleanupTask(taskId: taskId)
    }
    
    // MARK: - Check if task can be cancelled
    
    /// Checks if a task can still be cancelled by verifying if the background task exists
    /// and if the API request hasn't been submitted yet
    /// - Parameter notificationId: The notification ID to check
    /// - Returns: True if the task can be cancelled, false otherwise
    func canCancelTask(notificationId: UUID) -> Bool {
        // Find the task ID associated with this notification
        guard let taskInfo = generationTasks.values.first(where: { $0.notificationId == notificationId }) else {
            return false
        }
        
        // Can't cancel if API request has already been submitted (past point of no return)
        if taskInfo.apiRequestSubmitted {
            return false
        }
        
        // Check if the background task still exists (hasn't been cleaned up yet)
        // taskId is non-optional in GenerationTaskInfo, so we can use it directly
        return backgroundTasks[taskInfo.taskId] != nil
    }
    
    /// Marks that the API request has been submitted for a given notification
    /// This is called right before submitting the API request to prevent cancellation
    /// - Parameter notificationId: The notification ID to update
    func markApiRequestSubmitted(notificationId: UUID) {
        // Find the task info by notification ID
        if let (taskId, taskInfo) = generationTasks.first(where: { $0.value.notificationId == notificationId }) {
            var updatedTaskInfo = taskInfo
            updatedTaskInfo.apiRequestSubmitted = true
            generationTasks[taskId] = updatedTaskInfo
        }
    }

    // MARK: - Removes all tracking for a given task.

    // Ensures memory stays clean and nothing leaks.
    private func cleanupTask(taskId: UUID) {
        generationTasks.removeValue(forKey: taskId)
        backgroundTasks.removeValue(forKey: taskId)
    }
    
    // MARK: - Helper
    
    private func createPlaceholderImage() -> UIImage {
        let size = CGSize(width: 1, height: 1)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
}
