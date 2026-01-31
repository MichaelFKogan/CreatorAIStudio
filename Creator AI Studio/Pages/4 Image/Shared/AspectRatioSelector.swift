import SwiftUI

struct AspectRatioOption: Identifiable {
    let id: String
    let label: String
    let width: CGFloat
    let height: CGFloat
    let platforms: [String]
}

// MARK: ASPECT RATIO SELECTOR BUTTON

struct AspectRatioSelector: View {
    let options: [AspectRatioOption]
    @Binding var selectedIndex: Int
    let color: Color
    
    @State private var isSheetPresented: Bool = false
    
    private var selectedOption: AspectRatioOption {
        options[selectedIndex]
    }

    var body: some View {
        Button(action: { isSheetPresented = true }) {
            HStack(spacing: 12) {
                // Rectangular preview
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(color, lineWidth: 2)
                        .aspectRatio(selectedOption.width / selectedOption.height, contentMode: .fit)
                        .padding(4)
                }
                .frame(width: 40, height: 40)
                
                // Label and platform
                HStack(spacing: 6) {
                    Text(selectedOption.label)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if !selectedOption.platforms.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(selectedOption.platforms, id: \.self) { platform in
                                Text(platform)
                                    .font(.caption2)
                                    .foregroundColor(color)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(color.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                
                Spacer()

                Text("Size")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isSheetPresented) {
            AspectRatioSelectorSheet(
                options: options,
                selectedIndex: $selectedIndex,
                color: color,
                isPresented: $isSheetPresented
            )
        }
    }
}

// MARK: ASPECT RATIO SELECTOR SHEET

struct AspectRatioSelectorSheet: View {
    let options: [AspectRatioOption]
    @Binding var selectedIndex: Int
    let color: Color
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(options.indices, id: \.self) { idx in
                        let option = options[idx]
                        let isSelected = idx == selectedIndex
                        
                        Button {
                            selectedIndex = idx
                            isPresented = false
                        } label: {
                            HStack(spacing: 12) {
                                // Rectangular preview
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.gray.opacity(0.08))
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(isSelected ? color : Color.gray.opacity(0.5), lineWidth: isSelected ? 2 : 1)
                                        .aspectRatio(option.width / option.height, contentMode: .fit)
                                        .padding(4)
                                }
                                .frame(width: 40, height: 40)
                                
                                // Label and platform info
                                HStack(spacing: 6) {
                                    Text(option.label)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    
                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(color)
                                    }
                                    
                                    if !option.platforms.isEmpty {
                                        HStack(spacing: 4) {
                                            ForEach(option.platforms, id: \.self) { platform in
                                                Text(platform)
                                                    .font(.caption2)
                                                    .foregroundColor(color)
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 2)
                                                    .background(color.opacity(0.12))
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                }
                                
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isSelected ? color : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Select Size")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

//// MARK: ASPECT RATIO SECTION
//
//struct AspectRatioSection: View {
//    let options: [AspectRatioOption]
//    @Binding var selectedIndex: Int
//    var body: some View {
//        VStack(alignment: .leading, spacing: 6) {
//            Text("Size")
//                .font(.caption)
//                .foregroundColor(.secondary)
//                .padding(.top, -6)
//            AspectRatioSelector(
//                options: options, selectedIndex: $selectedIndex, color: .blue
//            )
//        }
//        .padding(.horizontal)
//    }
//}
