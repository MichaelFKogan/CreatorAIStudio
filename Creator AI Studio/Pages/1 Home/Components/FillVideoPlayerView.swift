import SwiftUI
import AVKit

/// A UIViewRepresentable that uses AVPlayerLayer with `.resizeAspectFill`
/// so the video fills the entire frame (cropping edges if needed),
/// unlike SwiftUI's `VideoPlayer` which letterboxes/pillarboxes.
struct FillVideoPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> UIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let view = uiView as? PlayerUIView {
            view.playerLayer.player = player
        }
    }

    private class PlayerUIView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
