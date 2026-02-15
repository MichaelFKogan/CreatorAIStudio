import SwiftUI

// MARK: EXAMPLE PROMPTS SHEET

struct ExamplePromptsSheet: View {
    let examplePrompts: [String]
    let examplePromptsTransform: [String]
    @Binding var selectedPrompt: String
    @Binding var isPresented: Bool
    let title: String
    /// When true, tabs are hidden and only examplePrompts are shown (single list).
    var singleList: Bool = false
    /// When true, prompt text is not truncated (no line limit). Default false uses 3 lines.
    var unlimitedLines: Bool = false

    @State private var selectedTab: Int = 0

    private var currentPrompts: [String] {
        singleList ? examplePrompts : (selectedTab == 0 ? examplePrompts : examplePromptsTransform)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if !singleList {
                    TabSwitcher(selectedMode: $selectedTab)
                        .padding(.top, 8)
                }

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(currentPrompts, id: \.self) { examplePrompt in
                            Button(action: {
                                selectedPrompt = examplePrompt
                                isPresented = false
                            }) {
                                HStack(spacing: 12) {
                                    // Prompt text
                                    Text(examplePrompt)
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(unlimitedLines ? nil : 3)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    // Arrow icon
                                    Image(systemName: "arrow.up.left")
                                        .font(.system(size: 12))
                                        .foregroundColor(.blue.opacity(0.6))
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.gray.opacity(0.06))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(title)
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
}

// MARK: TAB SWITCHER

struct TabSwitcher: View {
    @Binding var selectedMode: Int

    var body: some View {
        HStack(spacing: 0) {
            // Text to Image button with icon
            Button(action: { selectedMode = 0 }) {
                HStack(spacing: 6) {
                    Image(systemName: "character.textbox")
                        .font(.system(size: 10))
                    Text("Text to Image")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
            }
            .tabButtonStyle(isSelected: selectedMode == 0)

            // Image to Image button with icon
            Button(action: { selectedMode = 1 }) {
                HStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 10))
                    Text("Image to Image")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
            }
            .tabButtonStyle(isSelected: selectedMode == 1)
        }
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8).stroke(
                Color.gray.opacity(0.3), lineWidth: 1
            )
        )
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

// extension View {
//     func tabButtonStyle(isSelected: Bool) -> some View {
//         font(.caption).fontWeight(.medium)
//             .foregroundColor(isSelected ? .white : .secondary)
//             .frame(maxWidth: .infinity)
//             .padding(.vertical, 10)
//             .background(isSelected ? Color.gray.opacity(0.15) : Color.clear)
//             .clipShape(RoundedRectangle(cornerRadius: 8))
//     }
// }
