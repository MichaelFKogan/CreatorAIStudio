import SwiftUI

enum ImageDiffAnimation {
    case scanHorizontal
    case scanVertical
    case scanHorizontalVarying
    case scanVerticalVarying
    case crossfade
    case slider
    case flipCard
    case cubeTurn
    case cameraAperture
    case instagramFilter
}

struct ImageAnimations: View {
    let originalImageName: String
    let transformedImageName: String
    let width: CGFloat
    let height: CGFloat
    let animation: ImageDiffAnimation
    
    @State private var scanPosition: CGFloat = 0
    @State private var scanPositionVertical: CGFloat = 0
    @State private var fadeToOriginal: Bool = false
    @State private var sliderPosition: CGFloat? = nil
    @State private var flipAngle: Double = 0
    @State private var cubeAngle: Double = 0
    @State private var scanHorizontalDuration: Double = 2.5
    @State private var scanVerticalDuration: Double = 2.5
    @State private var hasStartedAnimation: Bool = false
    @State private var apertureSize: CGFloat = 0
    @State private var instagramFilterOpacity: Double = 0
    
    // Helper to strip file extension from image name (iOS assets don't use extensions)
    private func assetName(from imageName: String) -> String {
        if let dotIndex = imageName.lastIndex(of: ".") {
            return String(imageName[..<dotIndex])
        }
        return imageName
    }
    
