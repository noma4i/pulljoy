import PullJoyCore
import SwiftUI

struct PaneHeader: View {
    var back: String
    var title: String
    var onBack: () -> Void

    var body: some View {
        ZStack {
            Text(title).font(.system(size: 13, weight: .semibold))
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                        Text(back)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.link)
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 52)
        .background(Metrics.raised)
    }
}
