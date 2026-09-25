import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Renders the overlay to PNGs without opening a window: `zmkaid --render <dir>`.
@MainActor
enum SnapshotRenderer {
    static func render(into directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        write(.preview(), to: directory.appending(path: "overlay.png"))
        for size in OverlaySize.allCases {
            write(.preview(typing: true, size: size), to: directory.appending(path: "overlay-typing-\(size.rawValue).png"))
        }
        for layer in Keymap.mine.layerIDs where layer != .base {
            write(.preview(typing: true, size: .large, layer: layer), to: directory.appending(path: "overlay-\(layer.rawValue).png"))
        }

        // Also shows a low left battery on Bluetooth only, and a right half that isn't reporting.
        let waiting = AppState.preview()
        waiting.keyAccess = .waiting
        waiting.keyboardStatus = KeyboardStatus(bluetooth: true, leftBattery: 12)
        write(waiting, to: directory.appending(path: "overlay-needs-access.png"))

        // Real event routing: the keyboard signals LOWER, then sends `!` (Shift+1, Shift added by the firmware).
        // Expect the LOWER layer, with LOWER and `!` lit and no Shift key lit.
        let signalled = AppState.preview()
        let shift = CGEventFlags(rawValue: CGEventFlags.maskShift.rawValue | 0x2)
        for event: KeyEvent in [
            .key(code: UInt16(kVK_F16), down: true, isRepeat: false, flags: []),
            .key(code: UInt16(kVK_Shift), down: true, isRepeat: false, flags: shift),
            .key(code: UInt16(kVK_ANSI_1), down: true, isRepeat: false, flags: shift),
        ] {
            signalled.handle(event)
        }
        write(signalled, to: directory.appending(path: "overlay-signal-lower.png"))
    }

    private static func write(_ state: AppState, to url: URL) {
        let renderer = ImageRenderer(content: OverlayRoot(state: state, solidBackground: true))
        renderer.scale = 2
        guard let image = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        else { return }
        try? png.write(to: url)
    }
}
