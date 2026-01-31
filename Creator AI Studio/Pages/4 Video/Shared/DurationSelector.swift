import SwiftUI

struct DurationOption: Identifiable {
    let id: String
    let label: String
    let duration: Double // Duration in seconds
    let description: String? // Optional description
}

// MARK: DURATION SELECTOR BUTTON

struct DurationSelector: View {
    let options: [DurationOption]
    @Binding var selectedIndex: Int
    let color: Color
    
    @State private var isSheetPresented: Bool = false
    
    private var selectedOption: DurationOption {
        options[selectedIndex]
    }

    var body: some View {
        Button(action: { isSheetPresented = true }) {
            HStack(spacing: 12) {
                // Duration icon
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                    Image(systemName: "clock.fill")
                        .font(.system(size: 16))
                        .foregroundColor(color)
                }
                .frame(width: 40, height: 40)
                
                // Label and description
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedOption.label)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if let description = selectedOption.description {
                        Text(description)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()

                Text("Duration")
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
            DurationSelectorSheet(
                options: options,
                selectedIndex: $selectedIndex,
                color: color,
                isPresented: $isSheetPresented
            )
        }
    }
}

// MARK: DURATION SELECTOR SHEET

struct DurationSelectorSheet: View {
    let options: [DurationOption]
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
                                // Duration icon
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.gray.opacity(0.08))
                                    Image(systemName: "clock.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(isSelected ? color : Color.gray.opacity(0.5))
                                }
                                .frame(width: 40, height: 40)
                                
                                // Label and description
                                VStack(alignment: .leading, spacing: 2) {
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
                                    }
                                    
                                    if let description = option.description {
                                        Text(description)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
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
            .navigationTitle("Select Duration")
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
