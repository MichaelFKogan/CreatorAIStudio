import AVFoundation
import Foundation

class VideoCacheManager {
    static let shared = VideoCacheManager()
    
    private let cacheDirectory: URL
    private let maxCacheSize: Int64 = 500 * 1024 * 1024 // 500 MB
    
    private init() {
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = cachesDir.appendingPathComponent("VideoCache", isDirectory: true)
        
        // Create cache directory if it doesn't exist
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Clean old cache files (without extensions) and manage cache size
        Task {
            await cleanOldCacheFiles()
            await cleanCacheIfNeeded()
        }
    }
    
    /// Removes old cache files that don't have proper extensions (from previous version)
    private func cleanOldCacheFiles() async {
        guard let files = try? FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else { return }
        
        for file in files {
            // Remove files without video extensions
            let ext = file.pathExtension.lowercased()
            if ext.isEmpty || !["mp4", "webm", "mov", "m4v"].contains(ext) {
                try? FileManager.default.removeItem(at: file)
                print("🗑️ Removed old cache file without extension: \(file.lastPathComponent)")
            }
        }
    }
    
    /// Returns a cached URL if available, otherwise downloads and caches the video
    func getCachedVideoURL(for remoteURL: URL) async -> URL? {
        // Create cache key from URL, preserving file extension
        let urlString = remoteURL.absoluteString
        let fileExtension = remoteURL.pathExtension.isEmpty ? "mp4" : remoteURL.pathExtension
        
        // Create a safe cache key (base64 but replace invalid filename characters)
        let cacheKeyBase = urlString.data(using: .utf8)?.base64EncodedString() ?? remoteURL.lastPathComponent
        let cacheKey = cacheKeyBase
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
        
        let cachedFileURL = cacheDirectory.appendingPathComponent(cacheKey).appendingPathExtension(fileExtension)
        
        // Check if file exists in cache and is valid
        if FileManager.default.fileExists(atPath: cachedFileURL.path) {
            // Verify file size is reasonable (at least 1KB)
            if let attributes = try? FileManager.default.attributesOfItem(atPath: cachedFileURL.path),
               let fileSize = attributes[.size] as? Int64,
               fileSize > 1024 {
                print("✅ Video cache hit: \(remoteURL.lastPathComponent) (\(Double(fileSize) / 1_000_000) MB)")
                return cachedFileURL
            } else {
                // Invalid cached file, remove it
                print("⚠️ Invalid cached file, removing: \(cachedFileURL.lastPathComponent)")
                try? FileManager.default.removeItem(at: cachedFileURL)
            }
        }
        
        // Download and cache
        print("📥 Downloading video for caching: \(remoteURL.lastPathComponent)")
        do {
            let (data, _) = try await URLSession.shared.data(from: remoteURL)
            try data.write(to: cachedFileURL)
            print("✅ Video cached: \(remoteURL.lastPathComponent) (\(Double(data.count) / 1_000_000) MB)")
            
            // Verify the file was written correctly
            guard FileManager.default.fileExists(atPath: cachedFileURL.path) else {
                print("❌ Cached file not found after write")
                return nil
            }
            
            // Clean cache if needed
            await cleanCacheIfNeeded()
            
            return cachedFileURL
        } catch {
            print("❌ Failed to cache video: \(error)")
            return nil
        }
    }
    
    /// Cleans cache if it exceeds max size
    private func cleanCacheIfNeeded() async {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
        ) else { return }
        
        // Calculate total size
        var totalSize: Int64 = 0
        var fileAttributes: [(url: URL, size: Int64, date: Date)] = []
        
        for file in files {
            if let attributes = try? file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
               let size = attributes.fileSize,
               let date = attributes.contentModificationDate {
                totalSize += Int64(size)
                fileAttributes.append((file, Int64(size), date))
            }
        }
        
        // If cache is too large, delete oldest files
        if totalSize > maxCacheSize {
            fileAttributes.sort { $0.date < $1.date } // Oldest first
            
            var sizeToRemove = totalSize - maxCacheSize
            for fileAttr in fileAttributes {
                if sizeToRemove <= 0 { break }
                
                try? FileManager.default.removeItem(at: fileAttr.url)
                sizeToRemove -= fileAttr.size
                print("🗑️ Removed cached video: \(fileAttr.url.lastPathComponent)")
            }
        }
    }
    
    /// Clears all cached videos
    func clearCache() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}
