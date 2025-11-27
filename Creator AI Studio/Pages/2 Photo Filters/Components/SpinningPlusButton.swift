import SwiftUI

struct SpinningPlusButton: View {
    @Binding var showPhotoPicker: Bool
    @State private var rotation: Double = 0
    @State private var shine = false
    @State private var isAnimating = false

    var body: some View {
        Button(action: {
            showPhotoPicker = true
        }) {
            HStack {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 16, weight: .semibold))
                    .rotationEffect(.degrees(rotation))
                Text("Add Photo")
                    .font(.system(size: 17, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.green.opacity(1), Color.mint.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.green.opacity(0.4), radius: 8, x: 0, y: 4)
            .scaleEffect(isAnimating ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: isAnimating)
        }
        .onAppear {
            isAnimating = true
            // Initial spin
            withAnimation(.easeInOut(duration: 1.0)) {
                rotation += 360
            }

            // Continuous spin every few seconds
            Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 1.0)) {
                        rotation += 360
                    }
                }
            }

            // Gradient shine animation
            withAnimation(.linear(duration: 3.5).repeatForever(autoreverses: false)) {
                shine.toggle()
            }
        }
    }
}
