//
//  PhotoLibraryPickerView.swift
//  Video Game App
//
//  Created by Mike K on 8/18/25.
//

import SwiftUI

// MARK: - PhotoLibraryPickerView

struct PhotoLibraryPickerView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    @Binding var selectedImage: UIImage?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        picker.modalPresentationStyle = .automatic
        return picker
    }

    func updateUIViewController(_: UIImagePickerController, context _: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: PhotoLibraryPickerView
        init(_ parent: PhotoLibraryPickerView) { self.parent = parent }

        func imagePickerController(_: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any])
        {
            if let original = info[.originalImage] as? UIImage {
                parent.selectedImage = original
            }
            parent.isPresented = false
        }

        func imagePickerControllerDidCancel(_: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}
