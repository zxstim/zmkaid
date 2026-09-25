import Carbon.HIToolbox

extension Keymap {
    /// The keymap on the user's Sofle, as shown in ZMK Studio (2026-09-25). It differs from the stock ZMK
    /// Sofle keymap.
    static let mine = Keymap(
        name: "My Sofle (ZMK Studio)",
        deviceName: "Sofle",
        layers: [.myBase, .myLower, .myRaise, .myAdjust]
    )
}

extension KeyLayer {
    static let myBase = KeyLayer(
        id: .base,
        bindings: [
            // Row 0
            key("esc", kVK_Escape),
            key("1", kVK_ANSI_1, shifted: "!"), key("2", kVK_ANSI_2, shifted: "@"),
            key("3", kVK_ANSI_3, shifted: "#"), key("4", kVK_ANSI_4, shifted: "$"),
            key("5", kVK_ANSI_5, shifted: "%"),
            key("6", kVK_ANSI_6, shifted: "^"), key("7", kVK_ANSI_7, shifted: "&"),
            key("8", kVK_ANSI_8, shifted: "*"), key("9", kVK_ANSI_9, shifted: "("),
            key("0", kVK_ANSI_0, shifted: ")"), key("=", kVK_ANSI_Equal, shifted: "+"),
            // Row 1
            named("⇪", "caps", kVK_CapsLock),
            key("Q", kVK_ANSI_Q), key("W", kVK_ANSI_W), key("E", kVK_ANSI_E), key("R", kVK_ANSI_R), key("T", kVK_ANSI_T),
            key("Y", kVK_ANSI_Y), key("U", kVK_ANSI_U), key("I", kVK_ANSI_I), key("O", kVK_ANSI_O), key("P", kVK_ANSI_P),
            key("-", kVK_ANSI_Minus, shifted: "_"),
            // Row 2
            named("⇥", "tab", kVK_Tab),
            key("A", kVK_ANSI_A), key("S", kVK_ANSI_S), key("D", kVK_ANSI_D),
            key("F", kVK_ANSI_F, homing: true), key("G", kVK_ANSI_G),
            key("H", kVK_ANSI_H), key("J", kVK_ANSI_J, homing: true), key("K", kVK_ANSI_K), key("L", kVK_ANSI_L),
            key(";", kVK_ANSI_Semicolon, shifted: ":"), key("'", kVK_ANSI_Quote, shifted: "\""),
            // Row 3
            modifier("⌘", "cmd", kVK_Command),
            key("Z", kVK_ANSI_Z), key("X", kVK_ANSI_X), key("C", kVK_ANSI_C), key("V", kVK_ANSI_V), key("B", kVK_ANSI_B),
            KeyBinding(label: "mute", role: .encoder, trigger: .media(MediaKey.mute)),
            KeyBinding(label: "", role: .encoder),
            key("N", kVK_ANSI_N), key("M", kVK_ANSI_M),
            key(",", kVK_ANSI_Comma, shifted: "<"), key(".", kVK_ANSI_Period, shifted: ">"),
            key("/", kVK_ANSI_Slash, shifted: "?"),
            modifier("⇧", "shift", kVK_RightShift),
            // Thumbs. 53 and 56 are blank in ZMK Studio: 53 is LOWER, 56 is RAISE (both confirmed). 59 types `/` (confirmed).
            modifier("⇧", "shift", kVK_Shift), modifier("⌥", "opt", kVK_Option), modifier("⌃", "ctrl", kVK_Control),
            layerKey(.lower), named("␣", "space", kVK_Space),
            named("⏎", "enter", kVK_Return), layerKey(.raise),
            named("⌫", "bksp", kVK_Delete), named("⌦", "del", kVK_ForwardDelete),
            key("/", kVK_ANSI_Slash, shifted: "?"),
        ],
        // Not visible in ZMK Studio; assumed unchanged from stock (knob icon on 42 matches stock mute).
        encoders: [
            EncoderBinding(position: 42, caption: "vol",
                           clockwise: .media(MediaKey.volumeUp), counterClockwise: .media(MediaKey.volumeDown)),
            EncoderBinding(position: 43, caption: "page",
                           clockwise: .key(UInt16(kVK_PageUp)), counterClockwise: .key(UInt16(kVK_PageDown))),
        ]
    )
}

