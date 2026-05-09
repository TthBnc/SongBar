import AppKit
import SwiftUI
import QuartzCore
import Observation

// MARK: - MenuBarRenderer

/// Pure, stateless renderer. Composites the existing menuBarArtwork bitmap
/// (artwork + indicator, already produced by NowPlayingViewModel) with the
/// title string at an arbitrary target width, optionally crossfading between
/// an old and a new title during a width animation.
enum MenuBarRenderer {
    private static let barHeight: CGFloat = 22
    private static let artworkToTextGap: CGFloat = 6
    private static let scale: CGFloat = 2

    /// Approximate width of the artwork section (indicator + gap + thumbnail)
    /// as produced by NowPlayingViewModel. We derive this from the image itself
    /// at render time rather than hardcoding, so it adapts automatically.
    private static func artworkWidth(for artwork: NSImage?) -> CGFloat {
        artwork?.size.width ?? 0
    }

    /// Natural total width for a given menuBarArtwork + title combination.
    static func measure(artwork: NSImage?, title: String) -> CGFloat {
        let aw = artworkWidth(for: artwork)
        let textWidth = titleTextWidth(title)
        if aw > 0 {
            return aw + artworkToTextGap + textWidth
        }
        return textWidth
    }

    private static func titleTextWidth(_ title: String) -> CGFloat {
        let attrs = textAttributes()
        let size = (title as NSString).size(withAttributes: attrs)
        return ceil(size.width)
    }

    private static func textAttributes(alpha: CGFloat = 1) -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.menuBarFont(ofSize: 0),
            .foregroundColor: NSColor.labelColor.withAlphaComponent(alpha),
        ]
    }

    /// Pre-render just the text strip (no artwork) into a bitmap at natural text width.
    /// The result is cached by MenuBarController and reused on every equalizer tick,
    /// avoiding expensive NSAttributedString drawing on the hot path.
    static func renderTextStrip(title: String, artworkWidth: CGFloat) -> NSImage {
        let textWidth = titleTextWidth(title)
        let width = max(1, textWidth)
        let height = barHeight
        let pw = max(1, Int(width * scale))
        let ph = max(1, Int(height * scale))
        guard let rep = NSBitmapImageRep(
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
        ), let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
            return NSImage(size: NSSize(width: width, height: height))
        }
        rep.size = NSSize(width: width, height: height)
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = ctx

        let font = NSFont.menuBarFont(ofSize: 0)
        let fontHeight = font.ascender - font.descender
        let textY = (height - fontHeight) / 2 + font.descender
        (title as NSString).draw(at: NSPoint(x: 0, y: textY), withAttributes: textAttributes())

        let result = NSImage(size: NSSize(width: width, height: height))
        result.addRepresentation(rep)
        return result
    }

    /// Fast composite: blit artwork at left, then blit cached text strip to the right.
    /// Only allocates one NSBitmapImageRep per equalizer tick but does no text drawing.
    static func compositeWithStrip(
        artwork: NSImage?,
        textStrip: NSImage,
        totalWidth: CGFloat
    ) -> NSImage {
        let height = barHeight
        let pw = max(1, Int(totalWidth * scale))
        let ph = max(1, Int(height * scale))
        guard let rep = NSBitmapImageRep(
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
        ), let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
            return NSImage(size: NSSize(width: totalWidth, height: height))
        }
        rep.size = NSSize(width: totalWidth, height: height)
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = ctx

        var textX: CGFloat = 0
        if let artwork, artwork.size.width > 0 {
            let artY = (height - artwork.size.height) / 2
            artwork.draw(
                in: NSRect(x: 0, y: artY, width: artwork.size.width, height: artwork.size.height),
                from: .zero,
                operation: .sourceOver,
                fraction: 1.0
            )
            textX = artwork.size.width + artworkToTextGap
        }

        let stripY = (height - textStrip.size.height) / 2
        textStrip.draw(
            in: NSRect(x: textX, y: stripY, width: textStrip.size.width, height: textStrip.size.height),
            from: .zero,
            operation: .sourceOver,
            fraction: 1.0
        )

        let result = NSImage(size: NSSize(width: totalWidth, height: height))
        result.addRepresentation(rep)
        return result
    }

    /// Composite the full menu bar bitmap.
    ///
    /// - Parameters:
    ///   - artwork: The menuBarArtwork from NowPlayingViewModel (indicator + thumbnail).
    ///   - newTitle: The title to render fully at alpha 1.
    ///   - width: Total bitmap width to produce.
    ///   - oldTitle: Previous title drawn at alpha `(1 - t)` during crossfade.
    ///   - t: Crossfade progress 0…1. Pass 1 (or no oldTitle) for a clean render.
    static func composite(
        artwork: NSImage?,
        newTitle: String,
        width: CGFloat,
        oldTitle: String?,
        t: Double
    ) -> NSImage {
        let height = barHeight
        let pw = max(1, Int(width * scale))
        let ph = max(1, Int(height * scale))

        guard let rep = NSBitmapImageRep(
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
        ) else {
            return NSImage(size: NSSize(width: width, height: height))
        }
        rep.size = NSSize(width: width, height: height)

        guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
            let img = NSImage(size: NSSize(width: width, height: height))
            img.addRepresentation(rep)
            return img
        }

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = ctx

        var textX: CGFloat = 0

        // Draw artwork section if present
        if let artwork, artwork.size.width > 0 {
            let artY = (height - artwork.size.height) / 2
            artwork.draw(
                in: NSRect(x: 0, y: artY, width: artwork.size.width, height: artwork.size.height),
                from: .zero,
                operation: .sourceOver,
                fraction: 1.0
            )
            textX = artwork.size.width + artworkToTextGap
        }

        // Available width for text
        let textAreaWidth = max(0, width - textX)
        guard textAreaWidth > 1 else {
            let result = NSImage(size: NSSize(width: width, height: height))
            result.addRepresentation(rep)
            return result
        }

        let font = NSFont.menuBarFont(ofSize: 0)
        let fontHeight = font.ascender - font.descender
        let textY = (height - fontHeight) / 2 + font.descender

        // Draw old title fading out
        if let old = oldTitle, t < 1.0 {
            let oldAlpha = CGFloat(1.0 - t)
            let oldAttrs = textAttributes(alpha: oldAlpha)
            let oldStr = old as NSString
            let clipRect = NSRect(x: textX, y: 0, width: textAreaWidth, height: height)
            NSBezierPath(rect: clipRect).setClip()
            oldStr.draw(at: NSPoint(x: textX, y: textY), withAttributes: oldAttrs)
            // Reset clip
            NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).setClip()
        }

        // Draw new title fading in
        let newAlpha: CGFloat = (oldTitle != nil && t < 1.0) ? CGFloat(t) : 1.0
        let newAttrs = textAttributes(alpha: newAlpha)
        let newStr = newTitle as NSString
        let clipRect = NSRect(x: textX, y: 0, width: textAreaWidth, height: height)
        NSBezierPath(rect: clipRect).setClip()
        newStr.draw(at: NSPoint(x: textX, y: textY), withAttributes: newAttrs)

        let result = NSImage(size: NSSize(width: width, height: height))
        result.addRepresentation(rep)
        // Mark as template so the system can adapt it to the menu bar appearance
        result.isTemplate = false
        return result
    }
}

