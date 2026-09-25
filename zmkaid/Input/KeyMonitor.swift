import AppKit
import Carbon.HIToolbox

enum KeyEvent {
    case key(code: UInt16, down: Bool, isRepeat: Bool, flags: CGEventFlags)
    case media(code: Int, down: Bool)
}

/// Media key codes from IOKit's ev_keymap.h (NX_KEYTYPE_*).
enum MediaKey {
    static let volumeUp = 0
    static let volumeDown = 1
    static let mute = 7
}

enum MacKey {
    static let capsLock = UInt16(kVK_CapsLock)

    /// Unused keys the keyboard's LOWER / RAISE macros tap when those layers turn on and off
    /// (see `config/sofle.keymap` in unified-zmk-config-template).
    static let layerSignals: [UInt16: (layer: LayerID, on: Bool)] = [
        UInt16(kVK_F16): (.lower, true),
        UInt16(kVK_F17): (.lower, false),
        UInt16(kVK_F18): (.raise, true),
        UInt16(kVK_F19): (.raise, false),
    ]

    /// Device-dependent modifier bits in CGEventFlags (NX_DEVICE*KEYMASK), which tell left from right.
    static let modifierDeviceBits: [UInt16: UInt64] = [
        UInt16(kVK_Control): 0x0001,
        UInt16(kVK_Shift): 0x0002,
        UInt16(kVK_RightShift): 0x0004,
        UInt16(kVK_Command): 0x0008,
        UInt16(kVK_RightCommand): 0x0010,
        UInt16(kVK_Option): 0x0020,
        UInt16(kVK_RightOption): 0x0040,
        UInt16(kVK_RightControl): 0x2000,
    ]
}

/// Watches keystrokes in every app through a listen-only event tap. It never changes or
/// blocks events, and needs the Input Monitoring permission.
@MainActor
final class KeyMonitor {
    static var hasAccess: Bool { CGPreflightListenEventAccess() }

    /// Shows the system prompt the first time; afterwards macOS only allows changing it in System Settings.
    static func requestAccess() {
        _ = CGRequestListenEventAccess()
    }

    private let handler: @MainActor (KeyEvent) -> Void
    private var tap: CFMachPort?

    init(handler: @escaping @MainActor (KeyEvent) -> Void) {
        self.handler = handler
    }

    /// Installs the tap if access has been granted. Returns whether it's running.
    func start() -> Bool {
        if tap != nil { return true }
        guard Self.hasAccess else { return false }

        var mask: CGEventMask = 0
        for type in [CGEventType.keyDown, .keyUp, .flagsChanged] {
            mask |= 1 << type.rawValue
        }
        mask |= 1 << systemDefinedEventType

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: keyTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        return true
    }

    fileprivate func receive(_ type: CGEventType, _ event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }

        case .keyDown, .keyUp:
            let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            handler(.key(code: code, down: type == .keyDown, isRepeat: isRepeat, flags: event.flags))

        case .flagsChanged:
            let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            if code == MacKey.capsLock {
                // Caps Lock sends one flagsChanged per toggle, not a down/up pair, so show it as a tap.
                handler(.key(code: code, down: true, isRepeat: false, flags: event.flags))
                handler(.key(code: code, down: false, isRepeat: false, flags: event.flags))
                return
            }
            guard let bit = MacKey.modifierDeviceBits[code] else { return }
            let down = event.flags.rawValue & bit != 0
            handler(.key(code: code, down: down, isRepeat: false, flags: event.flags))

        default:
            // Volume / mute arrive as NX_SYSDEFINED events with subtype 8 (aux control buttons).
            guard type.rawValue == systemDefinedEventType,
                  let ns = NSEvent(cgEvent: event), ns.subtype.rawValue == 8 else { return }
            let data = ns.data1
            handler(.media(code: (data & 0xFFFF_0000) >> 16, down: (data & 0xFF00) >> 8 == 0x0A))
        }
    }
}

/// NX_SYSDEFINED, which CGEventType has no case for.
private let systemDefinedEventType: UInt32 = 14

private func keyTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if let userInfo {
        let monitor = Unmanaged<KeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
        // The tap's run loop source lives on the main run loop.
        MainActor.assumeIsolated { monitor.receive(type, event) }
    }
    return Unmanaged.passUnretained(event)
}
