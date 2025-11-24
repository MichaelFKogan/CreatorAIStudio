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

    // Replace with your actual Supabase URL and anon key
    let client: SupabaseClient

    // Storage buckets (create these in Supabase dashboard)
    private let imageStorageBucket = "user-generated-images"
    private let videoStorageBucket = "user-generated-videos"

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://inaffymocuppuddsewyq.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImluYWZmeW1vY3VwcHVkZHNld3lxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA2MTQwMDgsImV4cCI6MjA3NjE5MDAwOH0.rsklD7VpItxb2UTCzH1RPYD8HWKpFifekJaUi8JYkNY"
        )
    }

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
                        filename,       // path
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

    /// Downloads an image from a URL and uploads it to Supabase Storage
    /// - Parameters:
    ///   - urlString: The URL of the image to download
    ///   - userId: The user's ID
    ///   - modelName: The AI model name
    /// - Returns: The Supabase Storage public URL
    func downloadAndUploadImage(from urlString: String, userId: String, modelName: String) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "URLError", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        // Download the image
        let (data, _) = try await URLSession.shared.data(from: url)

        guard let image = UIImage(data: data) else {
            throw NSError(domain: "ImageError", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to decode image"])
        }

        // Upload to Supabase Storage
        return try await uploadImage(image: image, userId: userId, modelName: modelName)
    }

    /// Uploads a video to Supabase Storage and returns the public URL
    /// - Parameters:
    ///   - videoData: The video data to upload
    ///   - userId: The user's ID for organizing files
    ///   - modelName: The AI model name used for generation
    ///   - fileExtension: The video file extension (e.g., "mp4", "webm")
    ///   - maxRetries: Maximum number of retry attempts for upload
    /// - Returns: The public URL of the uploaded video in Supabase Storage
    func uploadVideo(videoData: Data, userId: String, modelName: String, fileExtension: String, maxRetries: Int = 3) async throws -> String {
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

    /// Downloads a video from a URL and uploads it to Supabase Storage
    /// - Parameters:
    ///   - urlString: The URL of the video to download
    ///   - userId: The user's ID
    ///   - modelName: The AI model name
    ///   - fileExtension: The video file extension
    /// - Returns: The Supabase Storage public URL
    func downloadAndUploadVideo(from urlString: String, userId: String, modelName: String, fileExtension: String = "mp4") async throws -> String {
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "URLError", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        print("[Storage] Downloading video from: \(urlString)")

        // Download the video
        let (data, _) = try await URLSession.shared.data(from: url)

        print("[Storage] Video downloaded, size: \(data.count) bytes")

        // Upload to Supabase Storage
        return try await uploadVideo(videoData: data, userId: userId, modelName: modelName, fileExtension: fileExtension)
    }

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
}
