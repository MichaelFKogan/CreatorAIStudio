import SwiftUI

// MARK: GRID CARD

struct GridView: View {
    let item: InfoPacket
    let capabilities: [String]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Image with overlays
            ZStack(alignment: .bottom) {
                Image(item.display.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                // Gradient overlay for better text readability
                LinearGradient(
                    colors: [Color.black.opacity(0.6), Color.clear],
                    startPoint: .bottom,
                    endPoint: .center
                )
                .frame(height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )

            // Title and Cost section
            HStack(alignment: .top) {
                Text(item.display.title)
//                    .font(.custom("Nunito-Bold", size: 12))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                Spacer()
                Text("$\(item.cost, specifier: "%.2f")")
//                    .font(.custom("Nunito-Bold", size: 11))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(color)
            }
        }
    }
}
