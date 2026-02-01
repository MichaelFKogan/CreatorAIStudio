//
//  PlaylistModel.swift
//  Creator AI Studio
//
//  Custom playlists for organizing user-generated media
//

import Foundation

// MARK: - Playlist Model

/// Represents a user-created playlist for organizing media
struct Playlist: Codable, Identifiable, Equatable {
    let id: String
    let user_id: String
    let name: String
    let created_at: String?
    let updated_at: String?
    
    // Computed property for display
    var displayName: String {
        name.isEmpty ? "Untitled Playlist" : name
    }
}

// MARK: - Playlist Item Model

/// Represents a junction record linking a playlist to a media item
struct PlaylistItem: Codable, Identifiable {
    let id: String
    let playlist_id: String
    let image_id: String
    let added_at: String?
}

// MARK: - Playlist with Count

/// Extended playlist model that includes item count for display
struct PlaylistWithCount: Identifiable {
    let playlist: Playlist
    let itemCount: Int
    let thumbnailURL: String?
    
    var id: String { playlist.id }
    var name: String { playlist.name }
    var displayName: String { playlist.displayName }
}

// MARK: - Create Playlist Request

/// Request model for creating a new playlist
struct CreatePlaylistRequest: Codable {
    let user_id: String
    let name: String
}

// MARK: - Add to Playlist Request

/// Request model for adding an item to a playlist
struct AddToPlaylistRequest: Codable {
    let playlist_id: String
    let image_id: String
}
