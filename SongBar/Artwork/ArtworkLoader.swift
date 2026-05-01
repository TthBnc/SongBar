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

    /// Render an N-bar audio equalizer to a template NSImage. Heights derive
    /// from sin() with a phase offset per bar, sampled at the given frame
    /// index so consecutive frames produce smooth motion. `isTemplate = true`
    /// lets macOS tint the bars to whatever foreground the menu bar wants
    /// instead of relying on SwiftUI Color.primary, which doesn't render
    /// reliably inside MenuBarExtra's label.
    static func equalizerBars(
        frame: Int,
        barCount: Int = 4,
        barWidth: CGFloat = 2,
        spacing: CGFloat = 1,
        minHeight: CGFloat = 3,
        maxHeight: CGFloat = 12
    ) -> NSImage? {
        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * spacing
        let canvasSize = NSSize(width: totalWidth, height: maxHeight)
        let scale: CGFloat = 2
        let pixelWidth = Int(canvasSize.width * scale)
        let pixelHeight = Int(canvasSize.height * scale)
        guard pixelWidth > 0, pixelHeight > 0 else { return nil }
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
        rep.size = canvasSize

        guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = ctx

        NSColor.black.setFill()  // template — color doesn't matter, alpha shape does

        for i in 0..<barCount {
            let t = Double(frame) * 0.55
            let phase = Double(i) * 0.95
            let normalized = (sin(t + phase) + 1) * 0.5
            let h = minHeight + CGFloat(normalized) * (maxHeight - minHeight)
            let x = CGFloat(i) * (barWidth + spacing)
            let y = (canvasSize.height - h) / 2
            let rect = NSRect(x: x, y: y, width: barWidth, height: h)
            let radius = barWidth / 2
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
        }

        let result = NSImage(size: canvasSize)
        result.addRepresentation(rep)
        result.isTemplate = true
        return result
    }
}
