import SwiftUI

// MARK: - Generation Details Sheet

struct GenerationDetailsSheet: View {
    let placeholder: PlaceholderImage
    @Binding var isPresented: Bool
    @State private var showCopiedConfirmation = false
    @State private var dynamicMessage: String = ""
    @State private var timeoutMessage: String = ""
    @State private var showTimeoutMessage: Bool = false
    @State private var showCancelButton: Bool = false
    @StateObject private var notificationManager = NotificationManager.shared
    
    // Timer to update messages every minute
    @State private var messageUpdateTimer: Timer?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Status Section
                    statusSection
                    
                    // Generation Start Time Section
                    generationTimeSection
                    
                    // Model Section
                    if let modelName = placeholder.modelName, !modelName.isEmpty {
                        detailSection(title: "Model", content: modelName)
                    }
                    
                    // Prompt Section
                    if let prompt = placeholder.prompt, !prompt.isEmpty {
                        promptSection(prompt: prompt)
                    }
                    
                    // Error Message Section (if failed)
                    if placeholder.state == .failed, let errorMessage = placeholder.errorMessage, !errorMessage.isEmpty {
                        errorSection(errorMessage: errorMessage)
                    }
                    
                    // Progress Section (if in progress)
                    if placeholder.state == .inProgress {
                        progressSection
                    }
                }
                .padding()
            }
            .navigationTitle("Generation Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
        .onAppear {
            // Initialize messages
            updateMessages()
            
            // Set up timer to update messages every 10 seconds to keep in sync with other views
            messageUpdateTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
                updateMessages()
            }
        }
        .onDisappear {
            messageUpdateTimer?.invalidate()
        }
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Status")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                statusIcon
                Text(statusText)
                    .font(.body)
                    .foregroundColor(.primary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var statusIcon: some View {
        Image(systemName: statusIconName)
            .font(.title3)
            .foregroundColor(statusColor)
    }
    
    private var statusIconName: String {
        switch placeholder.state {
        case .inProgress:
            return "clock.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch placeholder.state {
        case .inProgress:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
    
    private var statusText: String {
        switch placeholder.state {
        case .inProgress:
            return "In Progress"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        }
    }
    
    // MARK: - Generation Time Section
    
    private var generationTimeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Started")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatDate(placeholder.createdAt))
                    .font(.body)
                    .foregroundColor(.primary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - Detail Section
    
    private func detailSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(content)
                .font(.body)
                .foregroundColor(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    // MARK: - Prompt Section
    
    private func promptSection(prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Prompt")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    copyPrompt(prompt)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: showCopiedConfirmation ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                        Text(showCopiedConfirmation ? "Copied!" : "Copy")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(showCopiedConfirmation ? .green : .blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(showCopiedConfirmation ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            Text(prompt)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    // MARK: - Error Section
    
    private func errorSection(errorMessage: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Error Message")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(errorMessage)
                .font(.body)
                .foregroundColor(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.1))
        .cornerRadius(10)
    }
    
    // MARK: - Progress Section
    
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progress")
                .font(.headline)
                .foregroundColor(.secondary)
            
            // Timeout message (shown when appropriate - 2-5 minutes)
            if showTimeoutMessage && !timeoutMessage.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text(timeoutMessage)
                        .font(.subheadline)
                        .foregroundColor(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            } else if !dynamicMessage.isEmpty {
                // Dynamic message (shown when not showing timeout warning)
                Text(dynamicMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 4)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * placeholder.progress, height: 8)
                }
            }
            .frame(height: 8)
            
            Text("\(Int(placeholder.progress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Cancel button (shown when elapsed time >= 2 minutes)
            if showCancelButton {
                Button(action: {
                    notificationManager.cancelTask(notificationId: placeholder.id)
                    // Close the sheet after cancellation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isPresented = false
                    }
                }) {
                    Text("Cancel")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    // MARK: - Helper Methods
    
    private func copyPrompt(_ prompt: String) {
        UIPasteboard.general.string = prompt
        showCopiedConfirmation = true
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Reset confirmation after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showCopiedConfirmation = false
        }
    }
    
    private func updateMessages() {
        // Don't show timeout messages if generation is completed
        if placeholder.state == .completed {
            dynamicMessage = GenerationMessageHelper.getDynamicMessage(
                elapsedSeconds: 0,
                isVideo: false,
                baseMessage: placeholder.message,
                state: placeholder.state
            )
            showTimeoutMessage = false
            timeoutMessage = ""
            showCancelButton = false
            return
        }
        
        let elapsed = Date().timeIntervalSince(placeholder.createdAt)
        let isVideo = placeholder.title.contains("Video") || placeholder.title.contains("video")
        let elapsedMinutes = Int(elapsed / 60)
        
        // Update dynamic message
        dynamicMessage = GenerationMessageHelper.getDynamicMessage(
            elapsedSeconds: elapsed,
            isVideo: isVideo,
            baseMessage: placeholder.message,
            state: placeholder.state
        )
        
        // Show cancel button when elapsed time >= 5 minutes and task can still be cancelled
        if elapsedMinutes >= 5 && placeholder.state == .inProgress {
            // Check if task can still be cancelled
            let canCancel = ImageGenerationCoordinator.shared.canCancelTask(notificationId: placeholder.id) ||
                           VideoGenerationCoordinator.shared.canCancelTask(notificationId: placeholder.id)
            print("🔍 [GenerationDetailsSheet] Cancel button check: elapsedMinutes=\(elapsedMinutes), canCancel=\(canCancel), state=\(placeholder.state)")
            showCancelButton = canCancel
        } else {
            print("🔍 [GenerationDetailsSheet] Cancel button not shown: elapsedMinutes=\(elapsedMinutes), state=\(placeholder.state)")
            showCancelButton = false
        }
        
        // Show timeout message in two scenarios:
        // 1. Initial timeout warning (5-6 minutes)
        // 2. Countdown timeout warning (5-10 minutes)
        if elapsedMinutes >= 5 && elapsedMinutes < 6 {
            // Initial timeout message (5-6 minutes)
            showTimeoutMessage = true
            timeoutMessage = GenerationMessageHelper.getTimeoutMessage(isVideo: isVideo)
        } else if elapsedMinutes >= 5 && elapsedMinutes < 10 {
            // Countdown timeout message (5-10 minutes)
            showTimeoutMessage = true
            let remainingMinutes = 10 - elapsedMinutes
            timeoutMessage = "This will cancel in \(remainingMinutes) minute\(remainingMinutes == 1 ? "" : "s") if no result. You won't be charged for failed generations."
        } else {
            // No timeout message to show
            showTimeoutMessage = false
            timeoutMessage = ""
        }
    }
}

