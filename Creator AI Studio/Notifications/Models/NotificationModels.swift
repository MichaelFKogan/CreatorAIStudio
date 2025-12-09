import SwiftUI

// MARK: - Notification State
enum NotificationState: Equatable {
    case inProgress
    case completed
    case failed
}

// MARK: - Notification Data Model
struct NotificationData: Identifiable, Equatable {
    let id: UUID
    var title: String
    var message: String
    var progress: Double // 0.0 to 1.0
    var thumbnailImage: UIImage?
    var isActive: Bool
    var state: NotificationState
    var errorMessage: String?
    var taskId: UUID? // Associated task ID for cancellation
    
    static func == (lhs: NotificationData, rhs: NotificationData) -> Bool {
        lhs.id == rhs.id
            && lhs.state == rhs.state
            && lhs.progress == rhs.progress
            && lhs.title == rhs.title
            && lhs.message == rhs.message
            && lhs.errorMessage == rhs.errorMessage
            && lhs.taskId == rhs.taskId
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        message: String,
        progress: Double = 0.0,
        thumbnailImage: UIImage? = nil,
        isActive: Bool = true,
        state: NotificationState = .inProgress,
        errorMessage: String? = nil,
        taskId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.progress = progress
        self.thumbnailImage = thumbnailImage
        self.isActive = isActive
        self.state = state
        self.errorMessage = errorMessage
        self.taskId = taskId
    }
}

// MARK: - Placeholder Image (for Profile Grid)
struct PlaceholderImage: Identifiable {
    let id: UUID
    let title: String
    let message: String
    let progress: Double
    let thumbnailImage: UIImage?
    let state: NotificationState
    let errorMessage: String?
    let taskId: UUID? // Associated task ID for cancellation
    
    init(from notification: NotificationData) {
        self.id = notification.id
        self.title = notification.title
        self.message = notification.message
        self.progress = notification.progress
        self.thumbnailImage = notification.thumbnailImage
        self.state = notification.state
        self.errorMessage = notification.errorMessage
        self.taskId = notification.taskId
    }
}






