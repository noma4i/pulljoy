import PullJoyCore
import SwiftUI

/// The CI chip and the reason, right-aligned on the title line. The reason is
/// never clipped — the title yields instead, and every reason is short.
struct RowStatus: View {
    var ci: CIStatus
    var reason: Reason?

    var body: some View {
        HStack(spacing: 7) {
            CIChip(status: ci)
            if let reason {
                Text(reason.text)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(reason.accent.color)
            }
        }
        .fixedSize()
    }
}

struct CIChip: View {
    var status: CIStatus

    var body: some View {
        if let (symbol, accent, label) = appearance {
            Image(systemName: symbol)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(accent.color)
                .frame(width: 16, height: 16)
                .background(accent.tint, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                .help(label)
                .accessibilityLabel(label)
        }
    }

    private var appearance: (String, Accent, String)? {
        switch status {
        case .success: ("checkmark", .positive, "CI green")
        case .failure: ("xmark", .critical, "CI failing")
        case .pending: ("clock", .warning, "CI running")
        case .none: nil
        }
    }
}
