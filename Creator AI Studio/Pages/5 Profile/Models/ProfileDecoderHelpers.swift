//
//  ProfileDecoderHelpers.swift
//  Creator AI Studio
//
//  Helper extensions for Decodable to reduce type inference overhead.
//  Extracted from ProfileModel.swift to improve build performance.
//

import Foundation

// MARK: - Decoder Helpers

extension KeyedDecodingContainer {

    /// Decodes a flexible ID that can be either String or Int, returning as String.
    /// Falls back to a provided key's value if ID is missing.
    func decodeFlexibleId(
        forKey key: Key,
        fallbackKey: Key? = nil
    ) throws -> String {
        // Try String first
        if let idString = try? decode(String.self, forKey: key) {
            return idString
        }
        // Try Int
        if let idInt = try? decode(Int.self, forKey: key) {
            return String(idInt)
        }
        // Try fallback key
        if let fallback = fallbackKey,
           let fallbackValue = try? decode(String.self, forKey: fallback) {
            return fallbackValue
        }
        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: self,
            debugDescription: "Expected String or Int for \(key)"
        )
    }

    /// Decodes an optional String, returning nil if not present or invalid.
    func decodeStringOrNil(forKey key: Key) -> String? {
        try? decode(String.self, forKey: key)
    }

    /// Decodes an optional Double, returning nil if not present or invalid.
    func decodeDoubleOrNil(forKey key: Key) -> Double? {
        try? decode(Double.self, forKey: key)
    }

    /// Decodes an optional Int, returning a default value if not present or invalid.
    func decodeIntOrDefault(forKey key: Key, default defaultValue: Int = 0) -> Int {
        (try? decode(Int.self, forKey: key)) ?? defaultValue
    }

    /// Decodes an optional Bool, returning a default value if not present or invalid.
    func decodeBoolOrDefault(forKey key: Key, default defaultValue: Bool = false) -> Bool {
        (try? decode(Bool.self, forKey: key)) ?? defaultValue
    }

    /// Decodes a dictionary, returning empty dictionary if not present or invalid.
    func decodeDictionaryOrEmpty<V: Decodable>(forKey key: Key) -> [String: V] {
        (try? decode([String: V].self, forKey: key)) ?? [:]
    }
}

// MARK: - URL Path Helpers

/// Extracts the storage path from a full URL for a given bucket.
/// Used for deleting files from Supabase storage.
func extractStoragePath(from url: String, bucket: String) -> String? {
    let bucketPattern = "/\(bucket)/"
    guard let range = url.range(of: bucketPattern) else {
        return nil
    }
    return String(url[range.upperBound...])
}

// MARK: - Stats Computation Helpers

/// Computed statistics from media items.
/// Used to consolidate duplicated stats computation logic.
struct ComputedStats {
    var favoriteCount: Int = 0
    var imageCount: Int = 0
    var videoCount: Int = 0
    var modelCounts: [String: Int] = [:]
    var videoModelCounts: [String: Int] = [:]
    var failedCount: Int = 0
}

/// Protocol for media items that can be used for stats computation.
/// Both MediaStats and UserImage conform to this.
protocol StatsComputable {
    var model: String? { get }
    var is_favorite: Bool? { get }
    var isImage: Bool { get }
    var isVideo: Bool { get }
    var isSuccess: Bool { get }
}

/// Computes stats from an array of media items.
/// Extracted from computeStatsFromDatabase() and initializeUserStats() to reduce code duplication.
func computeStats<T: StatsComputable>(from media: [T]) -> ComputedStats {
    var stats = ComputedStats()

    for item in media {
        // Skip failed items
        guard item.isSuccess else {
            stats.failedCount += 1
            continue
        }

        // Count favorites
        if item.is_favorite == true {
            stats.favoriteCount += 1
        }

        // Count images and videos
        if item.isImage {
            stats.imageCount += 1
        } else if item.isVideo {
            stats.videoCount += 1
        }

        // Count by model (exclude null/empty model names)
        if let model = item.model, !model.isEmpty, model != "(null)" {
            if item.isImage {
                stats.modelCounts[model, default: 0] += 1
            } else if item.isVideo {
                stats.videoModelCounts[model, default: 0] += 1
            }
        }
    }

    return stats
}
