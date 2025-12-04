import SwiftUI

struct PhotoConfirmationView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var notificationManager: NotificationManager

    let item: InfoPacket
    let image: UIImage

    @State private var shimmer: Bool = false
    @State private var sparklePulse: Bool = false
    @State private var generatePulse: Bool = false

    @State private var rotation: Double = 0
    @State private var isAnimating = false

    @State private var generatedImage: UIImage? = nil
    @State private var isLoading = false

    @State private var arrowWiggle: Bool = false
    @State private var currentTaskId: UUID? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // MARK: - Animated Title

                ZStack {
                    Text("Confirm Your Photo")
                        .font(.custom("Nunito-Black", size: 28))
                        .foregroundColor(.primary)
                        .overlay(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.0),
                                    Color.white.opacity(0.9),
                                    Color.white.opacity(0.0),
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .rotationEffect(.degrees(20))
                            .offset(x: shimmer ? 300 : -300)
                            .mask(
                                Text("Confirm Your Photo")
                                    .font(.custom("Nunito-Black", size: 28))
                            )
                        )
                        .onAppear {
                            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                                shimmer.toggle()
                            }
                        }

                    Image(systemName: "sparkles")
                        .foregroundColor(.yellow.opacity(0.9))
                        .offset(x: -80, y: -10)
                        .scaleEffect(sparklePulse ? 1.2 : 0.8)
                        .opacity(sparklePulse ? 1 : 0.7)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: sparklePulse)

                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .offset(x: 80, y: -5)
                        .scaleEffect(sparklePulse ? 0.9 : 0.6)
                        .opacity(sparklePulse ? 0.95 : 0.6)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(0.3), value: sparklePulse)
                }
                .onAppear { sparklePulse = true }

                // MARK: - Main Photo

                // MARK: - Diagonal Overlapping Images

                GeometryReader { geometry in
                    let imageWidth = geometry.size.width * 0.48
                    let imageHeight = imageWidth * 1.38
                    let arrowYOffset = -imageHeight * 0.15

                    ZStack(alignment: .center) {
                        // Right image (example result) - drawn first so it's behind
                        Image(item.display.imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: imageWidth, height: imageHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        LinearGradient(colors: [.white, .gray], startPoint: .topLeading, endPoint: .bottomTrailing),
                                        lineWidth: 2
                                    )
                            )
                            .shadow(color: Color.black.opacity(0.25), radius: 12, x: 4, y: 4)
                            .rotationEffect(.degrees(8))
                            .offset(x: imageWidth * 0.50)

                        // Left image (user's photo) - drawn second so it's on top
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: imageWidth, height: imageHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        LinearGradient(colors: [.white, .gray], startPoint: .topLeading, endPoint: .bottomTrailing),
                                        lineWidth: 2
                                    )
                            )
                            .shadow(color: Color.black.opacity(0.25), radius: 12, x: -4, y: 4)
                            .rotationEffect(.degrees(-6))
                            .offset(x: -imageWidth * 0.50)

                        // Arrow with gentle wiggle
                        Image("arrow")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 62, height: 62)
                            .rotationEffect(.degrees(arrowWiggle ? 6 : -6))
                            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: arrowWiggle)
                            .offset(x: 0, y: arrowYOffset)
                    }
                    .onAppear {
                        arrowWiggle = true
                    }
                    .frame(width: geometry.size.width, height: imageHeight + 20)
                }
                .frame(height: 260)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

                if let generated = generatedImage {
                    VStack {
                        Text("Generated Image")
                            .font(.headline)
                        Image(uiImage: generated)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(radius: 8)
                    }
                }

                // MARK: - Generate Button

                Button(action: {
                    guard !isLoading else { return }

                    isLoading = true

//                    // Start background generation that persists across view changes
//                    // Note: The generation continues in background even if user leaves this view
//                    let taskId = notificationManager.startBackgroundGeneration(
//                        item: item,
//                        image: image,
//                        userId: authViewModel.user?.id.uuidString.lowercased() ?? "",
//                        onImageGenerated: { [weak notificationManager] downloadedImage in
//                            // Optional: Update local state only if still on this view
//                            // The image is already saved to database regardless
//                            DispatchQueue.main.async {
//                                generatedImage = downloadedImage
//                                isLoading = false
//                            }
//                        }
//                    )

//                    currentTaskId = taskId
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                        }
                        Text("Generate")
                            .font(.custom("Nunito-ExtraBold", size: 22))
                            .foregroundColor(.white)
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 18))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(rotation))
                            .drawingGroup()
                    }
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
//                    .background(.white)
                    .background(
                        LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .cornerRadius(12)
                    .shadow(color: Color.purple.opacity(0.3), radius: 8, x: 0, y: 4)
                    .scaleEffect(generatePulse ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: generatePulse)
                }
                .padding(.horizontal, 24)
                .onAppear {
                    generatePulse = true

                    isAnimating = true
                    // Kick off the first rotation immediately
                    withAnimation(.easeInOut(duration: 1.0)) {
                        rotation += 360
                    }
                    // Then continue spinning every 4 seconds
                    Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
                        withAnimation(.easeInOut(duration: 1.0)) {
                            rotation += 360
                        }
                    }
                }

                // MARK: - Cost Display

                HStack {
                    Spacer()
                    Image(systemName: "tag.fill")
                        .foregroundStyle(
                            LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    Text("$\(NSDecimalNumber(decimal: item.cost ?? 0).stringValue)")
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemBackground))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "diamond.fill")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .font(.system(size: 9))

                        Text("$5.00")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("credits left")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.secondary.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
            }
        }
    }
}
