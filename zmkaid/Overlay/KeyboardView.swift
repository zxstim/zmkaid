import SwiftUI

/// Everything inside the overlay panel.
struct OverlayRoot: View {
    let state: AppState
    /// Snapshots can't capture the panel's blur, so they draw a solid background instead.
    var solidBackground = false

    static func cornerRadius(unit: CGFloat) -> CGFloat { (unit * 0.45).rounded() }

    static func padding(unit: CGFloat) -> CGFloat { (unit * 0.4).rounded() }

    /// The strip above the keys with each half's connection and battery.
    static func statusHeight(unit: CGFloat) -> CGFloat { max(13, (unit * 0.5).rounded()) }

    static func contentSize(unit: CGFloat) -> CGSize {
        let padding = padding(unit: unit)
        return CGSize(
            width: SofleLayout.size.width * unit + padding * 2,
            height: statusHeight(unit: unit) + SofleLayout.size.height * unit + padding * 2
        )
    }

    var body: some View {
        let unit = state.size.unit
        let status = state.keyboardStatus
        VStack(spacing: 0) {
            HStack {
                // Left half: USB when plugged into the Mac (typing goes over the cable), else Bluetooth.
                HalfStatusView(
                    link: status.usb ? "USB" : status.bluetooth ? "BT" : nil,
                    battery: status.leftBattery,
                    pluggedIn: status.usb,
                    unit: unit
                )
                Spacer()
                // Right half: always Bluetooth, to the left half; its USB port only charges it.
                HalfStatusView(
                    link: status.rightBattery != nil ? "BT" : nil,
                    battery: status.rightBattery,
                    pluggedIn: false,
                    unit: unit
                )
            }
            .padding(.horizontal, unit * 0.1)
            .frame(height: Self.statusHeight(unit: unit), alignment: .top)

            KeyboardView(state: state, unit: unit)
        }
            .padding(Self.padding(unit: unit))
            .background {
                if solidBackground {
                    RoundedRectangle(cornerRadius: Self.cornerRadius(unit: unit), style: .continuous)
                        .fill(Color(white: 0.11))
                }
            }
            .environment(\.colorScheme, .dark)
    }
}

struct KeyboardView: View {
    let state: AppState
    /// Points per key.
    let unit: CGFloat

    var body: some View {
        let layer = state.layer
        ZStack(alignment: .topLeading) {
            LayerIndicator(active: state.activeLayer, hint: hint, unit: unit)
                .frame(width: unit * 2.9, height: unit * 2.4, alignment: .top)
                .position(x: SofleLayout.size.width / 2 * unit, y: unit * 1.3)

            ForEach(SofleLayout.keys) { key in
                cap(for: key, in: layer)
                    .frame(width: key.frame.width * unit, height: key.frame.height * unit)
                    .rotationEffect(.degrees(key.rotation), anchor: key.anchor)
                    .position(x: key.frame.midX * unit, y: key.frame.midY * unit)
            }
        }
        .frame(width: SofleLayout.size.width * unit, height: SofleLayout.size.height * unit)
    }

    private var hint: String? {
        state.keyAccess == .granted ? nil : "Turn on live keys\nfrom the menu bar icon"
    }

    @ViewBuilder
    private func cap(for key: PhysicalKey, in layer: KeyLayer) -> some View {
        let binding = layer.bindings[key.id]
        let pressed = state.pressed.contains(key.id)
        if SofleLayout.encoderPositions.contains(key.id) {
            EncoderView(
                binding: binding,
                caption: layer.encoders.first { $0.position == key.id }?.caption,
                turns: state.encoderTurns[key.id] ?? 0,
                pressed: pressed,
                unit: unit
            )
        } else {
            KeyCapView(
                binding: binding,
                pressed: pressed,
                shiftHeld: state.shiftHeld,
                ledOn: state.capsLockOn && binding.trigger == .key(MacKey.capsLock),
                unit: unit
            )
        }
    }
}

/// The four layers, with the active one lit. Sits between the halves, where the OLEDs are.
struct LayerIndicator: View {
    let active: LayerID
    let hint: String?
    let unit: CGFloat

    var body: some View {
        // Without live keys the layer list means nothing, so the hint takes its place.
        if let hint {
            Text(hint)
                .font(.system(size: max(7, unit * 0.2), weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .fixedSize()
                .padding(.top, unit * 0.4)
        } else {
            VStack(spacing: unit * 0.06) {
                ForEach(LayerID.allCases) { layer in
                    let isActive = layer == active
                    HStack(spacing: unit * 0.12) {
                        Circle()
                            .fill(layer.color.opacity(isActive ? 1 : 0.35))
                            .frame(width: max(4, unit * 0.12), height: max(4, unit * 0.12))
                        Text(layer.title)
                            .font(.system(size: max(7, unit * 0.2), weight: .bold, design: .rounded))
                            .tracking(unit * 0.02)
                            .foregroundStyle(isActive ? layer.color : Color.white.opacity(0.3))
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, unit * 0.18)
                    .frame(width: max(58, unit * 2.1), height: max(10, unit * 0.3))
                    .background(Capsule().fill(layer.color.opacity(isActive ? 0.18 : 0)))
                }
            }
        }
    }
}

#Preview("Idle") {
    OverlayRoot(state: .preview(), solidBackground: true)
}

#Preview("Typing") {
    OverlayRoot(state: .preview(typing: true), solidBackground: true)
}

#Preview("Typing, small") {
    OverlayRoot(state: .preview(typing: true, size: .small), solidBackground: true)
}

#Preview("Lower") {
    OverlayRoot(state: .preview(typing: true, layer: .lower), solidBackground: true)
}

/// One half's link to the Mac and its battery, shown in the overlay's top corners.
struct HalfStatusView: View {
    /// "USB" / "BT", or nil when unknown.
    let link: String?
    let battery: Int?
    /// Plugged in by USB, so charging (if its power switch is on) or full.
    let pluggedIn: Bool
    let unit: CGFloat

    var body: some View {
        HStack(spacing: unit * 0.12) {
            if let link {
                Text(link)
                    .font(.system(size: max(7, unit * 0.2), weight: .bold, design: .rounded))
                    .tracking(0.3)
                    .padding(.horizontal, max(3, unit * 0.1))
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
            }
            Image(systemName: batterySymbol)
                .font(.system(size: max(10, unit * 0.34)))
            Text(battery.map { "\($0)%" } ?? "–")
                .font(.system(size: max(7.5, unit * 0.24), weight: .semibold, design: .rounded))
                .monospacedDigit()
            if pluggedIn {
                Image(systemName: "bolt.fill")
                    .font(.system(size: max(7, unit * 0.2)))
            }
        }
        .foregroundStyle(color)
    }

    private var batterySymbol: String {
        switch battery {
        case nil: "battery.0percent"
        case let level? where level < 13: "battery.0percent"
        case let level? where level < 38: "battery.25percent"
        case let level? where level < 63: "battery.50percent"
        case let level? where level < 88: "battery.75percent"
        default: "battery.100percent"
        }
    }

    private var color: Color {
        switch battery {
        case nil: .white.opacity(0.3)
        case let level? where level <= 15: .red
        case let level? where level <= 30: .orange
        default: .white.opacity(0.75)
        }
    }
}
