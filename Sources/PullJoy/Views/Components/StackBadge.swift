import PullJoyCore
import SwiftUI

struct StackBadge: View {
    var stack: StackPosition

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "square.stack.3d.up").font(.system(size: 8, weight: .semibold))
            Text(verbatim: "\(stack.index)/\(stack.total)").font(.system(size: 10, weight: .bold)).monospacedDigit()
        }
        .foregroundStyle(Color.link)
        .padding(.horizontal, 6)
        .frame(height: 16)
        .background(Accent.primary.tint, in: Capsule())
        .help("Part \(stack.index) of a stack of \(stack.total)")
    }
}
