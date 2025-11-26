import SwiftUI

@MainActor
class ImageGenerationCoordinator: ObservableObject {
    static let shared = ImageGenerationCoordinator()

    @Published var generationTasks: [UUID: GenerationTaskInfo] = [:]
    var backgroundTasks: [UUID: Task<Void, Never>] = [:]

    private init() {}

    func startImageGeneration(
        item: InfoPacket,
        image: UIImage,
        userId: String,
        onImageGenerated: @escaping (UIImage) -> Void = { _ in },
        onError: @escaping (Error) -> Void = { _ in }
    ) -> UUID {
        let taskId = UUID()

        let notificationId = NotificationManager.shared.showNotification(
            title: "Transforming Your Photo",
            message: "Creating your \(item.display.title)...",
            progress: 0.0,
            thumbnailImage: image
        )

        generationTasks[taskId] = GenerationTaskInfo(
            taskId: taskId,
            notificationId: notificationId,
            generatedImage: nil
        )

        let task = ImageGenerationTask(item: item, image: image, userId: userId)

        let backgroundTask = Task.detached { [weak self] in
            await task.execute(
                notificationId: notificationId,
                onProgress: { progress in
                    await NotificationManager.shared.updateProgress(progress.progress, for: notificationId)
                    await NotificationManager.shared.updateMessage(progress.message, for: notificationId)
                },
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

        backgroundTasks[taskId] = backgroundTask
        return taskId
    }

    private func handleCompletion(
        taskId: UUID,
        notificationId: UUID,
        result: TaskResult,
        onImageGenerated: @escaping (UIImage) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        switch result {
        case let .imageSuccess(image, _):
            if var taskInfo = generationTasks[taskId] {
                taskInfo.generatedImage = image
                generationTasks[taskId] = taskInfo
            }
            onImageGenerated(image)
            NotificationManager.shared.markAsCompleted(id: notificationId)

            Task {
                try? await Task.sleep(for: .seconds(5))
                await NotificationManager.shared.dismissNotification(id: notificationId)
                cleanupTask(taskId: taskId)
            }

        case let .failure(error):
            onError(error)
            NotificationManager.shared.markAsFailed(
                id: notificationId,
                errorMessage: "Generation failed: \(error.localizedDescription)"
            )
            cleanupTask(taskId: taskId)

        default: break
        }
    }

    func cancelTask(taskId: UUID) {
        backgroundTasks[taskId]?.cancel()
        cleanupTask(taskId: taskId)
    }

    private func cleanupTask(taskId: UUID) {
        generationTasks.removeValue(forKey: taskId)
        backgroundTasks.removeValue(forKey: taskId)
    }
}
