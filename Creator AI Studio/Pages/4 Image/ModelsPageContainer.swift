import SwiftUI

// MARK: - Models Page Container

struct ModelsPageContainer: View {
    @AppStorage("selectedModelType") private var savedModelType: Int = 0 // 0 = Image, 1 = Video (persisted)
    @State private var selectedModelType: Int = 0 // Local state for animation
    @State private var previousModelType: Int = 0 // Track previous selection for animation direction
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Content - use content-only versions with transitions
                // Each content view now has its own NavigationView so toolbar transitions too
                // Keep both views in hierarchy for better transition support with NavigationView
                ImageModelsPageContent()
                    .id("image") // Force view identity for proper state management
                    .opacity(selectedModelType == 0 ? 1 : 0)
                    .offset(x: selectedModelType == 0 ? 0 : -geometry.size.width)
                    .allowsHitTesting(selectedModelType == 0)
                
                VideoModelsPageContent()
                    .id("video") // Force view identity for proper state management
                    .opacity(selectedModelType == 1 ? 1 : 0)
                    .offset(x: selectedModelType == 1 ? 0 : geometry.size.width)
                    .allowsHitTesting(selectedModelType == 1)
                
                // Tab Switcher at bottom (above navbar)
                VStack {
                    Spacer()
                    ModelTypeTabSwitcher(selectedType: $selectedModelType, previousType: $previousModelType, savedType: $savedModelType)
                        .padding(.bottom, 0) // No padding - background extends to navbar
                }
            }
            .animation(.easeInOut(duration: 0.3), value: selectedModelType)
        }
        .onAppear {
            // Initialize from saved value without animation on first load or reappear
            if selectedModelType != savedModelType {
                // Update state without animation using a transaction
                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    selectedModelType = savedModelType
                    previousModelType = savedModelType
                }
            } else {
                // Ensure previousModelType is set even if state matches
                previousModelType = savedModelType
            }
        }
    }
}

// MARK: - Model Type Tab Switcher

private struct ModelTypeTabSwitcher: View {
    @Binding var selectedType: Int
    @Binding var previousType: Int
    @Binding var savedType: Int
    
    var body: some View {
        HStack(spacing: 0) {
            // Image Models button
            Button(action: { 
                previousType = selectedType
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectedType = 0
                }
                savedType = 0 // Save to AppStorage
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 12))
                    Text("Image Models")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
            }
            .filterPillTabStyle(isSelected: selectedType == 0, color: .blue)
            
            // Video Models button
            Button(action: { 
                previousType = selectedType
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectedType = 1
                }
                savedType = 1 // Save to AppStorage
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 12))
                    Text("Video Models")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
            }
            .filterPillTabStyle(isSelected: selectedType == 1, color: .purple)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10).stroke(
                Color.gray.opacity(0.3), lineWidth: 1
            )
        )
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
        // .padding(.bottom, 68) // Extend padding to match navbar height (55 + 8 + 5)
        .background(
            Color.black
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(
            // Top border to separate from content
            VStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 0.5)
                Spacer()
            }
        )
    }
}

// MARK: - Tab Button Style Extension

extension View {
    func filterPillTabStyle(isSelected: Bool, color: Color) -> some View {
        font(.caption)
            .fontWeight(.medium)
            .foregroundColor(isSelected ? .white : color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? color.opacity(1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? color.opacity(1) : Color.clear, lineWidth: 1)
            )
    }
}
