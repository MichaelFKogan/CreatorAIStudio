//
//  FullScreenVideoSheet.swift
//  Creator AI Studio
//
//  Presents a video full-screen in a sheet (tap banner video to expand).
//

import AVKit
import SwiftUI

/// Full-screen video sheet with close button. Use when user taps the banner video on filter detail pages.
struct FullScreenVideoSheet: View {
    @Binding var isPresented: Bool
    let videoURL: URL

    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let player = player {
                FullScreenVideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onAppear {
                        player.play()
                    }
            }
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.8))
                            .background(Circle().fill(Color.black.opacity(0.3)))
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .onAppear {
            let newPlayer = AVPlayer(url: videoURL)
            player = newPlayer
            newPlayer.play()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}
