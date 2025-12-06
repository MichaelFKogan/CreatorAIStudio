import SwiftUI

// MARK: - Filter Scroll Row

struct FilterScrollRow: View {
    let filters: [InfoPacket]
    let selectedFilter: InfoPacket?
    let onSelect: (InfoPacket) -> Void
    
    @State private var filterPositions: [UUID: CGFloat] = [:]
    @State private var isDragging = false
    @State private var isScrolling = false
    @State private var lastPositionHash: Int = 0
    @State private var checkScrollStopTask: DispatchWorkItem?
    @State private var currentCenteredFilterId: UUID?
    @State private var hapticGenerator = UIImpactFeedbackGenerator(style: .light)
    
    // Frame dimensions
    private let frameWidth: CGFloat = 80
    private let frameHeight: CGFloat = 80
    private let thumbnailWidth: CGFloat = 70
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Scrollable content
                ScrollViewReader { scrollProxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            // Leading spacer to center first item
                            Color.clear
                                .frame(width: (geometry.size.width - thumbnailWidth) / 2)
                            
// MARK: FOR EACH                           
                            ForEach(filters) { filter in
                                FilterThumbnailCompact(
                                    title: filter.display.title,
                                    imageName: filter.display.imageName,
                                    isSelected: selectedFilter?.id == filter.id,
                                    cost: filter.cost
                                )
                                .id(filter.id)
                                .background(
                                    GeometryReader { itemGeometry in
                                        Color.clear
                                            .preference(
                                                key: FilterPositionPreferenceKey.self,
                                                value: [filter.id: itemGeometry.frame(in: .named("scrollView")).midX]
                                            )
                                    }
                                )
                                .onTapGesture {
                                    // Cancel any pending snap when tapping
                                    checkScrollStopTask?.cancel()
                                    
                                    // Haptic feedback on tap
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                    
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        scrollProxy.scrollTo(filter.id, anchor: .center)
                                    }
                                    // Delay selection to allow scroll animation
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        onSelect(filter)
                                    }
                                }
                            }
                            
                            // Trailing spacer to center last item
                            Color.clear
                                .frame(width: (geometry.size.width - thumbnailWidth) / 2)
                        }
                        .padding(.horizontal, -12)
                    }
// MARK: TOOLBAR                    
                    .coordinateSpace(name: "scrollView")
                    .onPreferenceChange(FilterPositionPreferenceKey.self) { positions in
                        filterPositions = positions
                        
                        // Calculate hash of positions to detect when scrolling stops
                        let positionHash = positions.values.map { Int($0 * 1000) }.reduce(0, +)
                        lastPositionHash = positionHash
                        
                        // Check which filter is currently centered and trigger haptic if changed
                        checkCenteredFilter(centerX: geometry.size.width / 2)
                        
                        // Schedule check for scroll stop
                        if !isDragging && !isScrolling {
                            scheduleScrollStopCheck(
                                scrollProxy: scrollProxy,
                                centerX: geometry.size.width / 2,
                                currentHash: positionHash
                            )
                        }
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                isDragging = true
                                checkScrollStopTask?.cancel()
                            }
                            .onEnded { _ in
                                isDragging = false
                                // Schedule a check after drag ends to catch momentum scroll
                                let centerX = geometry.size.width / 2
                                scheduleScrollStopCheck(
                                    scrollProxy: scrollProxy,
                                    centerX: centerX,
                                    currentHash: lastPositionHash
                                )
                            }
                    )
                    .onChange(of: selectedFilter?.id) { newFilterId in
                        if let filterId = newFilterId {
                            isScrolling = true
                            checkScrollStopTask?.cancel()
                            
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                scrollProxy.scrollTo(filterId, anchor: .center)
                            }
                            
                            // Re-enable snapping after programmatic scroll
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                isScrolling = false
                            }
                        }
                    }
                }
                