// MARK: - WidthAnimator

/// CADisplayLink-driven width interpolation for smooth 200ms menu bar title transitions.
/// Calls onTick with (interpolatedWidth, fromTitle, toTitle, easedT) on every display
/// refresh, then calls onComplete when the animation finishes.
@MainActor
final class WidthAnimator {
    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval = 0
    private var fromWidth: CGFloat = 0
    private var toWidth: CGFloat = 0
    private var fromTitle: String = ""
    private var toTitle: String = ""
    private let duration: CFTimeInterval = 0.2

    private let onTick: (CGFloat, String, String, Double) -> Void
    private let onComplete: () -> Void

    init(
        onTick: @escaping (CGFloat, String, String, Double) -> Void,
        onComplete: @escaping () -> Void
    ) {
        self.onTick = onTick
        self.onComplete = onComplete
    }

    func animate(from: CGFloat, to: CGFloat, fromTitle: String, toTitle: String) {
        cancel()
        self.fromWidth = from
        self.toWidth = to
        self.fromTitle = fromTitle
        self.toTitle = toTitle
        startTime = 0  // will be set on first tick

        // NSScreen.main?.displayLink is available on macOS 14+ (our deployment target)
        guard let link = NSScreen.main?.displayLink(target: self, selector: #selector(tick(_:))) else {
            // No screen (e.g. headless test env) — snap to final state immediately
            onTick(to, fromTitle, toTitle, 1.0)
            onComplete()
            return
        }
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func cancel() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        // Capture start time on first tick
        if startTime == 0 {
            startTime = link.timestamp
        }
        let elapsed = link.timestamp - startTime
        let rawT = min(elapsed / duration, 1.0)
        let easedT = easeInOut(rawT)

        let interpolated = fromWidth + (toWidth - fromWidth) * CGFloat(easedT)
        onTick(interpolated, fromTitle, toTitle, easedT)

        if rawT >= 1.0 {
            displayLink?.invalidate()
            displayLink = nil
            onComplete()
        }
    }

    private func easeInOut(_ t: Double) -> Double {
        if t < 0.5 { return 4 * t * t * t }
        let f = 2 * t - 2
        return 1 + f * f * f / 2
    }
}

// MARK: - MenuBarController

/// Owns the NSStatusItem, NSPopover, rendering pipeline, and animation.
/// Created once by AppDelegate and lives for the lifetime of the app.
@MainActor
final class MenuBarController {
    private let viewModel: NowPlayingViewModel
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var animator: WidthAnimator?

    private var lastTitle: String = ""
    // Track current rendered width so we can interpolate from it
    private var currentWidth: CGFloat = 0
    // Cached pre-rendered text strip keyed by title; avoids redrawing text on every equalizer tick
    private var cachedTextStrip: (title: String, image: NSImage)?
    private var observationTask: Task<Void, Never>?

