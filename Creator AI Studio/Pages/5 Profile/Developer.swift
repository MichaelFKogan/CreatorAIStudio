//
//  Developer.swift
//  Creator AI Studio
//
//  Created by Mike K on 11/26/25.
//

import SwiftUI

struct Developer: View {
    @State private var animateSteps = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "gearshape.2.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(.top, 20)

                    Text("Image Generation Flow")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("What happens when you tap Generate Image")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.bottom, 8)

                // Flow Steps
                VStack(spacing: 16) {
                    FlowStep(
                        number: 1,
                        icon: "hand.tap.fill",
                        title: "User Interaction",
                        description: "User taps Generate Image button",
                        details: "Button triggers generate() function in ImageModelDetailPage",
                        color: .blue,
                        delay: 0.1
                    )

                    FlowArrow()

                    FlowStep(
                        number: 2,
                        icon: "checkmark.shield.fill",
                        title: "Validation",
                        description: "Validates prompt and configuration",
                        details: "Checks if prompt is not empty, prepares InfoPacket with aspect ratio and model settings",
                        color: .green,
                        delay: 0.2
                    )

                    FlowArrow()

                    FlowStep(
                        number: 3,
                        icon: "arrow.triangle.branch",
                        title: "Coordinator Start",
                        description: "ImageGenerationCoordinator starts task",
                        details: "Creates unique task ID, shows notification with thumbnail, spawns background task",
                        color: .orange,
                        delay: 0.3
                    )

                    FlowArrow()

                    FlowStep(
                        number: 4,
                        icon: "network",
                        title: "API Request (10% progress)",
                        description: "Send image to WaveSpeed AI API",
                        details: "Uploads image with prompt, aspect ratio, and model configuration. Timeout: 360s",
                        color: .purple,
                        delay: 0.4
                    )

                    FlowArrow()

                    FlowStep(
                        number: 5,
                        icon: "arrow.down.circle.fill",
                        title: "Download Result (60% progress)",
                        description: "Fetch generated image from API response",
                        details: "Extracts output URL from response, downloads image data. Timeout: 30s",
                        color: .blue,
                        delay: 0.5
                    )

                    FlowArrow()

                    FlowStep(
                        number: 6,
                        icon: "icloud.and.arrow.up.fill",
                        title: "Upload to Storage (75% progress)",
                        description: "Save to Supabase Storage bucket",
                        details: "Uploads to user's folder organized by model name, returns permanent URL",
                        color: .indigo,
                        delay: 0.6
                    )

                    FlowArrow()

                    FlowStep(
                        number: 7,
                        icon: "cylinder.fill",
                        title: "Save Metadata (90% progress)",
                        description: "Store record in database",
                        details: "Saves to user_media table: URL, model, title, cost, prompt, aspect ratio. Retries up to 3 times",
                        color: .teal,
                        delay: 0.7
                    )

                    FlowArrow()

                    FlowStep(
                        number: 8,
                        icon: "checkmark.circle.fill",
                        title: "Completion",
                        description: "Show success notification",
                        details: "Marks notification as completed, dismisses after 5 seconds, updates UI with generated image",
                        color: .green,
                        delay: 0.8
                    )
                }
                .padding(.horizontal)

                // Technical Details Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("Technical Architecture")
                            .font(.headline)
                    }

                    Divider()

                    TechDetail(
                        title: "Coordinator Pattern",
                        description: "ImageGenerationCoordinator manages multiple concurrent tasks with UUID tracking"
                    )

                    TechDetail(
                        title: "Background Processing",
                        description: "Uses Task.detached to run generation off main thread, preventing UI blocking"
                    )

                    TechDetail(
                        title: "Progress Tracking",
                        description: "Real-time notification updates with progress percentage and status messages"
                    )

                    TechDetail(
                        title: "Error Handling",
                        description: "Timeout protection, network error detection, and automatic retry logic for database saves"
                    )

                    TechDetail(
                        title: "Task Lifecycle",
                        description: "Cleanup on completion or cancellation, memory-efficient with automatic resource deallocation"
                    )
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(16)
                .padding(.horizontal)

                // Code References
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .foregroundColor(.green)
                        Text("Key Files")
                            .font(.headline)
                    }

                    Divider()

                    CodeReference(
                        file: "ImageModelDetailPage.swift",
                        function: "generate()",
                        purpose: "Entry point - validates and initiates generation"
                    )

                    CodeReference(
                        file: "ImageGenerationCoordinator.swift",
                        function: "startImageGeneration()",
                        purpose: "Manages task lifecycle and notifications"
                    )

                    CodeReference(
                        file: "ImageGenerationTask.swift",
                        function: "execute()",
                        purpose: "Core workflow - API, download, upload, save"
                    )

                    CodeReference(
                        file: "SupabaseManager.swift",
                        function: "uploadImage() & database.insert()",
                        purpose: "Storage and database operations"
                    )
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(16)
                .padding(.horizontal)

                // Bottom spacing
                Color.clear.frame(height: 40)
            }
        }
        .navigationTitle("Developer Info")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                animateSteps = true
            }
        }
    }
}

// MARK: - Flow Step Card

struct FlowStep: View {
    let number: Int
    let icon: String
    let title: String
    let description: String
    let details: String
    let color: Color
    let delay: Double

    @State private var appear = false

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Number badge
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)

                Circle()
                    .fill(color)
                    .frame(width: 40, height: 40)

                Text("\(number)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.title3)

                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                }

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Text(details)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: color.opacity(appear ? 0.3 : 0), radius: 8, x: 0, y: 4)
        .scaleEffect(appear ? 1 : 0.9)
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(delay)) {
                appear = true
            }
        }
    }
}

// MARK: - Flow Arrow

struct FlowArrow: View {
    var body: some View {
        Image(systemName: "arrow.down")
            .font(.title2)
            .foregroundColor(.gray.opacity(0.5))
            .frame(height: 20)
    }
}

// MARK: - Tech Detail Row

struct TechDetail: View {
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Code Reference Row

struct CodeReference: View {
    let file: String
    let function: String
    let purpose: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "doc.text.fill")
                    .font(.caption)
                    .foregroundColor(.green)

                Text(file)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }

            Text("→ \(function)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.blue)
                .padding(.leading, 22)

            Text(purpose)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 22)
        }
        .padding(.vertical, 4)
    }
}
