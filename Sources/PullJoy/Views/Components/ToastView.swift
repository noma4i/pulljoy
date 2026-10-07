import PullJoyCore
import SwiftUI

struct ToastView: View {
    var toast: SnoozeToast
    var onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(verbatim: "#\(toast.number) snoozed")
                .font(.caption)
                .fixedSize()
            Button("Undo", action: onUndo)
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Metrics.hairline))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
    }
}
