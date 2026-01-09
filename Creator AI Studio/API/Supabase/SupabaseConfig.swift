//
//  SupabaseConfig.swift
//  Creator AI Studio
//
//  Configuration helper for Supabase keys
//  Loads values from Info.plist to avoid hardcoding secrets
//

import Foundation

struct SupabaseConfig {
    /// Supabase project URL (e.g., "https://your-project.supabase.co")
    static var supabaseURL: String {
        guard let url = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              !url.isEmpty else {
            fatalError("SUPABASE_URL not found in Info.plist. Please add it to your Info.plist file.")
        }
        return url
    }
    
    /// Supabase anon/public key (JWT token)
    static var supabaseAnonKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              !key.isEmpty else {
            fatalError("SUPABASE_ANON_KEY not found in Info.plist. Please add it to your Info.plist file.")
        }
        return key
    }
    
    /// Supabase project ID (extracted from URL, e.g., "your-project")
    static var supabaseProjectId: String {
        // Try to get from Info.plist first
        if let projectId = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PROJECT_ID") as? String,
           !projectId.isEmpty {
            return projectId
        }
        
        // Fallback: extract from URL
        let url = supabaseURL
        if let urlObj = URL(string: url),
           let host = urlObj.host,
           host.hasSuffix(".supabase.co") {
            return String(host.dropLast(".supabase.co".count))
        }
        
        fatalError("Could not determine Supabase project ID. Please add SUPABASE_PROJECT_ID to Info.plist or ensure SUPABASE_URL is correctly formatted.")
    }
    
    /// Webhook secret for webhook verification
    static var webhookSecret: String {
        guard let secret = Bundle.main.object(forInfoDictionaryKey: "WEBHOOK_SECRET") as? String,
              !secret.isEmpty else {
            fatalError("WEBHOOK_SECRET not found in Info.plist. Please add it to your Info.plist file.")
        }
        return secret
    }
}
