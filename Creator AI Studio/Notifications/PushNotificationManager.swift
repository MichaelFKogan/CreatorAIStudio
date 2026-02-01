//
//  PushNotificationManager.swift
//  Creator AI Studio
//
//  Manages push notification registration and handling for webhook-based generation completion.
//  This is a stub implementation - full APNs integration requires:
//  1. Enable Push Notifications capability in Xcode
//  2. Create APNs key in Apple Developer Console
//  3. Configure Supabase Edge Function with APNs credentials
//

import Foundation
import UserNotifications
import UIKit

// MARK: - Push Notification Manager

@MainActor
class PushNotificationManager: NSObject, ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = PushNotificationManager()
    
    // MARK: - Published Properties

    @Published var isRegistered: Bool = false
    @Published var deviceToken: String?
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    /// Set to true when user taps a notification to trigger navigation to Gallery
    @Published var shouldNavigateToGallery: Bool = false
    
    // MARK: - Private Properties
    
    private var currentUserId: String?
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
    }
    
    // MARK: - Public Methods

    /// Clear the app badge count (the red circle with number on app icon).
    /// Uses setBadgeCount(0) on iOS 16+ for reliable clearing; falls back to applicationIconBadgeNumber on older iOS.
    func clearBadge() {
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
        }
        UIApplication.shared.applicationIconBadgeNumber = 0
    }

    /// Request push notification permissions from the user
    func requestPermissions() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            
            await MainActor.run {
                self.authorizationStatus = granted ? .authorized : .denied
            }
            
            if granted {
                print("[Push] Notification permissions granted")
                await registerForRemoteNotifications()
            } else {
                print("[Push] Notification permissions denied")
            }
            
            return granted
            
        } catch {
            print("[Push] Error requesting permissions: \(error)")
            return false
        }
    }
    
    /// Check current notification authorization status
    func checkAuthorizationStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        
        await MainActor.run {
            self.authorizationStatus = settings.authorizationStatus
        }
    }
    
    /// Register for remote notifications with APNs
    func registerForRemoteNotifications() async {
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    /// Called when device token is received from APNs
    /// This should be called from AppDelegate's didRegisterForRemoteNotificationsWithDeviceToken
    func didRegisterForRemoteNotifications(deviceToken data: Data) {
        let token = data.map { String(format: "%02.2hhx", $0) }.joined()
        
        self.deviceToken = token
        self.isRegistered = true
        
        print("[Push] Registered with device token: \(token)")
        
        // TODO: Store device token in Supabase user profile or pending_jobs
        // This token is needed by the send-push-notification Edge Function
        Task {
            await storeDeviceToken(token)
        }
    }
    
    /// Called when registration for remote notifications fails
    func didFailToRegisterForRemoteNotifications(error: Error) {
        print("[Push] Failed to register for remote notifications: \(error)")
        self.isRegistered = false
        self.deviceToken = nil
    }
    
    /// Set the current user ID for associating device token
    func setCurrentUser(_ userId: String?) {
        currentUserId = userId
        
        if let userId = userId, let token = deviceToken {
            Task {
                await storeDeviceToken(token)
            }
        }
    }
    
    // MARK: - Handle Received Notifications
    
    /// Handle notification received while app is in foreground
    func handleForegroundNotification(_ notification: UNNotification) {
        let userInfo = notification.request.content.userInfo
        
        print("[Push] Received foreground notification: \(userInfo)")
        
        // Extract job info from notification
        if let jobId = userInfo["job_id"] as? String,
           let jobType = userInfo["job_type"] as? String {
            handleJobCompletionNotification(jobId: jobId, jobType: jobType)
        }
    }
    
    /// Handle notification tap (user opened app from notification)
    func handleNotificationResponse(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo

        print("[Push] User tapped notification: \(userInfo)")

        // Clear badge when user taps notification
        clearBadge()

        // Navigate to Gallery tab when user taps notification
        shouldNavigateToGallery = true

        // Extract job info and navigate to result
        if let jobId = userInfo["job_id"] as? String,
           let jobType = userInfo["job_type"] as? String {
            handleJobCompletionNotification(jobId: jobId, jobType: jobType)
        }
    }
    
    // MARK: - Private Methods
    
    /// Store device token in Supabase (user_devices table) for push notification delivery.
    /// Called when the token is received from APNs or when the user changes.
    private func storeDeviceToken(_ token: String) async {
        guard let userId = currentUserId else {
            print("[Push] No user ID set, skipping device token storage")
            return
        }
        do {
            try await SupabaseManager.shared.upsertDeviceToken(userId: userId, deviceToken: token)
            print("[Push] Stored device token for user \(userId.prefix(8))...")
        } catch {
            print("[Push] Failed to store device token: \(error)")
        }
    }
    
    /// Handle job completion notification
    private func handleJobCompletionNotification(jobId: String, jobType: String) {
        print("[Push] Job completed - ID: \(jobId), Type: \(jobType)")
        
        // Post notification for UI to handle
        NotificationCenter.default.post(
            name: NSNotification.Name("JobCompletedFromPush"),
            object: nil,
            userInfo: [
                "jobId": jobId,
                "jobType": jobType
            ]
        )
        
        // TODO: Navigate to the completed job/result
        // This could open the profile page or show the generated media
    }
}

// MARK: - UNUserNotificationCenterDelegate Extension

extension PushNotificationManager: UNUserNotificationCenterDelegate {
    
    /// Called when notification is received while app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        handleForegroundNotification(notification)
        
        // Show notification banner even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    /// Called when user interacts with notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        handleNotificationResponse(response)
        completionHandler()
    }
}

// MARK: - Setup Instructions

/*
 
 APNs Setup Instructions
 ========================
 
 1. XCODE PROJECT SETUP:
    - Open your project in Xcode
    - Select your target > Signing & Capabilities
    - Click "+ Capability" and add "Push Notifications"
    - Also add "Background Modes" and check "Remote notifications"
 
 2. APPLE DEVELOPER CONSOLE:
    - Go to https://developer.apple.com
    - Navigate to Certificates, Identifiers & Profiles > Keys
    - Create a new key with "Apple Push Notifications service (APNs)" enabled
    - Download the .p8 key file (you can only download it once!)
    - Note the Key ID shown on the page
    - Note your Team ID (shown in Membership section)
 
 3. SUPABASE EDGE FUNCTION SECRETS:
    Add these secrets to your Supabase project (Dashboard > Edge Functions > Secrets):
    
    - APNS_KEY_ID: The Key ID from step 2
    - APNS_TEAM_ID: Your Apple Team ID
    - APNS_KEY: The entire contents of your .p8 file
    - APNS_BUNDLE_ID: Your app's bundle identifier (e.g., com.yourcompany.CreatorAIStudio)
 
 4. APP DELEGATE SETUP:
    Add these methods to your AppDelegate (or App struct if using SwiftUI lifecycle):
    
    ```swift
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushNotificationManager.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        PushNotificationManager.shared.didFailToRegisterForRemoteNotifications(error: error)
    }
    ```
    
    And in your app initialization:
    
    ```swift
    UNUserNotificationCenter.current().delegate = PushNotificationManager.shared
    ```
 
 5. REQUEST PERMISSIONS:
    Call this when appropriate (e.g., after user signs in):
    
    ```swift
    Task {
        await PushNotificationManager.shared.requestPermissions()
    }
    ```
 
 */
