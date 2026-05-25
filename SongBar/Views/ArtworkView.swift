import SwiftUI
import AppKit

struct ArtworkView: View {
    let image: NSImage?
    var size: CGFloat = 160

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.secondary.opacity(0.12)
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.32, weight: .light))
                        .foregroundStyle(.secondary.opacity(0.6))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: PanelMetrics.artworkRadius, style: .continuous))
        .shadow(color: .black.opacity(0.42), radius: 16, x: 0, y: 9)
        .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 1)
        .accessibilityLabel("Album artwork")
    }
}