    init(viewModel: NowPlayingViewModel) {
        self.viewModel = viewModel
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        setupStatusItem()
        setupPopover()
        startObservation()
        // Trigger an initial render immediately
        handleStateChange()
    }

    deinit {
        // observationTask.cancel() is safe to call on any thread (Task cancellation is thread-safe).
        // animator cleanup happens via cancel() on the main actor when state changes;
        // the displayLink will also be cleaned up when its last strong reference drops.
        observationTask?.cancel()
    }

    // MARK: - Setup

    private func setupStatusItem() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        // Receive both left and right mouse-up so we can distinguish them in the handler
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func setupPopover() {
        popover.behavior = .transient
        popover.animates = true
        let panel = NowPlayingPanel(viewModel: viewModel)
        let host = NSHostingController(rootView: panel)
        // Provide an initial content size; the SwiftUI .frame(width:360) drives actual sizing
        host.view.frame = NSRect(origin: .zero, size: NSSize(width: 360, height: 580))
        popover.contentViewController = host
        popover.contentSize = NSSize(width: 360, height: 580)
    }

    private func setupRightClickMenu() -> NSMenu {
        let menu = NSMenu()
        let quitItem = NSMenuItem(
            title: "Quit SongBar",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp
        menu.addItem(quitItem)
        return menu
    }

    // MARK: - Click handling

    @objc private func statusItemClicked(_ sender: Any?) {
        // Distinguish right click from left click
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            let menu = setupRightClickMenu()
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            // Immediately clear the menu so next left-click triggers our action handler
            DispatchQueue.main.async { [weak self] in
                self?.statusItem.menu = nil
            }
            return
        }
        togglePopover()
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Bring app to front so the popover can receive key events
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Observation

    private func startObservation() {
        observationTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.observeOnce()
            }
        }
    }

    private func observeOnce() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            withObservationTracking {
                // Read both title and artwork — artwork changes on every equalizer tick
                _ = viewModel.menuBarTitle
                _ = viewModel.menuBarArtwork
            } onChange: { [weak self] in
                Task { @MainActor [weak self] in
                    self?.handleStateChange()
                    cont.resume()
                }
            }
        }
    }

    // MARK: - State change

    private func handleStateChange() {
        let newTitle = viewModel.menuBarTitle
        let artwork = viewModel.menuBarArtwork
        let newWidth = MenuBarRenderer.measure(artwork: artwork, title: newTitle)

        if newTitle == lastTitle {
            // Same title — just refresh the bitmap (handles equalizer ticks without animating)
            renderAndApply(width: currentWidth > 0 ? currentWidth : newWidth, oldTitle: nil, t: 1)
            return
        }

        let oldTitle = lastTitle
        lastTitle = newTitle
        cachedTextStrip = nil  // invalidate so next render draws the new title

        // First paint or tiny delta: no animation
        if oldTitle.isEmpty || abs(newWidth - currentWidth) < 4 {
            animator?.cancel()
            animator = nil
            renderAndApply(width: newWidth, oldTitle: nil, t: 1)
            return
        }

        let startWidth = currentWidth > 0 ? currentWidth : newWidth
        animator?.cancel()
        animator = WidthAnimator(
            onTick: { [weak self] interpolatedWidth, from, to, easedT in
                self?.renderAndApply(width: interpolatedWidth, oldTitle: from, t: easedT)
            },
            onComplete: { [weak self] in
                self?.animator = nil
                self?.renderAndApply(width: newWidth, oldTitle: nil, t: 1)
            }
        )
        animator?.animate(from: startWidth, to: newWidth, fromTitle: oldTitle, toTitle: newTitle)
    }

    private func renderAndApply(width: CGFloat, oldTitle: String?, t: Double) {
        let artwork = viewModel.menuBarArtwork
        let title = lastTitle.isEmpty ? viewModel.menuBarTitle : lastTitle

        let image: NSImage
        let isCrossfading = oldTitle != nil && t < 1.0

        if !isCrossfading {
            // Fast path: composite artwork onto a cached pre-rendered text strip.
            // This avoids redrawing text (the expensive part) on every equalizer tick.
            let textStrip = cachedTextStripImage(for: title, artworkWidth: artwork?.size.width ?? 0)
            image = MenuBarRenderer.compositeWithStrip(
                artwork: artwork,
                textStrip: textStrip,
                totalWidth: width
            )
        } else {
            // During crossfade animation: full composite with alpha blending
            image = MenuBarRenderer.composite(
                artwork: artwork,
                newTitle: title,
                width: width,
                oldTitle: oldTitle,
                t: t
            )
        }

        currentWidth = width
        statusItem.button?.image = image
        // Remove any title so only the image shows in the button cell
        statusItem.button?.title = ""
        statusItem.length = width
    }

    private func cachedTextStripImage(for title: String, artworkWidth: CGFloat) -> NSImage {
        if let cached = cachedTextStrip, cached.title == title {
            return cached.image
        }
        let strip = MenuBarRenderer.renderTextStrip(title: title, artworkWidth: artworkWidth)
        cachedTextStrip = (title: title, image: strip)
        return strip
    }
}
