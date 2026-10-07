import PullJoyCore
import SwiftUI

struct SettingsGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .background(Metrics.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Metrics.hairline))
    }
}

struct SettingRow<Control: View>: View {
    var label: String
    var description: String?
    var problem: String?
    var value: String?
    var badge: AnyView?
    @ViewBuilder var control: Control
    var onTap: (() -> Void)?

    init(
        label: String,
        description: String? = nil,
        problem: String? = nil,
        value: String? = nil,
        badge: AnyView? = nil,
        @ViewBuilder control: () -> Control = { EmptyView() },
        onTap: (() -> Void)? = nil
    ) {
        self.label = label
        self.description = description
        self.problem = problem
        self.value = value
        self.badge = badge
        self.onTap = onTap
        self.control = control()
    }

    var body: some View {
        let row = HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(label).font(.system(size: 13))
                    badge
                }
                if let description {
                    Text(description).font(.caption).foregroundStyle(.secondary)
                }
                if let problem {
                    Text(problem).font(.caption).foregroundStyle(Color.deletions)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let value {
                Text(value).font(.caption).monospacedDigit().foregroundStyle(.secondary)
            }
            control
            if onTap != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .contentShape(Rectangle())

        if let onTap {
            Button(action: onTap) { row }.buttonStyle(.plain)
        } else {
            row
        }
    }
}
