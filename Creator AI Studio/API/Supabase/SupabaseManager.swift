//
//  SupabaseManager.swift
//  AI Photo Generation
//
//  Created by Mike K on 10/18/25.
//

import AVFoundation
import Foundation
import Supabase
import UIKit

class SupabaseManager {
    static let shared = SupabaseManager()

    // MARK: CLIENT SETUP

    // Supabase client configured via SupabaseConfig (loads from Info.plist)
    let client: SupabaseClient

    // Storage buckets (create these in Supabase dashboard)
    private let imageStorageBucket = "user-generated-images"
    private let videoStorageBucket = "user-generated-videos"

    private init() {
        let supabaseURL = URL(string: SupabaseConfig.supabaseURL)!
        let supabaseKey = SupabaseConfig.supabaseAnonKey
        
        client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey
        )
    }

    // MARK: UPLOAD IMAGE

    /// Uploads an image to Supabase Storage and returns the public URL

    /// - Parameters:
    ///   - image: The UIImage to upload
    ///   - userId: The user's ID for organizing files
    ///   - modelName: The AI model name used for generation
    ///   - maxRetries: Maximum number of retry attempts for upload

    /// - Returns: The public URL of the uploaded image in Supabase Storage

    func uploadImage(image: UIImage, userId: String, modelName: String, maxRetries: Int = 3) async throws -> String {
        // Convert UIImage to JPEG data
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            throw NSError(domain: "ImageError", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG"])
        }

        // Create unique filename: userId/timestamp_modelName.jpg
        let timestamp = Int(Date().timeIntervalSince1970)

        // Sanitize modelName: only allow letters, numbers, dots, underscores, and hyphens
        // Replace any invalid characters with underscore
        let sanitizedModelName = modelName.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-")).inverted)
            .joined(separator: "_")

        let filename = "\(userId)/\(timestamp)_\(sanitizedModelName).jpg"

        print("[Storage] Uploading image to: \(imageStorageBucket)/\(filename)")
        print("[Storage] Original model name: \(modelName)")
        print("[Storage] Sanitized model name: \(sanitizedModelName)")

        // Retry logic for upload
        var lastError: Error?
        for attempt in 1 ... maxRetries {
            do {
                // Upload to Supabase Storage
                let uploadResponse = try await client.storage
                    .from(imageStorageBucket)
                    .upload(
                        filename, // path
                        data: imageData, // new argument label `data`
                        options: FileOptions(
                            contentType: "image/jpeg",
                            upsert: false
                        )
                    )

                print("[Storage] Upload successful: \(uploadResponse)")

                // Get the public URL for the uploaded file
                let publicURL = try client.storage
                    .from(imageStorageBucket)
                    .getPublicURL(path: filename)

                print("[Storage] Public URL: \(publicURL)")

                return publicURL.absoluteString

            } catch {
                lastError = error
                print("⚠️ Upload attempt \(attempt)/\(maxRetries) failed: \(error)")

                if attempt < maxRetries {
                    // Exponential backoff: 2^attempt seconds
                    let delay = pow(2.0, Double(attempt))
                    print("[Storage] Retrying in \(delay) seconds...")
                    try await Task.sleep(for: .seconds(delay))
                } else {
                    print("❌ All upload attempts failed")
                    throw error
                }
            }
        }

        throw lastError ?? NSError(domain: "StorageError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Upload failed"])
    }

    // // MARK: DOWN/UPLOAD IMAGE

    // /// Downloads an image from an External URL and uploads it to Supabase Storage

    // /// - Parameters:
    // ///   - urlString: The URL of the image to download
    // ///   - userId: The user's ID
    // ///   - modelName: The AI model name

    // /// - Returns: The Supabase Storage public URL

    // func downloadAndUploadImage(from urlString: String, userId: String, modelName: String) async throws -> String {
    //     guard let url = URL(string: urlString) else {
    //         throw NSError(domain: "URLError", code: -1,
    //                       userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
    //     }

    //     // Download the image
    //     let (data, _) = try await URLSession.shared.data(from: url)

    //     guard let image = UIImage(data: data) else {
    //         throw NSError(domain: "ImageError", code: -1,
    //                       userInfo: [NSLocalizedDescriptionKey: "Failed to decode image"])
    //     }

    //     // Upload to Supabase Storage
    //     return try await uploadImage(image: image, userId: userId, modelName: modelName)
    // }

    // MARK: UPLOAD VIDEO

    /// Uploads a video to Supabase Storage and returns the public URL

    /// - Parameters:
    ///   - videoData: The video data to upload
    ///   - userId: The user's ID for organizing files
    ///   - modelName: The AI model name used for generation
    ///   - fileExtension: The video file extension (e.g., "mp4", "webm")
    ///   - maxRetries: Maximum number of retry attempts for upload

    /// - Returns: The public URL of the uploaded video in Supabase Storage

    func uploadVideo(videoData: Data, userId: String, modelName: String, fileExtension: String, maxRetries: Int = 3) async throws -> String {
        // Safety check: prevent uploading empty files
        guard videoData.count > 0 else {
            throw NSError(
                domain: "StorageError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Cannot upload empty video data (0 bytes)"]
            )
        }
        
        // Create unique filename: userId/timestamp_modelName.extension
        let timestamp = Int(Date().timeIntervalSince1970)
        let sanitizedModelName = modelName.replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        let filename = "\(userId)/\(timestamp)_\(sanitizedModelName).\(fileExtension)"

        print("[Storage] Uploading video to: \(videoStorageBucket)/\(filename)")
        print("[Storage] Video size: \(videoData.count) bytes (\(Double(videoData.count) / 1_000_000) MB)")

        // Determine content type based on extension
        let contentType: String
        switch fileExtension.lowercased() {
        case "mp4":
            contentType = "video/mp4"
        case "webm":
            contentType = "video/webm"
        case "mov":
            contentType = "video/quicktime"
        case "avi":
            contentType = "video/x-msvideo"
        default:
            contentType = "video/mp4" // Default to mp4
        }

        // Retry logic for upload
        var lastError: Error?
        for attempt in 1 ... maxRetries {
            do {
                // Upload to Supabase Storage
                let uploadResponse = try await client.storage
                    .from(videoStorageBucket)
                    .upload(
                        filename,
                        data: videoData,
                        options: FileOptions(
                            contentType: contentType,
                            upsert: false
                        )
                    )

                print("[Storage] Video upload successful: \(uploadResponse)")

                // Get the public URL for the uploaded file
                let publicURL = try client.storage
                    .from(videoStorageBucket)
                    .getPublicURL(path: filename)

                print("[Storage] Video public URL: \(publicURL)")

                return publicURL.absoluteString

            } catch {
                lastError = error
                print("⚠️ Video upload attempt \(attempt)/\(maxRetries) failed: \(error)")

                if attempt < maxRetries {
                    // Exponential backoff: 2^attempt seconds
                    let delay = pow(2.0, Double(attempt))
                    print("[Storage] Retrying in \(delay) seconds...")
                    try await Task.sleep(for: .seconds(delay))
                } else {
                    print("❌ All video upload attempts failed")
                    throw error
                }
            }
        }

        throw lastError ?? NSError(domain: "StorageError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Video upload failed"])
    }

    // // MARK: DOWN/UPLOAD VIDEO

    // /// Downloads a video from a URL and uploads it to Supabase Storage

    // /// - Parameters:
    // ///   - urlString: The URL of the video to download
    // ///   - userId: The user's ID
    // ///   - modelName: The AI model name
    // ///   - fileExtension: The video file extension

    // /// - Returns: The Supabase Storage public URL

    // func downloadAndUploadVideo(from urlString: String, userId: String, modelName: String, fileExtension: String = "mp4") async throws -> String {
    //     guard let url = URL(string: urlString) else {
    //         throw NSError(domain: "URLError", code: -1,
    //                       userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
    //     }

    //     print("[Storage] Downloading video from: \(urlString)")

    //     // Download the video
    //     let (data, _) = try await URLSession.shared.data(from: url)

    //     print("[Storage] Video downloaded, size: \(data.count) bytes")

    //     // Upload to Supabase Storage
    //     return try await uploadVideo(videoData: data, userId: userId, modelName: modelName, fileExtension: fileExtension)
    // }

    // MARK: VIDEO THUMBNAIL

    /// Generates a thumbnail from video data

    /// - Parameter videoData: The video data
    /// - Returns: UIImage thumbnail or nil if generation fails

    func generateVideoThumbnail(from videoData: Data) async -> UIImage? {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mp4")

        do {
            try videoData.write(to: tempURL)

            let asset = AVURLAsset(url: tempURL)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true

            return try await withCheckedThrowingContinuation { continuation in
                let time = CMTime(seconds: 1, preferredTimescale: 60)
                imageGenerator.generateCGImageAsynchronously(for: time) { cgImage, _, error in
                    // Clean up temp file
                    try? FileManager.default.removeItem(at: tempURL)

                    if let cgImage = cgImage {
                        continuation.resume(returning: UIImage(cgImage: cgImage))
                    } else if let error = error {
                        print("❌ Failed to generate video thumbnail: \(error)")
                        continuation.resume(returning: nil)
                    } else {
                        print("❌ Failed to generate video thumbnail: unknown error")
                        continuation.resume(returning: nil)
                    }
                }
            }

        } catch {
            print("❌ Failed to write temp video file: \(error)")
            try? FileManager.default.removeItem(at: tempURL)
            return nil
        }
    }
    
    // MARK: - USER DEVICES (Push Notifications)

    /// Upserts the current device token for a user (for push notifications on job completion).
    /// Call this when the device token is received or when the user signs in.
    func upsertDeviceToken(userId: String, deviceToken: String) async throws {
        let record = UserDeviceRecord(
            user_id: userId,
            device_token: deviceToken,
            updated_at: Date()
        )
        try await client.database
            .from("user_devices")
            .upsert(record)
            .execute()
        print("[UserDevices] Upserted device token for user: \(userId.prefix(8))...")
    }

    // MARK: - PENDING JOBS (Webhook Support)

    /// Creates a new pending job record in the database
    /// - Parameter job: The pending job to create
    func createPendingJob(_ job: PendingJob) async throws {
        let insertModel = PendingJobInsert(from: job)
        
        try await client.database
            .from("pending_jobs")
            .insert(insertModel)
            .execute()
        
        print("[PendingJobs] Created job with taskId: \(job.task_id)")
    }
    
    /// Fetches all pending jobs for a user
    /// - Parameter userId: The user's ID
    /// - Returns: Array of pending jobs
    func fetchPendingJobs(userId: String) async throws -> [PendingJob] {
        let jobs: [PendingJob] = try await client.database
            .from("pending_jobs")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        print("[PendingJobs] Fetched \(jobs.count) jobs for user: \(userId)")
        return jobs
    }
    
    /// Fetches a specific pending job by task ID
    /// - Parameter taskId: The task ID to look up
    /// - Returns: The pending job if found
    func fetchPendingJob(taskId: String) async throws -> PendingJob? {
        let jobs: [PendingJob] = try await client.database
            .from("pending_jobs")
            .select()
            .eq("task_id", value: taskId)
            .limit(1)
            .execute()
            .value
        
        return jobs.first
    }
    
    /// Updates a pending job's status
    /// - Parameters:
    ///   - taskId: The task ID to update
    ///   - status: The new status
    ///   - resultUrl: Optional result URL (for completed jobs)
    ///   - errorMessage: Optional error message (for failed jobs)
    func updatePendingJobStatus(
        taskId: String,
        status: JobStatus,
        resultUrl: String? = nil,
        errorMessage: String? = nil
    ) async throws {
        var updateData: [String: AnyJSON] = [
            "status": .string(status.rawValue),
            "updated_at": .string(ISO8601DateFormatter().string(from: Date()))
        ]
        
        if let resultUrl = resultUrl {
            updateData["result_url"] = .string(resultUrl)
            updateData["completed_at"] = .string(ISO8601DateFormatter().string(from: Date()))
        }
        
        if let errorMessage = errorMessage {
            updateData["error_message"] = .string(errorMessage)
            updateData["completed_at"] = .string(ISO8601DateFormatter().string(from: Date()))
        }
        
        try await client.database
            .from("pending_jobs")
            .update(updateData)
            .eq("task_id", value: taskId)
            .execute()
        
        print("[PendingJobs] Updated job \(taskId) to status: \(status.rawValue)")
    }
    
    /// Updates the provider for a pending job
    /// - Parameters:
    ///   - taskId: The task ID to update
    ///   - provider: The new provider name
    func updatePendingJobProvider(taskId: String, provider: String) async throws {
        let updateData: [String: AnyJSON] = [
            "provider": .string(provider),
            "updated_at": .string(ISO8601DateFormatter().string(from: Date()))
        ]
        
        try await client.database
            .from("pending_jobs")
            .update(updateData)
            .eq("task_id", value: taskId)
            .execute()
        
        print("[PendingJobs] Updated job \(taskId) provider to: \(provider)")
    }
    
    /// Updates the metadata for a pending job
    /// - Parameters:
    ///   - taskId: The task ID to update
    ///   - metadata: The new metadata
    func updatePendingJobMetadata(taskId: String, metadata: PendingJobMetadata) async throws {
        // Use Supabase's PostgrestFilterBuilder with proper JSON encoding
        struct MetadataUpdate: Encodable {
            let metadata: PendingJobMetadata
            let updated_at: String
        }
        
        let update = MetadataUpdate(
            metadata: metadata,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
        
        // Debug: Log what we're updating
        if let falRequestId = metadata.falRequestId {
            print("[PendingJobs] Updating job \(taskId) metadata with Fal.ai request_id: \(falRequestId)")
        }
        
        try await client.database
            .from("pending_jobs")
            .update(update)
            .eq("task_id", value: taskId)
            .execute()
        
        // Verify the update worked by fetching the job
        if let updatedJob = try? await fetchPendingJob(taskId: taskId) {
            if let updatedMetadata = updatedJob.metadata,
               let falRequestId = updatedMetadata.falRequestId {
                print("[PendingJobs] ✅ Verified: Job \(taskId) now has fal_request_id: \(falRequestId)")
            } else {
                print("[PendingJobs] ⚠️ Warning: Job \(taskId) metadata update may have failed - fal_request_id not found")
            }
        }
        
        print("[PendingJobs] Updated job \(taskId) metadata with Fal.ai request_id")
    }
    
    /// Deletes a pending job
    /// - Parameter taskId: The task ID to delete
    func deletePendingJob(taskId: String) async throws {
        try await client.database
            .from("pending_jobs")
            .delete()
            .eq("task_id", value: taskId)
            .execute()
        
        print("[PendingJobs] Deleted job with taskId: \(taskId)")
    }
    
    /// Cleans up old completed/failed jobs (older than specified days)
    /// - Parameter olderThanDays: Number of days after which to delete jobs
    /// - Returns: Number of deleted jobs
    func cleanupOldPendingJobs(olderThanDays: Int = 7) async throws -> Int {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -olderThanDays, to: Date())!
        let cutoffString = ISO8601DateFormatter().string(from: cutoffDate)
        
        // Fetch count first
        let jobs: [PendingJob] = try await client.database
            .from("pending_jobs")
            .select()
            .in("status", values: ["completed", "failed"])
            .lt("completed_at", value: cutoffString)
            .execute()
            .value
        
        let count = jobs.count
        
        if count > 0 {
            try await client.database
                .from("pending_jobs")
                .delete()
                .in("status", values: ["completed", "failed"])
                .lt("completed_at", value: cutoffString)
                .execute()
            
            print("[PendingJobs] Cleaned up \(count) old jobs")
        }
        
        return count
    }
    
    /// Cleans up orphaned pending jobs that are stuck in "pending" status
    /// These are jobs where the webhook submission failed but the job wasn't cleaned up
    /// (This can happen due to network failures during webhook submission before the fix was applied)
    /// - Parameter olderThanMinutes: Number of minutes after which to consider a pending job orphaned
    /// - Returns: Number of deleted orphaned jobs
    func cleanupOrphanedPendingJobs(olderThanMinutes: Int = 30) async throws -> Int {
        let cutoffDate = Calendar.current.date(byAdding: .minute, value: -olderThanMinutes, to: Date())!
        let cutoffString = ISO8601DateFormatter().string(from: cutoffDate)
        
        // Fetch orphaned jobs (stuck in pending status for too long)
        let jobs: [PendingJob] = try await client.database
            .from("pending_jobs")
            .select()
            .eq("status", value: "pending")
            .lt("created_at", value: cutoffString)
            .execute()
            .value
        
        let count = jobs.count
        
        if count > 0 {
            // Delete the orphaned jobs
            try await client.database
                .from("pending_jobs")
                .delete()
                .eq("status", value: "pending")
                .lt("created_at", value: cutoffString)
                .execute()
            
            print("[PendingJobs] 🧹 Cleaned up \(count) orphaned pending jobs (stuck for > \(olderThanMinutes) minutes)")
        }
        
        return count
    }
    
    /// Marks stuck jobs as failed (jobs in pending or processing status for too long)
    /// Saves them to user_media for tracking in UsageView, then deletes from pending_jobs
    /// Videos typically take longer, so we use different timeouts for different job types
    /// - Parameter olderThanMinutes: Number of minutes after which to consider a job stuck
    /// - Returns: Number of jobs deleted
    func markStuckJobsAsFailed(olderThanMinutes: Int? = nil) async throws -> Int {
        let now = Date()
        
        // Fetch stuck jobs (pending or processing status for too long)
        // Both video and image jobs timeout after 10 minutes
        let timeoutCutoff = Calendar.current.date(byAdding: .minute, value: -(olderThanMinutes ?? 10), to: now)!
        
        let timeoutCutoffString = ISO8601DateFormatter().string(from: timeoutCutoff)
        
        // Fetch stuck jobs (both video and image)
        let stuckJobs: [PendingJob] = try await client.database
            .from("pending_jobs")
            .select()
            .in("status", values: ["pending", "processing"])
            .lt("created_at", value: timeoutCutoffString)
            .execute()
            .value
        
        let count = stuckJobs.count
        
        if count > 0 {
            // Save each stuck job to user_media before deleting from pending_jobs
            for job in stuckJobs {
                let errorMessage = "Generation timed out after 10 minutes. Please try again."
                
                // Save to user_media for tracking in UsageView
                if job.job_type == "image" {
                    let failedMetadata = ImageMetadata(
                        userId: job.user_id,
                        imageUrl: "", // Empty for failed attempts
                        model: job.metadata?.model,
                        title: job.metadata?.title,
                        cost: job.metadata?.cost, // Include cost since payment was taken
                        type: job.metadata?.type,
                        endpoint: job.metadata?.endpoint,
                        prompt: job.metadata?.prompt,
                        aspectRatio: job.metadata?.aspectRatio,
                        provider: job.provider,
                        status: "failed",
                        errorMessage: errorMessage
                    )
                    
                    try? await client.database
                        .from("user_media")
                        .insert(failedMetadata)
                        .execute()
                } else if job.job_type == "video" {
                    let failedMetadata = VideoMetadata(
                        userId: job.user_id,
                        videoUrl: "", // Empty for failed attempts
                        thumbnailUrl: nil,
                        model: job.metadata?.model,
                        title: job.metadata?.title,
                        cost: job.metadata?.cost, // Include cost since payment was taken
                        type: job.metadata?.type,
                        endpoint: job.metadata?.endpoint,
                        fileExtension: "mp4",
                        prompt: job.metadata?.prompt,
                        aspectRatio: job.metadata?.aspectRatio,
                        duration: job.metadata?.duration,
                        resolution: job.metadata?.resolution,
                        status: "failed",
                        errorMessage: errorMessage
                    )
                    
                    try? await client.database
                        .from("user_media")
                        .insert(failedMetadata)
                        .execute()
                }
                
                // Now delete from pending_jobs
                try await deletePendingJob(taskId: job.task_id)
            }
            
            print("[PendingJobs] 🗑️ Deleted \(count) timed-out jobs and saved to user_media")
        }
        
        return count
    }
}

// MARK: - User Device Record (Push Notifications)

/// Encodable record for user_devices table (APNs device token per user).
private struct UserDeviceRecord: Encodable {
    let user_id: String
    let device_token: String
    let updated_at: Date
}
