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

        // Create a notification to show progress to the user.
        let notificationId = NotificationManager.shared.showNotification(
            title: "Transforming Your Photo",
            message: "Creating your \(item.display.title)...",
            progress: 0.0,
            thumbnailImage: image,
            taskId: taskId
        )

        // Save initial task state before the process begins.
        generationTasks[taskId] = GenerationTaskInfo(
            taskId: taskId,
            notificationId: notificationId,
            generatedImage: nil
        )

        // Create the worker that actually performs the API call / processing.
        let task = ImageGenerationTask(item: item, image: image, userId: userId)

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

            // Remove the notification after a few seconds, then clean up.
            Task {
                try? await Task.sleep(for: .seconds(5))
                await NotificationManager.shared.dismissNotification(id: notificationId)
                cleanupTask(taskId: taskId)
            }

        // MARK: FAILURE CASE — Task failed.

        case let .failure(error):
            // Notify UI or parent caller of the error.
            onError(error)

            // Show failure message in the notification UI.
            NotificationManager.shared.markAsFailed(
                id: notificationId,
                errorMessage: "Generation failed: \(error.localizedDescription)"
            )

            // Remove the task from memory.
            cleanupTask(taskId: taskId)

        // Other result types (if added later) are simply ignored here.
        default:
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
}
