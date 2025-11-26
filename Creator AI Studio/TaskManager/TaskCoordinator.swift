// import SwiftUI

// // MARK: - Task Coordinator

// /// Coordinates media generation tasks and manages their lifecycle
// class TaskCoordinator: ObservableObject {
//     static let shared = TaskCoordinator()

//     @Published var generationTasks: [UUID: GenerationTaskInfo] = [:]
//     var backgroundTasks: [UUID: Task<Void, Never>] = [:]

//     private init() {}

//     // MARK: IMAGE GENERATION

//     /// Start a background image generation task
//     @MainActor
//     func startImageGeneration(
//         item: InfoPacket,
//         image: UIImage,
//         userId: String,
//         onImageGenerated: @escaping (UIImage) -> Void = { _ in },
//         onError: @escaping (Error) -> Void = { _ in }
//     ) -> UUID {
//         let taskId = UUID()

//         // Show notification immediately
//         let notificationId = NotificationManager.shared.showNotification(
//             title: "Transforming Your Photo",
//             message: "Creating your \(item.display.title)...",
//             progress: 0.0,
//             thumbnailImage: image
//         )

//         // Store task info
//         generationTasks[taskId] = GenerationTaskInfo(
//             taskId: taskId,
//             notificationId: notificationId,
//             generatedImage: nil
//         )

//         // Create the task
//         let task = ImageGenerationTask(item: item, image: image, userId: userId)

//         // Execute in background
//         let backgroundTask = Task.detached { [weak self] in
//             await task.execute(
//                 notificationId: notificationId,
//                 onProgress: { progress in
//                     await NotificationManager.shared.updateProgress(progress.progress, for: notificationId)
//                     await NotificationManager.shared.updateMessage(progress.message, for: notificationId)
//                 },
//                 onComplete: { result in
//                     await self?.handleImageCompletion(
//                         taskId: taskId,
//                         notificationId: notificationId,
//                         result: result,
//                         onImageGenerated: onImageGenerated,
//                         onError: onError
//                     )
//                 }
//             )
//         }

//         backgroundTasks[taskId] = backgroundTask
//         return taskId
//     }

//     // MARK: VIDEO GENERATION

//     /// Start a background video generation task
//     @MainActor
//     func startVideoGeneration(
//         item: InfoPacket,
//         image: UIImage,
//         userId: String,
//         onVideoGenerated: @escaping (String) -> Void = { _ in }
//     ) -> UUID {
//         let taskId = UUID()

//         // Show notification immediately
//         let notificationId = NotificationManager.shared.showNotification(
//             title: "Creating Your Video",
//             message: "Generating your \(item.display.title)...",
//             progress: 0.0,
//             thumbnailImage: image
//         )

//         // Store task info
//         generationTasks[taskId] = GenerationTaskInfo(
//             taskId: taskId,
//             notificationId: notificationId,
//             generatedImage: nil
//         )

//         // Create the task
//         let task = VideoGenerationTask(item: item, image: image, userId: userId)

//         // Execute in background
//         let backgroundTask = Task.detached { [weak self] in
//             await task.execute(
//                 notificationId: notificationId,
//                 onProgress: { progress in
//                     await NotificationManager.shared.updateProgress(progress.progress, for: notificationId)
//                     await NotificationManager.shared.updateMessage(progress.message, for: notificationId)
//                 },
//                 onComplete: { result in
//                     await self?.handleVideoCompletion(
//                         taskId: taskId,
//                         notificationId: notificationId,
//                         result: result,
//                         onVideoGenerated: onVideoGenerated
//                     )
//                 }
//             )
//         }

//         backgroundTasks[taskId] = backgroundTask
//         return taskId
//     }

//     // MARK: CANCEL TASK

//     // Cancel a running task
//     @MainActor
//     func cancelTask(taskId: UUID) {
//         backgroundTasks[taskId]?.cancel()
//         cleanupTask(taskId: taskId)
//     }

//     // Get generated image for a task
//     func getGeneratedImage(for taskId: UUID) -> UIImage? {
//         return generationTasks[taskId]?.generatedImage
//     }

//     // MARK: HANDLE IMAGE COMOPLETION

//     @MainActor
//     private func handleImageCompletion(
//         taskId: UUID,
//         notificationId: UUID,
//         result: TaskResult,
//         onImageGenerated: @escaping (UIImage) -> Void,
//         onError: @escaping (Error) -> Void
//     ) {
//         switch result {
//         case let .imageSuccess(image, _):
//             // Store generated image
//             if var taskInfo = generationTasks[taskId] {
//                 taskInfo.generatedImage = image
//                 generationTasks[taskId] = taskInfo
//             }
//             onImageGenerated(image)

//             // Mark as complete
//             NotificationManager.shared.markAsCompleted(id: notificationId)

//             // Auto-dismiss and cleanup
//             Task {
//                 try? await Task.sleep(for: .seconds(5))
//                 await NotificationManager.shared.dismissNotification(id: notificationId)
//                 await MainActor.run {
//                     self.cleanupTask(taskId: taskId)
//                 }
//             }

//         case let .failure(error):
//             onError(error)
//             NotificationManager.shared.markAsFailed(
//                 id: notificationId,
//                 errorMessage: "Generation failed: \(error.localizedDescription)"
//             )
//             cleanupTask(taskId: taskId)

//         default:
//             break
//         }
//     }

//     @MainActor
//     private func handleVideoCompletion(
//         taskId: UUID,
//         notificationId: UUID,
//         result: TaskResult,
//         onVideoGenerated: @escaping (String) -> Void
//     ) {
//         switch result {
//         case let .videoSuccess(videoUrl):
//             onVideoGenerated(videoUrl)

//             // Mark as complete
//             NotificationManager.shared.markAsCompleted(
//                 id: notificationId,
//                 message: "✅ Video created successfully!"
//             )

//             // Auto-dismiss and cleanup
//             Task {
//                 try? await Task.sleep(for: .seconds(5))
//                 await NotificationManager.shared.dismissNotification(id: notificationId)
//                 await MainActor.run {
//                     self.cleanupTask(taskId: taskId)
//                 }
//             }

//         case let .failure(error):
//             NotificationManager.shared.markAsFailed(
//                 id: notificationId,
//                 errorMessage: "Generation failed: \(error.localizedDescription)"
//             )
//             cleanupTask(taskId: taskId)

//         default:
//             break
//         }
//     }

//     @MainActor
//     private func cleanupTask(taskId: UUID) {
//         generationTasks.removeValue(forKey: taskId)
//         backgroundTasks.removeValue(forKey: taskId)
//     }
// }
