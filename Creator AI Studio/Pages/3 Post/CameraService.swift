import AVFoundation
import SwiftUI
import UIKit

@MainActor
final class CameraService: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var currentInput: AVCaptureDeviceInput?

    // Serial queue for all session/config/capture work (prevents UI blocking)
    private let sessionQueue = DispatchQueue(
        label: "com.example.camera.session")

    @Published var capturedImage: UIImage?
    @Published private(set) var cameraPosition: AVCaptureDevice.Position = .back

    // MARK: - Session lifecycle

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            // If session is already running, don't reconfigure
            if self.session.isRunning {
                return
            }

            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            // Only configure input if we don't have one
            if self.currentInput == nil {
                self.configureInputSynchronously(position: .back)
            }

            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
                self.photoOutput.isHighResolutionCaptureEnabled = true
            }

            self.session.commitConfiguration()

            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    // MARK: - Configure Input

    private func configureInputSynchronously(position: AVCaptureDevice.Position)
    {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: position
        )
        guard let device = discovery.devices.first,
            let newInput = try? AVCaptureDeviceInput(device: device)
        else { return }

        if session.canAddInput(newInput) {
            session.addInput(newInput)
            if let old = currentInput,
                old.device.uniqueID != newInput.device.uniqueID
            {
                session.removeInput(old)
            }
            currentInput = newInput

            Task { @MainActor in
                self.cameraPosition = position
            }

            applyMirroringAndOrientation(for: position)
        } else if let old = currentInput {
            session.removeInput(old)
            if session.canAddInput(newInput) {
                session.addInput(newInput)
                currentInput = newInput
                Task { @MainActor in
                    self.cameraPosition = position
                }
                applyMirroringAndOrientation(for: position)
            } else if session.canAddInput(old) {
                session.addInput(old)
                currentInput = old
            }
        }
    }

    // MARK: - Switch camera

    func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.session.beginConfiguration()
            let newPos: AVCaptureDevice.Position =
                (self.currentInput?.device.position == .back) ? .front : .back
            self.configureInputSynchronously(position: newPos)
            self.session.commitConfiguration()
        }
    }

    // MARK: - Capture

    // MARK: - Complete Fixed CameraService Methods

    // Replace your capturePhoto() method with this:
    func capturePhoto() {
        let settings = AVCapturePhotoSettings()

        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            // Ensure photo output connection is configured correctly
            if let connection = self.photoOutput.connection(with: .video) {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                if connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    // CRITICAL: Never mirror photos - capture reality as-is
                    connection.isVideoMirrored = false
                }
            }

            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    // MARK: - Helpers

    private func applyMirroringAndOrientation(
        for position: AVCaptureDevice.Position
    ) {
        // Configure preview connections (these affect the live preview)
        for connection in session.connections {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                // Mirror ONLY the front camera preview for natural selfie view
                connection.isVideoMirrored = (position == .front)
            }
        }

        // Configure photo output connection (this affects captured photos)
        if let photoConn = photoOutput.connection(with: .video) {
            if photoConn.isVideoOrientationSupported {
                photoConn.videoOrientation = .portrait
            }
            if photoConn.isVideoMirroringSupported {
                photoConn.automaticallyAdjustsVideoMirroring = false
                // NEVER mirror the actual captured photo - we want reality, not mirror image
                photoConn.isVideoMirrored = false
            }
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraService: AVCapturePhotoCaptureDelegate {

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil,
            let data = photo.fileDataRepresentation(),
            let image = UIImage(data: data)
        else { return }


        // DEBUG: Print orientation and camera info
        print("Captured orientation:", image.imageOrientation.rawValue)
        print("Camera position:", currentInput?.device.position == .front ? "front" : "back")


        Task { @MainActor in
            self.capturedImage = image.normalizedImage()
        }
    }

}

// MARK: - UIImage extension for normalization
extension UIImage {
    func normalizedImage() -> UIImage {
        if imageOrientation == .up { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalized ?? self
    }
}
