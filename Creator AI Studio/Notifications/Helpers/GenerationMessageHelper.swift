import Foundation
import SwiftUI

struct GenerationMessageHelper {
    // Rotating messages to keep users engaged during long generations
    private static let informativeMessages: [String] = [
        "Creating your image...",
        "Transforming your image...",
        "Processing your request...",
        "Generating your creation...",
        "Applying transformations...",
        "Optimizing quality...",
        "Working on your image...",
        "This may take a few minutes..."
    ]
    
    // Messages specifically for videos (longer generation times)
    private static let videoMessages: [String] = [
        "Creating your video...",
        "Rendering video frames...",
        "Processing video sequence...",
        "Generating your video...",
        "Compiling video frames...",
        "Finalizing video quality...",
        "This may take a few minutes..."
    ]
    
    /// Get a dynamic message based on elapsed time and generation type
    static func getDynamicMessage(
        elapsedSeconds: TimeInterval,
        isVideo: Bool = false,
        baseMessage: String,
        state: NotificationState = .inProgress
    ) -> String {
        // If generation is completed, show success message
        if state == .completed {
            return "Success"
        }
        
        let elapsedMinutes = Int(elapsedSeconds / 60)
        
        // After 3 minutes, show timeout warning
        if elapsedMinutes >= 3 && elapsedMinutes < 5 {
            let remainingMinutes = 5 - elapsedMinutes
            return "This will cancel in \(remainingMinutes) minute\(remainingMinutes == 1 ? "" : "s") if no result. You won't be charged for failed generations."
        }
        
        // Rotate messages every minute
        let messageIndex = elapsedMinutes % (isVideo ? videoMessages.count : informativeMessages.count)
        let messages = isVideo ? videoMessages : informativeMessages
        return messages[Int(messageIndex)]
    }
    
    /// Get the timeout message to show initially
    static func getTimeoutMessage(isVideo: Bool) -> String {
        if isVideo {
            return "Video will timeout in 3 minutes if no video is generated"
        } else {
            return "Image will timeout in 3 minutes if no image is generated"
        }
    }
    
    /// Check if we should show the timeout message (after 2 minutes)
    static func shouldShowTimeoutMessage(elapsedSeconds: TimeInterval) -> Bool {
        let elapsedMinutes = elapsedSeconds / 60
        return elapsedMinutes >= 2 && elapsedMinutes < 3
    }
}

