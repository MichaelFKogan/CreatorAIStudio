import SwiftUI

// MARK: - Coordinator that manages all image generation tasks.

// This acts as a central controller for starting tasks, tracking progress,
// updating notifications, handling results, and cleaning up.
@MainActor
class ImageGenerationCoordinator: ObservableObject {
    // Singleton instance so the entire app uses one shared coordinator.
    static let shared = ImageGenerationCoordinator()

    // Stores metadata about each task (notification ID, generated image, etc.)
    // Used for UI state or worker tracking.
    @Published var generationTasks: [UUID: GenerationTaskInfo] = [:]

    // Stores the actual Swift concurrency background tasks so they can be cancelled.
    var backgroundTasks: [UUID: Task<Void, Never>] = [:]

    // Private so outside code cannot create additional coordinators.
    private init() {}

    // MARK: - Starts an image generation request.

    // Creates an ID, shows a notification, runs the generation task in the background,
    // and wires up all callbacks and progress handlers.
    func startImageGeneration(
        item: InfoPacket,
        image: UIImage,
        userId: String,
        onImageGenerated: @escaping (UIImage) -> Void = { _ in },
        onError: @escaping (Error) -> Void = { _ in }
    ) -> UUID {
        // A unique identifier for this generation job.
        let taskId = UUID()

        // Get model name for notification (use modelName if available, otherwise use title)
        let modelName = item.display.modelName ?? item.display.title
        
        // Create a notification to show progress to the user.
        let notificationId = NotificationManager.shared.showNotification(
            title: "Transforming Your Photo",
            message: "Creating your \(item.display.title)...",
            progress: 0.0,
            thumbnailImage: image,
            taskId: taskId,
            modelName: modelName,
            prompt: item.prompt,
            originalImage: image
        )

        // Save initial task state before the process begins (including retry info).
        generationTasks[taskId] = GenerationTaskInfo(
            taskId: taskId,
            notificationId: notificationId,
            generatedImage: nil,
            item: item,
            originalImage: image,
            userId: userId
        )

        // Create the worker that actually performs the API call / processing.
        let task = ImageGenerationTask(item: item, image: image, userId: userId, useWebhook: true)

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
                        onImageGenerated: onImageGenerated,
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
        onImageGenerated: @escaping (UIImage) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        switch result {
        // MARK: SUCCESS CASE — Image was generated successfully.

        case let .imageSuccess(image, _):
            // Store the generated image so UI can access it if needed.
            if var taskInfo = generationTasks[taskId] {
                taskInfo.generatedImage = image
                generationTasks[taskId] = taskInfo
            }

            // Send the completed image back to the caller.
            onImageGenerated(image)

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
            print("📤 Image generation queued via webhook - taskId: \(webhookTaskId), type: \(jobType)")
            
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

        // Video success is not expected here, but handle gracefully
        case .videoSuccess:
            break
        }
    }

    // MARK: - Cancels a running task.

    // Cancels the background work and removes associated tracking data.
    func cancelTask(taskId: UUID) {
        backgroundTasks[taskId]?.cancel()
        cleanupTask(taskId: taskId)
    }

    // MARK: - Removes all tracking for a given task.

    // Ensures memory stays clean and nothing leaks.
    private func cleanupTask(taskId: UUID) {
        generationTasks.removeValue(forKey: taskId)
        backgroundTasks.removeValue(forKey: taskId)
    }
    
    // MARK: - Retry a failed generation task
    
    /// Retries a failed image generation using the stored item and image from the notification
    /// - Parameter notificationId: The notification ID of the failed task
    /// - Parameter onImageGenerated: Callback when image is successfully generated
    /// - Parameter onError: Callback when generation fails
    func retryImageGeneration(
        notificationId: UUID,
        onImageGenerated: @escaping (UIImage) -> Void = { _ in },
        onError: @escaping (Error) -> Void = { _ in }
    ) -> Bool {
        // Find the task info by notification ID
        guard let taskInfo = generationTasks.values.first(where: { $0.notificationId == notificationId }),
              let item = taskInfo.item,
              let image = taskInfo.originalImage,
              let userId = taskInfo.userId else {
            print("⚠️ Cannot retry: Task info not found for notification \(notificationId)")
            return false
        }
        
        // Reset the notification state to in-progress
        NotificationManager.shared.resetForRetry(notificationId: notificationId)
        
        // Create a new task ID for the retry
        let newTaskId = UUID()
        
        // Update the notification's taskId to the new task
        NotificationManager.shared.updateTaskId(newTaskId, for: notificationId)
        
        // Update the task info with the new task ID
        if let oldTaskId = generationTasks.first(where: { $0.value.notificationId == notificationId })?.key {
            var updatedTaskInfo = generationTasks[oldTaskId]!
            updatedTaskInfo = GenerationTaskInfo(
                taskId: newTaskId,
                notificationId: notificationId,
                generatedImage: nil,
                item: item,
                originalImage: image,
                userId: userId
            )
            generationTasks.removeValue(forKey: oldTaskId)
            generationTasks[newTaskId] = updatedTaskInfo
        }
        
        // Create the worker that actually performs the API call / processing.
        let task = ImageGenerationTask(item: item, image: image, userId: userId, useWebhook: true)
        
        // Run the worker on a background thread using Swift concurrency.
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
                        taskId: newTaskId,
                        notificationId: notificationId,
                        result: result,
                        onImageGenerated: onImageGenerated,
                        onError: onError
                    )
                }
            )
        }
        
        // Store a reference so we can cancel it later if needed.
        backgroundTasks[newTaskId] = backgroundTask
        
        return true
    }
}
