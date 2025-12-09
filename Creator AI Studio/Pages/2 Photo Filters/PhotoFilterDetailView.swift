//
//  ImageDetailView.swift
//  AI Photo Generation
//
//  Created by Mike K on 10/16/25.
//

import PhotosUI
import SwiftUI

struct PhotoFilterDetailView: View {
    let item: InfoPacket
    @State private var prompt: String = ""
    @State private var isGenerating: Bool = false
    @State private var selectedImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showCamera: Bool = false
    @State private var showPhotoPicker: Bool = false  // <-- new state
    @State private var createArrowMove: Bool = false
    @State private var navigateToConfirmation: Bool = false

    func allMoreStyles(for packet: InfoPacket) -> [InfoPacket] {
        // moreStyles is currently [[String]]? and doesn't contain InfoPacket objects
        // Return empty array until this feature is fully implemented
        // TODO: Implement lookup mechanism to convert moreStyles identifiers to InfoPacket objects
        return []
    }

    private var creditsDisplayView: some View {
        HStack(spacing: 12) {
            // Credits Display
            HStack(spacing: 6) {
                Image(systemName: "diamond.fill")
                    .foregroundStyle(diamondGradient)
                    .font(.system(size: 9))

                Text("$5.00")
                    .font(
                        .system(size: 16, weight: .semibold, design: .rounded)
                    )
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
                    .strokeBorder(diamondGradient)
            )
        }
    }

    private var diamondGradient: LinearGradient {
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                AnimatedTitle(text: item.display.title)

                // Hero Images Section - Two overlapping diagonal images
                DiagonalOverlappingImages(
                    leftImageName: item.display.imageNameOriginal
                        ?? item.display.imageName,
                    rightImageName: item.display.imageName
                )

                // Card 1: Photo Upload Section
                VStack(alignment: .leading) {
                    //                    HStack {
                    //                        Image(systemName: "photo.badge.plus")
                    //                            .foregroundColor(.blue)
                    //                        Text("Step 1: Add Your Photo")
                    //                            .font(.headline)
                    //                            .foregroundColor(.primary)
                    //                        Spacer()
                    //                    }
                    //
                    //                    Text("Upload or take a photo to transform")
                    //                        .font(.caption)
                    //                        .foregroundColor(.secondary)

                    // Horizontal layout: Add photo box on the left, Create button on the right
                    // Compute inner width based on page padding (24 + 24)
                    let pageInnerWidth = UIScreen.main.bounds.width - 48
                    let addPhotoWidth = pageInnerWidth * 0.48
                    let createButtonWidth = pageInnerWidth - addPhotoWidth - 16  // account for spacing
                    let controlHeight: CGFloat = 250

                    HStack(alignment: .center, spacing: 16) {

                        SpinningPlusButton(showPhotoPicker: $showPhotoPicker)
                            .photosPicker(
                                isPresented: $showPhotoPicker,
                                selection: $selectedPhotoItem,
                                matching: .images
                            )
                    }
                    .padding(.horizontal, 16)
                    .cornerRadius(16)
                    .shadow(
                        color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)

                    // MARK: - Cost Section
                    HStack {
                        Spacer()
                        HStack {
                            Image(systemName: "tag.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing))

                            // Decimal? -> Double for formatter safety
                            let costValue = (item.cost as NSDecimalNumber?)?
                                .doubleValue ?? 0.0

                            Text("Cost: $\(costValue, specifier: "%.2f")")
                                .font(.custom("Nunito-Bold", size: 16))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .padding(.trailing, 6)

                    // Example Images Section
                    if let exampleImages = item.display.exampleImages,
                        !exampleImages.isEmpty
                    {
                        ExampleImagesSection(images: exampleImages)
                    }

                    // MARK: - More Styles
                    if let moreStyles = item.display.moreStyles,
                        !moreStyles.isEmpty
                    {
                        VStack {
                            HStack {
                                Image(systemName: "paintbrush")
                                    .foregroundColor(.blue)
                                Text("More Styles")
                                    .font(.custom("Nunito-Bold", size: 22))
                                Spacer()
                            }

                            HStack {
                                Text(
                                    "See what's possible with this image style"
                                )
                                .font(.caption)
                                .foregroundColor(.secondary)
                                Spacer()
                            }
                        }

                        MoreStylesImageSection(items: allMoreStyles(for: item))

                    }

                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 150)

            NavigationLink(isActive: $navigateToConfirmation) {
                if let image = selectedImage {
                    PhotoConfirmationView(item: item, image: image)
                }
            } label: {
                EmptyView()
            }

        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                creditsDisplayView
            }
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(sourceType: .camera, selectedImage: $selectedImage)
        }
        // Replace the existing .onChange(of: selectedPhotoItem) modifier with this:

        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                // Wait for the image to load first
                guard
                    let data = try? await newItem?.loadTransferable(
                        type: Data.self),
                    let uiImage = UIImage(data: data)
                else {
                    return
                }

                // Update state on the main actor - but do it in the right order
                await MainActor.run {
                    selectedImage = uiImage  // Set the image FIRST
                }

                // Small delay to ensure state is fully updated before navigation
                try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

                await MainActor.run {
                    navigateToConfirmation = true  // Then trigger navigation
                }
            }
        }
        .onAppear {
            prompt = item.prompt ?? ""
            // kick off the subtle arrow motion next to the Create text
            createArrowMove = true
        }
    }
}

