import SwiftUI
import Supabase
import Kingfisher

// MARK: - Usage Item (unified row: generation or credit added)

enum UsageItem: Identifiable {
    case generation(UserImage)
    case creditAdded(CreditTransaction)
    
    var id: String {
        switch self {
        case .generation(let g): return "gen-\(g.id)"
        case .creditAdded(let t): return "credit-\(t.id.uuidString)"
        }
    }
    
    var sortDate: Date? {
        switch self {
        case .generation(let g):
            guard let s = g.created_at else { return nil }
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f.date(from: s)
        case .creditAdded(let t): return t.created_at
        }
    }
}

struct UsageView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = UsageViewModel()
    @StateObject private var creditsViewModel = CreditsViewModel()
    @State private var selectedFilter: UsageFilter = .all
    @State private var selectedMediaType: MediaTypeFilter = .all
    
    enum UsageFilter: String, CaseIterable {
        case all = "All"
        case success = "Successful"
        case failed = "Failed"
        case creditsAdded = "Credits added"
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
                
                // StatisticsRow(
                //     title: "Total Spent",
                //     value: PricingManager.formatPriceWithUnit(Decimal(viewModel.totalCost)),
                //     icon: "dollarsign.circle.fill",
                //     color: .purple
                // )
                
                // StatisticsRow(
                //     title: "Credits added",
                //     value: "\(viewModel.creditsAddedCount)",
                //     icon: "dollarsign.circle.fill",
                //     color: .green
                // )
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
            
            // Activity List (generations + credits added)
            Section {
                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding()
                } else if filteredUsageItems.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "tray")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text(emptyMessage)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        Spacer()
                    }
                } else {
                    ForEach(filteredUsageItems) { item in
                        switch item {
                        case .generation(let generation):
                            GenerationRow(
                                generation: generation,
                                balanceBefore: viewModel.balanceBeforeByMediaId[generation.id.lowercased()]
                            )
                        case .creditAdded(let transaction):
                            CreditAddedRow(transaction: transaction)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Activity")
                    Spacer()
                    if creditsViewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text(creditsViewModel.formattedBalance())
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Usage")
        .task {
            await viewModel.fetchUsage(userId: authViewModel.user?.id.uuidString)
            if let userId = authViewModel.user?.id {
                await creditsViewModel.fetchBalance(userId: userId)
            }
        }
        .refreshable {
            await viewModel.fetchUsage(userId: authViewModel.user?.id.uuidString)
            if let userId = authViewModel.user?.id {
                await creditsViewModel.fetchBalance(userId: userId)
            }
        }
    }
    
    private var emptyMessage: String {
        switch selectedFilter {
        case .creditsAdded: return "No credit purchases found"
        default: return "No generations found"
        }
    }
    
    private var filteredUsageItems: [UsageItem] {
        var items: [UsageItem] = []
        
        switch selectedFilter {
        case .all:
            items = viewModel.sortedUsageItems
        case .success:
            items = viewModel.generations
                .filter { $0.isSuccess }
                .map { UsageItem.generation($0) }
        case .failed:
            items = viewModel.generations
                .filter { $0.isFailed }
                .map { UsageItem.generation($0) }
        case .creditsAdded:
            items = viewModel.creditTransactions.map { UsageItem.creditAdded($0) }
        }
        
        // Filter by media type (only for generations)
        if selectedMediaType != .all {
            items = items.filter { item in
                switch item {
                case .generation(let g):
                    switch selectedMediaType {
                    case .images: return g.isImage
                    case .videos: return g.isVideo
                    default: return true
                    }
                case .creditAdded:
                    return true // keep credit rows when filtering media
                }
            }
        }
        
        return items
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

// MARK: - Credit Added Row

struct CreditAddedRow: View {
    let transaction: CreditTransaction
    @State private var isExpanded = false
    
    private var displayDescription: String {
        if let desc = transaction.description, !desc.isEmpty {
            return String(desc.prefix(50))
        }
        return transaction.transaction_type == "refund" ? "Refund" : "Credit purchase"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                // Icon
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                    .frame(width: 40, height: 40)
                    .background(Color.green.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(displayDescription)
                            .font(.subheadline)
                            .lineLimit(1)
                            .foregroundColor(.primary)
                        Spacer(minLength: 4)
                        Text("+" + PricingManager.formatPrice(Decimal(transaction.amount)))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    HStack(spacing: 6) {
                        if let method = transaction.payment_method, !method.isEmpty {
                            Text(method == "apple" ? "App Store" : method.capitalized)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Text(formatDateCompact(transaction.created_at))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
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
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    if let desc = transaction.description, !desc.isEmpty {
                        Text(desc)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 3) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(formatDate(transaction.created_at))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDateCompact(_ date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)
        if interval < 60 { return "now" }
        if interval < 3600 { return "\(Int(interval / 60))m" }
        if interval < 86400 { return "\(Int(interval / 3600))h" }
        if interval < 604800 { return "\(Int(interval / 86400))d" }
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

// MARK: - Generation Row

struct GenerationRow: View {
    let generation: UserImage
    var balanceBefore: Double?
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
                        
                        VStack{
                            // Cost (if available and generation succeeded)
                            if let cost = generation.cost, cost > 0, !generation.isFailed {
                                Text("-" + PricingManager.formatPrice(Decimal(cost)))
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.red)
                            }
                            // Balance before deduction (beneath cost when available)
                            if let before = balanceBefore, generation.cost != nil, !generation.isFailed {
                                Text("\(PricingManager.formatPrice(Decimal(before)))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
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
    @Published var creditTransactions: [CreditTransaction] = []
    @Published var deductionTransactions: [CreditTransaction] = []
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
    
    var creditsAddedCount: Int {
        creditTransactions.count
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
    
    /// Merged list of generations and credit additions, sorted by date descending.
    var sortedUsageItems: [UsageItem] {
        let genItems = generations.map { UsageItem.generation($0) }
        let creditItems = creditTransactions.map { UsageItem.creditAdded($0) }
        let combined = genItems + creditItems
        return combined.sorted { (a, b) in
            let da = a.sortDate ?? .distantPast
            let db = b.sortDate ?? .distantPast
            return da > db
        }
    }
    
    /// Balance before deduction for each generation (key = user_media id, lowercased). Only set when we have balance_after on the deduction transaction.
    var balanceBeforeByMediaId: [String: Double] {
        var map: [String: Double] = [:]
        for tx in deductionTransactions {
            guard let mediaId = tx.related_media_id,
                  let after = tx.balance_after else { continue }
            // amount is negative for deduction; balance_before = balance_after - amount
            let before = after - tx.amount
            map[mediaId.uuidString.lowercased()] = before
        }
        return map
    }
    
    private let client = SupabaseManager.shared.client
    
    func fetchUsage(userId: String?) async {
        guard let userId = userId else { return }
        
        isLoading = true
        
        do {
            // Fetch generations (success and failed)
            let response: PostgrestResponse<[UserImage]> = try await client.database
                .from("user_media")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .limit(1000)
                .execute()
            
            generations = response.value ?? []
            
            // Fetch credit additions (purchase + refund)
            let txResponse: PostgrestResponse<[CreditTransaction]> = try await client.database
                .from("credit_transactions")
                .select()
                .eq("user_id", value: userId)
                .in("transaction_type", values: ["purchase", "refund"])
                .order("created_at", ascending: false)
                .limit(500)
                .execute()
            
            creditTransactions = txResponse.value ?? []
            
            // Fetch deduction transactions (for "balance before" on generations)
            let dedResponse: PostgrestResponse<[CreditTransaction]> = try await client.database
                .from("credit_transactions")
                .select()
                .eq("user_id", value: userId)
                .eq("transaction_type", value: "deduction")
                .order("created_at", ascending: false)
                .limit(1000)
                .execute()
            
            deductionTransactions = (dedResponse.value ?? []).filter { $0.related_media_id != nil }
            
            print("✅ Fetched \(generations.count) generations, \(creditTransactions.count) credit additions, \(deductionTransactions.count) deductions for usage view")
        } catch {
            print("❌ Failed to fetch usage data: \(error)")
        }
        
        isLoading = false
    }
}

