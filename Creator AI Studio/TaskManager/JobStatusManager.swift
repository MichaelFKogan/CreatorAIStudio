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
    
    /// Timer for periodic polling of job status (fallback if Realtime fails)
    private var pollingTask: Task<Void, Never>?
    
    /// Decoder configured for Supabase's ISO8601 date format
    /// Handles various formats including 6-digit fractional seconds with timezone offsets
    private lazy var supabaseDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // ISO8601DateFormatter only supports up to 3-digit fractional seconds (milliseconds)
            // Supabase can return 6-digit fractional seconds (microseconds), so we need DateFormatter
            
            // First, try DateFormatter with the most common formats
            let flexibleFormatter = DateFormatter()
            flexibleFormatter.locale = Locale(identifier: "en_US_POSIX")
            
            // Try various date formats in order of likelihood
            let dateFormats = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ",  // 6-digit microseconds with timezone +00:00
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZ",   // 6-digit microseconds with timezone +0000 (no colon)
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",    // 6-digit microseconds with Z
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",        // 6-digit microseconds without timezone
                "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ",     // 3-digit milliseconds with timezone +00:00
                "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZ",      // 3-digit milliseconds with timezone +0000
                "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",       // 3-digit milliseconds with Z
                "yyyy-MM-dd'T'HH:mm:ss.SSS",          // 3-digit milliseconds without timezone
                "yyyy-MM-dd'T'HH:mm:ssZZZZZ",         // No fractional seconds with timezone +00:00
                "yyyy-MM-dd'T'HH:mm:ssZZZZ",          // No fractional seconds with timezone +0000
                "yyyy-MM-dd'T'HH:mm:ss'Z'"            // No fractional seconds with Z
            ]
            
            for format in dateFormats {
                flexibleFormatter.dateFormat = format
                if let date = flexibleFormatter.date(from: dateString) {
                    return date
                }
            }
            
            // Fallback: Try ISO8601DateFormatter (only works for standard formats)
            let isoFormatter = ISO8601DateFormatter()
            
            // Try with fractional seconds and timezone
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone]
            if let date = isoFormatter.date(from: dateString) {
                return date
            }
            
            // Try with fractional seconds without timezone
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFormatter.date(from: dateString) {
                return date
            }
            
            // Try without fractional seconds but with timezone
            isoFormatter.formatOptions = [.withInternetDateTime, .withTimeZone]
            if let date = isoFormatter.date(from: dateString) {
                return date
            }
            
            // Try without fractional seconds
            isoFormatter.formatOptions = [.withInternetDateTime]
            if let date = isoFormatter.date(from: dateString) {
                return date
            }
            
            // If all else fails, log the problematic date and throw
            print("[JobStatusManager] ⚠️ Failed to decode date: \(dateString)")
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
        
        // Mark stuck jobs as failed (jobs in pending/processing status for too long)
        await markStuckJobsAsFailed()
        
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
    
    /// Mark stuck jobs as failed
    private func markStuckJobsAsFailed() async {
        do {
            // Get stuck jobs before they're deleted so we can update notifications
            let now = Date()
            // Both video and image jobs timeout after 10 minutes
            let timeoutCutoff = Calendar.current.date(byAdding: .minute, value: -10, to: now)!
            
            let timeoutCutoffString = ISO8601DateFormatter().string(from: timeoutCutoff)
            
            // Fetch stuck jobs (both video and image timeout after 10 minutes)
            let stuckJobs: [PendingJob] = try await SupabaseManager.shared.client.database
                .from("pending_jobs")
                .select()
                .in("status", values: ["pending", "processing"])
                .lt("created_at", value: timeoutCutoffString)
                .execute()
                .value
            
            // Update notifications for stuck jobs before they're deleted
            for job in stuckJobs {
                let errorMessage = "Generation timed out after 10 minutes. Please try again."
                
                if let notificationId = taskNotificationMap[job.task_id] {
                    await MainActor.run {
                        NotificationManager.shared.markAsFailed(
                            id: notificationId,
                            errorMessage: errorMessage
                        )
                        print("[JobStatusManager] ⚠️ Marked notification as failed for stuck job: \(job.task_id)")
                    }
                    // Remove the notification mapping
                    taskNotificationMap.removeValue(forKey: job.task_id)
                }
            }
            
            // Now call the function to actually delete them
            let failedCount = try await SupabaseManager.shared.markStuckJobsAsFailed()
            if failedCount > 0 {
                print("[JobStatusManager] ⏱️ Marked \(failedCount) stuck jobs as failed and updated notifications")
            }
        } catch {
            print("[JobStatusManager] ⚠️ Failed to mark stuck jobs as failed: \(error.localizedDescription)")
        }
    }
    
    /// Stop listening for updates
    func stopListening() async {
        // Cancel polling task
        pollingTask?.cancel()
        pollingTask = nil
        
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
    
    /// Get webhook taskId for a notification ID (reverse lookup)
    func getWebhookTaskId(for notificationId: UUID) -> String? {
        for (taskId, notifId) in taskNotificationMap where notifId == notificationId {
            return taskId
        }
        return nil
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
            
            // Check for and mark any stuck jobs as failed
            await markStuckJobsAsFailed()
            
            // Process any already-completed jobs that haven't been processed yet
            for job in jobs where job.isComplete && job.hasResult {
                print("[JobStatusManager] Found completed job to process: \(job.task_id)")
                await handleJobCompletion(job)
            }
            
            // Also check for stuck jobs in the fetched list and save to user_media before deleting
            let now = Date()
            for job in jobs where !job.isComplete {
                guard let createdAt = job.created_at else { continue }
                let jobAge = now.timeIntervalSince(createdAt) // Positive value for past dates
                let timeoutMinutes: Double = 10 // Both video and image timeout after 10 minutes
                
                if jobAge > timeoutMinutes * 60 {
                    // Job is stuck, get actual error from provider if possible
                    let defaultErrorMessage = "Generation timed out after 10 minutes. Please try again."
                    let actualErrorMessage = await getActualErrorMessage(for: job, defaultMessage: defaultErrorMessage)
                    
                    // Update notification if one exists
                    if let notificationId = taskNotificationMap[job.task_id] {
                        await MainActor.run {
                            NotificationManager.shared.markAsFailed(
                                id: notificationId,
                                errorMessage: actualErrorMessage
                            )
                            print("[JobStatusManager] ⚠️ Marked notification as failed for timed-out job: \(job.task_id)")
                        }
                        // Remove the notification mapping
                        taskNotificationMap.removeValue(forKey: job.task_id)
                    }
                    
                    // Use the shared handler for timed-out jobs
                    await handleTimedOutJob(job, errorMessage: actualErrorMessage)
                }
            }
            
        } catch {
            print("[JobStatusManager] ❌ Error fetching pending jobs: \(error)")
            if let decodingError = error as? DecodingError {
                print("[JobStatusManager] Decoding error details: \(decodingError)")
            }
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
        
        // Start periodic polling as a fallback (checks every 30 seconds)
        startPeriodicPolling(userId: userId)
    }
    
    /// Start periodic polling to check for timed-out jobs (fallback if Realtime fails)
    private func startPeriodicPolling(userId: String) {
        // Cancel any existing polling task
        pollingTask?.cancel()
        
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                // Wait 30 seconds before checking
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                
                guard let self = self, self.currentUserId == userId else {
                    break
                }
                
                // Check for timed-out jobs
                await self.checkForTimedOutJobs(userId: userId)
            }
        }
    }
    
    /// Check for timed-out jobs and handle them
    private func checkForTimedOutJobs(userId: String) async {
        do {
            let response = try await SupabaseManager.shared.client.database
                .from("pending_jobs")
                .select()
                .eq("user_id", value: userId)
                .in("status", values: ["pending", "processing"])
                .execute()
            
            let jobs = try supabaseDecoder.decode([PendingJob].self, from: response.data)
            let now = Date()
            let timeoutSeconds: Double = 10 * 60 // 10 minutes
            
            for job in jobs {
                guard let createdAt = job.created_at else { continue }
                let jobAge = now.timeIntervalSince(createdAt)
                
                if jobAge > timeoutSeconds {
                    // Job has timed out, get actual error from provider if possible
                    let defaultErrorMessage = "Generation timed out after 10 minutes. Please try again."
                    let actualErrorMessage = await getActualErrorMessage(for: job, defaultMessage: defaultErrorMessage)
                    
                    // Update notification if one exists
                    if let notificationId = taskNotificationMap[job.task_id] {
                        await MainActor.run {
                            NotificationManager.shared.markAsFailed(
                                id: notificationId,
                                errorMessage: actualErrorMessage
                            )
                            print("[JobStatusManager] ⚠️ Marked notification as failed for timed-out job: \(job.task_id)")
                        }
                        taskNotificationMap.removeValue(forKey: job.task_id)
                    }
                    
                    // Save to user_media and delete from pending_jobs
                    await handleTimedOutJob(job, errorMessage: actualErrorMessage)
                }
            }
        } catch {
            print("[JobStatusManager] ⚠️ Error checking for timed-out jobs: \(error.localizedDescription)")
        }
    }
    
    /// Get the actual error message from the provider if possible, otherwise return default
    private func getActualErrorMessage(for job: PendingJob, defaultMessage: String) async -> String {
        // Only poll Runware for actual error if this is a Runware job
        guard job.provider == "runware" else {
            return defaultMessage
        }
        
        do {
            print("[JobStatusManager] 🔍 Polling Runware for actual status: \(job.task_id)")
            let runwareResponse = try await pollRunwareTaskStatus(taskUUID: job.task_id)
            
            // Check for error in response
            if let error = runwareResponse.error, !error.isEmpty {
                let errorMessage = "Runware error: \(error)"
                print("[JobStatusManager] ✅ Got actual error from Runware: \(error)")
                return errorMessage
            } else if let first = runwareResponse.data.first, let status = first.status {
                let statusLower = status.lowercased()
                if statusLower == "failed" || statusLower == "error" {
                    let errorMessage = "Generation failed with status: \(status)"
                    print("[JobStatusManager] ✅ Got failed status from Runware: \(status)")
                    return errorMessage
                } else {
                    print("[JobStatusManager] ℹ️ Runware status: \(status) (using timeout message)")
                }
            } else {
                print("[JobStatusManager] ℹ️ No specific error from Runware, using timeout message")
            }
        } catch {
            print("[JobStatusManager] ⚠️ Failed to poll Runware status: \(error.localizedDescription)")
        }
        
        return defaultMessage
    }
    
    /// Handle a timed-out job: save to user_media and delete from pending_jobs
    private func handleTimedOutJob(_ job: PendingJob, errorMessage: String) async {
        // Use the provided error message (may have already been enriched with Runware error)
        let finalErrorMessage = errorMessage
        
        do {
            // Save to user_media for tracking in UsageView
            if job.job_type == "image" {
                let failedMetadata = ImageMetadata(
                    userId: job.user_id,
                    imageUrl: "",
                    model: job.metadata?.model,
                    title: job.metadata?.title,
                    cost: job.metadata?.cost,
                    type: job.metadata?.type,
                    endpoint: job.metadata?.endpoint,
                    prompt: job.metadata?.prompt,
                    aspectRatio: job.metadata?.aspectRatio,
                    provider: job.provider,
                    status: "failed",
                    errorMessage: finalErrorMessage
                )
                
                try? await SupabaseManager.shared.client.database
                    .from("user_media")
                    .insert(failedMetadata)
                    .execute()
            } else if job.job_type == "video" {
                let failedMetadata = VideoMetadata(
                    userId: job.user_id,
                    videoUrl: "",
                    thumbnailUrl: nil,
                    model: job.metadata?.model,
                    title: job.metadata?.title,
                    cost: job.metadata?.cost,
                    type: job.metadata?.type,
                    endpoint: job.metadata?.endpoint,
                    fileExtension: "mp4",
                    prompt: job.metadata?.prompt,
                    aspectRatio: job.metadata?.aspectRatio,
                    duration: job.metadata?.duration,
                    resolution: job.metadata?.resolution,
                    status: "failed",
                    errorMessage: finalErrorMessage
                )
                
                try? await SupabaseManager.shared.client.database
                    .from("user_media")
                    .insert(failedMetadata)
                    .execute()
            }
            
            // Delete from pending_jobs
            try await SupabaseManager.shared.deletePendingJob(taskId: job.task_id)
            print("[JobStatusManager] 🗑️ Deleted timed-out job and saved to user_media: \(job.task_id)")
            
            // Remove from pendingJobs list
            await MainActor.run {
                pendingJobs.removeAll { $0.task_id == job.task_id }
            }
        } catch {
            print("[JobStatusManager] ⚠️ Failed to handle timed-out job: \(error)")
        }
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
            if let decodingError = error as? DecodingError {
                print("[JobStatusManager] Decoding error details: \(decodingError)")
            }
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
            
            // Check if job completed or failed
            if job.isComplete {
                if job.jobStatus == .failed {
                    // Handle failed job - update notification
                    await handleJobFailure(job)
                } else {
                    // Handle successful completion
                    await handleJobCompletion(job)
                }
            }
            
        } catch {
            print("[JobStatusManager] ❌ Error decoding updated job: \(error)")
            if let decodingError = error as? DecodingError {
                print("[JobStatusManager] Decoding error details: \(decodingError)")
            }
        }
    }
    
    /// Handle job deletion
    private func handleDelete(_ action: DeleteAction) async {
        // Extract task_id from old record if available
        let oldRecord = action.oldRecord
        if let taskIdValue = oldRecord["task_id"],
           case .string(let taskId) = taskIdValue {
            
            // Check if there's a notification for this task
            if let notificationId = taskNotificationMap[taskId] {
                // Job was deleted (likely due to timeout) - mark notification as failed
                await MainActor.run {
                    NotificationManager.shared.markAsFailed(
                        id: notificationId,
                        errorMessage: "Generation timed out after 10 minutes. Please try again."
                    )
                    print("[JobStatusManager] ⚠️ Marked notification as failed for deleted job: \(taskId)")
                }
                // Remove the notification mapping
                taskNotificationMap.removeValue(forKey: taskId)
            }
            
            await MainActor.run {
                pendingJobs.removeAll { $0.task_id == taskId }
            }
            
            print("[JobStatusManager] 🗑️ Job deleted: \(taskId)")
        }
    }
    
    /// Handle a failed job
    private func handleJobFailure(_ job: PendingJob) async {
        print("[JobStatusManager] ❌ Job failed: \(job.task_id), status: \(job.status)")
        
        // Get error message from job or use default
        let errorMessage = job.error_message ?? "Generation failed"
        
        // Update notification if one exists
        var notificationId: UUID? = taskNotificationMap[job.task_id]
        
        // Fallback: Try to find notification by matching metadata if task_id lookup failed
        if notificationId == nil {
            let metadata = job.metadata
            let title = metadata?.title ?? (job.job_type == "image" ? "Image" : "Video")
            await MainActor.run {
                notificationId = NotificationManager.shared.findNotificationByMetadata(
                    title: title,
                    modelName: metadata?.model,
                    prompt: metadata?.prompt
                )
            }
        }
        
        if let notifId = notificationId {
            await MainActor.run {
                NotificationManager.shared.markAsFailed(
                    id: notifId,
                    errorMessage: errorMessage
                )
                print("[JobStatusManager] ⚠️ Marked notification as failed: \(job.task_id)")
            }
            // Remove the notification mapping
            taskNotificationMap.removeValue(forKey: job.task_id)
        } else {
            print("[JobStatusManager] ⚠️ Could not find notification to mark as failed for task: \(job.task_id)")
        }
        
        // Call registered completion handler if any
        if let handler = completionHandlers[job.task_id] {
            handler(job)
            completionHandlers.removeValue(forKey: job.task_id)
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
                    "resultUrl": job.result_url ?? "",
                    "error": errorMessage
                ]
            )
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
                    var existingNotificationId: UUID? = taskNotificationMap[job.task_id]
                    
                    // Fallback: Try to find notification by matching metadata if task_id lookup failed
                    if existingNotificationId == nil {
                        print("[JobStatusManager] ⚠️ No notification found for task_id: \(job.task_id), trying metadata fallback...")
                        existingNotificationId = NotificationManager.shared.findNotificationByMetadata(
                            title: title,
                            modelName: metadata?.model,
                            prompt: metadata?.prompt
                        )
                        
                        // If found via metadata, register it in the map for future reference
                        if let foundId = existingNotificationId {
                            taskNotificationMap[job.task_id] = foundId
                            print("[JobStatusManager] ✅ Found notification via metadata fallback, registered mapping")
                        }
                    }
                    
                    if let notificationId = existingNotificationId {
                        // Update the existing notification to show completion
                        NotificationManager.shared.markAsCompleted(id: notificationId, message: "✅ \(title) ready!")
                        taskNotificationMap.removeValue(forKey: job.task_id)
                        print("[JobStatusManager] ✅ Updated existing notification \(notificationId)")
                    } else {
                        // Create a new notification (fallback for jobs started before app was listening)
                        let notificationId = NotificationManager.shared.showNotification(
                            title: title,
                            message: "Processing...",
                            progress: 1.0,
                            thumbnailImage: image
                        )
                        NotificationManager.shared.markAsCompleted(id: notificationId, message: "✅ \(title) ready!")
                        print("[JobStatusManager] ✅ Created new success notification (no existing notification found)")
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
                    var existingNotificationId: UUID? = taskNotificationMap[job.task_id]
                    
                    // Fallback: Try to find notification by matching metadata if task_id lookup failed
                    if existingNotificationId == nil {
                        print("[JobStatusManager] ⚠️ No notification found for task_id: \(job.task_id), trying metadata fallback...")
                        existingNotificationId = NotificationManager.shared.findNotificationByMetadata(
                            title: title,
                            modelName: metadata?.model,
                            prompt: metadata?.prompt
                        )
                        
                        // If found via metadata, register it in the map for future reference
                        if let foundId = existingNotificationId {
                            taskNotificationMap[job.task_id] = foundId
                            print("[JobStatusManager] ✅ Found notification via metadata fallback, registered mapping")
                        }
                    }
                    
                    if let notificationId = existingNotificationId {
                        // Update the existing notification to show completion
                        NotificationManager.shared.markAsCompleted(id: notificationId, message: "✅ \(title) ready!")
                        taskNotificationMap.removeValue(forKey: job.task_id)
                        print("[JobStatusManager] ✅ Updated existing notification \(notificationId)")
                    } else {
                        // Create a new notification (fallback for jobs started before app was listening)
                        let notificationId = NotificationManager.shared.showNotification(
                            title: title,
                            message: "Processing...",
                            progress: 1.0,
                            thumbnailImage: thumbnail
                        )
                        NotificationManager.shared.markAsCompleted(id: notificationId, message: "✅ \(title) ready!")
                        print("[JobStatusManager] ✅ Created new success notification (no existing notification found)")
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
            print("[JobStatusManager] Error details: \(error.localizedDescription)")
            
            // If there's a notification for this job, mark it as failed
            var notificationId: UUID? = taskNotificationMap[job.task_id]
            
            // Fallback: Try to find notification by matching metadata if task_id lookup failed
            if notificationId == nil {
                let metadata = job.metadata
                let title = metadata?.title ?? (job.job_type == "image" ? "Image" : "Video")
                await MainActor.run {
                    notificationId = NotificationManager.shared.findNotificationByMetadata(
                        title: title,
                        modelName: metadata?.model,
                        prompt: metadata?.prompt
                    )
                }
            }
            
            if let notifId = notificationId {
                await MainActor.run {
                    NotificationManager.shared.markAsFailed(
                        id: notifId,
                        errorMessage: "Failed to process result: \(error.localizedDescription)"
                    )
                    print("[JobStatusManager] ⚠️ Marked notification as failed due to processing error: \(job.task_id)")
                }
                taskNotificationMap.removeValue(forKey: job.task_id)
            } else {
                print("[JobStatusManager] ⚠️ Could not find notification to mark as failed for task: \(job.task_id)")
            }
        }
    }
}
