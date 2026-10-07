import PullJoyCore
import SwiftUI

struct ToastView: View {
    var toast: Toast
    var onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(message)
                .font(.caption)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            if toast.canUndo {
                Button("Undo", action: onUndo)
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: 380)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Metrics.hairline))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
    }

    private var message: String {
        switch toast.kind {
        case .snoozed: "#\(toast.number) snoozed"
        case .unsubscribed: "#\(toast.number) unsubscribed"
        case .failure(let text): "Couldn't unsubscribe #\(toast.number): \(text)"
        }
    }
}