extension KeyLayer {
    /// ZMK Studio hides the Shift that ZMK adds for symbols (it shows `!` as `1`, `[` and `{` both as `{`), so the
    /// symbols were confirmed by typing them (2026-09-25). `*` and `+` also match the keypad keys, since typing
    /// can't tell Shift+8 from keypad `*`.
    static let myLower = KeyLayer(
        id: .lower,
        bindings: Array(myBase.bindings[0...11]) + [
            // Row 1
            key("F1", kVK_F1), key("F2", kVK_F2), key("F3", kVK_F3), key("F4", kVK_F4),
            key("F5", kVK_F5), key("F6", kVK_F6),
            key("F7", kVK_F7), key("F8", kVK_F8), key("F9", kVK_F9), key("F10", kVK_F10),
            key("F11", kVK_F11), key("F12", kVK_F12),
            // Row 2
            named("⇥", "tab", kVK_Tab),
            symbol("!", kVK_ANSI_1), symbol("@", kVK_ANSI_2), symbol("#", kVK_ANSI_3),
            symbol("$", kVK_ANSI_4), symbol("%", kVK_ANSI_5),
            symbol("^", kVK_ANSI_6), symbol("&", kVK_ANSI_7), symbol("*", kVK_ANSI_8, alias: kVK_ANSI_KeypadMultiply),
            symbol("(", kVK_ANSI_9), symbol(")", kVK_ANSI_0), symbol("|", kVK_ANSI_Backslash),
            // Row 3
            trans, key("=", kVK_ANSI_Equal), key("-", kVK_ANSI_Minus), symbol("+", kVK_ANSI_Equal, alias: kVK_ANSI_KeypadPlus),
            symbol("{", kVK_ANSI_LeftBracket), symbol("}", kVK_ANSI_RightBracket),
            trans, trans,
            key("[", kVK_ANSI_LeftBracket), key("]", kVK_ANSI_RightBracket),
            key(";", kVK_ANSI_Semicolon), symbol(":", kVK_ANSI_Semicolon), key("\\", kVK_ANSI_Backslash),
            trans,
            // Thumbs
            trans, trans, trans, trans, trans, trans, trans, trans, trans, trans,
        ]
    )
}

extension KeyLayer {
    /// Same as the stock Sofle RAISE except the `0` at 22 (confirmed: it types `0`). The blank left number row is
    /// unconfirmed (stock has Bluetooth keys there, which Studio may draw blank).
    /// Undo / Cut / Copy / Paste send PC editing keys that macOS ignores (confirmed). Their triggers assume the
    /// user rebinds them in ZMK Studio to ⌘Z / ⌘X / ⌘C / ⌘V; until then they simply never light.
    static let myRaise = KeyLayer(
        id: .raise,
        bindings: [
            // Row 0
            trans, trans, trans, trans, trans, trans,
            trans, trans, trans, trans, trans, trans,
            // Row 1 (Insert reaches macOS as Help, Print Screen as F13)
            trans, key("ins", kVK_Help), key("prtsc", kVK_F13), key("menu", kVK_ContextualMenu), trans, trans,
            key("pgup", kVK_PageUp), trans, key("↑", kVK_UpArrow), trans, key("0", kVK_ANSI_0), trans,
            // Row 2
            trans, modifier("⌥", "opt", kVK_Option), modifier("⌃", "ctrl", kVK_Control),
            modifier("⇧", "shift", kVK_Shift), trans, named("⇪", "caps", kVK_CapsLock),
            key("pgdn", kVK_PageDown), key("←", kVK_LeftArrow), key("↓", kVK_DownArrow), key("→", kVK_RightArrow),
            named("⌦", "del", kVK_ForwardDelete), named("⌫", "bksp", kVK_Delete),
            // Row 3
            trans, key("undo", kVK_ANSI_Z), key("cut", kVK_ANSI_X), key("copy", kVK_ANSI_C),
            key("paste", kVK_ANSI_V), trans,
            trans, trans,
            trans, trans, trans, trans, trans, trans,
            // Thumbs
            trans, trans, trans, trans, trans, trans, trans, trans, trans, trans,
        ]
    )
}

extension KeyLayer {
    /// LOWER + RAISE held together. ZMK Studio shows only a `W` (at 6, probably a stray edit). The blanks are
    /// drawn empty rather than as fall-through: the stock ADJUST has Bluetooth / RGB keys on the left, which
    /// Studio draws blank. LOWER / RAISE fall through so the held keys still show.
    static let myAdjust = KeyLayer(
        id: .adjust,
        bindings: [
            // Row 0
            blank, blank, blank, blank, blank, blank,
            key("W", kVK_ANSI_W), blank, blank, blank, blank, blank,
            // Rows 1–2
            blank, blank, blank, blank, blank, blank, blank, blank, blank, blank, blank, blank,
            blank, blank, blank, blank, blank, blank, blank, blank, blank, blank, blank, blank,
            // Row 3
            blank, blank, blank, blank, blank, blank, blank, blank, blank, blank, blank, blank, blank, blank,
            // Thumbs
            blank, blank, blank, trans, blank, blank, trans, blank, blank, blank,
        ]
    )
}

private let trans = KeyBinding(label: "", transparent: true)
private let blank = KeyBinding(label: "", role: .blank)

private func key(_ label: String, _ code: Int, shifted: String? = nil, homing: Bool = false) -> KeyBinding {
    KeyBinding(label: label, shifted: shifted, trigger: .key(UInt16(code)), homing: homing)
}

/// A shifted symbol key, e.g. `!` = Shift+1.
private func symbol(_ label: String, _ code: Int, alias: Int? = nil) -> KeyBinding {
    KeyBinding(
        label: label,
        trigger: .key(UInt16(code)),
        aliases: alias.map { [.key(UInt16($0))] } ?? [],
        sendsShift: true
    )
}

private func named(_ symbol: String, _ caption: String, _ code: Int) -> KeyBinding {
    KeyBinding(label: symbol, caption: caption, trigger: .key(UInt16(code)))
}

private func modifier(_ symbol: String, _ caption: String, _ code: Int) -> KeyBinding {
    KeyBinding(label: symbol, caption: caption, role: .modifier, trigger: .key(UInt16(code)))
}

private func layerKey(_ layer: LayerID) -> KeyBinding {
    KeyBinding(label: layer.title, caption: "hold", role: .layer(layer))
}
