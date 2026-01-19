import SwiftUI
import Supabase
import Kingfisher

struct UsageView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = UsageViewModel()
    @State private var selectedFilter: UsageFilter = .all
    @State private var selectedMediaType: MediaTypeFilter = .all
    
    enum UsageFilter: String, CaseIterable {
        case all = "All"
        case success = "Successful"
        case failed = "Failed"
    }
    
    enum MediaTypeFilter: String, CaseIterable {
        case all = "All"
        case images = "Images"
        case videos = "Videos"
    }
    
    var body: some View {
        List {
            // Statistics Section
            Section("Statistics") {
                StatisticsRow(
                    title: "Total Attempts",
                    value: "\(viewModel.totalAttempts)",
                    icon: "number.circle.fill",
                    color: .blue
                )
                
                StatisticsRow(
                    title: "Successful",
                    value: "\(viewModel.successfulCount)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                StatisticsRow(
                    title: "Failed",
                    value: "\(viewModel.failedCount)",
                    icon: "xmark.circle.fill",
                    color: .red
                )
                
                if viewModel.totalAttempts > 0 {
                    StatisticsRow(
                        title: "Success Rate",
                        value: String(format: "%.1f%%", viewModel.successRate),
                        icon: "percent",
                        color: .orange
                    )
                }
                
                StatisticsRow(
                    title: "Total Cost",
                    value: PricingManager.formatPriceWithUnit(Decimal(viewModel.totalCost)),
                    icon: "dollarsign.circle.fill",
                    color: .purple
                )
            }
            
            // Filters Section
            Section("Filters") {
                Picker("Status", selection: $selectedFilter) {
                    ForEach(UsageFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                
                Picker("Media Type", selection: $selectedMediaType) {
                    ForEach(MediaTypeFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
            }
            
            // Generations List
            Section("Generations") {
                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding()
                } else if filteredGenerations.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "tray")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("No generations found")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        Spacer()
                    }
                } else {
                    ForEach(filteredGenerations) { generation in
                        GenerationRow(generation: generation)
                    }
                }
            }
        }
        .navigationTitle("Usage")
        .task {
            await viewModel.fetchUsage(userId: authViewModel.user?.id.uuidString)
        }
        .refreshable {
            await viewModel.fetchUsage(userId: authViewModel.user?.id.uuidString)
        }
    }
    
    private var filteredGenerations: [UserImage] {
        var filtered = viewModel.generations
        
        // Filter by status
        switch selectedFilter {
        case .all:
            break
        case .success:
            filtered = filtered.filter { $0.isSuccess }
        case .failed:
            filtered = filtered.filter { $0.isFailed }
        }
        
        // Filter by media type
        switch selectedMediaType {
        case .all:
            break
        case .images:
            filtered = filtered.filter { $0.isImage }
        case .videos:
            filtered = filtered.filter { $0.isVideo }
        }
        
        return filtered
    }
}

// MARK: - Statistics Row

struct StatisticsRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(title)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Generation Row

