//import SwiftUI
//
//@MainActor
//class VideoGenerationCoordinator: ObservableObject {
//    static let shared = VideoGenerationCoordinator()
//
//    @Published var generationTasks: [UUID: GenerationTaskInfo] = [:]
//    var backgroundTasks: [UUID: Task<Void, Never>] = [:]
//
//    private init() {}
//
//    func startVideoGeneration(
//        item: InfoPacket,
//        image: UIImage,
//        userId: String,
//        onVideoGenerated: @escaping (String) -> Void = { _ in }
//    ) -> UUID {
//        let taskId = UUID()
//
//        let notificationId = NotificationManager.shared.showNotification(
//            title: "Creating Your Video",
//            message: "Generating your \(item.display.title)...",
//            progress: 0.0,
//            thumbnailImage: image
//        )
//
//        generationTasks[taskId] = GenerationTaskInfo(
//            taskId: taskId,
//            notificationId: notificationId,
//            generatedImage: nil
//        )
//
//        let task = VideoGenerationTask(item: item, image: image, userId: userId)
//
//        let backgroundTask = Task.detached { [weak self] in
//            await task.execute(
//                notificationId: notificationId,
//                onProgress: { progress in
//                    await NotificationManager.shared.updateProgress(progress.progress, for: notificationId)
//                    await NotificationManager.shared.updateMessage(progress.message, for: notificationId)
//                },
//                onComplete: { result in
//                    await self?.handleCompletion(
//                        taskId: taskId,
//                        notificationId: notificationId,
//                        result: result,
//                        onVideoGenerated: onVideoGenerated
//                    )
//                }
//            )
//        }
//
//        backgroundTasks[taskId] = backgroundTask
//        return taskId
//    }
//
//    private func handleCompletion(
//        taskId: UUID,
//        notificationId: UUID,
//        result: TaskResult,
//        onVideoGenerated: @escaping (String) -> Void
//    ) {
//        switch result {
//        case let .videoSuccess(videoUrl):
//            onVideoGenerated(videoUrl)
//            NotificationManager.shared.markAsCompleted(
//                id: notificationId,
//                message: "✅ Video created successfully!"
//            )
//            Task {
//                try? await Task.sleep(for: .seconds(5))
//                await NotificationManager.shared.dismissNotification(id: notificationId)
//                cleanupTask(taskId: taskId)
//            }
//
//        case let .failure(error):
//            NotificationManager.shared.markAsFailed(
//                id: notificationId,
//                errorMessage: "Generation failed: \(error.localizedDescription)"
//            )
//            cleanupTask(taskId: taskId)
//
//        default: break
//        }
//    }
//
//    func cancelTask(taskId: UUID) {
//        backgroundTasks[taskId]?.cancel()
//        cleanupTask(taskId: taskId)
//    }
//
//    private func cleanupTask(taskId: UUID) {
//        generationTasks.removeValue(forKey: taskId)
//        backgroundTasks.removeValue(forKey: taskId)
//    }
//}
