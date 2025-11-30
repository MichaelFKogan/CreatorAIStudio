import SwiftUI

// MARK: EXAMPLE PROMPTS SHEET
struct ExamplePromptsSheet: View {
    let examplePrompts: [String]
    @Binding var selectedPrompt: String
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(examplePrompts, id: \.self) { examplePrompt in
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
                                    .lineLimit(3)
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
            .navigationTitle("Example Prompts")
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
