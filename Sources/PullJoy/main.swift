import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel?
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
            if let path = ProcessInfo.processInfo.environment["PULLJOY_SNAPSHOT"] {
                Snapshot.run(to: path)
                return
            }
        #endif
        let model = AppModel()
        self.model = model
        statusItem = StatusItemController(model: model)
        model.launch()
        #if DEBUG
            if ProcessInfo.processInfo.environment["PULLJOY_OPEN_ON_LAUNCH"] == "1" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [statusItem] in statusItem?.toggle() }
            }
        #endif
    }

    /// Frees the MCP port before the process goes, so a relaunch finds it free.
    func applicationWillTerminate(_ notification: Notification) {
        model?.willTerminate()
    }
}

/// Never shown, since the app is an accessory, but AppKit routes ⌘X ⌘C ⌘V ⌘A to text fields through it.
@MainActor
func editMenu() -> NSMenu {
    let edit = NSMenu(title: "Edit")
    edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
    edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
    edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
    edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
    let item = NSMenuItem()
    item.submenu = edit
    let menu = NSMenu()
    menu.addItem(item)
    return menu
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.mainMenu = editMenu()
    let delegate = AppDelegate()
    app.delegate = delegate
    // A menu-bar app: no Dock icon, no entry in the app switcher.
    app.setActivationPolicy(.accessory)
    // `NSApplication.delegate` is weak, and ARC may end a local's lifetime at
    // its last use — so pin it until `run()` returns.
    withExtendedLifetime(delegate) { app.run() }
}
