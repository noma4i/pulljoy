import PullJoyCore
import SwiftUI

/// A small rounded count or keycap: a faint wash with secondary text.
struct Pill: View {
    var text: String
    var weight: Font.Weight = .semibold
    var minWidth: CGFloat = 0
    var capsule = false

    var body: some View {
        Text(text)
            .font(.caption.weight(weight))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .frame(minWidth: minWidth)
            .background(Metrics.faintFill, in: RoundedRectangle(cornerRadius: capsule ? 20 : 5, style: .continuous))
    }
}
