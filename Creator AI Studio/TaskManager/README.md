# TaskManager - Media Generation Orchestration

## Overview

The TaskManager layer separates business logic (media generation) from UI concerns (notifications). This provides better testability, maintainability, and reusability.

## Architecture

```
View Layer (SwiftUI)
       ↓
TaskCoordinator (manages lifecycle)
       ↓
MediaGenerationTask (executes workflow)
       ↓
API Layer (WaveSpeed, Supabase)
```

## Usage Examples

### Image Generation

```swift
// In your SwiftUI view:
import SwiftUI

struct MyView: View {
    @StateObject private var authViewModel = AuthViewModel.shared
    @State private var selectedImage: UIImage?
    
    var body: some View {
        Button("Generate Image") {
            guard let image = selectedImage,
                  let userId = authViewModel.userId else { return }
            
            // Create InfoPacket with your model configuration
            let item = InfoPacket(
                display: DisplayInfo(
                    title: "Anime Style",
                    imageName: "anime",
                    modelName: "flux-pro"
                ),
                apiConfig: APIConfiguration(
                    endpoint: "https://api.wavespeed.com/v1/image",
                    aspectRatio: "1:1"
                ),
                prompt: "anime style portrait",
                cost: 0.05
            )
            
            // Start generation
            TaskCoordinator.shared.startImageGeneration(
                item: item,
                image: image,
                userId: userId
            ) { generatedImage in
                // Handle success - image is already saved to database
                print("Image generated successfully!")
            }
        }
    }
}
```

### Video Generation

```swift
// In your SwiftUI view:
TaskCoordinator.shared.startVideoGeneration(
    item: videoItem,
    image: sourceImage,
    userId: userId
) { videoUrl in
    // Handle success - video is already saved to database
    print("Video generated: \(videoUrl)")
}
```

### Canceling Tasks

```swift
// Store the task ID when starting
let taskId = TaskCoordinator.shared.startImageGeneration(...)

// Cancel later if needed
TaskCoordinator.shared.cancelTask(taskId: taskId)
```

### Retrieving Generated Images

```swift
// Get the generated image from a completed task
if let image = TaskCoordinator.shared.getGeneratedImage(for: taskId) {
    // Use the image
}
```

## Notifications

Progress notifications are automatically managed:
- TaskCoordinator creates a notification when generation starts
- Updates progress during execution
- Marks as complete or failed
- Auto-dismisses after 5 seconds

The NotificationBar (already in your app) displays these notifications automatically.

## File Structure

```
TaskManager/
├── TaskCoordinator.swift          # Manages task lifecycle
├── MediaGenerationTask.swift      # Protocol definition
├── ImageGenerationTask.swift      # Image generation workflow
├── VideoGenerationTask.swift      # Video generation workflow
└── TaskModels.swift               # Data models
```

## Testing

Each component can now be tested independently:

```swift
// Test image generation logic without UI
let task = ImageGenerationTask(item: testItem, image: testImage, userId: "test-user")
await task.execute(
    notificationId: UUID(),
    onProgress: { progress in
        XCTAssertGreaterThan(progress.progress, 0)
    },
    onComplete: { result in
        // Assert result
    }
)
```

## Benefits

1. **Separation of Concerns**: UI notifications separated from business logic
2. **Testability**: Each layer can be tested independently
3. **Reusability**: Generation tasks can be called from anywhere
4. **Maintainability**: Smaller, focused files (< 200 lines each)
5. **Scalability**: Easy to add new media types (audio, 3D, etc.)

