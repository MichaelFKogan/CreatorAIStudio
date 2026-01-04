//
//  VideoPlayerWithMuteButton.swift
//  Creator AI Studio
//
//  Created by Auto on 12/25/25.
//

import SwiftUI
import AVKit
import UIKit

// MARK: CUSTOM VIDEO PLAYER VIEW

struct CustomVideoPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer
    @Binding var isMuted: Bool
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false // Hide default controls
        controller.videoGravity = .resizeAspectFill
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // Update mute status when binding changes
        player.isMuted = isMuted
    }
}

// MARK: CUSTOM VIDEO PLAYER WITH MUTE BUTTON

struct VideoPlayerWithMuteButton: View {
    let player: AVPlayer?
    @Binding var isMuted: Bool
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        ZStack {
            if let player = player {
                CustomVideoPlayerView(player: player, isMuted: $isMuted)
                    .frame(width: width, height: height)
                
                // Mute/Unmute button overlay - positioned in top right
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            isMuted.toggle()
                        }) {
                            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.5))
                                )
                        }
                        .padding(12)
                    }
                    Spacer()
                }
            }
        }
    }
}

