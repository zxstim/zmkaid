# zmkaid

macOS menu bar app that shows a floating overlay of the user's **Sofle split keyboard (ZMK)** and lights keys as
they type in any app. The user is learning the Sofle and wants something visible all day while working, to
memorize the layers. See README.md for user-facing docs and the roadmap.

The user's board: Sofle with OLEDs + two encoders, running ZMK, **edited with ZMK Studio**. Its keymap is NOT the
stock ZMK Sofle keymap. The source of truth is what ZMK Studio shows (see "User's keymap" below). The printed
keycap legends are wrong; ignore them. The user likes to see the UI before going further, so show rendered
previews of visual changes.

## Commands

```sh
make build     # xcodebuild Release into ./build (quiet)
make run       # build, kill any running copy, launch
make install   # build, copy to /Applications, launch
make preview   # render overlay PNGs into ./preview via `zmkaid --render <dir>` (no window, no permissions)
```

Filter build output: `make build 2>&1 | grep -E "error|warning: |BUILD"`. The user's zsh profile prints
harmless `FakeAssocArray ... _encode` noise on every command; ignore it.

**Verify UI changes with `make preview`, then Read `preview/*.png`.** It renders the idle overlay, the typing state
at every size (check Small too, where text hits its minimum sizes), and the needs-permission state. When adding
a new visual state, add a render of it to `Overlay/SnapshotRenderer.swift` (and a `#Preview` in
`KeyboardView.swift`). Preview states come from `AppState.preview(...)`, which sets `persists = false` so
rendering never overwrites the user's saved settings.

**Signing keeps the Input Monitoring permission across rebuilds.** The target is signed with the user's Personal
Team (`DEVELOPMENT_TEAM = HL8G57PM74`, `CODE_SIGN_IDENTITY[sdk=macosx*] = Apple Development`, set in Xcode on
2026-09-25). macOS matches the permission on the designated requirement (bundle id + certificate), not the
binary, so rebuilds keep it. Don't change the bundle id, team or signing identity: any of those makes macOS
treat it as a new app, and the user has to remove and re-allow zmkaid in Privacy & Security → Input Monitoring.
Check with `codesign -d -r- build/Build/Products/Release/zmkaid.app`. Don't run `tccutil reset` without asking.
The development certificate renews yearly, which may need one more grant.

## Project setup

- `zmkaid.xcodeproj` was written by hand and uses a **file-system synchronized group**: any file under `zmkaid/`
  is compiled automatically. Don't add file references to `project.pbxproj`.
- Shared scheme `zmkaid` in `xcshareddata`. Bundle id `com.zxstim.zmkaid`, macOS 14+, `LSUIElement` (no Dock
  icon), App Sandbox off (a sandbox would block the event tap), hardened runtime on.
- Swift 5 language mode with `SWIFT_STRICT_CONCURRENCY = minimal`. Mark AppKit/state types `@MainActor`
  explicitly; in C callbacks, timers and `asyncAfter` blocks use `MainActor.assumeIsolated { }` (they run on
  the main run loop).
- No third-party dependencies.
- Avoid names that clash with SwiftUI: `Layer`, `Binding`, `Settings` (hence `KeyLayer`, `KeyBinding`).

## Architecture

- `AppState` (`@Observable`, `@MainActor`, `.shared`) is the single source of truth: pressed positions, shift,
  encoder turns, active layer, permission state, persisted settings (UserDefaults via `didSet`).
- `KeyMonitor` is a **listen-only** `CGEventTap` on the main run loop (needs Input Monitoring): keyDown/keyUp,
  flagsChanged (left vs right from device bits in `MacKey.modifierDeviceBits`), and `NX_SYSDEFINED` (type 14,
  subtype 8) for volume/mute. It emits `KeyEvent`s to `AppState.handle`.
