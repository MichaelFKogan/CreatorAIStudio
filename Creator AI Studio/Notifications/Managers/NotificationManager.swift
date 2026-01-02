import SwiftUI

// MARK: - Global Notification Manager
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var notifications: [NotificationData] = []
    @Published var newCompletedCount: Int = 0
    @Published var newFailedCount: Int = 0
    @Published var isNotificationBarVisible: Bool = true
    
    /// Computed property to get active placeholders for Profile page
    /// Returns placeholders in reverse order (newest first) so the most recent transformation appears in the first slot
    var activePlaceholders: [PlaceholderImage] {
        notifications
            .filter { $0.isActive && $0.state != .completed }
            .reversed()
            .map { PlaceholderImage(from: $0) }
    }
    
    private init() {}
    
    /// Creates and shows a new notification, returns its ID for future updates
    @discardableResult
    func showNotification(
        title: String,
        message: String,
        progress: Double = 0.0,
        thumbnailImage: UIImage? = nil,
        taskId: UUID? = nil,
        modelName: String? = nil,
        prompt: String? = nil,
        originalImage: UIImage? = nil
    ) -> UUID {
        let notification = NotificationData(
            title: title,
            message: message,
            progress: progress,
            thumbnailImage: thumbnailImage,
            isActive: true,
            taskId: taskId,
            modelName: modelName,
            prompt: prompt,
            originalImage: originalImage
        )
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            notifications.append(notification)
            // Show notification bar when a new notification is added
            isNotificationBarVisible = true
        }
        
        return notification.id
    }
    
    /// Update the task ID for a specific notification
    @MainActor
    func updateTaskId(_ taskId: UUID, for notificationId: UUID) {
        guard let index = notifications.firstIndex(where: { $0.id == notificationId }) else { return }
        notifications[index].taskId = taskId
    }
    
    /// Update progress for a specific notification by ID
    @MainActor
    func updateProgress(_ progress: Double, for id: UUID) {
        guard let index = notifications.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            notifications[index].progress = progress
        }
    }
    
    /// Update message for a specific notification by ID
    @MainActor
    func updateMessage(_ message: String, for id: UUID) {
        guard let index = notifications.firstIndex(where: { $0.id == id }) else { return }
        notifications[index].message = message
    }
    
    /// Update title for a specific notification by ID
    @MainActor
    func updateTitle(_ title: String, for id: UUID) {
        guard let index = notifications.firstIndex(where: { $0.id == id }) else { return }
        notifications[index].title = title
    }
    
    /// Hide a notification from the notification bar (but keep it for placeholders)
    @MainActor
    func hideNotificationFromBar(id: UUID) {
        guard let index = notifications.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            notifications[index].isHiddenFromBar = true
        }
    }
    
    /// Dismiss a specific notification by ID (removes it completely)
    @MainActor
    func dismissNotification(id: UUID) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            notifications.removeAll { $0.id == id }
        }
    }
    
    /// Dismiss all notifications
    @MainActor
    func dismissAllNotifications() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            notifications.removeAll()
        }
    }
    
    /// Hide the notification bar (doesn't affect the notifications themselves)
    @MainActor
    func hideNotificationBar() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            isNotificationBarVisible = false
        }
    }
    
    /// Mark notification as completed
    @MainActor
    func markAsCompleted(id: UUID, message: String = "✅ Transformation complete!") {
        guard let index = notifications.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            notifications[index].state = .completed
            notifications[index].progress = 1.0
            notifications[index].message = message
            newCompletedCount += 1
        }
        
        // Notification stays visible until user manually dismisses it (via chevron button)
    }
    
    /// Mark notification as failed with error message
    @MainActor
    func markAsFailed(id: UUID, errorMessage: String) {
        guard let index = notifications.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            notifications[index].state = .failed
            notifications[index].errorMessage = errorMessage
            notifications[index].message = "❌ Failed"
            notifications[index].progress = 0.0 // Stop progress bar animation
            newFailedCount += 1
        }
    }
    
    /// Clear badge counts (called when user views Gallery)
    @MainActor
    func clearBadges() {
        newCompletedCount = 0
        newFailedCount = 0
    }
    
    /// Cancel a task by notification ID
    @MainActor
    func cancelTask(notificationId: UUID) {
        guard let notification = notifications.first(where: { $0.id == notificationId }),
              let taskId = notification.taskId else {
            print("⚠️ Cannot cancel: No task ID found for notification")
            return
        }
        
        // Cancel the task via the appropriate coordinator
        // Try both coordinators - the taskId should only exist in one
        ImageGenerationCoordinator.shared.cancelTask(taskId: taskId)
        VideoGenerationCoordinator.shared.cancelTask(taskId: taskId)
        
        // Check if there's a webhook taskId associated with this notification
        // IMPORTANT: Only delete pending job if API request hasn't been submitted yet
        // Once the API request is submitted, payment is taken and we can't cancel/refund
        Task {
            // Check if the task can still be cancelled (API request not submitted)
            let canCancel = ImageGenerationCoordinator.shared.canCancelTask(notificationId: notificationId) ||
                           VideoGenerationCoordinator.shared.canCancelTask(notificationId: notificationId)
            
            if canCancel {
                // Find webhook taskId by reverse lookup in JobStatusManager
                if let webhookTaskId = await JobStatusManager.shared.getWebhookTaskId(for: notificationId) {
                    // Fetch the pending job before deleting it so we can save to user_media
                    do {
                        if let pendingJob = try await SupabaseManager.shared.fetchPendingJob(taskId: webhookTaskId) {
                            // Get user ID from current session
                            if let session = try? await SupabaseManager.shared.client.auth.session {
                                let userId = session.user.id.uuidString
                                
                                // Save cancelled job to user_media for tracking in UsageView
                                if pendingJob.job_type == "image" {
                                    let cancelledMetadata = ImageMetadata(
                                        userId: userId,
                                        imageUrl: "", // Empty for cancelled attempts
                                        model: pendingJob.metadata?.model,
                                        title: pendingJob.metadata?.title,
                                        cost: pendingJob.metadata?.cost,
                                        type: pendingJob.metadata?.type,
                                        endpoint: pendingJob.metadata?.endpoint,
                                        prompt: pendingJob.metadata?.prompt,
                                        aspectRatio: pendingJob.metadata?.aspectRatio,
                                        provider: pendingJob.provider,
                                        status: "failed",
                                        errorMessage: "Cancelled"
                                    )
                                    
                                    try? await SupabaseManager.shared.client.database
                                        .from("user_media")
                                        .insert(cancelledMetadata)
                                        .execute()
                                    
                                    print("✅ Saved cancelled image job to user_media: \(webhookTaskId)")
                                } else if pendingJob.job_type == "video" {
                                    let cancelledMetadata = VideoMetadata(
                                        userId: userId,
                                        videoUrl: "", // Empty for cancelled attempts
                                        thumbnailUrl: nil,
                                        model: pendingJob.metadata?.model,
                                        title: pendingJob.metadata?.title,
                                        cost: pendingJob.metadata?.cost,
                                        type: pendingJob.metadata?.type,
                                        endpoint: pendingJob.metadata?.endpoint,
                                        fileExtension: "mp4",
                                        prompt: pendingJob.metadata?.prompt,
                                        aspectRatio: pendingJob.metadata?.aspectRatio,
                                        duration: pendingJob.metadata?.duration,
                                        resolution: pendingJob.metadata?.resolution,
                                        status: "failed",
                                        errorMessage: "Cancelled"
                                    )
                                    
                                    try? await SupabaseManager.shared.client.database
                                        .from("user_media")
                                        .insert(cancelledMetadata)
                                        .execute()
                                    
                                    print("✅ Saved cancelled video job to user_media: \(webhookTaskId)")
                                }
                            }
                        }
                        
                        // Now delete the pending job
                        try await SupabaseManager.shared.deletePendingJob(taskId: webhookTaskId)
                        print("🧹 Deleted pending job from database after cancellation: \(webhookTaskId)")
                    } catch {
                        print("⚠️ Failed to delete pending job after cancellation: \(error)")
                    }
                    // Remove the notification mapping
                    await JobStatusManager.shared.removeNotificationMapping(for: webhookTaskId)
                }
            } else {
                print("⚠️ Cannot delete pending job - API request already submitted, payment taken")
            }
        }
        
        // Update the notification to show cancellation
        if let index = notifications.firstIndex(where: { $0.id == notificationId }) {
            notifications[index].state = .failed
            notifications[index].errorMessage = "Cancelled"
            notifications[index].message = "Cancelled"
        }
        
        // Note: Placeholder remains on screen so user can manually dismiss with X button
    }
    
    
    /// Reset a failed notification to in-progress state for retry
    @MainActor
    func resetForRetry(notificationId: UUID) {
        guard let index = notifications.firstIndex(where: { $0.id == notificationId }) else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            notifications[index].state = .inProgress
            notifications[index].progress = 0.0
            notifications[index].errorMessage = nil
            notifications[index].message = "Retrying generation..."
        }
    }
    
    /// Find a notification by matching metadata (title, model, prompt)
    /// Used as a fallback when task_id lookup fails
    /// - Parameters:
    ///   - title: The metadata title (model name) - not the notification title
    ///   - modelName: Optional model name to match (should match notification.modelName)
    ///   - prompt: Optional prompt to match
    /// - Returns: The notification ID if found, nil otherwise
    @MainActor
    func findNotificationByMetadata(title: String, modelName: String? = nil, prompt: String? = nil) -> UUID? {
        // Look for notifications that are still in progress (not completed/failed)
        let matchingNotifications = notifications.filter { notification in
            // Must be in progress (not completed/failed)
            guard notification.state == .inProgress else { return false }
            
            // For image generations, notification title is "Transforming Your Photo"
            // For video generations, notification title is "Creating Your Video"
            // We need to match by model name and prompt instead
            let isImageNotification = notification.title.lowercased().contains("transforming") || 
                                     notification.title.lowercased().contains("photo")
            let isVideoNotification = notification.title.lowercased().contains("creating") && 
                                      notification.title.lowercased().contains("video")
            
            // Must be either image or video notification
            guard isImageNotification || isVideoNotification else { return false }
            
            // Model name matching is the most reliable
            if let modelName = modelName, !modelName.isEmpty {
                if let notificationModel = notification.modelName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                   !notificationModel.isEmpty {
                    let searchModel = modelName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    // Model names should match (case-insensitive)
                    if notificationModel != searchModel {
                        return false
                    }
                } else {
                    // If notification has no model name but we're searching with one, skip
                    return false
                }
            } else {
                // If we don't have a model name to match, we can't reliably identify the notification
                // But we can still try prompt matching if available
            }
            
            // If prompt is provided, try to match it (optional, less reliable but helpful)
            if let prompt = prompt, !prompt.isEmpty {
                if let notificationPrompt = notification.prompt?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                   !notificationPrompt.isEmpty {
                    // Prompts should be similar (at least 50% match)
                    let promptWords = Set(prompt.split(separator: " "))
                    let notificationWords = Set(notificationPrompt.split(separator: " "))
                    let intersection = promptWords.intersection(notificationWords)
                    let similarity = Double(intersection.count) / Double(max(promptWords.count, notificationWords.count))
                    if similarity < 0.3 { // Lower threshold since prompts might vary slightly
                        return false
                    }
                }
            }
            
            return true
        }
        
        // Return the most recent matching notification (newest first)
        if let matchingNotification = matchingNotifications.sorted(by: { $0.createdAt > $1.createdAt }).first {
            print("[NotificationManager] ✅ Found notification by metadata: \(matchingNotification.id), title: \(matchingNotification.title), model: \(matchingNotification.modelName ?? "nil")")
            return matchingNotification.id
        }
        
        print("[NotificationManager] ⚠️ No matching notification found for title: \(title), model: \(modelName ?? "nil"), prompt: \(prompt?.prefix(50) ?? "nil")")
        return nil
    }
    
}
