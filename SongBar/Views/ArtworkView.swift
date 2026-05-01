import SwiftUI
import AppKit

struct ArtworkView: View {
    let image: NSImage?

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
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(.secondary.opacity(0.6))
                }
            }
        }
        .frame(width: 132, height: 132)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.28), radius: 12, x: 0, y: 6)
        .shadow(color: .black.opacity(0.10), radius: 2, x: 0, y: 1)
        .accessibilityLabel("Album artwork")
    }
}