// MARK: - Animated Title
struct AnimatedTitle: View {
    let text: String
    @State private var shimmer: Bool = false
    @State private var sparklePulse: Bool = false

    var body: some View {
        ZStack {
            Text(text)
                //                .font(.title)
                .font(.custom("Nunito-Black", size: 30))
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
                        Text(text)
                            .font(.title)
                            .fontWeight(.bold)
                    )
                )
                .onAppear {
                    withAnimation(
                        .linear(duration: 2.2).repeatForever(
                            autoreverses: false)
                    ) {
                        shimmer.toggle()
                    }
                }

            // Subtle sparkles around the title
            Image(systemName: "sparkles")
                .foregroundColor(.yellow.opacity(0.9))
                .offset(x: -70, y: -18)
                .scaleEffect(sparklePulse ? 1.15 : 0.85)
                .opacity(sparklePulse ? 1.0 : 0.7)
                .animation(
                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                    value: sparklePulse)

            Image(systemName: "star.fill")
                .foregroundColor(.yellow)
                .offset(x: 72, y: -6)
                .scaleEffect(sparklePulse ? 0.9 : 0.6)
                .opacity(sparklePulse ? 0.95 : 0.6)
                .animation(
                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                        .delay(0.3), value: sparklePulse)
        }
        .onAppear { sparklePulse = true }
    }
}

// MARK: - Diagonal Overlapping Images
struct DiagonalOverlappingImages: View {
    let leftImageName: String
    let rightImageName: String

    @State private var arrowWiggle: Bool = false

    var body: some View {
        GeometryReader { geometry in
            let imageWidth = geometry.size.width * 0.53
            let imageHeight = imageWidth * 1.38
            let arrowYOffset = -imageHeight * 0.15

            ZStack(alignment: .center) {
                // Left image
                Image(leftImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: imageWidth, height: imageHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [.white, .gray],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing),
                                lineWidth: 2
                            )
                    )
                    .shadow(
                        color: Color.black.opacity(0.25), radius: 12, x: -4,
                        y: 4
                    )
                    .rotationEffect(.degrees(-6))
                    .offset(x: -imageWidth * 0.50)

                // Right image
                Image(rightImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: imageWidth, height: imageHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [.white, .gray],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing),
                                lineWidth: 2
                            )
                    )
                    .shadow(
                        color: Color.black.opacity(0.25), radius: 12, x: 4, y: 4
                    )
                    .rotationEffect(.degrees(8))
                    .offset(x: imageWidth * 0.50)

                // Arrow with gentle wiggle
                Image("arrow")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 62, height: 62)
                    .rotationEffect(.degrees(arrowWiggle ? 6 : -6))
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever(
                            autoreverses: true), value: arrowWiggle
                    )
                    .offset(x: 0, y: arrowYOffset)
            }
            .onAppear {
                arrowWiggle = true
            }
            .frame(width: geometry.size.width, height: imageHeight + 20)
        }
        .frame(height: 260)
        .padding(.horizontal, 20)
    }
}

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
                Spacer()
                Text("Add Photo")
                    .font(.custom("Nunito-ExtraBold", size: 20))
                    .foregroundColor(.black)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.custom("Nunito-ExtraBold", size: 22))
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                    .rotationEffect(.degrees(rotation))
            }
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            .overlay(
                LinearGradient(
                    colors: [
                        .white.opacity(0.0), .white.opacity(0.25),
                        .white.opacity(0.0),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(20))
                .offset(x: shine ? 250 : -250)
                .mask(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(lineWidth: 2)
                )
            )
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            .scaleEffect(isAnimating ? 1.04 : 1.0)
            .animation(
                .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                value: isAnimating)
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
            withAnimation(
                .linear(duration: 3.5).repeatForever(autoreverses: false)
            ) {
                shine.toggle()
            }
        }
    }
}

