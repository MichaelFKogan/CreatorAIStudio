import Foundation

// MARK: - Image Metadata for Database
struct ImageMetadata: Encodable {
    let user_id: String
    let image_url: String
    let model: String?
    let title: String?
    let cost: Double?
    let type: String?
    let endpoint: String?
    let prompt: String?
    let aspect_ratio: String?
    let provider: String?
    
    init(userId: String, imageUrl: String, model: String? = nil, title: String? = nil, cost: Double? = nil, type: String? = nil, endpoint: String? = nil, prompt: String? = nil, aspectRatio: String? = nil, provider: String? = nil) {
        self.user_id = userId
        self.image_url = imageUrl
        self.model = model
        self.title = title
        self.cost = cost
        self.type = type
        self.endpoint = endpoint
        self.prompt = prompt
        self.aspect_ratio = aspectRatio
        self.provider = provider
    }
}

// MARK: - Video Metadata for Database
struct VideoMetadata: Encodable {
    let user_id: String
    let image_url: String // Using same column name for consistency
    let model: String?
    let title: String?
    let cost: Double?
    let type: String?
    let endpoint: String?
    let media_type: String
    let file_extension: String
    let thumbnail_url: String?
    let prompt: String?
    let aspect_ratio: String?
    
    init(userId: String, videoUrl: String, thumbnailUrl: String? = nil, model: String? = nil, title: String? = nil, cost: Double? = nil, type: String? = nil, endpoint: String? = nil, fileExtension: String = "mp4", prompt: String? = nil, aspectRatio: String? = nil) {
        self.user_id = userId
        self.image_url = videoUrl // Using image_url column for video URL
        self.thumbnail_url = thumbnailUrl
        self.model = model
        self.title = title
        self.cost = cost
        self.type = type
        self.endpoint = endpoint
        self.media_type = "video"
        self.file_extension = fileExtension
        self.prompt = prompt
        self.aspect_ratio = aspectRatio
    }
}

