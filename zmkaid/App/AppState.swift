import AppKit
import Observation
import SwiftUI

enum OverlaySize: String, CaseIterable, Identifiable {
    case small, medium, large, extraLarge, superLarge

    var id: Self { self }

    var title: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        case .extraLarge: "Extra Large"
        case .superLarge: "Super Large"
        }
    }

    /// Points per key.
    var unit: CGFloat {
        switch self {
        case .small: 22
        case .medium: 28
        case .large: 34
        case .extraLarge: 42
        case .superLarge: 52
        }
    }
}

/// How each half is connected, and its battery.
struct KeyboardStatus: Equatable {
    /// The left half is plugged into this Mac (it types over USB, and charges).
    var usb = false
    /// The Mac has a Bluetooth connection to the keyboard (the left half).
    var bluetooth = false
    var leftBattery: Int?
    /// Forwarded by the left half; stays at its last value if the right half drops its link.
    var rightBattery: Int?
}

enum KeyAccess {
    case waiting
    case granted
    /// Permission is on but the tap still won't start; macOS sometimes needs a relaunch.
    case needsRelaunch
}

@MainActor
@Observable
final class AppState {
    static let shared = AppState()

    let keymap = Keymap.mine
    var activeLayer: LayerID = .base
    var layer: KeyLayer { keymap.layer(activeLayer) }

    // Live input
    var pressed: Set<Int> = []
    var shiftHeld = false
    var capsLockOn = false
    /// Net clicks per encoder position; drives the knob's rotation.
    var encoderTurns: [Int: Int] = [:]
    var keyAccess: KeyAccess = .waiting
    var keyboardStatus = KeyboardStatus()

    // Settings
    var overlayVisible = UserDefaults.standard.object(forKey: "overlayVisible") as? Bool ?? true {
        didSet { save(overlayVisible, "overlayVisible") }
    }
    /// Locked = pinned in place and click-through. Unlocked (default) = drag it anywhere.
    var locked = UserDefaults.standard.object(forKey: "positionLocked") as? Bool ?? false {
        didSet { save(locked, "positionLocked") }
    }
    var size = OverlaySize(rawValue: UserDefaults.standard.string(forKey: "size") ?? "") ?? .medium {
        didSet { save(size.rawValue, "size") }
    }
    var opacity = UserDefaults.standard.object(forKey: "opacity") as? Double ?? 1.0 {
        didSet { save(opacity, "opacity") }
    }
    /// Bumped by "Reset Position"; the overlay controller watches it.
    var positionResets = 0

    /// Off for preview states, so rendering snapshots never touches the user's settings.
    @ObservationIgnored private var persists = true
    @ObservationIgnored private var monitor: KeyMonitor?
    @ObservationIgnored private var batteryMonitor: BatteryMonitor?
    @ObservationIgnored private var usbTimer: Timer?
    @ObservationIgnored private var accessTimer: Timer?
    @ObservationIgnored private var sweepTimer: Timer?
    @ObservationIgnored private var pendingModifiers: Set<Int> = []
    /// Layers the keyboard says are held (from the F16–F19 signals).
    @ObservationIgnored private var heldLayers: Set<LayerID> = []
    /// Positions each held trigger lit, so its key-up releases them even after a layer change.
    @ObservationIgnored private var lit: [Trigger: [Int]] = [:]
    @ObservationIgnored private var releaseGeneration: [Int: Int] = [:]
    @ObservationIgnored private var lastSeen: [Int: Date] = [:]

    // MARK: Live keys