struct GenerationRow: View {
    let generation: UserImage
    @State private var isExpanded = false
    @State private var showCopiedIndicator = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main compact row
            HStack(spacing: 8) {
                // Thumbnail (small, 40x40)
                thumbnailView
                    .frame(width: 40, height: 40)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                
                // Main content - compact two-line layout
                VStack(alignment: .leading, spacing: 3) {
                    // Line 1: Status + Prompt + Cost
                    HStack(spacing: 6) {
                        // Status indicator (small)
                        Image(systemName: generation.isFailed ? "xmark.circle.fill" : "checkmark.circle.fill")
                            .foregroundColor(generation.isFailed ? .red : .green)
                            .font(.caption)
                        
                        // Prompt/Title (truncated)
                        Text(generation.title ?? (generation.prompt.map { String($0.prefix(40)) } ?? "Untitled"))
                            .font(.subheadline)
                            .lineLimit(1)
                            .foregroundColor(.primary)
                        
                        Spacer(minLength: 4)
                        
                        // Cost (if available and generation succeeded)
                        if let cost = generation.cost, cost > 0, !generation.isFailed {
                            Text(PricingManager.formatPrice(Decimal(cost)))
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                    }
                    
                    // Line 2: Model + Type + Time + Error
                    HStack(spacing: 6) {
                        // Model (compact)
                        if let model = generation.model {
                            Text(model)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        // Media type (compact)
                        Text(generation.isVideo ? "Video" : "Image")
                            .font(.caption2)
                            .foregroundColor(generation.isVideo ? .purple : .blue)
                        
                        // Timestamp (compact)
                        if let createdAt = generation.created_at {
                            Text(formatDateCompact(createdAt))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Error indicator (if failed)
                        if generation.isFailed {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                        
                        // Expand/collapse chevron
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
            
            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    // Full prompt with copy button
                    if let prompt = generation.prompt, !prompt.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Prompt:")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button(action: {
                                    UIPasteboard.general.string = prompt
                                    // Haptic feedback
                                    let generator = UINotificationFeedbackGenerator()
                                    generator.notificationOccurred(.success)
                                    
                                    // Show visual indicator
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showCopiedIndicator = true
                                    }
                                    
                                    // Hide indicator after 2 seconds
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            showCopiedIndicator = false
                                        }
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        if showCopiedIndicator {
                                            Image(systemName: "checkmark")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                            Text("Copied")
                                                .font(.caption2)
                                                .foregroundColor(.green)
                                        } else {
                                            Image(systemName: "doc.on.doc")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                            }
                            Text(prompt)
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    // Error message (if failed)
                    if generation.isFailed, let errorMessage = generation.error_message {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Error:")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    // Additional metadata - full width
                    HStack(spacing: 8) {
                        // For videos, show aspect ratio, resolution, and duration
                        if generation.isVideo {
                            // Aspect ratio (for videos) - first in row
                            if let aspectRatio = generation.aspect_ratio {
                                HStack(spacing: 3) {
                                    Image(systemName: "aspectratio")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(aspectRatio)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            // Resolution (from database)
                            if let resolution = generation.resolution {
                                HStack(spacing: 3) {
                                    Image(systemName: "rectangle.inset.filled")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(resolution)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            // Duration (from database)
                            if let duration = generation.duration {
                                HStack(spacing: 3) {
                                    Image(systemName: "timer")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(formatDuration(duration))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else {
                            // For images, show aspect ratio
                            if let aspectRatio = generation.aspect_ratio {
                                HStack(spacing: 3) {
                                    Image(systemName: "aspectratio")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(aspectRatio)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Calendar and date - aligned right
                        if let createdAt = generation.created_at {
                            HStack(spacing: 3) {
                                Image(systemName: "calendar")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(formatDate(createdAt))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 0) // Full width, no left padding
            }
        }
    }
    
    // MARK: - Thumbnail View
    
    @ViewBuilder
    private var thumbnailView: some View {
        // Get the appropriate URL (thumbnail for videos, image_url for images)
        let displayUrl = generation.isVideo 
            ? (generation.thumbnail_url?.isEmpty == false ? generation.thumbnail_url : generation.image_url)
            : generation.image_url
        
        if let urlString = displayUrl, !urlString.isEmpty, let url = URL(string: urlString) {
            // Show thumbnail for successful generations - use larger size for better quality
            KFImage(url)
                .setProcessor(DownsamplingImageProcessor(size: CGSize(width: 80, height: 80)))
                .cacheMemoryOnly()
                .fade(duration: 0.1)
                .placeholder {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.7)
                        )
                }
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipped()
        } else {
            // Placeholder for failed generations or missing URLs
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .overlay(
                    Image(systemName: generation.isFailed ? "xmark" : (generation.isVideo ? "video.fill" : "photo"))
                        .font(.caption)
                        .foregroundColor(.gray)
                )
        }
    }
    
    // MARK: - Date Formatting
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
    
    private func formatDateCompact(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            let now = Date()
            let timeInterval = now.timeIntervalSince(date)
            
            // Show relative time for recent items
            if timeInterval < 60 {
                return "now"
            } else if timeInterval < 3600 {
                let minutes = Int(timeInterval / 60)
                return "\(minutes)m"
            } else if timeInterval < 86400 {
                let hours = Int(timeInterval / 3600)
                return "\(hours)h"
            } else if timeInterval < 604800 {
                let days = Int(timeInterval / 86400)
                return "\(days)d"
            } else {
                // For older items, show date
                let displayFormatter = DateFormatter()
                displayFormatter.dateFormat = "M/d"
                return displayFormatter.string(from: date)
            }
        }
        
        return dateString
    }
    
    // Helper to format duration in seconds to readable format
    private func formatDuration(_ seconds: Double) -> String {
        let intSeconds = Int(seconds)
        if intSeconds < 60 {
            return "\(intSeconds)s"
        } else {
            let minutes = intSeconds / 60
            let remainingSeconds = intSeconds % 60
            if remainingSeconds == 0 {
                return "\(minutes)m"
            } else {
                return "\(minutes)m \(remainingSeconds)s"
            }
        }
    }
}

// MARK: - Usage ViewModel

@MainActor
class UsageViewModel: ObservableObject {
    @Published var generations: [UserImage] = []
    @Published var isLoading = false
    
    var totalAttempts: Int {
        generations.count
    }
    
    var successfulCount: Int {
        generations.filter { $0.isSuccess }.count
    }
    
    var failedCount: Int {
        generations.filter { $0.isFailed }.count
    }
    
    var successRate: Double {
        guard totalAttempts > 0 else { return 0 }
        return (Double(successfulCount) / Double(totalAttempts)) * 100
    }
    
    var totalCost: Double {
        generations
            .compactMap { $0.cost }
            .reduce(0, +)
    }
    
    private let client = SupabaseManager.shared.client
    
    func fetchUsage(userId: String?) async {
        guard let userId = userId else { return }
        
        isLoading = true
        
        do {
            // Fetch all generations (both successful and failed)
            let response: PostgrestResponse<[UserImage]> = try await client.database
                .from("user_media")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .limit(1000) // Fetch up to 1000 records
                .execute()
            
            generations = response.value ?? []
            print("✅ Fetched \(generations.count) generations for usage view")
        } catch {
            print("❌ Failed to fetch usage data: \(error)")
        }
        
        isLoading = false
    }
}

