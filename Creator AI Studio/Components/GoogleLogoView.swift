//
//  GoogleLogoView.swift
//  Creator AI Studio
//
//  Created for Google Sign-In button logo
//

import SwiftUI

struct GoogleLogoView: View {
    var size: CGFloat = 18
    
    var body: some View {
        // Try to load Google logo from assets first
        if let image = UIImage(named: "google-logo") {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            // Fallback: Simple programmatic Google "G" logo
            // Using Google's brand colors: Blue, Red, Yellow, Green
            ZStack {
                // Background circle (white)
                Circle()
                    .fill(Color.white)
                    .frame(width: size, height: size)
                
                // Google "G" shape - simplified version
                GeometryReader { geometry in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let centerX = width / 2
                    let centerY = height / 2
                    let radius = min(width, height) / 2 * 0.75
                    let strokeWidth = radius * 0.25
                    
                    ZStack {
                        // Blue arc (top-right to right)
                        Path { path in
                            path.addArc(
                                center: CGPoint(x: centerX, y: centerY),
                                radius: radius,
                                startAngle: .degrees(-20),
                                endAngle: .degrees(70),
                                clockwise: false
                            )
                        }
                        .stroke(Color(red: 0.26, green: 0.52, blue: 0.96), lineWidth: strokeWidth)
                        
                        // Red arc (top-left)
                        Path { path in
                            path.addArc(
                                center: CGPoint(x: centerX, y: centerY),
                                radius: radius,
                                startAngle: .degrees(140),
                                endAngle: .degrees(220),
                                clockwise: false
                            )
                        }
                        .stroke(Color(red: 0.99, green: 0.40, blue: 0.36), lineWidth: strokeWidth)
                        
                        // Yellow arc (bottom-left)
                        Path { path in
                            path.addArc(
                                center: CGPoint(x: centerX, y: centerY),
                                radius: radius,
                                startAngle: .degrees(220),
                                endAngle: .degrees(290),
                                clockwise: false
                            )
                        }
                        .stroke(Color(red: 0.99, green: 0.75, blue: 0.18), lineWidth: strokeWidth)
                        
                        // Green arc (bottom-right)
                        Path { path in
                            path.addArc(
                                center: CGPoint(x: centerX, y: centerY),
                                radius: radius,
                                startAngle: .degrees(290),
                                endAngle: .degrees(340),
                                clockwise: false
                            )
                        }
                        .stroke(Color(red: 0.13, green: 0.59, blue: 0.30), lineWidth: strokeWidth)
                        
                        // Horizontal bar (for the "G" - extends from center to right)
                        Path { path in
                            path.move(to: CGPoint(x: centerX, y: centerY))
                            path.addLine(to: CGPoint(x: centerX + radius * 0.5, y: centerY))
                        }
                        .stroke(Color(red: 0.26, green: 0.52, blue: 0.96), lineWidth: strokeWidth * 0.9)
                    }
                }
                .frame(width: size, height: size)
            }
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        GoogleLogoView(size: 18)
        GoogleLogoView(size: 24)
        GoogleLogoView(size: 32)
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}
