import AppKit
import PullJoyCore
import SwiftUI

extension Color {
    init(light: NSColor, dark: NSColor) {
        self.init(
            nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            })
    }

    static let additions = Color(light: .rgb(20, 125, 65), dark: .rgb(118, 194, 139))
    static let deletions = Color(light: .rgb(195, 10, 50), dark: .rgb(255, 122, 126))
    static let link = Color(light: .rgb(11, 87, 208), dark: .rgb(99, 164, 251))
    static let warning = Color(light: .rgb(158, 87, 0), dark: .rgb(232, 176, 80))
}

extension NSColor {
    static func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> NSColor {
        NSColor(srgbRed: red / 255, green: green / 255, blue: blue / 255, alpha: 1)
    }
}

extension Accent {
    var color: Color {
        switch self {
        case .primary: .link
        case .critical: .deletions
        case .positive: .additions
        case .warning: .warning
        case .neutral: .secondary
        }
    }

    /// A translucent wash of the accent, for a badge with a fill and no border.
    /// A neutral fill would vanish on exactly the row the cursor tints.
    var tint: Color {
        color.opacity(0.14)
    }
}

enum Metrics {
    static let hairline = Color.primary.opacity(0.1)
    static let selection = Color.primary.opacity(0.07)
    static let faintFill = Color.primary.opacity(0.06)
    static let raised = Color.primary.opacity(0.025)
}

extension View {
    func linkCursor() -> some View {
        onContinuousHover { phase in
            switch phase {
            case .active: NSCursor.pointingHand.set()
            case .ended: NSCursor.arrow.set()
            }
        }
    }
}
