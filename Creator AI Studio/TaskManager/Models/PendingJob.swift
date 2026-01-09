import Foundation

// MARK: - Pending Job Model

/// Represents a pending generation job tracked in Supabase
/// This model maps to the `pending_jobs` table
struct PendingJob: Codable, Identifiable {
    let id: UUID?
    let user_id: String
    let task_id: String
    let provider: String
    let job_type: String
    let status: String
    let result_url: String?
    let error_message: String?
    let metadata: PendingJobMetadata?
    let device_token: String?
    let notification_sent: Bool?
    let created_at: Date?
    let updated_at: Date?
    let completed_at: Date?
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case id, user_id, task_id, provider, job_type, status
        case result_url, error_message, metadata, device_token
        case notification_sent, created_at, updated_at, completed_at
    }
    
    // MARK: - Custom Decoder (handles metadata as JSON string or object)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(UUID.self, forKey: .id)
        user_id = try container.decode(String.self, forKey: .user_id)
        task_id = try container.decode(String.self, forKey: .task_id)
        provider = try container.decode(String.self, forKey: .provider)
        job_type = try container.decode(String.self, forKey: .job_type)
        status = try container.decode(String.self, forKey: .status)
        result_url = try container.decodeIfPresent(String.self, forKey: .result_url)
        error_message = try container.decodeIfPresent(String.self, forKey: .error_message)
        device_token = try container.decodeIfPresent(String.self, forKey: .device_token)
        notification_sent = try container.decodeIfPresent(Bool.self, forKey: .notification_sent)
        created_at = try container.decodeIfPresent(Date.self, forKey: .created_at)
        updated_at = try container.decodeIfPresent(Date.self, forKey: .updated_at)
        completed_at = try container.decodeIfPresent(Date.self, forKey: .completed_at)
        
        // Handle metadata - can be a JSON object OR a JSON string
        if let metadataObj = try? container.decodeIfPresent(PendingJobMetadata.self, forKey: .metadata) {
            metadata = metadataObj
        } else if let metadataString = try? container.decodeIfPresent(String.self, forKey: .metadata),
                  let metadataData = metadataString.data(using: .utf8) {
            // Metadata is stored as a JSON string - parse it
            metadata = try? JSONDecoder().decode(PendingJobMetadata.self, from: metadataData)
        } else {
            metadata = nil
        }
    }
    
    // MARK: - Convenience Initializer
    
    init(
        userId: String,
        taskId: String,
        provider: JobProvider,
        jobType: JobType,
        metadata: PendingJobMetadata? = nil,
        deviceToken: String? = nil
    ) {
        self.id = nil
        self.user_id = userId
        self.task_id = taskId
        self.provider = provider.rawValue
        self.job_type = jobType.rawValue
        self.status = JobStatus.pending.rawValue
        self.result_url = nil
        self.error_message = nil
        self.metadata = metadata
        self.device_token = deviceToken
        self.notification_sent = nil
        self.created_at = nil
        self.updated_at = nil
        self.completed_at = nil
    }
    
    // MARK: - Computed Properties
    
    var jobStatus: JobStatus {
        JobStatus(rawValue: status) ?? .pending
    }
    
    var jobProvider: JobProvider {
        JobProvider(rawValue: provider) ?? .runware
    }
    
    var isComplete: Bool {
        jobStatus == .completed || jobStatus == .failed
    }
    
    var hasResult: Bool {
        result_url != nil && !result_url!.isEmpty
    }
}

// MARK: - Job Status Enum

enum JobStatus: String, Codable {
    case pending = "pending"
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"
}

// MARK: - Job Provider Enum

enum JobProvider: String, Codable {
    case runware = "runware"
    case wavespeed = "wavespeed"
    case falai = "falai"
}

// MARK: - Job Type Enum

enum JobType: String, Codable {
    case image = "image"
    case video = "video"
}

// MARK: - Pending Job Metadata

/// Stores additional information about the job for later processing
struct PendingJobMetadata: Codable {
    let prompt: String?
    let model: String?
    let title: String?
    let aspectRatio: String?
    let resolution: String?
    let duration: Double?
    let cost: Double?
    let type: String?  // "Photo Filter", "Video Model", etc.
    let endpoint: String?
    let falRequestId: String?  // Fal.ai request_id (different from our task_id)
    
    enum CodingKeys: String, CodingKey {
        case prompt
        case model
        case title
        case aspectRatio = "aspect_ratio"
        case resolution
        case duration
        case cost
        case type
        case endpoint
        case falRequestId = "fal_request_id"
    }
    
    init(
        prompt: String? = nil,
        model: String? = nil,
        title: String? = nil,
        aspectRatio: String? = nil,
        resolution: String? = nil,
        duration: Double? = nil,
        cost: Double? = nil,
        type: String? = nil,
        endpoint: String? = nil,
        falRequestId: String? = nil
    ) {
        self.prompt = prompt
        self.model = model
        self.title = title
        self.aspectRatio = aspectRatio
        self.resolution = resolution
        self.duration = duration
        self.cost = cost
        self.type = type
        self.endpoint = endpoint
        self.falRequestId = falRequestId
    }
}

// MARK: - Insert Model (for creating new jobs)

/// Model for inserting new pending jobs (excludes server-generated fields)
struct PendingJobInsert: Encodable {
    let user_id: String
    let task_id: String
    let provider: String
    let job_type: String
    let status: String
    let metadata: PendingJobMetadata?
    let device_token: String?
    
    init(from job: PendingJob) {
        self.user_id = job.user_id
        self.task_id = job.task_id
        self.provider = job.provider
        self.job_type = job.job_type
        self.status = job.status
        self.metadata = job.metadata
        self.device_token = job.device_token
    }
}
