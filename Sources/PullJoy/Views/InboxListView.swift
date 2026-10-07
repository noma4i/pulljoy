import PullJoyCore
import SwiftUI

struct InboxListView: View {
    var model: AppModel

    var body: some View {
        let sections = model.orderedSections
        let showEmptyState = model.snapshot.attentionCount == 0

        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    if showEmptyState {
                        EmptyStateView(health: InboxHealth(model.snapshot))
                            .frame(minHeight: sections.isEmpty ? 480 : 260)
                    }
                    ForEach(Array(sections.enumerated()), id: \.element.category) { index, section in
                        if showEmptyState || index > 0 { Divider() }
                        SectionView(model: model, category: section.category, items: section.items)
                    }
                }
            }
            .scrollIndicators(.automatic)
            .coordinateSpace(name: "list")
            .onAppear { model.ensureSelection() }
            .onChange(of: model.visibleItems.map(\.id)) { model.ensureSelection() }
            .onChange(of: model.scrollRequest) {
                guard let id = model.selectedID else { return }
                proxy.scrollTo(id)
            }
        }
    }
}

struct SectionView: View {
    var model: AppModel
    var category: InboxSection
    var items: [ClassifiedPullRequest]

    var body: some View {
        let open = !model.collapsed.contains(category)
        let compact = model.settings.layout == .compact

        Section {
            if open {
                // No spacing between rows: the stack line runs from row to
                // row, and any gap would break it.
                VStack(spacing: 0) {
                    ForEach(sectionRows(items)) { row in
                        PullRequestRow(model: model, row: row, compact: compact)
                            .id(row.id)
                    }
                }
                .padding(.horizontal, 8)
            }
        } header: {
            Button {
                model.toggleSection(category)
            } label: {
                HStack(spacing: 8) {
                    Text(category.title)
                        .font(.caption.weight(.semibold))
                    if compact {
                        Text(verbatim: "\(items.count)")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    } else {
                        Pill(text: "\(items.count)", minWidth: 18, capsule: true)
                    }
                    Spacer()
                    Image(systemName: open ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 15)
                }
                .padding(.top, 14)
                .padding(.bottom, 6)
                .padding(.horizontal, compact ? 16 : 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // The cards scroll under a pinned heading, so it needs a backdrop.
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .padding(.bottom, open ? 8 : 0)
    }
}

struct EmptyStateView: View {
    var health: InboxHealth

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(color)
            Text(health.emptyTitle)
                .font(.system(size: 13, weight: .semibold))
                .padding(.top, 14)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 3)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var symbol: String {
        switch health {
        case .failed: "icloud.slash"
        case .partial: "eye.slash"
        case .clear: "checkmark"
        }
    }

    private var color: Color {
        switch health {
        case .failed: .deletions
        case .partial: .warning
        case .clear: .additions
        }
    }

    private var detail: String {
        switch health {
        case .failed: "What you see may be stale or incomplete."
        case .partial(let notice): "Up to date for everything else, but \(notice) — their pull requests aren't shown."
        case .clear: "Nothing waiting on you. Great job, buddy."
        }
    }
}