    var body: some View {
        ZStack {
            switch animation {
            case .scanHorizontal:
                scanningHorizontal
            case .scanVertical:
                scanningVertical
            case .scanHorizontalVarying:
                scanningHorizontal
            case .scanVerticalVarying:
                scanningVertical
            case .crossfade:
                crossfade
            case .slider:
                slider
            case .flipCard:
                flipCard
            case .cubeTurn:
                cubeTurn
            case .cameraAperture:
                cameraAperture
            case .instagramFilter:
                instagramFilter
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .onAppear {
            // Only start animation once to prevent restarting when view reappears
            if !hasStartedAnimation {
                startIfNeeded()
                hasStartedAnimation = true
            }
        }
    }
    
    // MARK: - Variants
    
    private var scanningHorizontal: some View {
        ZStack(alignment: .leading) {
            Image(assetName(from: transformedImageName))
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: height)
                .clipped()
            
            Image(assetName(from: originalImageName))
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: height)
                .clipped()
                .mask(
                    Rectangle()
                        .frame(width: scanPosition)
                        .frame(maxWidth: .infinity, alignment: .leading)
                )
            
            Rectangle()
                .fill(Color.white)
                .frame(width: 2)
                .frame(height: height)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 0)
                .offset(x: scanPosition)
        }
    }
    
    private var scanningVertical: some View {
        ZStack(alignment: .top) {
            Image(assetName(from: transformedImageName))
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: height)
                .clipped()
            
            Image(assetName(from: originalImageName))
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: height)
                .clipped()
                .mask(
                    Rectangle()
                        .frame(height: scanPositionVertical)
                        .frame(maxHeight: .infinity, alignment: .top)
                )
            
            Rectangle()
                .fill(Color.white)
                .frame(height: 2)
                .frame(width: width)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 0)
                .offset(y: scanPositionVertical)
        }
    }
    
    private var crossfade: some View {
        ZStack {
            Image(assetName(from: transformedImageName))
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: height)
                .clipped()
            
            Image(assetName(from: originalImageName))
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: height)
                .clipped()
                .opacity(fadeToOriginal ? 1.0 : 0.0)
        }
    }
    
    private var slider: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            ZStack(alignment: .leading) {
                Image(assetName(from: transformedImageName))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
                
                let currentX = sliderPosition ?? totalWidth * 0.5
                
                Image(assetName(from: originalImageName))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
                    .mask(
                        Rectangle()
                            .frame(width: currentX)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    )
                
                // Handle
                ZStack {
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 2)
                        .frame(height: height)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 0)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 0)
                }
                .contentShape(Rectangle())
                .offset(x: currentX - 1)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let newX = min(max(0, value.location.x), totalWidth)
                            sliderPosition = newX
                        }
                )
            }
        }
        .frame(width: width, height: height)
    }
    
    private var flipCard: some View {
        ZStack {
            // Front: original
            Image(assetName(from: originalImageName))
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: height)
                .clipped()
                .opacity(flipAngle < 90 ? 1 : 0)
            
            // Back: transformed
            Image(assetName(from: transformedImageName))
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: height)
                .clipped()
                .opacity(flipAngle >= 90 ? 1 : 0)
        }
        .rotation3DEffect(
            .degrees(flipAngle),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.6
        )
    }
    
    private var cubeTurn: some View {
        ZStack {
            // Leading face: original
            Image(assetName(from: originalImageName))
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: height)
                .clipped()
                .rotation3DEffect(
                    .degrees(cubeAngle),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .leading,
                    perspective: 0.6
                )
                .opacity(cubeAngle <= 90 ? 1 : 0)
            
            // Trailing face: transformed
            Image(assetName(from: transformedImageName))
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: height)
                .clipped()
                .rotation3DEffect(
                    .degrees(cubeAngle - 180),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .trailing,
                    perspective: 0.6
                )
                .opacity(cubeAngle > 90 ? 1 : 0)
        }
    }
    
    private var cameraAperture: some View {
        GeometryReader { geometry in
            let centerX = geometry.size.width / 2
            let centerY = geometry.size.height / 2
            let maxRadius = sqrt(pow(geometry.size.width, 2) + pow(geometry.size.height, 2)) / 2
            
            // Calculate overlay opacity: 0.3 when closed (apertureSize = 0), 0 when open (apertureSize = maxRadius)
            let overlayOpacity = max(0, 0.3 * (1 - (apertureSize / maxRadius)))
            
            ZStack {
                // Original image (background) - shown when aperture is closed
                Image(assetName(from: originalImageName))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
                    .overlay(
                        // Black overlay that fades out as aperture opens
                        Color.black.opacity(overlayOpacity)
                    )
                
                // Transformed image with circular mask (aperture effect) - shown when aperture is open
                Image(assetName(from: transformedImageName))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
                    .mask(
                        Circle()
                            .frame(width: apertureSize, height: apertureSize)
                            .position(x: centerX, y: centerY)
                    )
            }
        }
        .frame(width: width, height: height)
    }
    
    private var instagramFilter: some View {
        ZStack {
            // Original image (base)
            Image(assetName(from: originalImageName))
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: height)
                .clipped()
            
            // Transformed image with filter overlay effect
            Image(assetName(from: transformedImageName))
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: height)
                .clipped()
                .opacity(instagramFilterOpacity)
                .overlay(
                    // Instagram-style color overlay that fades in
                    LinearGradient(
                        colors: [
                            Color.purple.opacity(0.3 * instagramFilterOpacity),
                            Color.pink.opacity(0.2 * instagramFilterOpacity),
                            Color.orange.opacity(0.15 * instagramFilterOpacity)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
    
    // MARK: - Animation Control
    
    private func startIfNeeded() {
        switch animation {
        case .scanHorizontal:
            scanPosition = 0
            withAnimation(
                Animation
                    .easeInOut(duration: 1.25)
                    .repeatForever(autoreverses: true)
            ) {
                scanPosition = width
            }
            
        case .scanVertical:
            scanPositionVertical = 0
            withAnimation(
                Animation
                    .easeInOut(duration: 1.25)
                    .repeatForever(autoreverses: true)
            ) {
                scanPositionVertical = height
            }
        case .scanHorizontalVarying:
            scanHorizontalDuration = Double.random(in: 1.0...2.0)
            scanPosition = 0
            withAnimation(
                Animation
                    .easeInOut(duration: scanHorizontalDuration)
                    .repeatForever(autoreverses: true)
            ) {
                scanPosition = width
            }
        case .scanVerticalVarying:
            scanVerticalDuration = Double.random(in: 1.0...2.0)
            scanPositionVertical = 0
            withAnimation(
                Animation
                    .easeInOut(duration: scanVerticalDuration)
                    .repeatForever(autoreverses: true)
            ) {
                scanPositionVertical = height
            }
            
        case .crossfade:
            fadeToOriginal = false
            withAnimation(
                Animation
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
            ) {
                fadeToOriginal = true
            }
            
        case .cubeTurn:
            cubeAngle = 0
            withAnimation(
                Animation
                    .easeInOut(duration: 2)
                    .repeatForever(autoreverses: true)
            ) {
                cubeAngle = 180
            }
            
        case .flipCard:
            flipAngle = 0
            withAnimation(
                Animation
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
            ) {
                flipAngle = 180
            }
            
        case .slider:
            // Initialize slider to middle
            sliderPosition = width * 0.5
            
        case .cameraAperture:
            apertureSize = 0
            let maxRadius = sqrt(pow(width, 2) + pow(height, 2))
            
            // Custom sequence: Open quickly, stay open longer, close quickly, stay closed shorter
            func animateAperture() {
                // Phase 1: Open aperture quickly (ease-out) - reveals transformed image
                // Duration: 0.3s
                withAnimation(
                    Animation
                        .easeOut(duration: 0.3)
                ) {
                    apertureSize = maxRadius
                }
                
                // Phase 2: Stay open (pause) - show transformed image longer
                // Wait: 0.3s (animation) + 1.5s (pause) = 1.8s total
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    // Phase 3: Close aperture quickly (ease-in) - shows original image
                    // Duration: 0.3s
                    withAnimation(
                        Animation
                            .easeIn(duration: 0.3)
                    ) {
                        apertureSize = 0
                    }
                    
                    // Phase 4: Stay closed (pause) - show original image shorter, then repeat
                    // Wait: 0.3s (animation) + 0.5s (pause) = 0.8s total
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        animateAperture() // Loop
                    }
                }
            }
            
            animateAperture()
            
        case .instagramFilter:
            instagramFilterOpacity = 0
            withAnimation(
                Animation
                    .easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true)
            ) {
                instagramFilterOpacity = 1.0
            }
        }
    }
}

