import AppKit
import SwiftUI
import QuartzCore
import Observation
import os

// MARK: - MenuBarRenderer

/// Width measurement for the status bar item. Drawing of the title is now
/// done by NSStatusBarButton's own attributedTitle rendering (so the system
/// handles appearance, vibrancy, and template tinting correctly); this enum
/// just predicts the natural width so we can animate `statusItem.length`.
enum MenuBarRenderer {
    /// Total horizontal padding the NSStatusBarButton cell adds around its
    /// content (image + title). Measured empirically — gives enough room so
    /// the title isn't clipped or wrapped to a second line at the
    /// natural-fit length.
    private static let cellPadding: CGFloat = 18
    /// Spacing the cell inserts between the image and the title when
    /// imagePosition is .imageLeading and imageHugsTitle is true.
    private static let imageTitleSpacing: CGFloat = 4

    /// Natural total length the status item should adopt for a given artwork +
    /// title combination. Animator interpolates between the old and new value.
    static func measure(artwork: NSImage?, title: String) -> CGFloat {
        let aw = artwork?.size.width ?? 0
        let titleWidth = ceil((title as NSString).size(withAttributes: [
            .font: NSFont.menuBarFont(ofSize: 0)
        ]).width)
        if aw > 0 {
            return aw + imageTitleSpacing + titleWidth + cellPadding
        }
        return titleWidth + cellPadding
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
final class MenuBarController: NSObject, NSPopoverDelegate {
    private static let logger = Logger(subsystem: "dev.tothbnc.SongBar", category: "menubar")

    private let viewModel: NowPlayingViewModel
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var animator: WidthAnimator?

    private var lastTitle: String = ""
    // Track current rendered width so we can interpolate from it
    private var currentWidth: CGFloat = 0
    private var observationTask: Task<Void, Never>?

    init(viewModel: NowPlayingViewModel) {
        self.viewModel = viewModel
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        super.init()
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
        // Use the native button text rendering for the title (always
        // appearance-correct and never tinted-out by the system) and let our
        // composite NSImage handle artwork + indicator.
        button.imagePosition = .imageLeading
        button.imageHugsTitle = true
        // Disallow multi-line wrapping at the cell level. Without this the
        // cell grows vertically when the title is just-too-long, which
        // pushes the popover anchor below the menu bar.
        button.cell?.usesSingleLineMode = true
        button.cell?.wraps = false
        button.cell?.lineBreakMode = .byTruncatingTail
        // Receive both left and right mouse-up so we can distinguish them in the handler
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private static func attributedTitle(for title: String) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        return NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.menuBarFont(ofSize: 0),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: style
            ]
        )
    }

    private func setupPopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
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
            // Freeze any in-flight width animation so the popover doesn't
            // shift while it's anchoring.
            animator?.cancel()
            animator = nil
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Bring app to front so the popover can receive key events
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - NSPopoverDelegate

    nonisolated func popoverDidClose(_ notification: Notification) {
        // User dismissed the panel — sync the menu bar to the latest state
        // without animating (they're not watching the menu bar transition).
        Task { @MainActor [weak self] in
            self?.snapToCurrentState()
        }
    }

    private func snapToCurrentState() {
        let newTitle = viewModel.menuBarTitle
        let artwork = viewModel.menuBarArtwork
        let newWidth = MenuBarRenderer.measure(artwork: artwork, title: newTitle)
        animator?.cancel()
        animator = nil
        lastTitle = newTitle
        renderAndApply(width: newWidth, oldTitle: nil, t: 1)
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

        // Popover is shown: pin the menu bar item's width so the panel stays
        // anchored where the user opened it. Image and title can still update
        // silently (they don't move the button frame); only `length` does.
        if popover.isShown {
            applyContentOnly(artwork: artwork, title: newTitle)
            return
        }

        let newWidth = MenuBarRenderer.measure(artwork: artwork, title: newTitle)

        let titleChanged = newTitle != lastTitle
        let widthDelta = abs(newWidth - currentWidth)
        let oldTitle = lastTitle
        lastTitle = newTitle

        // No-op refresh: same title AND width didn't materially change.
        // This is the equalizer-tick path — just rebind image/title at current width.
        if !titleChanged && widthDelta < 1 {
            renderAndApply(width: newWidth, oldTitle: nil, t: 1)
            return
        }

        // First paint, or change too small to be worth animating: snap.
        // Critical: use newWidth here, not currentWidth — when artwork arrives
        // after a title-only render, currentWidth is stale-narrow and would
        // clip the now-wider content (image + title) producing a visible-but-
        // truncated title or no title at all.
        if oldTitle.isEmpty || widthDelta < 4 {
            animator?.cancel()
            animator = nil
            renderAndApply(width: newWidth, oldTitle: nil, t: 1)
            return
        }

        // Worth animating: title swap, or artwork arriving/leaving with a
        // meaningful width delta.
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

    private func applyContentOnly(artwork: NSImage?, title: String) {
        // Sets image + title without touching length. Used while the popover
        // is open so the button's geometry — and the popover's anchor —
        // stays pinned. The cell may clip the title if length is too narrow
        // for the new content; that's acceptable because the user is reading
        // the popover, not the menu bar.
        if let artwork {
            artwork.isTemplate = false
            statusItem.button?.image = artwork
        } else {
            statusItem.button?.image = nil
        }
        statusItem.button?.attributedTitle = Self.attributedTitle(for: title)
    }

    private func renderAndApply(width: CGFloat, oldTitle: String?, t: Double) {
        let artwork = viewModel.menuBarArtwork
        let title = lastTitle.isEmpty ? viewModel.menuBarTitle : lastTitle

        // Image is just the artwork composite (artwork + indicator) — no text.
        if let artwork {
            artwork.isTemplate = false
            statusItem.button?.image = artwork
        } else {
            statusItem.button?.image = nil
        }

        // Native button-title rendering. Always appearance-correct, never
        // template-tinted away.
        statusItem.button?.attributedTitle = Self.attributedTitle(for: title)

        // Width is animated independently of content. While `statusItem.length`
        // is below the natural fit, the title text gets clipped on the right —
        // that's the "growing-into-view" reveal during a width animation.
        statusItem.length = width
        currentWidth = width

        Self.logger.info("render title='\(title, privacy: .public)' targetWidth=\(width, privacy: .public) artwork=\(String(describing: artwork?.size), privacy: .public) buttonFrame=\(String(describing: self.statusItem.button?.frame), privacy: .public)")
    }
}
