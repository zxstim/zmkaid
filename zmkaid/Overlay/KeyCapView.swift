import SwiftUI

struct KeyCapView: View {
    let binding: KeyBinding
    let pressed: Bool
    let shiftHeld: Bool
    /// Lock light, like the Caps Lock LED on a Mac keyboard.
    var ledOn = false
    let unit: CGFloat

    private struct Style {
        let fill: Color
        let stroke: Color
        let text: Color
        let lit: Color
    }

    private var style: Style {
        switch binding.role {
        case .layer(let layer):
            Style(fill: layer.color.opacity(0.16), stroke: layer.color.opacity(0.5), text: layer.color, lit: layer.color)
        case .modifier:
            Style(fill: .white.opacity(0.045), stroke: .white.opacity(0.1), text: .white.opacity(0.72), lit: .white)
        case .blank, .encoder:
            Style(fill: .white.opacity(0.02), stroke: .white.opacity(0.05), text: .clear, lit: .white.opacity(0.3))
        case .normal:
            Style(fill: .white.opacity(0.085), stroke: .white.opacity(0.12), text: .white.opacity(0.94), lit: .white)
        }
    }

    var body: some View {
        let style = style
        let shape = RoundedRectangle(cornerRadius: unit * 0.16, style: .continuous)
        ZStack {
            shape.fill(pressed ? style.lit : style.fill)
            shape.strokeBorder(pressed ? style.lit : style.stroke, lineWidth: max(1, unit * 0.025))
            legend
                .foregroundStyle(pressed ? Color.black.opacity(0.85) : style.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, unit * 0.05)
            if binding.homing {
                Capsule()
                    .fill(pressed ? Color.black.opacity(0.5) : style.text.opacity(0.55))
                    .frame(width: unit * 0.2, height: max(1.5, unit * 0.035))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, unit * 0.09)
            }
            if ledOn {
                Circle()
                    .fill(Color.green)
                    .frame(width: max(3, unit * 0.1), height: max(3, unit * 0.1))
                    .shadow(color: .green, radius: unit * 0.08)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(unit * 0.1)
            }
        }
        .padding(unit * 0.045)
        // Keys that fall through to the base layer (&trans) are dimmed until pressed.
        .opacity(binding.transparent && !pressed ? 0.35 : 1)
        .scaleEffect(pressed ? 0.93 : 1)
        .shadow(color: pressed ? style.lit.opacity(0.55) : .clear, radius: unit * 0.22)
    }

    @ViewBuilder
    private var legend: some View {
        switch binding.role {
        case .blank, .encoder:
            EmptyView()
        case .layer:
            VStack(spacing: 0) {
                Text(binding.label)
                    .font(font(0.22, .bold, min: 7))
                    .tracking(unit * 0.01)
                if let caption = binding.caption {
                    Text(caption).font(font(0.17, .medium, min: 6)).opacity(0.7)
                }
            }
        case .normal, .modifier:
            if let shifted = binding.shifted {
                VStack(spacing: -unit * 0.02) {
                    Text(shifted).font(font(0.27, min: 7)).opacity(shiftHeld ? 1 : 0.45)
                    Text(binding.label).font(font(0.3, min: 7.5)).opacity(shiftHeld ? 0.45 : 1)
                }
            } else if let caption = binding.caption {
                VStack(spacing: 0) {
                    Text(binding.label).font(font(0.3, min: 7.5))
                    Text(caption).font(font(0.2, .medium, min: 6.5)).opacity(0.65)
                }
            } else {
                Text(binding.label).font(font(binding.label.count > 1 ? 0.26 : 0.36, min: 7))
            }
        }
    }

    /// Scales with the key, but never below `min` points so small sizes stay legible.
    private func font(_ scale: CGFloat, _ weight: Font.Weight = .semibold, min: CGFloat) -> Font {
        .system(size: max(min, unit * scale), weight: weight, design: .rounded)
    }
}

/// A rotary encoder: a knob whose notch turns with each click, and glows when pushed or turned.
struct EncoderView: View {
    let binding: KeyBinding
    let caption: String?
    let turns: Int
    let pressed: Bool
    let unit: CGFloat

    var body: some View {
        let diameter = unit * 0.84
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [.white.opacity(0.2), .white.opacity(0.05)],
                    center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: diameter * 0.7
                ))
            Circle()
                .strokeBorder(pressed ? Color.white.opacity(0.95) : Color.white.opacity(0.18), lineWidth: pressed ? 2 : 1)
            Capsule()
                .fill(Color.white.opacity(0.85))
                .frame(width: max(2, unit * 0.05), height: unit * 0.15)
                .offset(y: -diameter * 0.33)
                .rotationEffect(.degrees(Double(turns) * 15))
            if !binding.label.isEmpty {
                Text(binding.label)
                    .font(.system(size: max(6.5, unit * 0.2), weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.75))
            }
        }
        .frame(width: diameter, height: diameter)
        .shadow(color: pressed ? Color.white.opacity(0.5) : .clear, radius: unit * 0.2)
        .overlay(alignment: .top) {
            if let caption {
                Text("↺ \(caption) ↻")
                    .font(.system(size: max(6.5, unit * 0.19), weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .fixedSize()
                    .offset(y: -unit * 0.3)
            }
        }
        .animation(.spring(duration: 0.25, bounce: 0.3), value: turns)
    }
}
