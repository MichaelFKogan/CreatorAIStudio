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
        
        // Clean old cache on init
        Task {
            await cleanCacheIfNeeded()
        }
    }
    
    /// Returns a cached URL if available, otherwise downloads and caches the video
    func getCachedVideoURL(for remoteURL: URL) async -> URL? {
        let cacheKey = remoteURL.absoluteString.data(using: .utf8)?.base64EncodedString() ?? remoteURL.lastPathComponent
        let cachedFileURL = cacheDirectory.appendingPathComponent(cacheKey)
        
        // Check if file exists in cache
        if FileManager.default.fileExists(atPath: cachedFileURL.path) {
            print("✅ Video cache hit: \(remoteURL.lastPathComponent)")
            return cachedFileURL
        }
        
        // Download and cache
        print("📥 Downloading video for caching: \(remoteURL.lastPathComponent)")
        do {
            let (data, _) = try await URLSession.shared.data(from: remoteURL)
            try data.write(to: cachedFileURL)
            print("✅ Video cached: \(remoteURL.lastPathComponent)")
            
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
