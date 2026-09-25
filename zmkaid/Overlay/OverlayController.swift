import AppKit
import SwiftUI

/// A borderless floating panel that never takes focus from the app you're typing in.
final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Lets the overlay be dragged from anywhere while it's unlocked, with a hand cursor.
/// (When locked the panel ignores the mouse entirely, so none of this fires.)
final class DragHostingView<Content: View>: NSHostingView<Content> {
    private var handArea: NSTrackingArea?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let handArea { removeTrackingArea(handArea) }
        // activeAlways: the panel is never key, and the cursor should still change.
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        handArea = area
    }

    override func mouseEntered(with event: NSEvent) { NSCursor.openHand.set() }
    override func mouseMoved(with event: NSEvent) { NSCursor.openHand.set() }
    override func mouseExited(with event: NSEvent) { NSCursor.arrow.set() }

    override func mouseDown(with event: NSEvent) {
        NSCursor.closedHand.set()
        window?.performDrag(with: event)
        NSCursor.openHand.set()
    }
}

@MainActor
final class OverlayController: NSObject, NSWindowDelegate {
    private static let originKey = "overlayOrigin"

    private let state: AppState
    private let panel: OverlayPanel
    private let blur = NSVisualEffectView()
    private var appliedSize: OverlaySize?
    private var appliedResets = 0

    init(state: AppState) {
        self.state = state
        panel = OverlayPanel(
            contentRect: NSRect(origin: .zero, size: OverlayRoot.contentSize(unit: state.size.unit)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.acceptsMouseMovedEvents = true
        panel.delegate = self

        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active

        let host = DragHostingView(rootView: OverlayRoot(state: state))
        host.sizingOptions = []
        host.frame = blur.bounds
        host.autoresizingMask = [.width, .height]
        blur.addSubview(host)
        panel.contentView = blur

        panel.setFrameOrigin(savedOrigin(for: panel.frame.size) ?? defaultOrigin(for: panel.frame.size))
        track()
    }

    // MARK: Following settings

    private func track() {
        withObservationTracking {
            apply()
        } onChange: { [weak self] in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.track() } }
        }
    }

    private func apply() {
        let size = state.size
        panel.alphaValue = state.opacity
        panel.ignoresMouseEvents = state.locked

        if appliedSize != size {
            blur.maskImage = Self.roundedMask(radius: OverlayRoot.cornerRadius(unit: size.unit))
            resize(to: OverlayRoot.contentSize(unit: size.unit), keepingBottomCenter: appliedSize != nil)
            appliedSize = size
        }
        if appliedResets != state.positionResets {
            appliedResets = state.positionResets
            panel.setFrameOrigin(defaultOrigin(for: panel.frame.size))
        }
        if state.overlayVisible {
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
    }

    private func resize(to size: CGSize, keepingBottomCenter: Bool) {
        let old = panel.frame
        let origin = keepingBottomCenter ? NSPoint(x: old.midX - size.width / 2, y: old.minY) : old.origin
        panel.setFrame(Self.keptOnScreen(NSRect(origin: origin, size: size)), display: true)
        panel.invalidateShadow()
    }

    /// Nudges a frame back inside the visible part of the screen it's on (a bigger size near an edge would
    /// otherwise spill off it).
    private static func keptOnScreen(_ frame: NSRect) -> NSRect {
        let screen = NSScreen.screens.first { $0.frame.intersects(frame) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return frame }
        var frame = frame
        frame.origin.x = min(max(frame.minX, visible.minX), visible.maxX - frame.width)
        frame.origin.y = min(max(frame.minY, visible.minY), visible.maxY - frame.height)
        return frame
    }

    // MARK: Position

    func windowDidMove(_ notification: Notification) {
        UserDefaults.standard.set(NSStringFromPoint(panel.frame.origin), forKey: Self.originKey)
    }

    private func savedOrigin(for size: CGSize) -> NSPoint? {
        guard let saved = UserDefaults.standard.string(forKey: Self.originKey) else { return nil }
        let origin = NSPointFromString(saved)
        let frame = NSRect(origin: origin, size: size)
        return NSScreen.screens.contains { $0.visibleFrame.intersects(frame) } ? origin : nil
    }

    /// Bottom center of the main screen, just above the Dock.
    private func defaultOrigin(for size: CGSize) -> NSPoint {
        let screen = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame ?? .zero
        return NSPoint(x: screen.midX - size.width / 2, y: screen.minY + 16)
    }

    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}
