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
    /// Render this image into a fixed-size square NSImage with rounded corners.
    /// Eagerly rasterizes into an NSBitmapImageRep so subsequent draws are
    /// just a bitmap blit — critical for the menu bar label, where the
    /// previous deferred-drawing approach re-rasterized the source on every
    /// menu bar snapshot and pegged the CPU.
    func roundedThumbnail(size pointSize: CGFloat, cornerRadius: CGFloat) -> NSImage? {
        guard self.size.width > 0, self.size.height > 0 else { return nil }
        let scale: CGFloat = 2
        let pixelWidth = Int(pointSize * scale)
        let pixelHeight = Int(pointSize * scale)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        rep.size = NSSize(width: pointSize, height: pointSize)

        guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = ctx

        let rect = NSRect(origin: .zero, size: NSSize(width: pointSize, height: pointSize))
        NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius).addClip()

        let s = max(rect.width / self.size.width, rect.height / self.size.height)
        let drawSize = NSSize(width: self.size.width * s, height: self.size.height * s)
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

        let result = NSImage(size: NSSize(width: pointSize, height: pointSize))
        result.addRepresentation(rep)
        return result
    }
}
