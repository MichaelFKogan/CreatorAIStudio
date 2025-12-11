import Kingfisher
import SwiftUI

// MARK: - Filter Scroll Row

struct FilterScrollRow: View {
    let presets: [InfoPacket]
    let imageModels: [InfoPacket]
    let filters: [InfoPacket]
    let selectedFilter: InfoPacket?
    let selectedImageModel: InfoPacket?
    let onSelect: (InfoPacket) -> Void
    var onCenteredFilterChanged: ((InfoPacket?) -> Void)? = nil
    var onScrollingStateChanged: ((Bool) -> Void)? = nil
    var onCapture: (() -> Void)? = nil
    var isCaptureEnabled: Bool = false

    // // Combined items: presets first, then image models, then filters
    // private var allItems: [InfoPacket] {
    //     presets + imageModels + filters
    // }

        // Combined items: presets first, then image models, then filters
    private var allItems: [InfoPacket] {
        imageModels + filters
    }

    @State private var filterPositions: [UUID: CGFloat] = [:]
    @State private var isDragging = false
    @State private var isScrolling = false
    @State private var lastPositionHash: Int = 0
    @State private var checkScrollStopTask: DispatchWorkItem?
    @State private var currentCenteredFilterId: UUID?
    @State private var hapticGenerator = UIImpactFeedbackGenerator(
        style: .light)
    @State private var isScrollingActive = false
    @State private var scrollStopTimer: DispatchWorkItem?
    @State private var hasInitializedPositions = false
    @State private var hasUserInteracted = false

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
                            // Leading spacer to position first item to the right of white frame
                            // White frame is centered at width/2, extends 40 points each side
                            // Position first item to start after the frame (width/2 + 40 + spacing)
                            Color.clear
                                .frame(
                                    width: geometry.size.width / 2 + frameWidth
                                        / 2 + 12)

                            // MARK: FOR EACH
                            ForEach(allItems) { item in
                                FilterThumbnailCompact(
                                    title: item.display.title,
                                    imageName: item.display.imageName,
                                    isSelected: (selectedFilter?.id == item.id)
                                        || (selectedImageModel?.id == item.id),
                                    cost: item.cost,
                                    imageUrl: item.display.imageName.hasPrefix(
                                        "http") ? item.display.imageName : nil
                                )
                                .id(item.id)
                                .background(
                                    GeometryReader { itemGeometry in
                                        Color.clear
                                            .preference(
                                                key: FilterPositionPreferenceKey
                                                    .self,
                                                value: [
                                                    item.id: itemGeometry.frame(
                                                        in: .named("scrollView")
                                                    ).midX
                                                ]
                                            )
                                    }
                                )
                                .onTapGesture {
                                    // Mark that user has interacted
                                    hasUserInteracted = true
                                    // Cancel any pending snap when tapping
                                    checkScrollStopTask?.cancel()

                                    // Haptic feedback on tap
                                    let impactFeedback =
                                        UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()

                                    withAnimation(
                                        .spring(
                                            response: 0.4, dampingFraction: 0.8)
                                    ) {
                                        scrollProxy.scrollTo(
                                            item.id, anchor: .center)
                                    }
                                    // Delay selection to allow scroll animation
                                    DispatchQueue.main.asyncAfter(
                                        deadline: .now() + 0.1
                                    ) {
                                        onSelect(item)
                                    }
                                }
                            }

