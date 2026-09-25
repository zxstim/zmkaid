import CoreGraphics
import SwiftUI

/// One key's place on the board, in key units (1 = one key width).
struct PhysicalKey: Identifiable {
    let id: Int
    let frame: CGRect
    /// Degrees, clockwise.
    let rotation: Double
    /// Point the key rotates around.
    let pivot: CGPoint

    /// `pivot` expressed relative to the key's own bounds, for `rotationEffect`.
    var anchor: UnitPoint {
        guard rotation != 0 else { return .center }
        return UnitPoint(x: (pivot.x - frame.minX) / frame.width, y: (pivot.y - frame.minY) / frame.height)
    }
}

/// Physical geometry of the Sofle, copied from ZMK's `app/dts/layouts/josefadamcik/sofle.dtsi`.
/// Key order matches the keymap's binding order (60 positions, including the two encoder buttons).
enum SofleLayout {
    static let keys: [PhysicalKey] = raw.enumerated().map { index, k in
        PhysicalKey(
            id: index,
            frame: CGRect(x: cu(k[2]), y: cu(k[3]), width: cu(k[0]), height: cu(k[1])),
            rotation: Double(k[4]) / 100,
            pivot: CGPoint(x: cu(k[5]), y: cu(k[6]))
        )
    }

    /// Bounding box of the whole board, in key units.
    static let size = CGSize(width: 15, height: 5.7)

    /// Positions that are encoder push buttons (drawn as knobs).
    static let encoderPositions: Set<Int> = [42, 43]

    private static func cu(_ value: Int) -> CGFloat { CGFloat(value) / 100 }

    // w, h, x, y in 1/100 key; rotation in 1/100 degree; rx, ry = rotation origin.
    private static let raw: [[Int]] = [
        // Row 0: ` 1 2 3 4 5 | 6 7 8 9 0 -
        [100, 100, 0, 37, 0, 0, 0], [100, 100, 100, 37, 0, 0, 0], [100, 100, 200, 12, 0, 0, 0],
        [100, 100, 300, 0, 0, 0, 0], [100, 100, 400, 12, 0, 0, 0], [100, 100, 500, 24, 0, 0, 0],
        [100, 100, 900, 24, 0, 0, 0], [100, 100, 1000, 12, 0, 0, 0], [100, 100, 1100, 0, 0, 0, 0],
        [100, 100, 1200, 12, 0, 0, 0], [100, 100, 1300, 37, 0, 0, 0], [100, 100, 1400, 37, 0, 0, 0],
        // Row 1
        [100, 100, 0, 137, 0, 0, 0], [100, 100, 100, 137, 0, 0, 0], [100, 100, 200, 112, 0, 0, 0],
        [100, 100, 300, 100, 0, 0, 0], [100, 100, 400, 112, 0, 0, 0], [100, 100, 500, 124, 0, 0, 0],
        [100, 100, 900, 124, 0, 0, 0], [100, 100, 1000, 112, 0, 0, 0], [100, 100, 1100, 100, 0, 0, 0],
        [100, 100, 1200, 112, 0, 0, 0], [100, 100, 1300, 137, 0, 0, 0], [100, 100, 1400, 137, 0, 0, 0],
        // Row 2
        [100, 100, 0, 237, 0, 0, 0], [100, 100, 100, 237, 0, 0, 0], [100, 100, 200, 212, 0, 0, 0],
        [100, 100, 300, 200, 0, 0, 0], [100, 100, 400, 212, 0, 0, 0], [100, 100, 500, 224, 0, 0, 0],
        [100, 100, 900, 224, 0, 0, 0], [100, 100, 1000, 212, 0, 0, 0], [100, 100, 1100, 200, 0, 0, 0],
        [100, 100, 1200, 212, 0, 0, 0], [100, 100, 1300, 237, 0, 0, 0], [100, 100, 1400, 237, 0, 0, 0],
        // Row 3 (with the two encoder buttons in the middle)
        [100, 100, 0, 337, 0, 0, 0], [100, 100, 100, 337, 0, 0, 0], [100, 100, 200, 312, 0, 0, 0],
        [100, 100, 300, 300, 0, 0, 0], [100, 100, 400, 312, 0, 0, 0], [100, 100, 500, 324, 0, 0, 0],
        [100, 100, 600, 274, 0, 0, 0], [100, 100, 800, 274, 0, 0, 0],
        [100, 100, 900, 324, 0, 0, 0], [100, 100, 1000, 312, 0, 0, 0], [100, 100, 1100, 300, 0, 0, 0],
        [100, 100, 1200, 312, 0, 0, 0], [100, 100, 1300, 337, 0, 0, 0], [100, 100, 1400, 337, 0, 0, 0],
        // Thumb row
        [100, 100, 175, 437, 0, 0, 0], [100, 100, 275, 412, 0, 0, 0], [100, 100, 375, 412, 0, 0, 0],
        [100, 100, 490, 412, 1200, 490, 412], [100, 150, 600, 383, 2400, 600, 433],
        [100, 150, 800, 383, -2400, 900, 433], [100, 100, 910, 412, -1200, 1010, 412],
        [100, 100, 1025, 412, 0, 0, 0], [100, 100, 1125, 412, 0, 0, 0], [100, 100, 1225, 437, 0, 0, 0],
    ]
}
