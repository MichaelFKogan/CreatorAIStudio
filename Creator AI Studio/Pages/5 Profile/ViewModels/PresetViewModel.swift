////
////  PresetViewModel.swift
////  Creator AI Studio
////
////  Created by Mike K on 11/22/25.
////
//
//import Combine
//import Supabase
//import SwiftUI
//
//@MainActor
//class PresetViewModel: ObservableObject {
////    @Published var presets: [Preset] = []
//    @Published var isLoading = false
//    
//    private let client = SupabaseManager.shared.client
//    private var hasFetchedFromDatabase = false
//    var userId: String?
//    
//    // Cache presets persistently between launches
//    @AppStorage("cachedPresets") private var cachedPresetsData: Data = .init()
//    
//    init() {
//        loadCachedPresets()
//    }
//    
//    private func loadCachedPresets() {
//        if let decoded = try? JSONDecoder().decode([Preset].self, from: cachedPresetsData) {
//            presets = decoded
//        }
//    }
//    
//    private func saveCachedPresets() {
//        if let encoded = try? JSONEncoder().encode(presets) {
//            cachedPresetsData = encoded
//        }
//    }
//    
//    /// Fetches presets from Supabase database
//    func fetchPresets(forceRefresh: Bool = false) async {
//        guard let userId = userId else {
//            print("⚠️ Cannot fetch presets: userId is nil")
//            return
//        }
//        
//        // If we've already fetched this session and it's not a forced refresh, skip
//        guard !hasFetchedFromDatabase || forceRefresh else { return }
//        
//        // Only show loading state if we don't have any cached presets to display
//        let shouldShowLoading = presets.isEmpty
//        
//        if shouldShowLoading {
//            isLoading = true
//        }
//        
//        do {
//            let response: PostgrestResponse<[Preset]> = try await client.database
//                .from("user_presets")
//                .select()
//                .eq("user_id", value: userId)
//                .order("display_order", ascending: true)
//                .order("created_at", ascending: false)
//                .execute()
//            
//            var fetchedPresets = response.value ?? []
//            
//            // Ensure all presets have a display_order (fallback for any that don't)
//            for (index, preset) in fetchedPresets.enumerated() {
//                if preset.displayOrder == nil {
//                    let orderUpdate = PresetOrderUpdateMetadata(displayOrder: index)
//                    do {
//                        try await client.database
//                            .from("user_presets")
//                            .update(orderUpdate)
//                            .eq("id", value: preset.id)
//                            .eq("user_id", value: userId)
//                            .execute()
//                        
//                        // Update the preset in the array
//                        let updatedPreset = Preset(
//                            id: preset.id,
//                            title: preset.title,
//                            modelName: preset.modelName,
//                            prompt: preset.prompt,
//                            imageUrl: preset.imageUrl,
//                            created_at: preset.created_at,
//                            displayOrder: index
//                        )
//                        fetchedPresets[index] = updatedPreset
//                    } catch {
//                        print("⚠️ Failed to set display_order for preset \(preset.id): \(error)")
//                    }
//                }
//            }
//            
//            presets = fetchedPresets
//            saveCachedPresets()
//            hasFetchedFromDatabase = true
//            // print("✅ Fetched and cached \(presets.count) presets from Supabase")
//            
//        } catch {
//            print("❌ Failed to fetch presets: \(error)")
//        }
//        
//        if shouldShowLoading {
//            isLoading = false
//        }
//    }
//    
//    /// Saves a new preset to Supabase database
//    func savePreset(title: String, modelName: String?, prompt: String?, imageUrl: String? = nil) async throws {
//        print("🔵 [PresetViewModel] Starting savePreset")
//        print("🔵 [PresetViewModel] Title: '\(title)'")
//        print("🔵 [PresetViewModel] Model Name: '\(modelName ?? "nil")'")
//        print("🔵 [PresetViewModel] Prompt: '\(prompt?.prefix(50) ?? "nil")...'")
//        print("🔵 [PresetViewModel] Image URL: '\(imageUrl ?? "nil")'")
//        
//        guard let userId = userId else {
//            print("❌ [PresetViewModel] User ID is nil!")
//            throw NSError(
//                domain: "PresetError",
//                code: -1,
//                userInfo: [NSLocalizedDescriptionKey: "User ID is required to save preset"]
//            )
//        }
//        
//        print("🔵 [PresetViewModel] User ID: \(userId)")
//        print("🔵 [PresetViewModel] User ID length: \(userId.count)")
//        print("🔵 [PresetViewModel] User ID is valid UUID: \(UUID(uuidString: userId) != nil)")
//        
//        // Validate UUID format
//        guard UUID(uuidString: userId) != nil else {
//            print("❌ [PresetViewModel] Invalid UUID format: \(userId)")
//            throw NSError(
//                domain: "PresetError",
//                code: -2,
//                userInfo: [NSLocalizedDescriptionKey: "Invalid user ID format"]
//            )
//        }
//        
//        let metadata = PresetMetadata(
//            userId: userId,
//            title: title,
//            modelName: modelName,
//            prompt: prompt,
//            imageUrl: imageUrl
//        )
//        
//        print("🔵 [PresetViewModel] Created metadata:")
//        print("   - user_id: \(metadata.user_id)")
//        print("   - title: '\(metadata.title)'")
//        print("   - model_name: '\(metadata.model_name ?? "nil")'")
//        print("   - prompt length: \(metadata.prompt?.count ?? 0) characters")
//        if let prompt = metadata.prompt {
//            print("   - prompt preview: '\(prompt.prefix(100))...'")
//        }
//        
//        // Save with retry logic
//        var saveSuccessful = false
//        var retryCount = 0
//        let maxRetries = 3
//        
//        while !saveSuccessful, retryCount < maxRetries {
//            do {
//                print("🔵 [PresetViewModel] Attempt \(retryCount + 1)/\(maxRetries): Inserting preset into database...")
//                print("🔵 [PresetViewModel] Table: 'user_presets'")
//                print("🔵 [PresetViewModel] Metadata to insert:")
//                print("   \(metadata)")
//                
//                // Try to encode metadata to see what's being sent
//                if let jsonData = try? JSONEncoder().encode(metadata),
//                   let jsonString = String(data: jsonData, encoding: .utf8) {
//                    print("🔵 [PresetViewModel] JSON being sent: \(jsonString)")
//                }
//                
//                let response: PostgrestResponse<Preset> = try await client.database
//                    .from("user_presets")
//                    .insert(metadata)
//                    .select()
//                    .single()
//                    .execute()
//                
//                print("🔵 [PresetViewModel] Database response received")
//                print("🔵 [PresetViewModel] Response value: \(response.value)")
//                print("🔵 [PresetViewModel] Preset ID: \(response.value.id)")
//                print("🔵 [PresetViewModel] Preset title: \(response.value.title)")
//                
//                // Add to local array and set display_order if needed
//                var newPreset = response.value
//                
//                // If display_order is nil, set it to the maximum + 1 (or 0 if no presets)
//                if newPreset.displayOrder == nil {
//                    let maxOrder = presets.compactMap { $0.displayOrder }.max() ?? -1
//                    let newOrder = maxOrder + 1
//                    
//                    // Update the preset in the database with the display_order
//                    do {
//                        let orderUpdate = PresetOrderUpdateMetadata(displayOrder: newOrder)
//                        try await client.database
//                            .from("user_presets")
//                            .update(orderUpdate)
//                            .eq("id", value: newPreset.id)
//                            .eq("user_id", value: userId)
//                            .execute()
//                        
//                        // Update local preset with the new order
//                        newPreset = Preset(
//                            id: newPreset.id,
//                            title: newPreset.title,
//                            modelName: newPreset.modelName,
//                            prompt: newPreset.prompt,
//                            imageUrl: newPreset.imageUrl,
//                            created_at: newPreset.created_at,
//                            displayOrder: newOrder
//                        )
//                    } catch {
//                        print("⚠️ [PresetViewModel] Failed to set display_order for new preset: \(error)")
//                    }
//                }
//                
//                presets.append(newPreset)
//                // Sort by display_order to maintain order
//                presets.sort { ($0.displayOrder ?? Int.max) < ($1.displayOrder ?? Int.max) }
//                saveCachedPresets()
//                print("✅ [PresetViewModel] Preset saved successfully!")
//                print("✅ [PresetViewModel] Preset ID: \(newPreset.id)")
//                print("✅ [PresetViewModel] Total presets in cache: \(presets.count)")
//                saveSuccessful = true
//                
//            } catch {
//                retryCount += 1
//                print("❌ [PresetViewModel] Save preset attempt \(retryCount) failed")
//                print("❌ [PresetViewModel] Error type: \(type(of: error))")
//                print("❌ [PresetViewModel] Error description: \(error.localizedDescription)")
//                if let nsError = error as NSError? {
//                    print("❌ [PresetViewModel] Error domain: \(nsError.domain)")
//                    print("❌ [PresetViewModel] Error code: \(nsError.code)")
//                    print("❌ [PresetViewModel] Error userInfo: \(nsError.userInfo)")
//                }
//                
//                if retryCount < maxRetries {
//                    let delay = pow(2.0, Double(retryCount))
//                    print("⏳ [PresetViewModel] Retrying in \(delay) seconds...")
//                    // Exponential backoff
//                    try await Task.sleep(for: .seconds(delay))
//                } else {
//                    print("❌ [PresetViewModel] Failed to save preset after \(maxRetries) attempts")
//                    throw error
//                }
//            }
//        }
//    }
//    
//    /// Updates an existing preset in Supabase database
//    func updatePreset(presetId: String, title: String, modelName: String?, prompt: String?, imageUrl: String?) async throws {
//        guard let userId = userId else {
//            throw NSError(
//                domain: "PresetError",
//                code: -1,
//                userInfo: [NSLocalizedDescriptionKey: "User ID is required to update preset"]
//            )
//        }
//        
//        // Update local array
//        if let index = presets.firstIndex(where: { $0.id == presetId }) {
//            // Create updated preset (preserve displayOrder)
//            let updatedPreset = Preset(
//                id: presets[index].id,
//                title: title,
//                modelName: modelName,
//                prompt: prompt,
//                imageUrl: imageUrl,
//                created_at: presets[index].created_at,
//                displayOrder: presets[index].displayOrder
//            )
//            presets[index] = updatedPreset
//            saveCachedPresets()
//        }
//        
//        // Update database
//        do {
//            let updateData = PresetUpdateMetadata(
//                title: title,
//                modelName: modelName,
//                prompt: prompt,
//                imageUrl: imageUrl
//            )
//            
//            try await client.database
//                .from("user_presets")
//                .update(updateData)
//                .eq("id", value: presetId)
//                .eq("user_id", value: userId)
//                .execute()
//            
//            print("✅ Preset updated successfully")
//        } catch {
//            print("❌ Failed to update preset: \(error)")
//            // Reload presets to restore state
//            await fetchPresets(forceRefresh: true)
//            throw error
//        }
//    }
//    
//    /// Reorders presets and persists the order to the database
//    func reorderPresets(from source: IndexSet, to destination: Int) {
//        guard let userId = userId else {
//            print("⚠️ Cannot reorder presets: userId is nil")
//            return
//        }
//        
//        // Update local array
//        presets.move(fromOffsets: source, toOffset: destination)
//        saveCachedPresets()
//        
//        // Update display_order in database for all affected presets
//        Task {
//            do {
//                // Update each preset's display_order based on its new position
//                for (index, preset) in presets.enumerated() {
//                    let newOrder = index
//                    
//                    // Only update if the order has changed
//                    if preset.displayOrder != newOrder {
//                        let orderUpdate = PresetOrderUpdateMetadata(displayOrder: newOrder)
//                        
//                        try await client.database
//                            .from("user_presets")
//                            .update(orderUpdate)
//                            .eq("id", value: preset.id)
//                            .eq("user_id", value: userId)
//                            .execute()
//                        
//                        // Update local preset with new order
//                        if let presetIndex = presets.firstIndex(where: { $0.id == preset.id }) {
//                            let updatedPreset = Preset(
//                                id: preset.id,
//                                title: preset.title,
//                                modelName: preset.modelName,
//                                prompt: preset.prompt,
//                                imageUrl: preset.imageUrl,
//                                created_at: preset.created_at,
//                                displayOrder: newOrder
//                            )
//                            presets[presetIndex] = updatedPreset
//                        }
//                    }
//                }
//                
//                saveCachedPresets()
//                print("✅ Preset order saved successfully")
//            } catch {
//                print("❌ Failed to save preset order: \(error)")
//                // Reload presets to restore correct order from database
//                await fetchPresets(forceRefresh: true)
//            }
//        }
//    }
//    
//    /// Deletes a preset from Supabase database
//    func deletePreset(presetId: String) async throws {
//        guard let userId = userId else {
//            throw NSError(
//                domain: "PresetError",
//                code: -1,
//                userInfo: [NSLocalizedDescriptionKey: "User ID is required to delete preset"]
//            )
//        }
//        
//        // Remove from local array
//        presets.removeAll { $0.id == presetId }
//        saveCachedPresets()
//        
//        // Delete from database
//        do {
//            try await client.database
//                .from("user_presets")
//                .delete()
//                .eq("id", value: presetId)
//                .eq("user_id", value: userId)
//                .execute()
//            
//            print("✅ Preset deleted successfully")
//        } catch {
//            print("❌ Failed to delete preset: \(error)")
//            // Reload presets to restore state
//            await fetchPresets(forceRefresh: true)
//            throw error
//        }
//    }
//}
