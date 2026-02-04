//
//  DesignConstants.swift
//  Creator AI Studio
//

import SwiftUI

/// Shared layout constants for consistent media input UI (reference image, frame, motion control slots).
enum DesignConstants {
    /// Height used for motion control slot cards (Character Image, Reference Video).
    static let mediaSlotSize: CGFloat = 100
    /// Minimum height for frame image cards (Start/End Frame); width is 50% of row.
    static let frameMinHeight: CGFloat = 120
    /// Size for the reference image "Add Image" square (Video and Image detail pages).
    static let referenceImageSlotSize: CGFloat = 130
}
