import Foundation
import AppKit
import os

actor ArtworkLoader {
    private let cache = NSCache<NSURL, NSImage>()
    private var inFlight: [URL: Task<NSImage?, Never>] = [:]
    private var currentTask: Task<NSImage?, Never>?
    private let logger = Logger(subsystem: "dev.tothbnc.SongBar", category: "artwork")

    func loadArtwork(from url: URL) async -> NSImage? {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }

        if let existing = inFlight[url] {
            return await existing.value
        }

        let task = Task<NSImage?, Never> { [logger] in
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                try Task.checkCancellation()
                guard let image = NSImage(data: data) else {
                    logger.debug("Artwork decode failed for \(url.absoluteString, privacy: .public)")
                    return nil
                }
                return image
            } catch {
                logger.debug("Artwork load failed for \(url.absoluteString, privacy: .public): \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }

        inFlight[url] = task
        currentTask = task

        let image = await task.value

        inFlight[url] = nil
        if currentTask == task {
            currentTask = nil
        }

        if let image, !Task.isCancelled {
            cache.setObject(image, forKey: url as NSURL)
        }

        return image
    }

    func cancelCurrentLoad() {
        currentTask?.cancel()
        currentTask = nil
    }

    func clearCache() {
        cache.removeAllObjects()
    }
}

extension NSImage {
    /// Render this image into a fixed-size square NSImage with rounded corners,
    /// using aspect-fill. Used for the menu bar item, where SwiftUI's .frame()
    /// + .clipShape() aren't honored by MenuBarExtra's label rendering — the
    /// bitmap has to arrive pre-shaped.
    func roundedThumbnail(size pointSize: CGFloat, cornerRadius: CGFloat) -> NSImage {
        let target = NSSize(width: pointSize, height: pointSize)
        return NSImage(size: target, flipped: false) { rect in
            guard self.size.width > 0, self.size.height > 0 else { return false }
            let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
            path.addClip()
            let scale = max(rect.width / self.size.width, rect.height / self.size.height)
            let drawSize = NSSize(width: self.size.width * scale, height: self.size.height * scale)
            let drawOrigin = NSPoint(
                x: (rect.width - drawSize.width) / 2,
                y: (rect.height - drawSize.height) / 2
            )
            self.draw(
                in: NSRect(origin: drawOrigin, size: drawSize),
                from: .zero,
                operation: .copy,
                fraction: 1.0
            )
            return true
        }
    }
}
