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
    let cornerRadius: CGFloat
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false // Hide default controls
        controller.videoGravity = .resizeAspectFill
        
        // Apply rounded corners to the view controller's view
        DispatchQueue.main.async {
            controller.view.layer.cornerRadius = cornerRadius
            controller.view.layer.masksToBounds = true
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // Update mute status when binding changes
        player.isMuted = isMuted
        
        // Ensure corner radius is maintained
        uiViewController.view.layer.cornerRadius = cornerRadius
        uiViewController.view.layer.masksToBounds = true
    }
}

// MARK: CUSTOM VIDEO PLAYER WITH MUTE BUTTON

struct VideoPlayerWithMuteButton: View {
    let player: AVPlayer?
    @Binding var isMuted: Bool
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    
    init(player: AVPlayer?, isMuted: Binding<Bool>, width: CGFloat, height: CGFloat, cornerRadius: CGFloat = 12) {
        self.player = player
        self._isMuted = isMuted
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        ZStack {
            if let player = player {
                CustomVideoPlayerView(player: player, isMuted: $isMuted, cornerRadius: cornerRadius)
                    .frame(width: width, height: height)
                
                // Mute/Unmute button overlay - positioned in top right
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            isMuted.toggle()
                        }) {
                            if isMuted {
                                HStack(spacing: 6) {
                                    Text("Unmute")
                                        .font(.system(size: 14, weight: .semibold))
                                    Image(systemName: "speaker.slash.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.5))
                                )
                            } else {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(
                                        Circle()
                                            .fill(Color.black.opacity(0.5))
                                    )
                            }
                        }
                        .padding(12)
                    }
                    Spacer()
                }
                .frame(width: width, height: height)
            }
        }
        .frame(width: width, height: height)
    }
}

