// import SwiftUI

// struct SpinningPlusButton: View {
//     @Binding var showPhotoPicker: Bool
//     @State private var rotation: Double = 0
//     @State private var shine = false
//     @State private var isAnimating = false

//     var body: some View {
//         Button(action: {
//             showPhotoPicker = true
//         }) {
//             HStack {
//                 Image(systemName: "arrow.right")
//                     .font(.system(size: 20, weight: .bold, design: .rounded)).opacity(0)
//                 Spacer()
//                 Text("Add Photo")
//                     .font(.system(size: 20, weight: .bold, design: .rounded))
//                 Spacer()
//                 Image(systemName: "arrow.right")
//                     .font(.system(size: 20, weight: .bold, design: .rounded))
//                     .rotationEffect(.degrees(rotation))
//             }
//             .frame(maxWidth: .infinity)
//             .padding()
//             .background(Color.white)
//             .foregroundColor(.black)
//             .clipShape(RoundedRectangle(cornerRadius: 12))
//             .shadow(color: Color.green.opacity(0.4), radius: 8, x: 0, y: 4)
//             .scaleEffect(isAnimating ? 1.02 : 1.0)
//             .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: isAnimating)
//         }
//         .onAppear {
//             isAnimating = true
//             // Initial spin
//             withAnimation(.easeInOut(duration: 1.0)) {
//                 rotation += 360
//             }

//             // Continuous spin every few seconds
//             Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
//                 DispatchQueue.main.async {
//                     withAnimation(.easeInOut(duration: 1.0)) {
//                         rotation += 360
//                     }
//                 }
//             }

//             // Gradient shine animation
//             withAnimation(.linear(duration: 3.5).repeatForever(autoreverses: false)) {
//                 shine.toggle()
//             }
//         }
//     }
// }