    func startLiveKeys() {
        let monitor = KeyMonitor { [weak self] event in self?.handle(event) }
        self.monitor = monitor
        if !KeyMonitor.hasAccess { KeyMonitor.requestAccess() }
        refreshAccess()
        if keyAccess != .granted {
            accessTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshAccess() }
            }
        }
        sweepTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.releaseStuckKeys() }
        }
    }

    /// Battery levels over Bluetooth, and whether the left half is plugged in by USB.
    func startKeyboardStatus() {
        batteryMonitor = BatteryMonitor(keyboardName: keymap.deviceName) { [weak self] report in
            guard let self else { return }
            var status = self.keyboardStatus
            status.bluetooth = report.connected
            status.leftBattery = report.left
            status.rightBattery = report.right
            if status != self.keyboardStatus { self.keyboardStatus = status }
        }
        refreshUSB()
        // Cheap enough to poll; plugging in or out shows up within a few seconds.
        usbTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshUSB() }
        }
    }

    private func refreshUSB() {
        let usb = USBPresence.isConnected(productName: keymap.deviceName)
        if usb != keyboardStatus.usb { keyboardStatus.usb = usb }
    }

    func openKeyAccessSettings() {
        KeyMonitor.requestAccess()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    func relaunch() {
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config) { _, _ in
            Task { @MainActor in NSApp.terminate(nil) }
        }
    }

    func resetPosition() {
        positionResets += 1
    }

    private func save(_ value: Any, _ key: String) {
        if persists { UserDefaults.standard.set(value, forKey: key) }
    }

    private func refreshAccess() {
        guard let monitor else { return }
        if monitor.start() {
            keyAccess = .granted
            accessTimer?.invalidate()
            accessTimer = nil
        } else {
            keyAccess = KeyMonitor.hasAccess ? .needsRelaunch : .waiting
        }
    }

    // MARK: Events

    func handle(_ event: KeyEvent) {
        switch event {
        case let .key(code, down, _, flags):
            if let signal = MacKey.layerSignals[code] {
                if down { applyLayerSignal(signal.layer, on: signal.on) }
                return
            }
            shiftHeld = flags.contains(.maskShift)
            capsLockOn = flags.contains(.maskAlphaShift)
            releaseModifiers(notIn: flags)
            if MacKey.modifierDeviceBits[code] != nil {
                routeModifier(.key(code), down: down, shift: shiftHeld)
            } else {
                // A key right behind a modifier press means the firmware sent that modifier (see below).
                if down { pendingModifiers.removeAll() }
                route(.key(code), down: down, shift: shiftHeld)
            }
        case let .media(code, down):
            route(.media(code), down: down, shift: false)
        }
    }

    /// Shows the layer the keyboard reports, and lights the layer key while it's held.
    private func applyLayerSignal(_ layer: LayerID, on: Bool) {
        if on { heldLayers.insert(layer) } else { heldLayers.remove(layer) }
        // Both held = ADJUST, like the keyboard's conditional layer.
        activeLayer = switch (heldLayers.contains(.lower), heldLayers.contains(.raise)) {
        case (true, true): .adjust
        case (true, false): .lower
        case (false, true): .raise
        case (false, false): .base
        }
        if let position = keymap.layer(.base).bindings.firstIndex(where: { $0.role == .layer(layer) }) {
            if on { press(position) } else { release(position) }
        }
    }

    private func route(_ trigger: Trigger, down: Bool, shift: Bool) {
        // A key-up releases what its key-down lit, even if the layer changed in between.
        guard down else {
            (lit.removeValue(forKey: trigger) ?? layer.positions(for: trigger, shift: shift)).forEach(release)
            return
        }
        let positions = layer.positions(for: trigger, shift: shift)
        // A key on this layer wins over an encoder that sends the same thing (RAISE's PgUp vs the right knob).
        if positions.isEmpty, let match = layer.encoder(for: trigger) {
            encoderTurns[match.encoder.position, default: 0] += match.clockwise ? 1 : -1
            press(match.encoder.position)
            release(match.encoder.position)
            return
        }
        lit[trigger] = positions
        positions.forEach(press)
    }

    /// ZMK sends the Shift for keys like `!` (Shift+1) in the same report as the key, so a modifier that is
    /// followed by a key within this window was added by the firmware, not pressed. Those stay dark.
    private static let implicitModifierWindow: TimeInterval = 0.015

    private func routeModifier(_ trigger: Trigger, down: Bool, shift: Bool) {
        guard down else {
            let positions = lit.removeValue(forKey: trigger) ?? layer.positions(for: trigger, shift: shift)
            pendingModifiers.subtract(positions)
            positions.forEach(release)
            return
        }
        let positions = layer.positions(for: trigger, shift: shift)
        lit[trigger] = positions
        pendingModifiers.formUnion(positions)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.implicitModifierWindow) { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                for position in positions where self.pendingModifiers.remove(position) != nil {
                    self.press(position)
                }
            }
        }
    }

    private func press(_ position: Int) {
        releaseGeneration[position, default: 0] += 1
        lastSeen[position] = Date()
        if !pressed.contains(position) { pressed.insert(position) }
    }

    /// Keeps the key lit for a moment so quick taps are still visible, then fades it out.
    private func release(_ position: Int) {
        releaseGeneration[position, default: 0] += 1
        let generation = releaseGeneration[position]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.releaseGeneration[position] == generation else { return }
                withAnimation(.easeOut(duration: 0.22)) { _ = self.pressed.remove(position) }
            }
        }
    }

    /// A modifier's key-up can be missed (e.g. while a password field has secure input on);
    /// the flags on every later event say what's really held.
    private func releaseModifiers(notIn flags: CGEventFlags) {
        for position in pressed {
            let binding = layer.bindings[position]
            guard binding.role == .modifier, case let .key(code)? = binding.trigger,
                  let bit = MacKey.modifierDeviceBits[code] else { continue }
            if flags.rawValue & bit == 0 { release(position) }
        }
    }

    /// Same idea for ordinary keys: held keys auto-repeat, so a key that has been quiet for a while was released.
    /// (Modifiers and layer keys don't repeat, and are released by their own events.)
    private func releaseStuckKeys() {
        let now = Date()
        for position in pressed where layer.bindings[position].role == .normal {
            if let seen = lastSeen[position], now.timeIntervalSince(seen) > 4 { release(position) }
        }
    }
}

extension AppState {
    /// A detached state for rendering previews and snapshots.
    static func preview(typing: Bool = false, size: OverlaySize = .medium, layer: LayerID = .base) -> AppState {
        let state = AppState()
        state.persists = false
        state.size = size
        state.locked = false
        state.keyAccess = .granted
        state.activeLayer = layer
        state.keyboardStatus = KeyboardStatus(usb: true, bluetooth: true, leftBattery: 82, rightBattery: 64)
        if typing {
            if layer == .base {
                state.pressed = [50, 26]  // left thumb shift + S
                state.shiftHeld = true
                state.capsLockOn = true
                state.encoderTurns[42] = 2
            } else if layer == .lower {
                state.pressed = [53, 25]  // LOWER + `!`
            } else if layer == .raise {
                state.pressed = [56, 20]  // RAISE + ↑
            } else {
                state.pressed = [53, 56]  // LOWER + RAISE
            }
        }
        return state
    }
}
