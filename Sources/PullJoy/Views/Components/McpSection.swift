import PullJoyCore
import PullJoyKit
import SwiftUI

struct McpSection: View {
    var model: AppModel

    var body: some View {
        let enabled = model.settings.mcpServerEnabled
        let status = model.mcpStatus

        VStack(alignment: .leading, spacing: 0) {
            SettingRow(
                label: "MCP server", description: "Lets Claude and other local agents read this inbox.",
                badge: enabled ? badge(status) : nil
            ) {
                Toggle(
                    "MCP server",
                    isOn: Binding(
                        get: { enabled },
                        set: { value in model.updateSettings { $0.mcpServerEnabled = value } }
                    )
                )
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
            }
            if enabled {
                detail(status)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
        }
    }

    /// Whether the server is actually up, which is not what the switch says:
    /// the setting stays on when the port is taken.
    private func badge(_ status: MCPServerStatus) -> AnyView {
        let (text, color): (String, Color) =
            if status.error != nil {
                ("Not running", Color.deletions)
            } else if !status.listening {
                ("Starting…", .secondary)
            } else {
                ("Running", Color.additions)
            }
        return AnyView(
            Text(text)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(color.opacity(0.14), in: Capsule())
        )
    }

    @ViewBuilder
    private func detail(_ status: MCPServerStatus) -> some View {
        if let error = status.error {
            Text(error).font(.caption).foregroundStyle(Color.deletions)
        } else if status.listening {
            HStack(spacing: 8) {
                // Monospaced: it is read character by character and typed
                // into another program's config.
                Text(model.mcpURLString)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(1)
                Spacer()
                Link(destination: AppConfig.mcpSetupURL) {
                    HStack(spacing: 3) {
                        Text("Setup instructions")
                        Image(systemName: "arrow.up.right.square")
                    }
                    .font(.caption.weight(.medium))
                }
                .linkCursor()
                .help(AppConfig.mcpSetupURL.absoluteString)
            }
        }
    }
}
