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
                    // Found the webhook taskId, delete the pending job (only if not yet submitted)
                    do {
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
            notifications[index].errorMessage = "Task cancelled by user"
            notifications[index].message = "❌ Cancelled"
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
    
}
