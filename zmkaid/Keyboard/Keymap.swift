import SwiftUI

enum LayerID: String, CaseIterable, Identifiable {
    case base, lower, raise, adjust

    var id: Self { self }
    var title: String { rawValue.uppercased() }

    var color: Color {
        switch self {
        case .base: Color(white: 0.92)
        case .lower: Color(red: 0.30, green: 0.85, blue: 0.80)
        case .raise: Color(red: 1.00, green: 0.64, blue: 0.30)
        case .adjust: Color(red: 0.74, green: 0.58, blue: 1.00)
        }
    }
}

/// How a key shows up on the Mac: a virtual keycode, or a media key (volume, mute)
/// that arrives as a system-defined event instead of a key event.
enum Trigger: Hashable {
    case key(UInt16)
    case media(Int)
}

enum KeyRole: Equatable {
    case normal
    case modifier
    case layer(LayerID)
    case encoder
    case blank
}

struct KeyBinding {
    var label: String
    /// Legend shown above `label` and emphasized while Shift is held.
    var shifted: String? = nil
    /// Small word under a symbol, e.g. "cmd" under ⌘.
    var caption: String? = nil
    var role: KeyRole = .normal
    var trigger: Trigger? = nil
    /// Other ways the same key may reach the Mac (e.g. keypad `*` instead of Shift+8).
    var aliases: [Trigger] = []
    /// Sends Shift along with the key, like ZMK's `&kp EXCL` (Shift+1). Tells `!` apart from `1`.
    var sendsShift = false
    /// `&trans`: falls through to the base layer. `Keymap` fills in the base binding; drawn dimmed.
    var transparent = false
    /// Home-row bump (F and J).
    var homing = false
}

struct EncoderBinding {
    let position: Int
    let caption: String
    let clockwise: Trigger
    let counterClockwise: Trigger
}

struct KeyLayer {
    let id: LayerID
    let bindings: [KeyBinding]
    /// Empty on a non-base layer means "same as base".
    let encoders: [EncoderBinding]
    private let positionsByTrigger: [Trigger: [Int]]

    init(id: LayerID, bindings: [KeyBinding], encoders: [EncoderBinding] = []) {
        precondition(bindings.count == SofleLayout.keys.count, "\(id) layer needs \(SofleLayout.keys.count) bindings")
        self.id = id
        self.bindings = bindings
        self.encoders = encoders
        var index: [Trigger: [Int]] = [:]
        for (position, binding) in bindings.enumerated() {
            for trigger in [binding.trigger].compactMap({ $0 }) + binding.aliases {
                index[trigger, default: []].append(position)
            }
        }
        positionsByTrigger = index
    }

    /// Where `trigger` is on this layer. When several keys send it, prefer those whose Shift matches
    /// (Shift+1 lights `!` rather than `1`), then this layer's own keys over ones falling through
    /// (RAISE's Shift rather than the thumb Shift).
    func positions(for trigger: Trigger, shift: Bool) -> [Int] {
        let all = positionsByTrigger[trigger] ?? []
        let shiftMatches = narrowed(all) { bindings[$0].sendsShift == shift }
        return narrowed(shiftMatches) { !bindings[$0].transparent }
    }

    private func narrowed(_ positions: [Int], to keep: (Int) -> Bool) -> [Int] {
        let kept = positions.filter(keep)
        return kept.isEmpty ? positions : kept
    }

    /// This layer with its `&trans` keys and missing encoders taken from `base`.
    func fallingThrough(to base: KeyLayer) -> KeyLayer {
        let resolved = zip(bindings, base.bindings).map { own, below in
            guard own.transparent else { return own }
            var inherited = below
            inherited.transparent = true
            return inherited
        }
        return KeyLayer(id: id, bindings: resolved, encoders: encoders.isEmpty ? base.encoders : encoders)
    }

    func encoder(for trigger: Trigger) -> (encoder: EncoderBinding, clockwise: Bool)? {
        for encoder in encoders {
            if encoder.clockwise == trigger { return (encoder, true) }
            if encoder.counterClockwise == trigger { return (encoder, false) }
        }
        return nil
    }
}

struct Keymap {
    let name: String
    /// ZMK's `CONFIG_ZMK_KEYBOARD_NAME`: how the keyboard shows up over USB and Bluetooth.
    let deviceName: String
    let layers: [LayerID: KeyLayer]

    /// `layers` must include `.base`; the others fall through to it.
    init(name: String, deviceName: String, layers: [KeyLayer]) {
        guard let base = layers.first(where: { $0.id == .base }) else { preconditionFailure("\(name) has no base layer") }
        self.name = name
        self.deviceName = deviceName
        self.layers = Dictionary(uniqueKeysWithValues: layers.map { layer in
            (layer.id, layer.id == .base ? layer : layer.fallingThrough(to: base))
        })
    }

    /// Layers this keymap defines, in order.
    var layerIDs: [LayerID] { LayerID.allCases.filter { layers[$0] != nil } }

    func layer(_ id: LayerID) -> KeyLayer {
        layers[id] ?? layers[.base]!
    }
}
