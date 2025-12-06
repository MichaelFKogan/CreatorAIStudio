//
//  TextRecognitionService.swift
//  Creator AI Studio
//
//  Created for OCR text recognition from images
//

import UIKit
import Vision

@MainActor
class TextRecognitionService {
    /// Recognizes text from an image using Vision framework
    /// - Parameter image: The UIImage to extract text from
    /// - Returns: The recognized text as a String, or nil if no text found or error occurred
    static func recognizeText(from image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else {
            print("Failed to get CGImage from UIImage")
            return nil
        }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    print("Text recognition error: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: nil)
                    return
                }

                // Extract text with line breaks preserved
                let formattedText = formatTextWithLineBreaks(from: observations)

                // Try to format as JSON if it looks like JSON
                let finalText = formatJSONIfNeeded(formattedText)

                if finalText.isEmpty {
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: finalText)
                }
            }

            // Configure for accurate recognition
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            // Perform the request
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    print("Failed to perform text recognition: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Formats text observations preserving line breaks based on bounding box positions
    private static func formatTextWithLineBreaks(from observations: [VNRecognizedTextObservation]) -> String {
        guard !observations.isEmpty else { return "" }

        // Sort observations by vertical position (top to bottom)
        let sortedObservations = observations.sorted { obs1, obs2 in
            let y1 = obs1.boundingBox.midY
            let y2 = obs2.boundingBox.midY
            // If on roughly the same line (within threshold), sort by x position
            if abs(y1 - y2) < 0.02 {
                return obs1.boundingBox.minX < obs2.boundingBox.minX
            }
            return y1 > y2 // Higher Y value = lower on screen
        }

        var result: [String] = []
        var currentLine: [String] = []
        var lastY: CGFloat = -1
        let lineThreshold: CGFloat = 0.02 // Threshold for considering text on the same line

        for observation in sortedObservations {
            guard let text = observation.topCandidates(1).first?.string else { continue }

            let currentY = observation.boundingBox.midY

            // Check if this observation is on a new line
            if lastY >= 0 && abs(currentY - lastY) > lineThreshold {
                // New line detected - add current line to result
                if !currentLine.isEmpty {
                    result.append(currentLine.joined(separator: " "))
                    currentLine = []
                }
            }

            currentLine.append(text)
            lastY = currentY
        }

        // Add the last line
        if !currentLine.isEmpty {
            result.append(currentLine.joined(separator: " "))
        }

        return result.joined(separator: "\n")
    }

    /// Attempts to format text as JSON if it appears to be JSON
    private static func formatJSONIfNeeded(_ text: String) -> String {
        // Check if text looks like JSON (starts with { or [ and contains JSON-like structure)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard (trimmed.hasPrefix("{") || trimmed.hasPrefix("[")) &&
            (trimmed.contains("\"") || trimmed.contains("'"))
        else {
            return text // Doesn't look like JSON, return as-is
        }

        // Try to parse and format as JSON
        if let data = text.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
           let formattedData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys]),
           let formattedString = String(data: formattedData, encoding: .utf8)
        {
            return formattedString
        }

        // If JSON parsing fails, try to add basic formatting (add line breaks after commas and braces)
        return addBasicJSONFormatting(text)
    }

    /// Adds basic JSON formatting when proper parsing fails
    private static func addBasicJSONFormatting(_ text: String) -> String {
        var formatted = text

        // Add line breaks after opening braces/brackets
        formatted = formatted.replacingOccurrences(of: "{", with: "{\n")
        formatted = formatted.replacingOccurrences(of: "[", with: "[\n")

        // Add line breaks after closing braces/brackets (but not if already there)
        formatted = formatted.replacingOccurrences(of: "}", with: "\n}")
        formatted = formatted.replacingOccurrences(of: "]", with: "\n]")

        // Add line breaks after commas
        formatted = formatted.replacingOccurrences(of: ",", with: ",\n")

        // Clean up multiple consecutive newlines
        formatted = formatted.replacingOccurrences(of: "\n\n+", with: "\n", options: .regularExpression)

        return formatted
    }
}
