import AppKit
import PullJoyCore

extension AppModel {
    /// Handles a key pressed in the popup. Returns false to let it through —
    /// to a focused text field, say.
    func handleKey(keyCode: UInt16, characters: String, isTyping: Bool) -> Bool {
        // Esc closes the popup from anywhere, settings included.
        if keyCode == 53 {
            hidePopup()
            return true
        }
        guard !isTyping, !showSettings, snapshot.status != .signedOut else { return false }

        switch keyCode {
        case 125:
            moveSelection(by: 1)
            return true
        case 126:
            moveSelection(by: -1)
            return true
        case 36, 76:
            if let item = selectedItem { open(item) }
            return true
        default: break
        }

        switch characters.lowercased() {
        case "s":
            guard let item = selectedItem else { return true }
            // Straight to "until new activity": the key is for speed, not for
            // picking a duration. Still raises the toast so Undo works.
            if item.isSnoozed { unsnooze(item.id) } else { snooze(item, type: .untilActivity) }
            return true
        case "r":
            refresh()
            return true
        case "m":
            if let item = selectedItem { showRowMenu(item) }
            return true
        default:
            return false
        }
    }
}
