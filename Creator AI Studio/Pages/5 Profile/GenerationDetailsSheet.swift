import SwiftUI

// MARK: - Generation Details Sheet

struct GenerationDetailsSheet: View {
    let placeholder: PlaceholderImage
    @Binding var isPresented: Bool
    @State private var showCopiedConfirmation = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Status Section
                    statusSection
                    
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Progress")
                .font(.headline)
                .foregroundColor(.secondary)
            
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
}