                            // Trailing spacer to center last item
                            Color.clear
                                .frame(
                                    width: (geometry.size.width - thumbnailWidth)
                                        / 2)
                        }
                        .padding(.horizontal, -12)
                    }
                    // MARK: TOOLBAR
                    .coordinateSpace(name: "scrollView")
                    .onPreferenceChange(FilterPositionPreferenceKey.self) {
                        positions in
                        filterPositions = positions

                        // Calculate hash of positions to detect when scrolling stops
                        let positionHash = positions.values.map {
                            Int($0 * 1000)
                        }.reduce(0, +)
                        let positionsChanged = positionHash != lastPositionHash

                        // Initialize lastPositionHash on first render to prevent false positive
                        if !hasInitializedPositions {
                            lastPositionHash = positionHash
                            hasInitializedPositions = true
                            // Don't check centered filter on initial load - wait for user interaction
                            // This prevents the preview from showing immediately
                            return
                        }

                        // Only process scrolling state if user has interacted
                        // This prevents the preview from showing on initial layout
                        guard hasUserInteracted else { return }

                        // Update lastPositionHash to track changes
                        lastPositionHash = positionHash

                        // If positions are changing, user is scrolling (either dragging or momentum)
                        if positionsChanged {
                            // Set scrolling active and check centered filter during any scroll
                            setScrollingActive(true)
                            scheduleScrollStopFade()
                            // Check centered filter during scrolling (including momentum)
                            checkCenteredFilter(
                                centerX: geometry.size.width / 2)
                        }

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
                                // Mark that user has interacted
                                hasUserInteracted = true
                                isDragging = true
                                checkScrollStopTask?.cancel()
                                setScrollingActive(true)
                                // Check centered filter when user starts dragging
                                checkCenteredFilter(
                                    centerX: geometry.size.width / 2)
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
                                // Schedule fade out after scroll stops
                                scheduleScrollStopFade()
                            }
                    )
                    .onChange(of: selectedFilter?.id) { newFilterId in
                        if let filterId = newFilterId {
                            // Mark that user has interacted (filter selected from sheet)
                            hasUserInteracted = true
                            isScrolling = true
                            checkScrollStopTask?.cancel()
                            setScrollingActive(true)

                            withAnimation(
                                .spring(response: 0.4, dampingFraction: 0.8)
                            ) {
                                scrollProxy.scrollTo(filterId, anchor: .center)
                            }

                            // Re-enable snapping after programmatic scroll
                            DispatchQueue.main.asyncAfter(
                                deadline: .now() + 0.5
                            ) {
                                isScrolling = false
                                scheduleScrollStopFade()
                            }
                        }
                    }
                    .onChange(of: selectedImageModel?.id) { newModelId in
                        if let modelId = newModelId {
                            // Mark that user has interacted (model selected from sheet)
                            hasUserInteracted = true
                            isScrolling = true
                            checkScrollStopTask?.cancel()
                            setScrollingActive(true)

                            withAnimation(
                                .spring(response: 0.4, dampingFraction: 0.8)
                            ) {
                                scrollProxy.scrollTo(modelId, anchor: .center)
                            }

                            // Re-enable snapping after programmatic scroll
                            DispatchQueue.main.asyncAfter(
                                deadline: .now() + 0.5
                            ) {
                                isScrolling = false
                                scheduleScrollStopFade()
                            }
                        }
                    }
                }

                // MARK: WHITE FRAME
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        style: StrokeStyle(
                            lineWidth: 3.5, dash: [6, 4]
                        )
                    )
                    .foregroundColor(.secondary.opacity(0.8))
                    .frame(width: frameWidth, height: frameHeight)
                    .shadow(
                        color: .black.opacity(0.5), radius: 8, x: 0, y: 0)
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
        // Find the item closest to center
        var closestItem: InfoPacket?
        var minDistance: CGFloat = .infinity

        for item in allItems {
            if let position = filterPositions[item.id] {
                let distance = abs(position - centerX)
                if distance < minDistance {
                    minDistance = distance
                    closestItem = item
                }
            }
        }

        // Check if an item is reasonably centered (within 50 points)
        if let item = closestItem, minDistance < 50 {
            // Trigger haptic if a different item is now centered
            if item.id != currentCenteredFilterId {
                currentCenteredFilterId = item.id
                hapticGenerator.impactOccurred(intensity: 0.6)
                hapticGenerator.prepare()  // Prepare for next haptic
            }
            // Always notify parent of centered item for real-time title updates
            onCenteredFilterChanged?(item)
        } else if currentCenteredFilterId != nil {
            // No item is reasonably centered anymore
            currentCenteredFilterId = nil
            onCenteredFilterChanged?(nil)
        }
    }

    private func scheduleScrollStopCheck(
        scrollProxy: ScrollViewProxy, centerX: CGFloat, currentHash: Int
    ) {
        // Cancel any existing task
        checkScrollStopTask?.cancel()

        // Create new task
        let task = DispatchWorkItem { [weak checkScrollStopTask] in
            // Check if positions have stopped changing
            if self.lastPositionHash == currentHash && !self.isDragging
                && !self.isScrolling
            {
                self.snapToNearestFilter(
                    scrollProxy: scrollProxy, centerX: centerX)
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

    private func snapToNearestFilter(
        scrollProxy: ScrollViewProxy, centerX: CGFloat
    ) {
        // Find the item closest to center
        var closestItem: InfoPacket?
        var minDistance: CGFloat = .infinity

        for item in allItems {
            if let position = filterPositions[item.id] {
                let distance = abs(position - centerX)
                if distance < minDistance {
                    minDistance = distance
                    closestItem = item
                }
            }
        }

        // Snap to closest item if it's different from current selection
        let currentSelectionId = selectedFilter?.id ?? selectedImageModel?.id
        if let item = closestItem, item.id != currentSelectionId {
            isScrolling = true
            setScrollingActive(true)

            // Haptic feedback on snap (stronger than scroll haptic)
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()

            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                scrollProxy.scrollTo(item.id, anchor: .center)
            }
            onSelect(item)

            // Re-enable snapping after programmatic scroll
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isScrolling = false
                scheduleScrollStopFade()
            }
        } else {
            // No snap needed, scrolling has stopped
            scheduleScrollStopFade()
        }
    }

    private func setScrollingActive(_ active: Bool) {
        if isScrollingActive != active {
            isScrollingActive = active
            onScrollingStateChanged?(active)
        }
    }

    private func scheduleScrollStopFade() {
        // Cancel any existing timer
        scrollStopTimer?.cancel()

        // Create new timer to fade out after scroll stops
        let task = DispatchWorkItem {
            // Only fade out if we're not dragging or programmatically scrolling
            if !self.isDragging && !self.isScrolling {
                self.setScrollingActive(false)
            }
        }

        scrollStopTimer = task
        // Wait a bit after scrolling stops before fading out
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
    }
}

