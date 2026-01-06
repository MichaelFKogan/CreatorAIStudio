import PhotosUI
import SwiftUI

struct PhotoFiltersBottomBar: View {
    @Binding var showPhotoPicker: Bool
    @Binding var selectedPhotoItem: PhotosPickerItem?
    let cost: Decimal
    @State private var hasCredits: Bool = true // TODO: Connect to actual credits check
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    
    @EnvironmentObject var authViewModel: AuthViewModel

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

                CostBadge(cost: cost)
                    .padding(.horizontal, 16)

                SpinningPlusButton(
                    showActionSheet: $showPhotoPicker,
                    isLoggedIn: authViewModel.user != nil,
                    hasCredits: hasCredits,
                    isConnected: networkMonitor.isConnected
                )
                    .photosPicker(
                        isPresented: $showPhotoPicker,
                        selection: $selectedPhotoItem,
                        matching: .images
                    )
                    .padding(.horizontal, 16)
            }
            .padding(.bottom, 80)
            .background(Color(.systemGroupedBackground))
        }
    }
}
