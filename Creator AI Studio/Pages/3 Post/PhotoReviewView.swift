import Supabase
import SwiftUI
import UIKit

struct PhotoReviewView: View {
    let capturedImage: UIImage
    @StateObject private var viewModel = PhotoFiltersViewModel()
    @State private var selectedFilter: InfoPacket? = nil

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showSignInSheet: Bool = false

    @State private var selectedStyle: String = "Anime"
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var isEditingTitle: Bool = false
    @State private var isEditingDescription: Bool = false
    @State private var isProcessing: Bool = false

    // Example styles
    let environmentStyles = [
        ("Anime", "$0.03", "💫", "Anime", "post_bg"),
        ("Ghibli", "$0.03", "💫", "Ghibli", "ghibli_style"),
        ("GTA", "$0.03", "", "GTA", "gta_style"),

        ("Comic", "$0.03", "", "Comic Book", "comicbook_style"),
        ("Manga", "$0.03", "", "Manga", "manga_style"),

        ("Van Gogh", "$0.03", "", "Van Gogh", "vangogh_style"),
        ("Watercolor", "$0.03", "", "Watercolor", "watercolor_style"),
    ]

    var body: some View {
        VStack {
            ScrollView {
                VStack {
                    // Top Section: Photo + Text Inputs
                    HStack(alignment: .top) {
                        Image(uiImage: capturedImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 150, height: 190)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                        //                    .shadow(radius: 2)

                        Spacer()
                    }
                    .padding(.horizontal)
                }

                // Choose Art Style Row
                VStack(alignment: .leading, spacing: 8) {
                    Text("Choose an Art Style")
                        .font(.headline)
                        .padding(.horizontal)

                    PhotoFiltersGrid(
                        filters: viewModel.filters,
                        selectedFilter: selectedFilter,
                        onSelect: { selectedFilter = $0 }
                    )
                }

                // ScrollView(.horizontal, showsIndicators: false) {
                //     HStack(spacing: 12) {
                //         ForEach(environmentStyles, id: \.0) { style in
                //             StyleSelectionButton(
                //                 title: style.0,
                //                 icon: style.2,
                //                 description: style.3,
                //                 backgroundImage: style.4,
                //                 isSelected: selectedStyle == style.0
                //             ) {
                //                 selectedStyle = style.0
                //             }
                //         }
                //     }
                //     .padding(.horizontal)
                // }
                // .frame(height: 110)
            }
            .padding(.bottom, 20)

            // Bottom: Cost + Buttons
            VStack(spacing: 12) {
                HStack {
                    HStack(spacing: 4) {
                        Text("Cost:")
                            .foregroundColor(.secondary)
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.accentColor)
                        Text("1 credit")
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Text("Remaining:")
                            .foregroundColor(.secondary)
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.accentColor)
                        Text("50")
                            .foregroundColor(.secondary)
                    }
                }
                .font(.subheadline)
                .padding(.horizontal)

                //                // Accept Button
                //                Button(action: handleAcceptPhoto) {
                //                    HStack {
                //                        if isProcessing {
                //                            ProgressView()
                //                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                //                                .scaleEffect(0.8)
                //                        } else {
                //                            Image(systemName: "checkmark")
                //                                .font(.system(size: 18, weight: .bold))
                //                        }
                //                        Text(isProcessing ? "Processing..." : "Transform Photo")
                //                            .font(.headline)
                //                            .fontWeight(.semibold)
                //                    }
                //                    .foregroundColor(.white)
                //                    .frame(maxWidth: .infinity)
                //                    .padding()
                //                    .background(Color.accentColor)
                //                    .cornerRadius(12)
                //                    .padding(.horizontal)
                //                }

                // Cancel Button
                Button(action: {
                    dismiss()
                }) {
                    Text("Cancel")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
                .disabled(isProcessing)
            }
            // Bottom spacing
            Color.clear.frame(height: 60)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: setDefaultFilter)
        .sheet(isPresented: $showSignInSheet) {
            SignInView()
                .environmentObject(authViewModel)
        }
    }

    // MARK: - Actions

    //    private func handleAcceptPhoto() {
    ////        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    //
    //        isProcessing = true
    //
    //        // Generate a unique ID for this photo upload
    //        let photoId = UUID().uuidString
    //
    //        // Add loading placeholder to gallery
    //        galleryViewModel.addLoadingPhoto(photoId)
    //
    //        // Show global transforming notification with style info
    //        notificationManager.showTransformingNotification(for: photoId)
    //
    //        // Make pixels upright and portrait before sending
    //        let normalized = capturedImage.normalizedOrientation()
    //        let portrait = normalized.centerCropped(toAspect: 3.0 / 4.0)
    //        let finalImage = portrait.resized(maxLongSide: 1536)
    //
    //        let runwareAPI = RunwareAPI()
    //
    //        // Use style-based configuration
    //        runwareAPI.sendImageToRunware(image: finalImage, style: selectedStyle) { result in
    //            DispatchQueue.main.async {
    //                switch result {
    //                case let .success(runwareURLString):
    //                    guard let runwareURL = URL(string: runwareURLString) else {
    //                        Task { @MainActor in
    //                            galleryViewModel.removeLoadingPhoto(photoId)
    //                            notificationManager.showErrorNotification("Invalid response from API", for: photoId)
    //                            isProcessing = false
    //                        }
    //                        return
    //                    }
    //
    //                    // Save into Supabase
    //                    Task {
    //                        do {
    //                            let service = PhotoService(client: supabase)
    //                            _ = try await service.saveRunwareImage(
    //                                runwareURL: runwareURL,
    //                                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
    //                                description: description.trimmingCharacters(in: .whitespacesAndNewlines)
    ////                                postType: selectedPostType
    //                            )
    //
    //                            await galleryViewModel.refreshFromSupabase()
    //
    //                            await MainActor.run {
    //                                galleryViewModel.removeLoadingPhoto(photoId)
    //                                notificationManager.showSuccessNotification(for: photoId)
    //                                isProcessing = false
    //                                dismiss()
    //                            }
    //                        } catch {
    //                            await MainActor.run {
    //                                galleryViewModel.removeLoadingPhoto(photoId)
    //                                notificationManager.showErrorNotification(error.localizedDescription, for: photoId)
    //                                isProcessing = false
    //                            }
    //                        }
    //                    }
    //
    //                case let .failure(error):
    //                    Task { @MainActor in
    //                        galleryViewModel.removeLoadingPhoto(photoId)
    //                        notificationManager.showErrorNotification(error.localizedDescription, for: photoId)
    //                        isProcessing = false
    //                    }
    //                }
    //            }
    //        }
    //    }
    private func setDefaultFilter() {
        if selectedFilter == nil { selectedFilter = viewModel.filters.first }
    }
}

