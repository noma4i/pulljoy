import PullJoyCore
import SwiftUI

/// One pull request. Comfortable is two lines — the meta line over the title;
/// compact fits one, dropping the repository, the age and the diff counts,
/// the three that least often decide whether to open a PR.
struct PullRequestRow: View {
    var model: AppModel
    var row: StackCardRow
    var compact: Bool

    private var item: ClassifiedPullRequest { row.item }
    private var pr: PullRequest { row.item.pr }
    @State private var hovering = false
    @State private var overButton = false

    private var isActive: Bool { model.selectedID == item.id }
    private var showsActions: Bool { isActive || hovering }

    // The connector's geometry is derived from these, so changing the padding
    // or the avatar moves the line with it.
    private var avatarSize: CGFloat { compact ? 20 : 28 }
    private var leadingInset: CGFloat { compact ? 8 : 6 }
    private var rowHeight: CGFloat { compact ? 30 : 56 }

    // The comfortable row's two lines. Fixed heights, so the row's layout — and
    // the actions button laid over it — is arithmetic rather than measured.
    static let metaLineHeight: CGFloat = 15
    static let titleLineHeight: CGFloat = 20
    static let lineSpacing: CGFloat = 2
    static let contentHeight = metaLineHeight + lineSpacing + titleLineHeight

    var body: some View {
        HStack(spacing: compact ? 8 : 10) {
            AvatarView(login: pr.authorLogin, urlString: pr.authorAvatarURL, size: avatarSize)
            if compact { compactContent } else { comfortableContent }
        }
        .padding(.horizontal, leadingInset)
        .frame(height: rowHeight)
        .background(alignment: .leading) {
            StackConnector(row: row, avatarSize: avatarSize, compact: compact, fadeBelowLength: compact ? nil : 12)
                .frame(width: 2)
                .padding(.leading, leadingInset + avatarSize / 2 - 1)
        }
        .background(isActive ? Metrics.selection : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .onHover { inside in
            hovering = inside
            if inside { model.pointAt(item.id) }
        }
        .onTapGesture { model.open(item) }
        .linkCursor()
        // After the tap gesture, so a click on the button can only ever open
        // the menu, never the pull request as well.
        .overlay(alignment: .topTrailing) {
            if !compact { actionsButton }
        }
        .contextMenu { PRMenuItems(model: model, item: item) }
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onAppear { RowFrames.shared.frames[item.id] = geometry.frame(in: .global) }
                    .onChange(of: geometry.frame(in: .global)) { _, frame in RowFrames.shared.frames[item.id] = frame }
                    // A row scrolled out of the lazy list keeps no stale position
                    // for a menu to hang off.
                    .onDisappear { RowFrames.shared.frames[item.id] = nil }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .animation(.easeOut(duration: 0.12), value: isActive)
    }

    private var comfortableContent: some View {
        VStack(alignment: .leading, spacing: Self.lineSpacing) {
            HStack(spacing: 8) {
                // The owner is dropped: it is the same for most of the list.
                // It comes back on hover, where two same-named repos differ.
                Text(repositoryName(pr.repository))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help(pr.repository)
                    .layoutPriority(-1)
                HStack(spacing: 4) {
                    Text(verbatim: "#\(pr.number)")
                        .foregroundStyle(Color.link)
                        .monospacedDigit()
                    if let stack = item.stack { StackBadge(stack: stack) }
                }
                .fixedSize()
                MetaDot()
                // Also what the section is sorted by, so the top row says why
                // it is the top row. The `waiting` section has no such time.
                Text(item.waitingSince.map { formatWaiting($0, now: model.now) } ?? formatAge(pr.updatedAt, now: model.now))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .fixedSize()
                MetaDot()
                HStack(spacing: 4) {
                    Text(verbatim: "+\(pr.additions)").foregroundStyle(Color.additions)
                    Text(verbatim: "−\(pr.deletions)").foregroundStyle(Color.deletions)
                }
                .fontWeight(.semibold)
                .monospacedDigit()
                .fixedSize()
                Spacer(minLength: 0)
                // Holds the actions button's place; the button itself is laid
                // over the row, outside the tap that opens the pull request.
                Color.clear.frame(width: Self.menuButtonSize.width - 4)
            }
            .font(.caption)
            .frame(height: Self.metaLineHeight)

            HStack(spacing: 8) {
                Text(pr.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(pr.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                RowStatus(ci: pr.ciStatus, reason: item.reason)
            }
            .frame(height: Self.titleLineHeight)
        }
    }

    static let menuButtonSize = CGSize(width: 28, height: 26)

    /// The same menu the right-click and the M key open: a plain button, since
    /// a SwiftUI `Menu` answers only over its glyph. Always in the layout, shown
    /// while the row is hovered or selected, so moving between rows never reflows them.
    private var actionsButton: some View {
        Button {
            model.showRowMenu(item, true)
        } label: {
            Image(systemName: "ellipsis")
                .font(.title3.weight(.bold))
                .foregroundStyle(overButton ? .primary : .secondary)
                .frame(width: Self.menuButtonSize.width, height: Self.menuButtonSize.height)
                .background(overButton ? Metrics.faintFill : .clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .contentShape(Rectangle())
                .onHover { overButton = $0 }
        }
        .buttonStyle(.plain)
        .opacity(showsActions ? 1 : 0)
        .allowsHitTesting(showsActions)
        .help("Actions — M")
        .padding(.top, (rowHeight - Self.contentHeight) / 2 + (Self.metaLineHeight - Self.menuButtonSize.height) / 2)
        .padding(.trailing, leadingInset - 4)
        .transaction { $0.animation = nil }
    }

    private var compactContent: some View {
        HStack(spacing: 8) {
            Text(verbatim: "#\(pr.number)")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .help(pr.repository)
                .fixedSize()
            Text(pr.title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .help(pr.title)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let stack = item.stack {
                HStack(spacing: 3) {
                    Image(systemName: "square.stack.3d.up").font(.system(size: 9, weight: .semibold))
                    Text(verbatim: "\(stack.index)/\(stack.total)").font(.caption.weight(.semibold)).monospacedDigit()
                }
                .foregroundStyle(Color.link)
                .fixedSize()
            }
            RowStatus(ci: pr.ciStatus, reason: item.reason)
        }
    }
}
