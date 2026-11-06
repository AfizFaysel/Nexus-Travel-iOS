import SwiftUI

/// Shows the airline's supplied logo, bundled logo, or initial in a fixed slot.
struct AirlineLogoBadge: View {
    let code: String?
    let name: String?
    let url: URL?
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    if case let .success(image) = phase {
                        image.resizable().scaledToFit()
                    } else {
                        fallback
                    }
                }
                .frame(width: width - NexusLayout.airlineLogoInset, height: artworkHeight, alignment: .leading)
            } else {
                fallback
            }
        }
        .frame(width: width, height: height, alignment: .leading)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var fallback: some View {
        let asset = "airline-\(code?.lowercased() ?? "")"
        if let image = UIImage(named: asset) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(
                    width: code == "G9" ? artworkHeight : width - NexusLayout.airlineLogoInset,
                    height: artworkHeight,
                    alignment: .leading
                )
        } else {
            Text(name?.prefix(1).uppercased() ?? "A")
                .nexusTextStyle(NexusText.styles.airlineLogoInitial)
                .foregroundStyle(NexusColors.white)
                .dynamicTypeSize(...DynamicTypeSize.large)
                .frame(width: tileSize, height: tileSize)
                .background {
                    RoundedRectangle(cornerRadius: NexusRadius.airlineLogoTile)
                        .fill(LinearGradient(
                            colors: [NexusColors.brand900, NexusColors.brand600],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                }
        }
    }

    private var artworkHeight: CGFloat { height - NexusLayout.airlineLogoInset }
    private var tileSize: CGFloat { min(height, NexusLayout.airlineLogoTileMaximum) }
}