// MARK: - StyleSelectionButton Component

struct StyleSelectionButton: View {
    let title: String
    let icon: String
    let description: String
    let backgroundImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        VStack {
            Button(action: action) {
                ZStack(alignment: .topTrailing) {
                    // Background image - no extra container
                    Image(backgroundImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 75, height: 75)
                        .clipped()

                    //                    // Gradient overlay for better readability
                    //                    LinearGradient(
                    //                        colors: [.black.opacity(0.55), .black.opacity(0.25), .clear],
                    //                        startPoint: .bottom,
                    //                        endPoint: .top
                    //                    )

                    // Clean content layout
                    VStack(alignment: .leading, spacing: 6) {
                        // Checkmark in top left
                        if isSelected {
                            HStack {
                                ZStack {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.accentColor)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            Spacer()
                        }
                    }
                    .padding(2)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            isSelected
                                ? Color.accentColor : Color.gray.opacity(0.3),
                            lineWidth: isSelected ? 3 : 1
                        )
                )
                .shadow(
                    color: isSelected
                        ? .accentColor.opacity(0.3) : .black.opacity(0.1),
                    radius: isSelected ? 8 : 4, x: 0, y: 2
                )
                .animation(.easeInOut(duration: 0.2), value: isSelected)
            }
            .padding(.vertical, 2)
            .buttonStyle(PlainButtonStyle())

            // Clean content layout
            VStack(alignment: .leading) {
                //                HStack {
                //                    Text(icon)
                //                        .font(.title2)
                //                        .shadow(color: .black.opacity(0.8), radius: 3)
                //
                //                    Spacer()
                //                }

                //                Text(title)
                //                    .font(.subheadline)
                //                    .fontWeight(.medium)
                //                    .foregroundColor(.white)
                //
                //                    .multilineTextAlignment(.leading)   // allow multiple lines
                //                    .lineLimit(2)                       // cap at 2 lines
                //                    .fixedSize(horizontal: false, vertical: true) // wrap inside bounds
                //
                //                    .padding(.horizontal, 8)
                //                    .padding(.vertical, 3)
                //
                //                    .background(
                //                        LinearGradient(
                //                            colors: isSelected
                //                                ? [.accentColor, .accentColor.opacity(0.7)]
                //                                : [.gray, .gray.opacity(0.7)],
                //                            startPoint: .leading,
                //                            endPoint: .trailing
                //                        )
                //                        .clipShape(Capsule())
                //                    )
                //                    .shadow(color: .gray.opacity(0.5), radius: 2)

                Text(description)
                    .font(.system(size: 14))
                    .fontWeight(.bold)
                    .foregroundColor(.primary.opacity(0.95))
                    //                    .shadow(radius: 2)
                    .lineLimit(2)
            }
            //            .padding(8)
        }
    }
}
