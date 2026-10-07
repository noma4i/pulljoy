import PullJoyCore
import SwiftUI

/// The line behind the avatars joining a pull request to its stack, drawn
/// inside the row that owns it. Solid to an adjacent member, dotted across
/// members that aren't shown, fading out where the chain carries on past the
/// list with nothing to meet.
struct StackConnector: View {
    var row: StackCardRow
    var avatarSize: CGFloat
    var compact: Bool
    /// Caps a fade below the avatar, where the segment is long enough that a
    /// full-length fade would smear across the row.
    var fadeBelowLength: CGFloat?

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let avatarTop = (height - avatarSize) / 2
            let avatarBottom = avatarTop + avatarSize
            ZStack(alignment: .top) {
                if row.lineAbove {
                    segment(gap: row.gapAbove, open: row.gapAboveOpen, fadeDownward: false)
                        .frame(height: avatarTop)
                }
                if row.lineBelow {
                    let length = row.gapBelowOpen ? min(fadeBelowLength ?? .infinity, height - avatarBottom) : height - avatarBottom
                    segment(gap: row.gapBelow, open: row.gapBelowOpen, fadeDownward: true)
                        .frame(height: length)
                        .offset(y: avatarBottom)
                }
            }
            .frame(width: 2, height: height, alignment: .top)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func segment(gap: Bool, open: Bool, fadeDownward: Bool) -> some View {
        let color = compact ? Color.accentColor.opacity(0.55) : Color(nsColor: .separatorColor)
        if !gap {
            Rectangle().fill(color)
        } else if open {
            Rectangle().fill(
                LinearGradient(
                    colors: [color, color.opacity(0)],
                    startPoint: fadeDownward ? .top : .bottom,
                    endPoint: fadeDownward ? .bottom : .top
                ))
        } else {
            DottedLine(fromBottom: fadeDownward)
                .stroke(color, style: StrokeStyle(lineWidth: 2, dash: compact ? [1.5, 1.5] : [2, 2], dashPhase: 2))
        }
    }
}

private struct DottedLine: Shape {
    var fromBottom: Bool

    func path(in rect: CGRect) -> Path {
        Path { path in
            let seam = fromBottom ? rect.maxY : rect.minY
            let avatar = fromBottom ? rect.minY : rect.maxY
            path.move(to: CGPoint(x: rect.midX, y: seam))
            path.addLine(to: CGPoint(x: rect.midX, y: avatar))
        }
    }
}
