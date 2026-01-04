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
        // If generation is failed, show failed message
        if state == .failed {
            return "Failed"
        }
        
        // If generation is completed, show success message
        if state == .completed {
            return "Success"
        }
        
        let elapsedMinutes = Int(elapsedSeconds / 60)
        
        // After 5 minutes and before 10 minutes, show timeout warning countdown
        // After 10 minutes, the generation should have timed out (state should be failed)
        // But if still in progress, show a final timeout message
        if elapsedMinutes >= 5 {
            if elapsedMinutes < 10 {
                let remainingMinutes = 10 - elapsedMinutes
                return "This will cancel in \(remainingMinutes) minute\(remainingMinutes == 1 ? "" : "s") if no result. You won't be charged for failed generations."
            } else {
                // After 10 minutes, show timeout message (shouldn't happen if state is properly updated)
                return "Generation timed out"
            }
        }
        
        // Before 3 minutes, rotate messages every minute
        let messageIndex = elapsedMinutes % (isVideo ? videoMessages.count : informativeMessages.count)
        let messages = isVideo ? videoMessages : informativeMessages
        return messages[Int(messageIndex)]
    }
    
    /// Get the timeout message to show initially
    static func getTimeoutMessage(isVideo: Bool) -> String {
        if isVideo {
            return "Video will timeout in 5 minutes if no video is generated"
        } else {
            return "Image will timeout in 5 minutes if no image is generated"
        }
    }
    
    /// Check if we should show the timeout message (after 5 minutes)
    static func shouldShowTimeoutMessage(elapsedSeconds: TimeInterval) -> Bool {
        let elapsedMinutes = elapsedSeconds / 60
        return elapsedMinutes >= 5 && elapsedMinutes < 6
    }
}

