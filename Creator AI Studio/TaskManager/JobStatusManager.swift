import Foundation
import Supabase
import SwiftUI

// MARK: - Job Status Manager

/// Manages Supabase Realtime subscriptions for pending job updates
/// Handles job completion by downloading results and uploading to storage
@MainActor
class JobStatusManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = JobStatusManager()
    
    // MARK: - Published Properties
    
    @Published var pendingJobs: [PendingJob] = []
    @Published var isConnected: Bool = false
    
    // MARK: - Private Properties
    
    private var realtimeChannel: RealtimeChannelV2?
    private var currentUserId: String?
    private var completionHandlers: [String: (PendingJob) -> Void] = [:]
    private var processingJobIds: Set<String> = [] // Track jobs being processed to avoid duplicates
    
    /// Maps webhook task IDs to their notification IDs for updating existing notifications
    private var taskNotificationMap: [String: UUID] = [:]
    
    /// Decoder configured for Supabase's ISO8601 date format
    private lazy var supabaseDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try with fractional seconds first
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
        }
        return decoder
    }()
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Start listening for job updates for a specific user
    func startListening(userId: String) async {
        // Don't restart if already listening for same user
        guard currentUserId != userId else { return }
        
        // Stop any existing subscription
        await stopListening()
        
        currentUserId = userId
        print("[JobStatusManager] Starting Realtime subscription for user: \(userId)")
        
        // Clean up orphaned pending jobs (stuck in "pending" status for > 30 minutes)
        // This handles jobs where webhook submission failed before the fix was applied
        await cleanupOrphanedJobs()
        
        // Fetch existing pending jobs
        await fetchPendingJobs(userId: userId)
        
        // Subscribe to Realtime updates
        await subscribeToRealtimeUpdates(userId: userId)
    }
    
    /// Clean up orphaned pending jobs that are stuck
    private func cleanupOrphanedJobs() async {
        do {
            let deletedCount = try await SupabaseManager.shared.cleanupOrphanedPendingJobs(olderThanMinutes: 30)
            if deletedCount > 0 {
                print("[JobStatusManager] 🧹 Cleaned up \(deletedCount) orphaned pending jobs")
            }
        } catch {
            print("[JobStatusManager] ⚠️ Failed to cleanup orphaned jobs: \(error.localizedDescription)")
        }
    }
    
    /// Stop listening for updates
    func stopListening() async {
        if let channel = realtimeChannel {
            await channel.unsubscribe()
            realtimeChannel = nil
        }
        currentUserId = nil
        isConnected = false
        pendingJobs = []
        completionHandlers = [:]
        print("[JobStatusManager] Stopped Realtime subscription")
    }
    
    /// Register a completion handler for a specific task
    func registerCompletionHandler(taskId: String, handler: @escaping (PendingJob) -> Void) {
        completionHandlers[taskId] = handler
    }
    
    /// Remove completion handler for a task
    func removeCompletionHandler(taskId: String) {
        completionHandlers.removeValue(forKey: taskId)
    }
    
    /// Get a pending job by task ID
    func getPendingJob(taskId: String) -> PendingJob? {
        pendingJobs.first { $0.task_id == taskId }
    }
    
    /// Register a notification ID for a webhook task so we can update it later
    func registerNotification(taskId: String, notificationId: UUID) {
        taskNotificationMap[taskId] = notificationId
        print("[JobStatusManager] 📋 Registered notification \(notificationId) for task \(taskId)")
    }
    
    /// Get the notification ID for a task if one was registered
    func getNotificationId(for taskId: String) -> UUID? {
        return taskNotificationMap[taskId]
    }
    
    /// Remove notification mapping for a task
    func removeNotificationMapping(for taskId: String) {
        taskNotificationMap.removeValue(forKey: taskId)
    }
    
    // MARK: - Private Methods
    
    /// Fetch existing pending jobs from database
    private func fetchPendingJobs(userId: String) async {
        do {
            let response = try await SupabaseManager.shared.client.database
                .from("pending_jobs")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
            
            // Decode using our custom decoder
            let jobs = try supabaseDecoder.decode([PendingJob].self, from: response.data)
            
            pendingJobs = jobs
            print("[JobStatusManager] Fetched \(jobs.count) pending jobs")
            
            // Process any already-completed jobs that haven't been processed yet
            for job in jobs where job.isComplete && job.hasResult {
                print("[JobStatusManager] Found completed job to process: \(job.task_id)")
                await handleJobCompletion(job)
            }
            
        } catch {
            print("[JobStatusManager] Error fetching pending jobs: \(error)")
        }
    }
    
    /// Subscribe to Realtime updates for the user's pending jobs
    private func subscribeToRealtimeUpdates(userId: String) async {
        let channel = SupabaseManager.shared.client.realtimeV2.channel("pending-jobs-\(userId)")
        
        // Listen for INSERT events
        let insertions = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "pending_jobs",
            filter: "user_id=eq.\(userId)"
        )
        
        // Listen for UPDATE events
        let updates = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "pending_jobs",
            filter: "user_id=eq.\(userId)"
        )
        
        // Listen for DELETE events
        let deletions = channel.postgresChange(
            DeleteAction.self,
            schema: "public",
            table: "pending_jobs",
            filter: "user_id=eq.\(userId)"
        )
        
        // Handle insertions
        Task {
            for await insertion in insertions {
                await handleInsert(insertion)
            }
        }
        
        // Handle updates
        Task {
            for await update in updates {
                await handleUpdate(update)
            }
        }
        
        // Handle deletions
        Task {
            for await deletion in deletions {
                await handleDelete(deletion)
            }
        }
        
        // Subscribe to the channel
        await channel.subscribe()
        realtimeChannel = channel
        isConnected = true
        
        print("[JobStatusManager] Realtime subscription active")
    }
    
    /// Handle new job insertion
    private func handleInsert(_ action: InsertAction) async {
        do {
            let job = try action.decodeRecord(as: PendingJob.self, decoder: supabaseDecoder)
            
            await MainActor.run {
                // Add to beginning of list
                pendingJobs.insert(job, at: 0)
            }
            
            print("[JobStatusManager] 📥 New job inserted: \(job.task_id)")
            
        } catch {
            print("[JobStatusManager] ❌ Error decoding inserted job: \(error)")
        }
    }
    
    /// Handle job update
    private func handleUpdate(_ action: UpdateAction) async {
        do {
            let job = try action.decodeRecord(as: PendingJob.self, decoder: supabaseDecoder)
            
            await MainActor.run {
                // Update existing job in list
                if let index = pendingJobs.firstIndex(where: { $0.task_id == job.task_id }) {
                    pendingJobs[index] = job
                }
            }
            
            print("[JobStatusManager] 🔄 Job updated: \(job.task_id), status: \(job.status)")
            
            // Check if job completed
            if job.isComplete {
                await handleJobCompletion(job)
            }
            
        } catch {
            print("[JobStatusManager] ❌ Error decoding updated job: \(error)")
        }
    }
    
    /// Handle job deletion
    private func handleDelete(_ action: DeleteAction) async {
        // Extract task_id from old record if available
        let oldRecord = action.oldRecord
        if let taskIdValue = oldRecord["task_id"],
           case .string(let taskId) = taskIdValue {
            
            await MainActor.run {
                pendingJobs.removeAll { $0.task_id == taskId }
            }
            
            print("[JobStatusManager] Job deleted: \(taskId)")
        }
    }
    
    /// Handle a completed or failed job
    private func handleJobCompletion(_ job: PendingJob) async {
        print("[JobStatusManager] ✅ Job completed: \(job.task_id), status: \(job.status)")
        
        // Prevent processing the same job twice
        guard !processingJobIds.contains(job.task_id) else {
            print("[JobStatusManager] ⏭️ Job already being processed, skipping: \(job.task_id)")
            return
        }
        
        // Call registered completion handler if any
        if let handler = completionHandlers[job.task_id] {
            handler(job)
            completionHandlers.removeValue(forKey: job.task_id)
        }
        
        // If job completed successfully with a result URL, process it
        if job.jobStatus == .completed, let resultUrl = job.result_url, !resultUrl.isEmpty {
            processingJobIds.insert(job.task_id)
            await processCompletedJob(job)
            processingJobIds.remove(job.task_id)
        }
        
        // Post notification for UI updates
        await MainActor.run {
            NotificationCenter.default.post(
                name: NSNotification.Name("PendingJobCompleted"),
                object: nil,
                userInfo: [
                    "job": job,
                    "taskId": job.task_id,
                    "status": job.status,
                    "resultUrl": job.result_url ?? ""
                ]
            )
        }
    }
    
    // MARK: - Process Completed Job
    
    /// Downloads the result from the API, uploads to Supabase storage, and saves metadata
    private func processCompletedJob(_ job: PendingJob) async {
        guard let resultUrl = job.result_url,
              let url = URL(string: resultUrl) else {
            print("[JobStatusManager] ❌ No valid result URL for job: \(job.task_id)")
            return
        }
        
        print("[JobStatusManager] 🚀 Processing completed job: \(job.task_id)")
        print("[JobStatusManager] 🔗 Result URL: \(resultUrl)")
        
        // Update the notification to show we're almost done (this is the RIGHT time!)
        if let notificationId = taskNotificationMap[job.task_id] {
            NotificationManager.shared.updateMessage("Almost done! Saving your creation...", for: notificationId)
            NotificationManager.shared.updateProgress(0.85, for: notificationId)
        }
        
        do {
            // Extract metadata
            let metadata = job.metadata
            let modelName = metadata?.model ?? "unknown"
            let userId = job.user_id
            
            if job.job_type == "image" {
                // MARK: Process Image
                
                // Download image from API result URL
                let (imageData, _) = try await URLSession.shared.data(from: url)
                
                guard let image = UIImage(data: imageData) else {
                    print("[JobStatusManager] ❌ Failed to decode image from result URL")
                    return
                }
                
                print("[JobStatusManager] 📦 Image downloaded successfully (\(imageData.count) bytes)")
                
                // Upload to Supabase storage
                let supabaseImageURL = try await SupabaseManager.shared.uploadImage(
                    image: image,
                    userId: userId,
                    modelName: modelName
                )
                
                print("[JobStatusManager] ☁️ Image uploaded to Supabase: \(supabaseImageURL)")
                
                // Show success notification with green bar and badge
                await MainActor.run {
                    let title = metadata?.title ?? "Image"
                    
                    // Check if we have an existing notification for this task
                    if let existingNotificationId = taskNotificationMap[job.task_id] {
                        // Update the existing notification to show completion
                        NotificationManager.shared.markAsCompleted(id: existingNotificationId, message: "✅ \(title) ready!")
                        taskNotificationMap.removeValue(forKey: job.task_id)
                        print("[JobStatusManager] ✅ Updated existing notification \(existingNotificationId)")
                    } else {
                        // Create a new notification (fallback for jobs started before app was listening)
                        let notificationId = NotificationManager.shared.showNotification(
                            title: title,
                            message: "Processing...",
                            progress: 1.0,
                            thumbnailImage: image
                        )
                        NotificationManager.shared.markAsCompleted(id: notificationId, message: "✅ \(title) ready!")
                        print("[JobStatusManager] ✅ Created new success notification")
                    }
                }
                
                // Save metadata to user_media table
                let imageMetadata = ImageMetadata(
                    userId: userId,
                    imageUrl: supabaseImageURL,
                    model: modelName,
                    title: metadata?.title,
                    cost: metadata?.cost,
                    type: metadata?.type,
                    endpoint: metadata?.endpoint,
                    prompt: metadata?.prompt,
                    aspectRatio: metadata?.aspectRatio,
                    provider: job.provider
                )
                
                try await SupabaseManager.shared.client.database
                    .from("user_media")
                    .insert(imageMetadata)
                    .execute()
                
                print("[JobStatusManager] 💾 Image metadata saved to database")
                
                // Post notification that image was saved (for Profile page refresh)
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ImageSavedToDatabase"),
                        object: nil,
                        userInfo: [
                            "userId": userId,
                            "imageUrl": supabaseImageURL
                        ]
                    )
                }
                
            } else if job.job_type == "video" {
                // MARK: Process Video
                
                // Download video from API result URL
                let (videoData, response) = try await URLSession.shared.data(from: url)
                
                guard videoData.count > 0 else {
                    print("[JobStatusManager] Downloaded video is empty")
                    return
                }
                
                print("[JobStatusManager] 📦 Video downloaded: \(videoData.count) bytes")
                
                // Detect file extension
                var fileExtension = "mp4"
                if let mimeType = (response as? HTTPURLResponse)?.mimeType {
                    if mimeType.contains("webm") { fileExtension = "webm" }
                    else if mimeType.contains("quicktime") { fileExtension = "mov" }
                } else if resultUrl.hasSuffix(".webm") { fileExtension = "webm" }
                else if resultUrl.hasSuffix(".mov") { fileExtension = "mov" }
                
                // Generate thumbnail
                let thumbnail = await SupabaseManager.shared.generateVideoThumbnail(from: videoData)
                var thumbnailUrl: String? = nil
                
                if let thumbnail = thumbnail {
                    thumbnailUrl = try? await SupabaseManager.shared.uploadImage(
                        image: thumbnail,
                        userId: userId,
                        modelName: "\(modelName)_thumbnail"
                    )
                }
                
                // Upload video to Supabase storage
                let supabaseVideoURL = try await SupabaseManager.shared.uploadVideo(
                    videoData: videoData,
                    userId: userId,
                    modelName: modelName,
                    fileExtension: fileExtension
                )
                
                print("[JobStatusManager] ☁️ Video uploaded to Supabase: \(supabaseVideoURL)")
                
                // Show success notification with green bar and badge
                await MainActor.run {
                    let title = metadata?.title ?? "Video"
                    
                    // Check if we have an existing notification for this task
                    if let existingNotificationId = taskNotificationMap[job.task_id] {
                        // Update the existing notification to show completion
                        NotificationManager.shared.markAsCompleted(id: existingNotificationId, message: "✅ \(title) ready!")
                        taskNotificationMap.removeValue(forKey: job.task_id)
                        print("[JobStatusManager] ✅ Updated existing notification \(existingNotificationId)")
                    } else {
                        // Create a new notification (fallback for jobs started before app was listening)
                        let notificationId = NotificationManager.shared.showNotification(
                            title: title,
                            message: "Processing...",
                            progress: 1.0,
                            thumbnailImage: thumbnail
                        )
                        NotificationManager.shared.markAsCompleted(id: notificationId, message: "✅ \(title) ready!")
                        print("[JobStatusManager] ✅ Created new success notification")
                    }
                }
                
                // Save metadata to user_media table
                let videoMetadata = VideoMetadata(
                    userId: userId,
                    videoUrl: supabaseVideoURL,
                    thumbnailUrl: thumbnailUrl,
                    model: modelName,
                    title: metadata?.title,
                    cost: metadata?.cost,
                    type: metadata?.type,
                    endpoint: metadata?.endpoint,
                    fileExtension: fileExtension,
                    prompt: metadata?.prompt,
                    aspectRatio: metadata?.aspectRatio,
                    duration: metadata?.duration,
                    resolution: metadata?.resolution
                )
                
                try await SupabaseManager.shared.client.database
                    .from("user_media")
                    .insert(videoMetadata)
                    .execute()
                
                print("[JobStatusManager] 💾 Video metadata saved to database")
                
                // Post notification that video was saved (for Profile page refresh)
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("VideoSavedToDatabase"),
                        object: nil,
                        userInfo: [
                            "userId": userId,
                            "videoUrl": supabaseVideoURL
                        ]
                    )
                }
            }
            
            // Clean up the pending job after successful processing
            try? await SupabaseManager.shared.deletePendingJob(taskId: job.task_id)
            print("[JobStatusManager] 🧹 Pending job cleaned up: \(job.task_id)")
            
        } catch {
            print("[JobStatusManager] ❌ Error processing completed job: \(error)")
        }
    }
}