struct FilterPositionPreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGFloat] = [:]

    static func reduce(
        value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]
    ) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: THUMBNAIL

struct FilterThumbnailCompact: View {
    let title: String
    let imageName: String
    let isSelected: Bool
    let cost: Decimal?
    let imageUrl: String?  // Optional URL for user-generated images (presets)

    init(
        title: String, imageName: String, isSelected: Bool, cost: Decimal?,
        imageUrl: String? = nil
    ) {
        self.title = title
        self.imageName = imageName
        self.isSelected = isSelected
        self.cost = cost
        self.imageUrl = imageUrl
    }

    // Check if imageName is a URL
    private var isImageUrl: Bool {
        imageName.hasPrefix("http://") || imageName.hasPrefix("https://")
    }

    // Use imageUrl if provided, otherwise check if imageName is a URL
    private var effectiveImageUrl: String? {
        imageUrl ?? (isImageUrl ? imageName : nil)
    }

    private var effectiveImageName: String {
        isImageUrl ? "" : imageName
    }

    var body: some View {
        VStack(spacing: 2) {
            ZStack(alignment: .topTrailing) {
                // Use KFImage for URLs, Image for local assets
                Group {
                    if let urlString = effectiveImageUrl,
                        let url = URL(string: urlString)
                    {
                        KFImage(url)
                            .placeholder {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .overlay(ProgressView())
                            }
                            .resizable()
                            .scaledToFill()
                            .frame(width: 70, height: 70)
                            .clipped()
                            .cornerRadius(12)
                            .padding(0)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        isSelected
                                            ? Color.pink
                                            : Color.black.opacity(0),
                                        lineWidth: isSelected ? 4 : 1)
                            )
                            .shadow(
                                color: .black.opacity(0.6), radius: 4, x: 0,
                                y: 0
                            )
                            .overlay(
                                VStack(alignment: .trailing, spacing: 3) {
                                    // Price badge (always visible if cost exists)
                                    if let cost = cost {
                                        // Text( "$\(NSDecimalNumber(decimal: cost).stringValue)")
                                        Text("\(cost.credits)")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(
                                            Capsule()
                                                .fill(Color.black.opacity(0.7))
                                        )
                                        .shadow(
                                            color: .black.opacity(0.3),
                                            radius: 2, x: 0,
                                            y: 1)
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
                                }
                                .padding(3),
                                alignment: .bottomTrailing
                            )
                    } else {
                        Image(effectiveImageName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 70, height: 70)
                            .clipped()
                            .cornerRadius(12)
                            .padding(0)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        isSelected
                                            ? Color.pink
                                            : Color.black.opacity(0),
                                        lineWidth: isSelected ? 4 : 1)
                            )
                            .shadow(
                                color: .black.opacity(0.6), radius: 4, x: 0,
                                y: 0
                            )
                            .overlay(
                                VStack(alignment: .trailing, spacing: 3) {
                                    // Price badge (always visible if cost exists)
                                    if let cost = cost {
                                        // Text("$\(NSDecimalNumber(decimal: cost).stringValue)")
                                        Text("\(cost.credits)")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background( Capsule().fill(Color.black.opacity(0.7)))
                                        .shadow( color: .black.opacity(0.3), radius: 2, x: 0,y: 1)}

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
                                }
                                .padding(3),
                                alignment: .bottomTrailing
                            )
                    }
                }
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