- `AppState.route` maps a `Trigger` (`.key(kVK)` or `.media(NX_KEYTYPE)`) to key positions through the active
  `KeyLayer`'s index (including `aliases`), or, only if no key on the layer sends it, to an encoder turn (so
  RAISE's PgUp key wins over the PgUp knob). When several positions share a trigger, the ones whose
  `sendsShift` matches the current Shift win (`!` vs `1`), then the layer's own keys over fall-through ones
  (RAISE's Shift vs the thumb Shift).
- Modifier presses wait 15 ms before lighting (`implicitModifierWindow`). ZMK sends the Shift for `&kp EXCL`
  etc. in the same HID report as the key, so a key-down inside that window marks the modifier as
  firmware-added, and it stays dark.
- `Keymap(name:layers:)` resolves `transparent` (`&trans`) bindings and empty encoder lists from the base
  layer. Inherited keys keep their triggers and are drawn at 35% opacity. Releases stay lit for 80 ms, then fade, so fast taps show.
  Missed key-ups are cleaned up (modifiers from the flags on each event; other keys after 4 s without repeats).
- Status strip (top corners): `AppState.keyboardStatus`.
  - `BatteryMonitor` (CoreBluetooth) finds the connected peripheral named `keymap.deviceName` ("Sofle") that has
    Battery service 0x180F, connects on top of the system's link, and reads/subscribes every 0x2A19. A level
    whose User Description (0x2901) starts with "Peripheral" is the right half. That second service exists only
    with `CONFIG_ZMK_SPLIT_BLE_CENTRAL_BATTERY_LEVEL_PROXY` (set in the config repo's build.yaml for the left
    half). ZMK keeps the right half's last level after a disconnect.
  - `USBPresence` polls IOKit every 3 s for ZMK's USB IDs (1d50:615e) plus the product name. Only the left half
    does USB: `ZMK_USB` depends on the central role.
  - `INFOPLIST_KEY_NSBluetoothAlwaysUsageDescription` is set in the target's build settings (required, or
    CoreBluetooth crashes the app).
- `OverlayController` owns a non-activating `NSPanel` (floating, all spaces, full-screen auxiliary,
  click-through when locked) with an `NSVisualEffectView` HUD blur and a hosting view. It follows settings
  through `withObservationTracking`. Unlocked (the default) = draggable: `DragHostingView` calls
  `performDrag` on mouse-down and shows an open-hand cursor via an `.activeAlways` tracking area (the panel is
  never key). Position is saved on `windowDidMove`. The user wanted it small and easy to place anywhere.
- The overlay is a SwiftUI `ZStack` with every key placed absolutely: `frame` → `rotationEffect(anchor:)` →
  `position`, in key units × `unit` (points per key: Small 22 / Medium 28 (default) / Large 34 / Extra Large 42 / Super Large 52; the user
  preferred these presets over free drag-resizing). Fonts scale
  with `unit` but have point minimums, and legends use `minimumScaleFactor` so they never overflow a key.

## Sofle key positions (0–59)

Position order is the same in `SofleLayout.keys` (geometry from ZMK `app/dts/layouts/josefadamcik/sofle.dtsi`,
units of 1/100 key, rotation in 1/100°) and in every layer's bindings (ZMK keymap order):

