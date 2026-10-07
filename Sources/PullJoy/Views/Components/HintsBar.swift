import PullJoyCore
import SwiftUI

struct HintsBar: View {
    private let hints = [("↑↓", "Move"), ("⏎", "Review"), ("S", "Snooze"), ("R", "Refresh"), ("esc", "Close")]

    var body: some View {
        HStack(spacing: 14) {
            ForEach(hints, id: \.0) { key, label in
                HStack(spacing: 4) {
                    Pill(text: key, minWidth: 18)
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
