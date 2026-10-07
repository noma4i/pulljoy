import PullJoyCore
import SwiftUI

struct HeaderIconButton: View {
    var systemImage: String
    var help: String
    var spinning = false
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if spinning {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .frame(width: 32, height: 32)
            .background(hovering ? Metrics.faintFill : .clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(help)
        .accessibilityLabel(help)
        .onHover { hovering = $0 }
    }
}