// MARK: WHITE FRAME
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white, lineWidth: 5)
                    .frame(width: frameWidth, height: frameHeight)
                    .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 0)
                    .allowsHitTesting(false)
            }
            .frame(width: geometry.size.width)
            .onAppear {
                // Prepare haptic generator for immediate response
                hapticGenerator.prepare()
            }
        }
        .frame(height: 100)
    }
    
    private func checkCenteredFilter(centerX: CGFloat) {
        // Find the filter closest to center
        var closestFilter: InfoPacket?
        var minDistance: CGFloat = .infinity
        
        for filter in filters {
            if let position = filterPositions[filter.id] {
                let distance = abs(position - centerX)
                if distance < minDistance {
                    minDistance = distance
                    closestFilter = filter
                }
            }
        }
        
        // Trigger haptic if a different filter is now centered
        if let filter = closestFilter,
           filter.id != currentCenteredFilterId,
           minDistance < 50 { // Only if reasonably centered
            currentCenteredFilterId = filter.id
            hapticGenerator.impactOccurred(intensity: 0.6)
            hapticGenerator.prepare() // Prepare for next haptic
        }
    }
    
    private func scheduleScrollStopCheck(scrollProxy: ScrollViewProxy, centerX: CGFloat, currentHash: Int) {
        // Cancel any existing task
        checkScrollStopTask?.cancel()
        
        // Create new task
        let task = DispatchWorkItem { [weak checkScrollStopTask] in
            // Check if positions have stopped changing
            if self.lastPositionHash == currentHash && !self.isDragging && !self.isScrolling {
                self.snapToNearestFilter(scrollProxy: scrollProxy, centerX: centerX)
            } else if !self.isDragging && !self.isScrolling {
                // Positions still changing, schedule another check
                self.scheduleScrollStopCheck(
                    scrollProxy: scrollProxy,
                    centerX: centerX,
                    currentHash: self.lastPositionHash
                )
            }
        }
        
        checkScrollStopTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: task)
    }
    
    private func snapToNearestFilter(scrollProxy: ScrollViewProxy, centerX: CGFloat) {
        // Find the filter closest to center
        var closestFilter: InfoPacket?
        var minDistance: CGFloat = .infinity
        
        for filter in filters {
            if let position = filterPositions[filter.id] {
                let distance = abs(position - centerX)
                if distance < minDistance {
                    minDistance = distance
                    closestFilter = filter
                }
            }
        }
        
        // Snap to closest filter if it's different from current selection
        if let filter = closestFilter, filter.id != selectedFilter?.id {
            isScrolling = true
            
            // Haptic feedback on snap (stronger than scroll haptic)
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                scrollProxy.scrollTo(filter.id, anchor: .center)
            }
            onSelect(filter)
            
            // Re-enable snapping after programmatic scroll
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isScrolling = false
            }
        }
    }
}


struct FilterPositionPreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGFloat] = [:]
    
    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: THUMBNAIL

struct FilterThumbnailCompact: View {
    let title: String
    let imageName: String
    let isSelected: Bool
    let cost: Decimal?

    var body: some View {
        VStack(spacing: 2) {
            ZStack(alignment: .topTrailing) {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 70, height: 70)
                    .clipped()
                    .cornerRadius(12)
                    .padding(0)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.pink : Color.black.opacity(0), lineWidth: isSelected ? 3 : 1)
                    )
                    .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 0)
                    .overlay(
                        VStack(alignment: .trailing, spacing: 3) {
                            // Price badge (always visible if cost exists)
                            if let cost = cost {
                                Text("$\(NSDecimalNumber(decimal: cost).stringValue)")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(Color.black.opacity(0.7))
                                    )
                                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            }
                            
                            // // Checkmark (shown when selected, below price)
                            // if isSelected {
                            //     Image(systemName: "checkmark.circle.fill")
                            //         .font(.system(size: 18))
                            //         .foregroundStyle(.white)
                            //         .background(
                            //             Circle()
                            //                 .fill(
                            //                     LinearGradient(
                            //                         colors: [.purple, .pink],
                            //                         startPoint: .topLeading,
                            //                         endPoint: .bottomTrailing
                            //                     )
                            //                 )
                            //                 .frame(width: 22, height: 22)
                            //         )
                            //         .transition(.scale.combined(with: .opacity))
                            // }
                        },
                        alignment: .topTrailing
                    )

            }
            .animation(
                .spring(response: 0.3, dampingFraction: 0.7), value: isSelected)

            // Text(title)
            //     .font(.caption2)
            //     .lineLimit(1)
            //     .foregroundColor(.white)
            //     .frame(width: 70)
        }
    }
}

// MARK: STYLE SELECTION BUTTON TWO

struct StyleSelectionButtonTwo: View {
    let title: String
    let icon: String
    let description: String
    let backgroundImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        VStack {
            Button(action: action) {
                ZStack(alignment: .topTrailing) {
                    // Background image - no extra container
                    Image(backgroundImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipped()

                    // Clean content layout
                    VStack(alignment: .leading, spacing: 6) {
                        // Checkmark in top left
                        if isSelected {
                            HStack {
                                ZStack {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.accentColor)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            Spacer()
                        }
                    }
                    .padding(2)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            isSelected
                                ? Color.accentColor : Color.gray.opacity(0.3),
                            lineWidth: isSelected ? 3 : 1
                        )
                )
                .shadow(
                    color: isSelected
                        ? .accentColor.opacity(0.3) : .black.opacity(0.1),
                    radius: isSelected ? 8 : 4, x: 0, y: 2
                )
                .animation(.easeInOut(duration: 0.2), value: isSelected)
            }
            .padding(.vertical, 2)
            .buttonStyle(PlainButtonStyle())

            // Clean content layout
            VStack(alignment: .leading) {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.primary.opacity(0.95))
                    .lineLimit(2)
            }
        }
    }
}
