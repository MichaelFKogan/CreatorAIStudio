//
//  SplashScreenView.swift
//  Creator AI Studio
//
//  Created by Mike K on 11/22/25.
//

import SwiftUI
import AVKit
import AVFoundation

struct SplashScreenView: View {
    @State private var player: AVPlayer?
    @State private var hasFinished = false
    let onFinish: () -> Void
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            if let player = player {
                VideoPlayerView(player: player)
                    .ignoresSafeArea()
                    .onAppear {
                        player.play()
                    }
            } else {
                // Show loading state while video is being set up
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
            }
        }
        .onAppear {
            setupVideo()
        }
        .onChange(of: hasFinished) { _, finished in
            if finished {
                // Small delay before transitioning
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onFinish()
                }
            }
        }
    }
    
    private func setupVideo() {
        // Try to load video from bundle
        // Replace "splash_video" with your actual video file name (without extension)
        guard let videoURL = Bundle.main.url(forResource: "splash_video", withExtension: "mp4") ??
                            Bundle.main.url(forResource: "splash_video", withExtension: "mov") else {
            print("⚠️ Splash video not found in bundle. Please add your video file to the project.")
            // If video not found, skip after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                hasFinished = true
            }
            return
        }
        
        let newPlayer = AVPlayer(url: videoURL)
        player = newPlayer
        
        // Listen for when video finishes
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: newPlayer.currentItem,
            queue: .main
        ) { _ in
            hasFinished = true
        }
        
        // Fallback: if video doesn't finish in 8.5 seconds, proceed anyway
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.5) {
            if !hasFinished {
                hasFinished = true
            }
        }
    }
}

// MARK: - Video Player View Without Controls

struct VideoPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspect
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // No updates needed
    }
}

