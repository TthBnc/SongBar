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

    /// Render `[indicator]  [self]` into a single horizontal bitmap and
    /// return the combined NSImage.
    ///
    /// MenuBarExtra's label maps to NSStatusItem.button — one image cell, one
    /// title cell. The SwiftUI bridge keeps the first Image and first Text
    /// only, so we can't put separate views side by side. Compositing the
    /// indicator and the artwork into one bitmap is the only path that lands
    /// on screen.
    func withIndicatorOnLeft(
        indicatorSize: NSSize,
        gap: CGFloat = 5,
        draw indicator: (_ origin: NSPoint, _ size: NSSize) -> Void
    ) -> NSImage {
        guard self.size.width > 0, self.size.height > 0 else { return self }
        let height = max(self.size.height, indicatorSize.height)
        let canvasSize = NSSize(
            width: indicatorSize.width + gap + self.size.width,
            height: height
        )
        let scale: CGFloat = 2
        let pw = Int(canvasSize.width * scale)
        let ph = Int(canvasSize.height * scale)
        guard pw > 0, ph > 0,
              let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: pw,
                pixelsHigh: ph,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
              ) else { return self }
        rep.size = canvasSize

        guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return self }
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = ctx

        let indicatorY = (canvasSize.height - indicatorSize.height) / 2
        indicator(NSPoint(x: 0, y: indicatorY), indicatorSize)

        let artworkX = indicatorSize.width + gap
        let artworkY = (canvasSize.height - self.size.height) / 2
        self.draw(
            in: NSRect(origin: NSPoint(x: artworkX, y: artworkY), size: self.size),
            from: .zero,
            operation: .sourceOver,
            fraction: 1.0
        )

        let result = NSImage(size: canvasSize)
        result.addRepresentation(rep)
        return result
    }

    /// Draw equalizer bars at `origin` within `size` into the active NSGraphicsContext.
    /// Drawn in the system label color so the indicator reads correctly on
    /// both light and dark menu bar backgrounds.
    static func drawEqualizerBars(
        frame: Int,
        at origin: NSPoint,
        in size: NSSize,
        barCount: Int = 4,
        barWidth: CGFloat = 2,
        spacing: CGFloat = 1
    ) {
        let totalW = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * spacing
        let scaleX = size.width / totalW
        NSColor.labelColor.setFill()
        for i in 0..<barCount {
            let t = Double(frame) * 0.55
            let phase = Double(i) * 0.95
            let normalized = (sin(t + phase) + 1) * 0.5
            let h = 3 + CGFloat(normalized) * (size.height - 3)
            let x = origin.x + CGFloat(i) * (barWidth + spacing) * scaleX
            let y = origin.y + (size.height - h) / 2
            let w = barWidth * scaleX
            let rect = NSRect(x: x, y: y, width: w, height: h)
            NSBezierPath(roundedRect: rect, xRadius: w / 2, yRadius: w / 2).fill()
        }
    }

    /// Draw a pause glyph (two vertical rounded rectangles) at `origin` within
    /// `size` into the active NSGraphicsContext.
    static func drawPauseGlyph(at origin: NSPoint, in size: NSSize) {
        let pillarW = max(2, size.width * 0.35)
        let gap = size.width - pillarW * 2
        NSColor.labelColor.setFill()
        let leftRect = NSRect(x: origin.x, y: origin.y, width: pillarW, height: size.height)
        let rightRect = NSRect(x: origin.x + pillarW + gap, y: origin.y, width: pillarW, height: size.height)
        NSBezierPath(roundedRect: leftRect, xRadius: pillarW / 2, yRadius: pillarW / 2).fill()
        NSBezierPath(roundedRect: rightRect, xRadius: pillarW / 2, yRadius: pillarW / 2).fill()
    }
}
