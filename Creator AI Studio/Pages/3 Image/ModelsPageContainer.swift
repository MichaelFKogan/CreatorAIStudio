import SwiftUI

// MARK: - Models Page Container

struct ModelsPageContainer: View {
    @State private var selectedModelType: Int = 0 // 0 = Image, 1 = Video
    @State private var previousModelType: Int = 0 // Track previous selection for animation direction
    
    var body: some View {
        ZStack {
            // Content - use content-only versions with transitions
            // Each content view now has its own NavigationView so toolbar transitions too
            Group {
                if selectedModelType == 0 {
                    ImageModelsPageContent()
                        .id("image") // Force view identity for proper state management
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            )
                        )
                } else {
                    VideoModelsPageContent()
                        .id("video") // Force view identity for proper state management
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            )
                        )
                }
            }
            
            // Tab Switcher at bottom (above navbar)
            VStack {
                Spacer()
                ModelTypeTabSwitcher(selectedType: $selectedModelType, previousType: $previousModelType)
                    .padding(.bottom, 0) // No padding - background extends to navbar
            }
        }
    }
}

// MARK: - Model Type Tab Switcher

private struct ModelTypeTabSwitcher: View {
    @Binding var selectedType: Int
    @Binding var previousType: Int
    
    var body: some View {
        HStack(spacing: 0) {
            // Image Models button
            Button(action: { 
                previousType = selectedType
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectedType = 0
                }
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
        .padding(.bottom, 68) // Extend padding to match navbar height (55 + 8 + 5)
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
            .foregroundColor(isSelected ? color : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? color.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? color.opacity(0.6) : Color.clear, lineWidth: 1)
            )
    }
}
