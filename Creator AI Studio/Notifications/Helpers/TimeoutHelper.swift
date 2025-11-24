import Foundation

// MARK: - Timeout Helper
struct TimeoutError: LocalizedError {
    var errorDescription: String? {
        "The operation timed out"
    }
}

func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        // Add the actual operation
        group.addTask {
            try await operation()
        }
        
        // Add the timeout task
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError()
        }
        
        // Return the first result (either success or timeout)
        guard let result = try await group.next() else {
            throw TimeoutError()
        }
        
        // Cancel remaining tasks
        group.cancelAll()
        
        return result
    }
}








