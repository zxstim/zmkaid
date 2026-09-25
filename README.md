# zmkaid

A floating overlay of the Sofle split keyboard that lights up keys as you type in any app — a practice aid for
memorizing the layers of your Sofle's ZMK keymap.

It's a native macOS menu bar app (SwiftUI + AppKit, no dependencies). The overlay floats above every app and
full-screen space and never takes focus. Drag it wherever you like, or lock it so clicks pass through.

## Status

- ✅ Base layer drawn with the real Sofle geometry (stagger, angled thumbs, encoders)
- ✅ Live key highlights from any app; holding Shift brings the shifted legends forward
- ✅ Encoders: left knob turns with volume and pushes as mute; right knob follows Page Up/Down
- ✅ Each half's connection and battery in the top corners (left: USB or BT, ⚡ when plugged in; right: BT to the
  left half). The right half's battery needs the firmware's battery forwarding (in the config repo)
- ✅ Drag to place it anywhere (position is remembered), or lock it in place as click-through
- ✅ Menu bar settings: show/hide, lock, size, opacity, reset position
- ✅ All four layers (Base, Lower, Raise, Adjust) drawn from ZMK Studio; pick one from **View Layer** in the
  menu to study it
- ✅ Switches layers automatically as you hold LOWER / RAISE, once the keyboard runs the firmware from
  [zxstim/unified-zmk-config-template](https://github.com/zxstim/unified-zmk-config-template) (it sends F16–F19 as layer signals)
- ⏳ Peek mode, hesitation stats, practice drills

## Requirements

- macOS 14 or later, Xcode 16+ (built with Xcode 26.3)
- A Sofle running ZMK. The keymap is built in (`zmkaid/Keyboard/MyKeymap.swift`), copied from ZMK Studio.

## Run

```sh
make run       # build (Release) and launch from ./build
make install   # copy to /Applications and launch — use this for everyday use
make preview   # render the overlay to ./preview/*.png without opening a window
make icon ICON=icon.png  # generate the app icon sizes from one PNG
make clean
```

Or open `zmkaid.xcodeproj` in Xcode and press ⌘R. The `#Preview`s at the bottom of
`zmkaid/Overlay/KeyboardView.swift` show the overlay in Xcode's canvas.

To start it at login: System Settings → General → Login Items → add `/Applications/zmkaid.app`.

### App icon

Put a square PNG (1024 × 1024 is best) anywhere and run:

```sh
make icon ICON=path/to/icon.png   # writes all 10 sizes into zmkaid/Assets.xcassets/AppIcon.appiconset
make install
```

Or drag PNGs into the AppIcon slots in Xcode. macOS 15 doesn't round the corners for you, so the PNG should
already be the rounded-square shape with a transparent margin. If Finder still shows the old icon, run
`killall Finder`.

### Permission

On first launch macOS asks for **Input Monitoring** (System Settings → Privacy & Security → Input Monitoring →
turn on zmkaid). Keys start lighting up within a couple of seconds; if the menu says "Relaunch to Turn On Live
Keys", click it.

The app only listens — it never changes or blocks keystrokes, and nothing is stored or sent anywhere.

It also asks for **Bluetooth** once, to read the keyboard's battery levels over the connection macOS already has.

### Signing

The app is signed with a Personal Team (free Apple ID) development certificate, so **Input Monitoring stays
granted across rebuilds** — macOS recognizes the app by its bundle id and certificate, not the exact binary.

You'll need to allow it again only if the bundle id, team or certificate changes (including the yearly
certificate renewal): remove the old zmkaid entry with −, then allow the new one.

Setting it up on another Mac: sign in to Xcode with your Apple ID (Settings → Accounts), then in the zmkaid
target's Signing & Capabilities pick your Personal Team and set Signing Certificate to "Development".

## Using it

**Drag the overlay** anywhere on screen (the cursor turns into a hand over it). It remembers where you put it,
and clicking it never takes focus from the app you're typing in.

The keyboard icon in the menu bar has the rest:

- **View Layer** — Base / Lower / Raise / Adjust. Until the keyboard reports its layer, pick one here to study it. Keys that
  fall through to the base layer are dimmed.
- **Show Overlay** — hide it when you don't need it
- **Lock Position (Click-Through)** — pins it in place and lets clicks pass through to whatever is underneath;
  turn it off to drag again
- **Size** — Small / Medium / Large / Extra Large / Super Large (22 / 28 / 34 / 42 / 52 points per key;
  Medium is about 440 × 195 points, Super Large about 820 × 365). It stays on screen when it grows.
- **Opacity** — 100% to 55%
- **Reset Position** — back to bottom center

## Known limitations

- With the old firmware, LOWER / RAISE aren't visible to the Mac; use **View Layer** instead.
- The F16–F19 layer signals also reach the app you're typing in. They do nothing in most apps; hiding them is on
  the roadmap.
- The laptop's built-in keyboard also lights keys — macOS reports both keyboards the same way.
- The right half's battery stays at its last reading if it loses its link to the left half (ZMK doesn't clear it).
- Battery levels need the keyboard connected over Bluetooth; USB alone doesn't report them.
- Password fields, and Terminal/iTerm with Secure Keyboard Entry on, hide keystrokes from all apps; the overlay
  pauses there.

## Roadmap

1. ✅ **Layer signals from the keyboard.** LOWER and RAISE are macros that also tap unused keys: F16/F17 for
   LOWER on/off, F18/F19 for RAISE on/off. The app switches the drawn layer (LOWER + RAISE together = ADJUST).
2. **Hide the F16–F19 signals** from other apps (needs Accessibility permission instead of Input Monitoring).
3. **Peek mode** — overlay stays hidden and fades in only if you hold a layer key for ~0.5s without pressing
   anything, so it helps only when you're stuck.
4. **Hesitation stats** — time from layer key to the next key, per key, shown as a heatmap of what you haven't
   memorized yet (only timings are kept, never what you type).
5. **Practice drills** — prompts a symbol or action and checks the answer, weighted toward weak keys.
6. **Keymap sync** — read the keymap straight from the keyboard (as ZMK Studio does) so the overlay follows
   your Studio edits automatically. Needs research.

## Project structure

```
zmkaid/
├── App/
│   ├── ZmkaidApp.swift        app entry, menu bar menu, --render flag
│   └── AppState.swift         pressed keys, encoders, settings, permission state
├── Keyboard/
│   ├── SofleLayout.swift      physical key positions (from ZMK's josefadamcik/sofle.dtsi)
│   ├── Keymap.swift           layer / binding / trigger model
│   └── MyKeymap.swift         your keymap (from ZMK Studio) and what each key sends to macOS
├── Input/
│   ├── KeyMonitor.swift       listen-only event tap: keys, modifiers, volume/mute, layer signals
│   ├── BatteryMonitor.swift   both halves' battery over Bluetooth (CoreBluetooth)
│   └── USBPresence.swift      is the left half plugged in by USB (IOKit)
└── Overlay/
    ├── OverlayController.swift  the floating panel (blur, position, size)
    ├── KeyboardView.swift       overlay layout + layer indicator + #Previews
    ├── KeyCapView.swift         keycaps and encoder knobs
    └── SnapshotRenderer.swift   renders PNGs for `make preview`
```
