import PhotosUI
import SwiftUI

struct PhotoFiltersBottomBar: View {
    @Binding var showPhotoPicker: Bool
    @Binding var selectedPhotoItem: PhotosPickerItem?
    let cost: Double

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [
                    Color(.systemGroupedBackground).opacity(0),
                    Color(.systemGroupedBackground),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 20)

            VStack(spacing: 16) {
                SpinningPlusButton(showPhotoPicker: $showPhotoPicker)
                    .photosPicker(
                        isPresented: $showPhotoPicker,
                        selection: $selectedPhotoItem,
                        matching: .images
                    )
                    .padding(.horizontal, 16)

                CostBadge(cost: cost)
                    .padding(.horizontal, 16)
            }
            .padding(.bottom, 80)
            .background(Color(.systemGroupedBackground))
        }
    }
}