// MARK: - ImagePicker for Camera
struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(
        _ uiViewController: UIImagePickerController, context: Context
    ) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate,
        UINavigationControllerDelegate
    {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController
                .InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Example Images Section
struct ExampleImagesSection: View {
    let images: [String]
    @State private var selectedImageIndex: Int = 0
    @State private var showFullScreen = false
    @State private var appeared = false  // <- new

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundColor(.blue)
                Text("Example Gallery")
                    .font(.custom("Nunito-Bold", size: 22))
                Spacer()
            }

            Text("See what's possible with this style")
                .font(.caption)
                .foregroundColor(.secondary)

            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 6), count: 2),
                spacing: 6
            ) {
                ForEach(Array(images.enumerated()), id: \.element) {
                    index, imageName in
                    GeometryReader { geo in
                        Image(imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(
                                width: geo.size.width, height: geo.size.width
                            )
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(
                                color: Color.black.opacity(0.1), radius: 4,
                                x: 0, y: 2
                            )
                            .onTapGesture {
                                selectedImageIndex = index
                                showFullScreen = true
                            }
                    }
                    .aspectRatio(1.0, contentMode: .fit)
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 30)
        .animation(.easeOut(duration: 0.8), value: appeared)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                appeared = true
            }
        }
        .sheet(isPresented: $showFullScreen) {
            FullScreenImageViewer(
                images: images,
                selectedIndex: selectedImageIndex,
                isPresented: $showFullScreen
            )
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Full Screen Image Viewer
struct FullScreenImageViewer: View {
    let images: [String]
    let selectedIndex: Int
    @Binding var isPresented: Bool
    @State private var currentIndex: Int
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    init(images: [String], selectedIndex: Int, isPresented: Binding<Bool>) {
        self.images = images
        self.selectedIndex = selectedIndex
        self._isPresented = isPresented
        self._currentIndex = State(initialValue: selectedIndex)
    }

    var body: some View {
        ZStack {
            // Black background
            Color.black.edgesIgnoringSafeArea(.all)

            // TabView for swipeable images
            TabView(selection: $currentIndex) {
                ForEach(Array(images.enumerated()), id: \.offset) {
                    index, imageName in
                    GeometryReader { geometry in
                        Image(imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(
                                width: geometry.size.width,
                                height: geometry.size.height
                            )
                            .scaleEffect(scale)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        scale = lastScale * value
                                    }
                                    .onEnded { value in
                                        lastScale = scale
                                        // Reset if zoomed out too much
                                        if scale < 1.0 {
                                            withAnimation(.spring()) {
                                                scale = 1.0
                                                lastScale = 1.0
                                            }
                                        }
                                    }
                            )
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .onChange(of: currentIndex) { _ in
                // Reset zoom when changing images
                withAnimation {
                    scale = 1.0
                    lastScale = 1.0
                }
            }

            // Custom page indicator dots
            VStack {
                Spacer()

                HStack(spacing: 8) {
                    ForEach(0..<images.count, id: \.self) { index in
                        Circle()
                            .fill(
                                currentIndex == index
                                    ? Color.white : Color.white.opacity(0.5)
                            )
                            .frame(width: 8, height: 8)
                            .scaleEffect(currentIndex == index ? 1.2 : 1.0)
                            .animation(
                                .easeInOut(duration: 0.2), value: currentIndex)
                    }
                }
                .padding(.bottom, 40)
            }

            // Close button - positioned at top right
            VStack {
                HStack {
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.secondary.opacity(1))
                                .frame(width: 32, height: 32)

                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)
                        }
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }
}

// MARK: - More Styles Image Section
struct MoreStylesImageSection: View {
    let items: [InfoPacket]  // InfoPacket-driven version for images

    // 2x2 grid
    private let gridColumns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // MARK: Grid
            LazyVGrid(columns: gridColumns, spacing: 6) {
                ForEach(items) { item in
                    NavigationLink(
                        destination: PhotoFilterDetailView(item: item)
                    ) {
                        GeometryReader { geo in
                            Image(item.display.imageName)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geo.size.width, height: 260)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(
                                    color: .black.opacity(0.1), radius: 4, x: 0,
                                    y: 2)
                        }
                        .frame(height: 260)
                    }
                }
            }
        }
    }
}
