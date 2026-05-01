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

    /// Composite a small state indicator into the bottom-right corner of this
    /// image and return the combined NSImage.
    ///
    /// MenuBarExtra's label maps to NSStatusItem.button — a single cell that
    /// holds exactly one image and one title. The SwiftUI bridge silently drops
    /// every Image past the first, so a second Image(nsImage:) for the state
    /// indicator never reaches the screen. Folding the indicator into the
    /// artwork bitmap before SwiftUI sees it bypasses that constraint.
    ///
    /// The overlay is drawn white-on-dark so it stays legible against any
    /// artwork colour without needing template rendering.
    func withStateOverlay(
        indicatorSize: NSSize,
        draw indicator: (_ origin: NSPoint, _ size: NSSize) -> Void
    ) -> NSImage {
        guard self.size.width > 0, self.size.height > 0 else { return self }
        let canvasSize = self.size
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

        self.draw(
            in: NSRect(origin: .zero, size: canvasSize),
            from: .zero,
            operation: .copy,
            fraction: 1.0
        )

        let pad: CGFloat = 1.5
        let badgeW = indicatorSize.width + pad * 2
        let badgeH = indicatorSize.height + pad * 2
        let badgeX = canvasSize.width - badgeW
        let badgeY: CGFloat = 0
        let badgeRect = NSRect(x: badgeX, y: badgeY, width: badgeW, height: badgeH)

        NSColor(white: 0, alpha: 0.55).setFill()
        NSBezierPath(roundedRect: badgeRect, xRadius: 2, yRadius: 2).fill()

        indicator(NSPoint(x: badgeX + pad, y: badgeY + pad), indicatorSize)

        let result = NSImage(size: canvasSize)
        result.addRepresentation(rep)
        return result
    }

    /// Draw equalizer bars at `origin` within `size` into the active NSGraphicsContext.
    /// Bars are drawn white so they show on the dark badge background.
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
        NSColor.white.setFill()
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
    /// `size` into the active NSGraphicsContext. Drawn white for the dark badge.
    static func drawPauseGlyph(at origin: NSPoint, in size: NSSize) {
        let pillarW = max(2, size.width * 0.35)
        let gap = size.width - pillarW * 2
        NSColor.white.setFill()
        let leftRect = NSRect(x: origin.x, y: origin.y, width: pillarW, height: size.height)
        let rightRect = NSRect(x: origin.x + pillarW + gap, y: origin.y, width: pillarW, height: size.height)
        NSBezierPath(roundedRect: leftRect, xRadius: pillarW / 2, yRadius: pillarW / 2).fill()
        NSBezierPath(roundedRect: rightRect, xRadius: pillarW / 2, yRadius: pillarW / 2).fill()
    }
}
