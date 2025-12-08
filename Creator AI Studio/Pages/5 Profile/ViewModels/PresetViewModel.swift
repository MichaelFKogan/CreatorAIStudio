//
//  PresetViewModel.swift
//  Creator AI Studio
//
//  Created by Mike K on 11/22/25.
//

import Combine
import Supabase
import SwiftUI

@MainActor
class PresetViewModel: ObservableObject {
    @Published var presets: [Preset] = []
    @Published var isLoading = false
    
    private let client = SupabaseManager.shared.client
    private var hasFetchedFromDatabase = false
    var userId: String?
    
    // Cache presets persistently between launches
    @AppStorage("cachedPresets") private var cachedPresetsData: Data = .init()
    
    init() {
        loadCachedPresets()
    }
    
    private func loadCachedPresets() {
        if let decoded = try? JSONDecoder().decode([Preset].self, from: cachedPresetsData) {
            presets = decoded
        }
    }
    
    private func saveCachedPresets() {
        if let encoded = try? JSONEncoder().encode(presets) {
            cachedPresetsData = encoded
        }
    }
    
    /// Fetches presets from Supabase database
    func fetchPresets(forceRefresh: Bool = false) async {
        guard let userId = userId else {
            print("⚠️ Cannot fetch presets: userId is nil")
            return
        }
        
        // If we've already fetched this session and it's not a forced refresh, skip
        guard !hasFetchedFromDatabase || forceRefresh else { return }
        
        // Only show loading state if we don't have any cached presets to display
        let shouldShowLoading = presets.isEmpty
        
        if shouldShowLoading {
            isLoading = true
        }
        
        do {
            let response: PostgrestResponse<[Preset]> = try await client.database
                .from("user_presets")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
            
            presets = response.value ?? []
            saveCachedPresets()
            hasFetchedFromDatabase = true
            print("✅ Fetched and cached \(presets.count) presets from Supabase")
            
        } catch {
            print("❌ Failed to fetch presets: \(error)")
        }
        
        if shouldShowLoading {
            isLoading = false
        }
    }
    
    /// Saves a new preset to Supabase database
    func savePreset(title: String, modelName: String?, prompt: String?, imageUrl: String? = nil) async throws {
        print("🔵 [PresetViewModel] Starting savePreset")
        print("🔵 [PresetViewModel] Title: '\(title)'")
        print("🔵 [PresetViewModel] Model Name: '\(modelName ?? "nil")'")
        print("🔵 [PresetViewModel] Prompt: '\(prompt?.prefix(50) ?? "nil")...'")
        print("🔵 [PresetViewModel] Image URL: '\(imageUrl ?? "nil")'")
        
        guard let userId = userId else {
            print("❌ [PresetViewModel] User ID is nil!")
            throw NSError(
                domain: "PresetError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "User ID is required to save preset"]
            )
        }
        
        print("🔵 [PresetViewModel] User ID: \(userId)")
        print("🔵 [PresetViewModel] User ID length: \(userId.count)")
        print("🔵 [PresetViewModel] User ID is valid UUID: \(UUID(uuidString: userId) != nil)")
        
        // Validate UUID format
        guard UUID(uuidString: userId) != nil else {
            print("❌ [PresetViewModel] Invalid UUID format: \(userId)")
            throw NSError(
                domain: "PresetError",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Invalid user ID format"]
            )
        }
        
        let metadata = PresetMetadata(
            userId: userId,
            title: title,
            modelName: modelName,
            prompt: prompt,
            imageUrl: imageUrl
        )
        
        print("🔵 [PresetViewModel] Created metadata:")
        print("   - user_id: \(metadata.user_id)")
        print("   - title: '\(metadata.title)'")
        print("   - model_name: '\(metadata.model_name ?? "nil")'")
        print("   - prompt length: \(metadata.prompt?.count ?? 0) characters")
        if let prompt = metadata.prompt {
            print("   - prompt preview: '\(prompt.prefix(100))...'")
        }
        
        // Save with retry logic
        var saveSuccessful = false
        var retryCount = 0
        let maxRetries = 3
        
        while !saveSuccessful, retryCount < maxRetries {
            do {
                print("🔵 [PresetViewModel] Attempt \(retryCount + 1)/\(maxRetries): Inserting preset into database...")
                print("🔵 [PresetViewModel] Table: 'user_presets'")
                print("🔵 [PresetViewModel] Metadata to insert:")
                print("   \(metadata)")
                
                // Try to encode metadata to see what's being sent
                if let jsonData = try? JSONEncoder().encode(metadata),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    print("🔵 [PresetViewModel] JSON being sent: \(jsonString)")
                }
                
                let response: PostgrestResponse<Preset> = try await client.database
                    .from("user_presets")
                    .insert(metadata)
                    .select()
                    .single()
                    .execute()
                
                print("🔵 [PresetViewModel] Database response received")
                print("🔵 [PresetViewModel] Response value: \(response.value)")
                print("🔵 [PresetViewModel] Preset ID: \(response.value.id)")
                print("🔵 [PresetViewModel] Preset title: \(response.value.title)")
                
                // Add to local array
                let newPreset = response.value
                presets.insert(newPreset, at: 0)
                saveCachedPresets()
                print("✅ [PresetViewModel] Preset saved successfully!")
                print("✅ [PresetViewModel] Preset ID: \(newPreset.id)")
                print("✅ [PresetViewModel] Total presets in cache: \(presets.count)")
                saveSuccessful = true
                
            } catch {
                retryCount += 1
                print("❌ [PresetViewModel] Save preset attempt \(retryCount) failed")
                print("❌ [PresetViewModel] Error type: \(type(of: error))")
                print("❌ [PresetViewModel] Error description: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    print("❌ [PresetViewModel] Error domain: \(nsError.domain)")
                    print("❌ [PresetViewModel] Error code: \(nsError.code)")
                    print("❌ [PresetViewModel] Error userInfo: \(nsError.userInfo)")
                }
                
                if retryCount < maxRetries {
                    let delay = pow(2.0, Double(retryCount))
                    print("⏳ [PresetViewModel] Retrying in \(delay) seconds...")
                    // Exponential backoff
                    try await Task.sleep(for: .seconds(delay))
                } else {
                    print("❌ [PresetViewModel] Failed to save preset after \(maxRetries) attempts")
                    throw error
                }
            }
        }
    }
    
    /// Deletes a preset from Supabase database
    func deletePreset(presetId: String) async throws {
        guard let userId = userId else {
            throw NSError(
                domain: "PresetError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "User ID is required to delete preset"]
            )
        }
        
        // Remove from local array
        presets.removeAll { $0.id == presetId }
        saveCachedPresets()
        
        // Delete from database
        do {
            try await client.database
                .from("user_presets")
                .delete()
                .eq("id", value: presetId)
                .eq("user_id", value: userId)
                .execute()
            
            print("✅ Preset deleted successfully")
        } catch {
            print("❌ Failed to delete preset: \(error)")
            // Reload presets to restore state
            await fetchPresets(forceRefresh: true)
            throw error
        }
    }
}
