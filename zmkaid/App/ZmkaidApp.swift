import SwiftUI

@main
struct ZmkaidApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("zmkaid", systemImage: "keyboard") {
            MenuContent(state: AppState.shared)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlay: OverlayController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        if let flag = args.firstIndex(of: "--render"), args.indices.contains(flag + 1) {
            SnapshotRenderer.render(into: URL(fileURLWithPath: args[flag + 1], isDirectory: true))
            exit(0)
        }
        overlay = OverlayController(state: .shared)
        AppState.shared.startLiveKeys()
        AppState.shared.startKeyboardStatus()
    }
}

struct MenuContent: View {
    @Bindable var state: AppState

    var body: some View {
        // Until the keyboard reports its layer, pick one here to study it.
        Picker("View Layer", selection: $state.activeLayer) {
            ForEach(state.keymap.layerIDs) { Text($0.rawValue.capitalized).tag($0) }
        }

        Divider()

        Toggle("Show Overlay", isOn: $state.overlayVisible)
        Toggle("Lock Position (Click-Through)", isOn: $state.locked)
        Picker("Size", selection: $state.size) {
            ForEach(OverlaySize.allCases) { Text($0.title).tag($0) }
        }
        Picker("Opacity", selection: $state.opacity) {
            ForEach([1.0, 0.85, 0.7, 0.55], id: \.self) { Text("\(Int($0 * 100))%").tag($0) }
        }
        Button("Reset Position") { state.resetPosition() }

        Divider()

        switch state.keyAccess {
        case .granted:
            Text("Live keys: on")
        case .waiting:
            Button("Allow Keystroke Access…") { state.openKeyAccessSettings() }
        case .needsRelaunch:
            Button("Relaunch to Turn On Live Keys") { state.relaunch() }
        }

        Divider()

        Button("Quit zmkaid") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