- 0–11 number row, 12–23 top row, 24–35 home row (6 left, then 6 right)
- 36–49 bottom row: 36–41 left, **42 left encoder push, 43 right encoder push**, 44–49 right
- 50–59 thumbs (user's keymap): 50 SHIFT, 51 ALT, 52 CTRL, **53 LOWER?**, 54 SPACE (1.5u) | 55 ENTER (1.5u),
  **56 RAISE?**, 57 BKSP, 58 DEL, 59 `/`
- Encoders: left = C_VOL_UP / C_VOL_DN, right = PG_UP / PG_DN (the first binding is clockwise; the direction
  hasn't been checked on the user's hardware)

## User's keymap

`Keyboard/MyKeymap.swift` (`Keymap.mine`) has all four layers (BASE, LOWER, RAISE, ADJUST), transcribed from ZMK
Studio screenshots on 2026-09-25. The menu bar **View Layer** picker sets
`activeLayer` by hand until the keyboard can report it.

BASE:

```
| Esc | 1 | 2 | 3 | 4 | 5 |                 | 6 | 7 | 8 | 9 | 0 | = |
| Caps| Q | W | E | R | T |                 | Y | U | I | O | P | - |
| Tab | A | S | D | F | G |                 | H | J | K | L | ; | ' |
| GUI | Z | X | C | V | B | Mute |  | (none) | N | M | , | . | / | Shift |
        | Shift | Alt | Ctrl | ? | Space |  | Enter | ? | BkSp | Del | / |
```

Base layer notes (confirm open items with the user or in ZMK Studio):
- 53 / 56 are blank in Studio. Both confirmed: 53 is LOWER (next to Space), 56 is RAISE (next to Enter).
- 59 types `/` (confirmed), the same as 48, so both light when `/` is typed.
- The modifiers are assumed to be the left variants on the left half and RSHFT on the right. If the overlay lights
  the wrong side, check which keycode the key sends.
- The encoder bindings don't show in Studio; they're assumed stock (the Mute icon on 42 matches).
- ZMK Studio hides the Shift that ZMK adds for symbols (it shows `EXCL` as `1`, `LBKT` and `LBRC` both as `{`),
  so screenshots are ambiguous for shifted characters. Confirm by asking the user to hold the layer key and type the row into the
  chat.

LOWER (blank = `&trans`, falls through to BASE):

```
| Esc | 1  | 2  | 3  | 4  | 5  |               | 6  | 7  | 8  | 9  | 0   | =   |
| F1  | F2 | F3 | F4 | F5 | F6 |               | F7 | F8 | F9 | F10| F11 | F12 |
| Tab | !  | @  | #  | $  | %  |               | ^  | &  | *  | (  | )   | |   |
|     | =  | -  | +  | {  | }  |    |  |       | [  | ]  | ;  | :  | \   |     |
        (all thumbs blank)
```

LOWER is confirmed: the user typed the symbol rows (2026-09-25), and they match the stock Sofle LOWER symbols,
even though Studio shows them as `1 2 3 4 5 | 6 7 * 9 0 \` and `= - + { } { } ; ; \`. `*` and `+` also match
the keypad keys (aliases), since typing can't tell Shift+8 from keypad `*`. For reference, the stock layers are
in `zmkfirmware/zmk` → `app/boards/shields/sofle/sofle.keymap`, and the user's layers may follow them where
Studio is ambiguous.

RAISE (the same as the stock RAISE except the `0`):

```
|     |      |      |      |       |      |               |      |    |    |    |     |      |
|     | Ins  | PrSc | Menu |       |      |               | PgUp |    | ↑  |    | 0   |      |
|     | Alt  | Ctrl | Shift|       | Caps |               | PgDn | ←  | ↓  | →  | Del | BkSp |
|     | Undo | Cut  | Copy | Paste |      |    |  |       |      |    |    |    |     |      |
        (all thumbs blank)
```

- On a Mac, Insert arrives as `kVK_Help` and Print Screen as `kVK_F13`. Menu is `kVK_ContextualMenu`.
- Undo/Cut/Copy/Paste are HID editing keys (`K_UNDO` etc.). macOS ignores them (confirmed: RAISE+C/V do
  nothing). The user was told to rebind them in Studio to ⌘Z/⌘X/⌘C/⌘V (`LG(Z)` …). Their triggers are already
  `.key(kVK_ANSI_Z)` etc.; the implicit ⌘ is filtered out like the implicit Shift.
- The `0` at 22 types `0` (confirmed). Unconfirmed: the blank left number row. The stock
  keymap has **Bluetooth keys** there (BT_CLR, BT_SEL 0–4), which Studio may draw blank. Don't tell the user to
  test-press them: BT_CLR clears the pairing.

ADJUST (LOWER + RAISE, if the firmware keeps the stock conditional layer): Studio shows only a `W` at 6, probably
a stray edit. Its blanks are drawn as `.blank` (empty), not `&trans`, because the stock ADJUST has Bluetooth / RGB
keys on the left (BT_CLR at 0!) that Studio draws blank. 53 / 56 fall through so the held LOWER / RAISE show.

Caps Lock sends one `flagsChanged` per toggle (no down/up pair), so `KeyMonitor` turns it into a tap, and
`AppState.capsLockOn` (from `.maskAlphaShift`) drives an LED dot on the Caps key.

## Layer detection (roadmap steps 1–2)

The Mac can't see ZMK layer keys, so the keyboard's LOWER / RAISE are macros (`lower_sig` / `raise_sig` in
`../unified-zmk-config-template/config/sofle.keymap`) that turn the layer on **first** (no typing delay), then tap an unused key:
F16 / F17 = LOWER on / off, F18 / F19 = RAISE on / off.

Firmware: `../unified-zmk-config-template` (github.com/zxstim/unified-zmk-config-template, a fork of ZMK's unified config template, ZMK v0.3; the user pushes and GitHub Actions builds):
- `build.yaml`: `nice_nano_v2` + `sofle_left` (Studio snippet, `CONFIG_ZMK_STUDIO_LOCKING=n` because there's
  no `&studio_unlock` key), `sofle_right`, `settings_reset`.
- `config/sofle.conf`: display, encoders, RGB underglow on (what the original firmware had).
- `config/sofle.keymap`: the user's four layers as they were in Studio, plus the macros on 53 / 56, and RAISE
  Undo/Cut/Copy/Paste changed to `LG(Z/X/C/V)`.
- Studio's saved keymap overrides the file, so after flashing the user clicks **Restore Stock Settings** in
  Studio. Flash both halves from the same build.

App side (done): `MacKey.layerSignals` → `AppState.applyLayerSignal` sets `activeLayer` (both = ADJUST) and
lights the held layer key. `lit` remembers what each key-down lit, so key-ups release correctly across layer
changes. `make preview` renders `overlay-signal-lower.png` by feeding real events through `handle`.

Status (2026-09-26): the firmware built on GitHub Actions and is flashed to both halves. The layer switching works
on real hardware (LOWER, RAISE, ADJUST), and the displays, knobs and RGB are fine.

Still to do:
- **RAISE+C / RAISE+V don't copy / paste** after flashing (unresolved). The keymap file has `&kp LG(C)` / `LG(V)`, and
  macOS has no modifier remap for the keyboard. Next check: in ZMK Studio's RAISE layer, do 37–40 show
  "Undo/Cut/Copy/Paste" (Studio's saved layer still overrides → Restore Stock Settings again and replug, or edit
  in Studio) or "Z/X/C/V" (keyboard is fine → look at what the Mac receives, e.g. does the overlay light `copy`)?
  The Studio serial port (`/dev/cu.usbmodem*`) is busy while ZMK Studio is open in Chrome; with it closed, the
  keymap could be read over Studio RPC (protos in zmkfirmware/zmk-studio-messages; locking is off).
- F16–F19 still reach other apps. Hiding them needs the tap changed to `.defaultTap` (active) returning `nil` for
  those events, which needs **Accessibility** permission (`AXIsProcessTrustedWithOptions`) instead of Input
  Monitoring; update the permission flow and README.
- A missed release (e.g. a Bluetooth hiccup) leaves a layer stuck until LOWER / RAISE is pressed again.
- Test fast LOWER+key rolls after flashing.

Firmware facts (read from the left half's bootloader backup, 2026-09-26; details and restore steps in
`../sofle-backups/README.md`):
- nice!nano (UF2 bootloader 0.6.0) → build for board `nice_nano_v2`, shields `sofle_left` / `sofle_right`.
  v1 vs v2 isn't provable from the backup (both use the ADC); v2 was chosen (v1 was discontinued in 2021).
  If the battery level or display / RGB power toggling acts inverted, try board `nice_nano` (v1).
- It's the standard ZMK Sofle shield build (name "Sofle", stock layer names) on Zephyr `v3.5.0+zmk-fixes`
  (Aug 2025), i.e. ZMK's v0.3 line. ZMK main has since moved to Zephyr 4.1, so pin the new zmk-config to the
  matching ZMK release unless there's a reason to upgrade.
- Enabled: SSD1306 OLED, RGB underglow (WS2812), left encoder, battery, Studio over USB. No macros yet.
- Both halves are backed up (same build); restore = drag the half's .uf2 onto its NICENANO drive.

Future idea: ZMK Studio talks to the keyboard over a protocol (USB serial or BLE), so the app might be able to read
the live keymap straight from the keyboard and always match the user's Studio edits. Research the protocol
before promising this.
