SUMMARY

1. 📁 ImageModelDetailPage.swift

User Taps "Generate" Button
↓
Fires the startImageGeneration() function
↓
Inside ImageGenerationCoordinator.swift

2. 📁 ImageGenerationCoordinator.swift

Inside func startImageGeneration() {

5 key steps are executed:

Step 1: Generate unique taskId (UUID)

Step 2: NotificationManager.showNotification()

• Shows progress notification to user
• Returns notificationId for tracking

Step 3: Create GenerationTaskInfo struct

• Stores task metadata
• Saved to generationTasks[taskId] dictionary

Step 4: Create ImageGenerationTask object

• Contains the actual generation logic
• Initialized with item, image, userId

Step 5: Launch Task.detached (background task)

• Executes task.execute() off main thread
• Provides progress & completion callbacks
• Saved to backgroundTasks[taskId] dictionary

}
